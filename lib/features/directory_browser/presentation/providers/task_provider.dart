import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

enum FileTaskStatus { pending, running, completed, error, cancelled }

class FileTask {
  final String id;
  final String title;
  final String subtitle;
  final double progress; // 0.0 to 1.0
  final FileTaskStatus status;
  final String? errorMessage;
  final bool isCancelled;
  final String? currentItem;
  final int processedCount;
  final int totalCount;
  final List<String> logs;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const FileTask({
    required this.id,
    required this.title,
    required this.subtitle,
    this.progress = 0.0,
    this.status = FileTaskStatus.pending,
    this.errorMessage,
    this.isCancelled = false,
    this.currentItem,
    this.processedCount = 0,
    this.totalCount = 0,
    this.logs = const [],
    required this.createdAt,
    this.startedAt,
    this.completedAt,
  });

  /// Computed estimated remaining duration based on elapsed time and progress.
  Duration? get estimatedRemaining {
    if (startedAt == null || progress <= 0 || progress >= 1.0) return null;
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
    String? currentItem,
    int? processedCount,
    int? totalCount,
    List<String>? logs,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return FileTask(
      id: id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      isCancelled: isCancelled ?? this.isCancelled,
      currentItem: currentItem ?? this.currentItem,
      processedCount: processedCount ?? this.processedCount,
      totalCount: totalCount ?? this.totalCount,
      logs: logs ?? this.logs,
      createdAt: createdAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Convert to a JSON-serializable map for history storage.
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'progress': progress,
    'status': status.name,
    'errorMessage': errorMessage,
    'currentItem': currentItem,
    'processedCount': processedCount,
    'totalCount': totalCount,
    'logs': logs,
    'createdAt': createdAt.toIso8601String(),
    'startedAt': startedAt?.toIso8601String(),
    'completedAt': completedAt?.toIso8601String(),
  };
}

class TaskNotifier extends Notifier<List<FileTask>> {
  static const int defaultMaxConcurrent = 3;
  int _maxConcurrent = defaultMaxConcurrent;

  int get maxConcurrent => _maxConcurrent;
  set maxConcurrent(int value) {
    _maxConcurrent = value.clamp(1, 10);
    _promoteNextQueued();
  }

  @override
  List<FileTask> build() => [];

  /// Currently running tasks.
  List<FileTask> get runningTasks =>
      state.where((t) => t.status == FileTaskStatus.running).toList();

  /// Pending (queued) tasks.
  List<FileTask> get pendingTasks =>
      state.where((t) => t.status == FileTaskStatus.pending).toList();

  /// Whether any task has an error.
  bool get hasErrors =>
      state.any((t) => t.status == FileTaskStatus.error);

  /// Aggregate progress across all running tasks (0.0 to 1.0).
  double get totalProgress {
    final running = runningTasks;
    if (running.isEmpty) return 0.0;
    double sum = 0.0;
    for (final t in running) {
      sum += t.progress;
    }
    return sum / running.length;
  }

  /// Whether any task is currently active (running or pending).
  bool get hasActiveTasks =>
      state.any((t) =>
          t.status == FileTaskStatus.running ||
          t.status == FileTaskStatus.pending);

  /// Add a new task. Returns the task ID.
  /// Task starts as `running` if under concurrency limit, else `pending`.
  String addTask({required String title, required String subtitle, int totalCount = 0}) {
    final id = const Uuid().v4();
    final now = DateTime.now();
    final canRun = runningTasks.length < _maxConcurrent;

    state = [
      ...state,
      FileTask(
        id: id,
        title: title,
        subtitle: subtitle,
        totalCount: totalCount,
        status: canRun ? FileTaskStatus.running : FileTaskStatus.pending,
        createdAt: now,
        startedAt: canRun ? now : null,
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

  /// Update the current item being processed.
  void updateCurrentItem(String id, String itemName) {
    state = state.map((task) {
      if (task.id == id) {
        return task.copyWith(currentItem: itemName);
      }
      return task;
    }).toList();
  }

  /// Update processed and total item counts.
  void updateItemCounts(String id, int processed, int total) {
    state = state.map((task) {
      if (task.id == id) {
        return task.copyWith(processedCount: processed, totalCount: total);
      }
      return task;
    }).toList();
  }

  /// Append a log line to a task's log buffer (capped at 200 lines).
  void addLog(String id, String message) {
    state = state.map((task) {
      if (task.id == id) {
        final timestamp = DateTime.now().toString().substring(11, 19);
        final newLogs = List<String>.from(task.logs);
        newLogs.add('[$timestamp] $message');
        if (newLogs.length > 200) {
          newLogs.removeRange(0, newLogs.length - 200);
        }
        return task.copyWith(logs: newLogs);
      }
      return task;
    }).toList();
  }

  /// Mark task as completed.
  void completeTask(String id) {
    state = state.map((task) {
      if (task.id == id) {
        return task.copyWith(
          status: FileTaskStatus.completed,
          progress: 1.0,
          completedAt: DateTime.now(),
        );
      }
      return task;
    }).toList();
    _promoteNextQueued();
  }

  /// Mark task as failed.
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
    _promoteNextQueued();
  }

  /// Cancel a single task.
  void cancelTask(String id) {
    state = state.map((task) {
      if (task.id == id && (task.status == FileTaskStatus.running || task.status == FileTaskStatus.pending)) {
        return task.copyWith(
          isCancelled: true,
          status: FileTaskStatus.cancelled,
          completedAt: DateTime.now(),
        );
      }
      return task;
    }).toList();
    _promoteNextQueued();
  }

  /// Cancel all running + pending tasks.
  void cancelAllTasks() {
    state = state.map((task) {
      if (task.status == FileTaskStatus.running || task.status == FileTaskStatus.pending) {
        return task.copyWith(
          isCancelled: true,
          status: FileTaskStatus.cancelled,
          completedAt: DateTime.now(),
        );
      }
      return task;
    }).toList();
  }

  /// Check if a task has been cancelled.
  bool isTaskCancelled(String id) {
    return state.any((t) => t.id == id && t.isCancelled);
  }

  /// Remove a specific task from the active list.
  void removeTask(String id) {
    state = state.where((task) => task.id != id).toList();
  }

  /// Remove all completed/errored/cancelled tasks from the list.
  void clearFinished() {
    state = state.where((t) =>
        t.status == FileTaskStatus.running ||
        t.status == FileTaskStatus.pending).toList();
  }

  /// Promote next pending task to running if under concurrency limit.
  void _promoteNextQueued() {
    final runCount = runningTasks.length;
    if (runCount >= _maxConcurrent) return;

    final pending = pendingTasks;
    if (pending.isEmpty) return;

    final slotsAvailable = _maxConcurrent - runCount;
    final toPromote = pending.take(slotsAvailable).toList();
    final now = DateTime.now();

    state = state.map((task) {
      if (toPromote.any((p) => p.id == task.id)) {
        return task.copyWith(
          status: FileTaskStatus.running,
          startedAt: now,
        );
      }
      return task;
    }).toList();
  }
}

final taskProvider = NotifierProvider<TaskNotifier, List<FileTask>>(() {
  return TaskNotifier();
});
