import 'dart:async';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_history_provider.dart';
import 'package:uuid/uuid.dart';

enum FileTaskStatus { pending, running, completed, error, cancelled }

class FileTask { // in bytes per second

  const FileTask({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.createdAt, double progress = 0.0,
    this.status = FileTaskStatus.pending,
    this.errorMessage,
    this.isCancelled = false,
    this.isSyncing = false,
    this.currentItem,
    this.processedCount = 0,
    this.totalCount = 0,
    this.processedSizeBytes = 0,
    this.totalSizeBytes = 0,
    this.logs = const [],
    this.startedAt,
    this.completedAt,
    this.sourcePaths,
    this.targetPath,
    this.isLight = false,
    this.speed,
  }) : _rawProgress = progress;
  final String id;
  final String title;
  final String subtitle;
  final double _rawProgress; // internal storage for progress
  final FileTaskStatus status;
  final String? errorMessage;
  final bool isCancelled;
  final bool isSyncing;
  final String? currentItem;
  final int processedCount;
  final int totalCount;
  final int processedSizeBytes;
  final int totalSizeBytes;
  final List<String> logs;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final List<String>? sourcePaths;
  final String? targetPath;
  final bool isLight;
  final double? speed;

  /// Progress value (0.0 to 1.0).
  /// Clamped to 0.99 during the syncing phase to prevent the UI from
  /// reporting completion before the hardware has finished writing.
  double get progress {
    if (isSyncing && _rawProgress >= 0.99) return 0.99;
    return _rawProgress;
  }

  /// Computed estimated remaining duration based on elapsed time and progress.
  Duration? get estimatedRemaining {
    if (isSyncing) return null; // During sync, ETA is meaningless
    if (startedAt == null || progress <= 0.001 || progress >= 1.0) return null;

    final elapsed = DateTime.now().difference(startedAt!);
    final totalEstimated = elapsed.inMilliseconds / progress;
    final remaining = totalEstimated - elapsed.inMilliseconds;

    if (remaining <= 0) return null;
    return Duration(milliseconds: remaining.round());
  }

  FileTask copyWith({
    String? title,
    String? subtitle,
    double? progress,
    FileTaskStatus? status,
    String? errorMessage,
    bool? isCancelled,
    bool? isSyncing,
    String? currentItem,
    int? processedCount,
    int? totalCount,
    int? processedSizeBytes,
    int? totalSizeBytes,
    List<String>? logs,
    DateTime? startedAt,
    DateTime? completedAt,
    List<String>? sourcePaths,
    String? targetPath,
    bool? isLight,
    double? speed,
  }) {
    return FileTask(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      progress: progress ?? _rawProgress,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      isCancelled: isCancelled ?? this.isCancelled,
      isSyncing: isSyncing ?? this.isSyncing,
      currentItem: currentItem ?? this.currentItem,
      processedCount: processedCount ?? this.processedCount,
      totalCount: totalCount ?? this.totalCount,
      processedSizeBytes: processedSizeBytes ?? this.processedSizeBytes,
      totalSizeBytes: totalSizeBytes ?? this.totalSizeBytes,
      logs: logs ?? this.logs,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      sourcePaths: sourcePaths ?? this.sourcePaths,
      targetPath: targetPath ?? this.targetPath,
      isLight: isLight ?? this.isLight,
      speed: speed ?? this.speed,
    );
  }
}

/// Manages background file operations with concurrency limits.
class TaskNotifier extends Notifier<List<FileTask>> {
  int _maxConcurrent = 3;

  /// Map of active isolates for hard-kill cancellation.
  final Map<String, Isolate> _taskIsolates = {};

  /// Map of task send ports for graceful cancellation.
  final Map<String, SendPort> _taskPorts = {};

  /// Map of timers for automatic removal of finished tasks.
  final Map<String, Timer> _removalTimers = {};

  /// Trackers for speed calculation
  final Map<String, DateTime> _lastUpdateTimes = {};
  final Map<String, int> _lastByteCounts = {};

  @override
  List<FileTask> build() {
    ref.onDispose(() {
      for (final timer in _removalTimers.values) {
        timer.cancel();
      }
      _removalTimers.clear();
    });
    return [];
  }

  /// Getter and setter for max concurrency.
  int get maxConcurrent => _maxConcurrent;
  set maxConcurrent(int value) {
    if (_maxConcurrent != value) {
      _maxConcurrent = value;
      _processQueue();
    }
  }

  /// The list of currently running heavy tasks (excluding light tasks).
  List<FileTask> get runningHeavyTasks => state
      .where((t) => t.status == FileTaskStatus.running && !t.isLight)
      .toList();

  /// ALL currently running tasks (including light ones).
  List<FileTask> get runningTasks =>
      state.where((t) => t.status == FileTaskStatus.running).toList();

  /// Whether any heavy task is currently active (running or pending).
  bool get hasActiveHeavyTasks => state.any(
    (t) =>
        !t.isLight &&
        (t.status == FileTaskStatus.running ||
            t.status == FileTaskStatus.pending),
  );

  /// Pending (queued) tasks.
  List<FileTask> get pendingTasks =>
      state.where((t) => t.status == FileTaskStatus.pending).toList();

  /// Whether any task currently has an error.
  bool get hasErrors => state.any((t) => t.status == FileTaskStatus.error);

  /// Recently completed tasks for the history panel.
  List<FileTask> get historyTasks =>
      state
          .where(
            (t) =>
                t.status == FileTaskStatus.completed ||
                t.status == FileTaskStatus.error ||
                t.status == FileTaskStatus.cancelled,
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  /// Aggregate progress across all running and pending tasks (0.0 to 1.0).
  double get totalProgress {
    final active = state
        .where(
          (t) =>
              t.status == FileTaskStatus.running ||
              t.status == FileTaskStatus.pending,
        )
        .toList();
    if (active.isEmpty) return 0;

    // ignore: omit_local_variable_types, prefer_int_literals
    double sum = 0.0;
    for (final t in active) {
      sum += t.progress;
    }
    return sum / active.length;
  }

  /// Whether any task is currently active (running or pending).
  bool get hasActiveTasks => state.any(
    (t) =>
        t.status == FileTaskStatus.running ||
        t.status == FileTaskStatus.pending,
  );

  /// Add a new task. Returns the task ID.
  /// Heavy tasks start as `running` if under concurrency limit, else `pending`.
  /// Light tasks (Rename, Delete, New Folder) always start as `running`.
  String addTask({
    required String title,
    required String subtitle,
    int totalCount = 0,
    int totalSizeBytes = 0,
    List<String>? sourcePaths,
    String? targetPath,
    bool isLight = false,
  }) {
    final id = const Uuid().v4();
    final now = DateTime.now();

    // Light tasks always run. Heavy tasks check concurrency limit.
    final canRun = isLight || runningHeavyTasks.length < _maxConcurrent;

    state = [
      ...state,
      FileTask(
        id: id,
        title: title,
        subtitle: subtitle,
        totalCount: totalCount,
        totalSizeBytes: totalSizeBytes,
        status: canRun ? FileTaskStatus.running : FileTaskStatus.pending,
        createdAt: now,
        startedAt: canRun ? now : null,
        sourcePaths: sourcePaths,
        targetPath: targetPath,
        isLight: isLight,
      ),
    ];
    return id;
  }

  /// Update progress of a task (0.0 to 1.0).
  void updateProgress(String id, double progress) {
    state = state.map((task) {
      if (task.id == id) {
        return task.copyWith(progress: progress.clamp(0.0, 1.0));
      }
      return task;
    }).toList();
  }

  /// Check if a task is cancelled.
  bool isTaskCancelled(String id) {
    if (state.isEmpty) return false;
    final task = state.where((t) => t.id == id).firstOrNull;
    if (task == null) return false;
    return task.status == FileTaskStatus.cancelled || task.isCancelled;
  }

  /// Update the current item being processed.
  void updateCurrentItem(String id, String name) {
    state = state.map((task) {
      if (task.id == id) {
        return task.copyWith(currentItem: name);
      }
      return task;
    }).toList();
  }

  /// Update item counts.
  void updateItemCounts(String id, int processed, int total) {
    state = state.map((task) {
      if (task.id == id) {
        return task.copyWith(processedCount: processed, totalCount: total);
      }
      return task;
    }).toList();
  }

  /// Update byte counts.
  void updateByteCounts(String id, int processed, int total) {
    final now = DateTime.now();
    final lastTime = _lastUpdateTimes[id];
    final lastBytes = _lastByteCounts[id] ?? 0;

    double? speed;
    if (lastTime != null) {
      final diff = now.difference(lastTime).inMilliseconds;
      if (diff > 500) {
        // Update speed every 500ms
        final byteDiff = processed - lastBytes;
        speed = (byteDiff * 1000) / diff; // bytes per second
        _lastUpdateTimes[id] = now;
        _lastByteCounts[id] = processed;
      }
    } else {
      _lastUpdateTimes[id] = now;
      _lastByteCounts[id] = processed;
    }

    state = state.map((task) {
      if (task.id == id) {
        return task.copyWith(
          processedSizeBytes: processed,
          totalSizeBytes: total,
          speed: speed ?? task.speed,
        );
      }
      return task;
    }).toList();
  }

  /// Mark task as syncing (waiting for OS write-cache).
  void setSyncing(String id, [bool syncing = true]) {
    state = [
      for (final task in state)
        if (task.id == id) task.copyWith(isSyncing: syncing) else task,
    ];
  }

  /// Add a log message to the task.
  void addLog(String id, String message) {
    state = state.map((task) {
      if (task.id == id) {
        return task.copyWith(logs: [...task.logs, message]);
      }
      return task;
    }).toList();
  }

  /// Complete a task and trigger next pending if possible.
  void completeTask(String id) {
    FileTask? completedTask;
    state = state.map((task) {
      if (task.id == id) {
        completedTask = task.copyWith(
          status: FileTaskStatus.completed,
          completedAt: DateTime.now(),
          progress: 1,
        );
        return completedTask!;
      }
      return task;
    }).toList();
    if (completedTask != null) {
      _startAutoRemovalTimer(id);
    }

    _taskPorts.remove(id);
    _taskIsolates.remove(id);
    _lastUpdateTimes.remove(id);
    _lastByteCounts.remove(id);
    _processQueue();
  }

  /// Fail a task and trigger next pending if possible.
  void failTask(String id, String error) {
    state = state.map((task) {
      if (task.id == id) {
        return task.copyWith(
          status: FileTaskStatus.error,
          errorMessage: error,
          completedAt: DateTime.now(),
        );
      }
      return task;
    }).toList();

    _startAutoRemovalTimer(id);

    _taskPorts.remove(id);
    _taskIsolates.remove(id);
    _lastUpdateTimes.remove(id);
    _lastByteCounts.remove(id);
    _processQueue();
  }

  /// Register an isolate's send port and handle for cancellation.
  void registerPort(String id, SendPort port, {Isolate? isolate}) {
    // If task was cancelled before port registered, kill immediately
    final task = state.where((t) => t.id == id).firstOrNull;
    if (task != null && task.status == FileTaskStatus.cancelled) {
      port.send({'command': 'cancel', 'taskId': id});
      isolate?.kill(priority: Isolate.immediate);
      return;
    }

    _taskPorts[id] = port;
    if (isolate != null) {
      _taskIsolates[id] = isolate;
    }
  }

  /// Cancel a running or pending task.
  Future<void> cancelTask(String id) async {
    final task = state.where((t) => t.id == id).firstOrNull;
    if (task == null) return;

    state = state.map((t) {
      if (t.id == id) {
        return t.copyWith(
          status: FileTaskStatus.cancelled,
          isCancelled: true,
          completedAt: DateTime.now(),
        );
      }
      return t;
    }).toList();

    // 1. Graceful: Send cancel signal
    final port = _taskPorts[id];
    if (port != null) {
      port.send({'command': 'cancel', 'taskId': id});
    }

    // 2. Hard-Kill: Ensure isolate is dead after short delay
    final isolate = _taskIsolates[id];
    if (isolate != null) {
      // Delay slightly to allow graceful cleanup (e.g. deleting partial file)
      await Future<void>.delayed(const Duration(milliseconds: 200));
      isolate.kill(priority: Isolate.immediate);
    }

    _taskPorts.remove(id);
    _taskIsolates.remove(id);
    _lastUpdateTimes.remove(id);
    _lastByteCounts.remove(id);
    _processQueue();
  }

  /// Cancel all running and pending tasks.
  Future<void> cancelAllTasks() async {
    final activeIds = state
        .where(
          (t) =>
              t.status == FileTaskStatus.running ||
              t.status == FileTaskStatus.pending,
        )
        .map((t) => t.id)
        .toList();

    for (final id in activeIds) {
      await cancelTask(id);
    }
  }

  /// Remove a completed/failed task from history.
  void removeTask(String id) {
    state = state.where((t) => t.id != id).toList();
  }

  /// Clear all finished tasks.
  void clearHistory() {
    state = state
        .where(
          (t) =>
              t.status == FileTaskStatus.running ||
              t.status == FileTaskStatus.pending,
        )
        .toList();
  }

  /// Manually trigger a refresh to recalculate ETAs and notify UI.
  void refreshTasks() {
    state = List<FileTask>.from(state);
  }

  /// Start next pending tasks if under limit.
  void _processQueue() {
    while (runningHeavyTasks.length < _maxConcurrent &&
        pendingTasks.isNotEmpty) {
      final nextTask = pendingTasks.first;
      state = state.map((t) {
        if (t.id == nextTask.id) {
          return t.copyWith(
            status: FileTaskStatus.running,
            startedAt: DateTime.now(),
          );
        }
        return t;
      }).toList();
    }
  }

  /// Start a 3-second timer to move a finished task to history.
  void _startAutoRemovalTimer(String id) {
    if (_removalTimers.containsKey(id)) return;

    _removalTimers[id] = Timer(const Duration(seconds: 3), () {
      final task = state.where((t) => t.id == id).firstOrNull;
      if (task != null &&
          (task.status == FileTaskStatus.completed ||
              task.status == FileTaskStatus.error)) {
        // Move to history
        ref.read(taskHistoryProvider.notifier).addEntry(task);
        // Remove from active list
        removeTask(id);
      }
      _removalTimers.remove(id);
    });
  }
}

/// Provider for the global TaskNotifier.
final taskProvider = NotifierProvider<TaskNotifier, List<FileTask>>(
  TaskNotifier.new,
);
