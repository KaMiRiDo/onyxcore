import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/downloader_process_wrapper.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_history_provider.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/core/utils/process_utils.dart';

enum DownloadStatus { pending, running, cancelling, completed, error, cancelled }

class DownloadTask {
  final String id;
  final String url;
  final String destination;
  final String title;
  final String downloadType;
  final DownloadStatus status;
  final double progress; // 0.0 to 1.0
  final String speed;
  final String eta;
  final String totalSize;
  final String? error;
  final Process? process;
  final List<String> logs;
  final DateTime createdAt;
  final DateTime? completedAt;

  const DownloadTask({
    required this.id,
    required this.url,
    required this.destination,
    required this.title,
    this.downloadType = 'generic',
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.speed = '',
    this.eta = '',
    this.totalSize = '',
    this.error,
    this.process,
    this.logs = const [],
    required this.createdAt,
    this.completedAt,
  });

  DownloadTask copyWith({
    String? title,
    String? downloadType,
    DownloadStatus? status,
    double? progress,
    String? speed,
    String? eta,
    String? totalSize,
    String? error,
    Process? process,
    List<String>? logs,
    DateTime? completedAt,
  }) {
    return DownloadTask(
      id: id,
      url: url,
      destination: destination,
      title: title ?? this.title,
      downloadType: downloadType ?? this.downloadType,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      speed: speed ?? this.speed,
      eta: eta ?? this.eta,
      totalSize: totalSize ?? this.totalSize,
      error: error ?? this.error,
      process: process ?? this.process,
      logs: logs ?? this.logs,
      createdAt: createdAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class DownloadTaskNotifier extends Notifier<List<DownloadTask>>
    with WindowListener {
  final _uuid = const Uuid();

  @override
  List<DownloadTask> build() {
    windowManager.addListener(this);
    ref.onDispose(() {
      windowManager.removeListener(this);
    });
    return [];
  }

  @override
  void onWindowClose() {
    // Zombie Process Prevention — must be sync since window is closing
    for (final task in state) {
      if ((task.status == DownloadStatus.running || task.status == DownloadStatus.cancelling) && task.process != null) {
        ProcessUtils.killProcessTreeSync(task.process!.pid);
      }
    }
  }

  final Map<String, Map<String, dynamic>> _taskArgs = {};

  int get _maxConcurrent {
    return ref.read(settingsProvider).value?.maxConcurrentDownloads ?? 3;
  }

  void _processQueue() async {
    final runningCount = state.where((t) => t.status == DownloadStatus.running).length;
    if (runningCount >= _maxConcurrent) return;

    final pendingTasks = state.where((t) => t.status == DownloadStatus.pending).toList();
    if (pendingTasks.isEmpty) return;

    final tasksToStart = pendingTasks.take(_maxConcurrent - runningCount).toList();

    for (final task in tasksToStart) {
      _startProcessForTask(task.id);
    }
  }

  void _startProcessForTask(String id) async {
    _updateTask(id, status: DownloadStatus.running);
    final args = _taskArgs[id];
    if (args == null) return;

    StreamSubscription? stdoutSub;
    StreamSubscription? stderrSub;

    try {
      final process = await MediaDownloaderBackend.startDownload(
        url: args['url'] as String,
        destination: args['destination'] as String,
        title: args['title'] as String?,
        format: args['format'] as MediaFormat?,
        audioOnly: args['audioOnly'] as bool? ?? false,
        mute: args['mute'] as bool? ?? false,
        galleryIndex: args['galleryIndex'] as int?,
        engine: args['engine'] as String? ?? 'auto',
        isPlaylist: args['isPlaylist'] as bool? ?? false,
        isProfile: args['isProfile'] as bool? ?? false,
        browser: args['browser'] as String?,
        isZip: args['isZip'] as bool? ?? false,
        filterType: args['filterType'] as String?,
        totalItems: args['totalItems'] as int?,
      );

      _updateTask(id, process: process);

      stdoutSub = process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((data) {
        _parseProgress(id, data);
        _appendLog(id, data);
      });

      stderrSub = process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((data) {
        _appendLog(id, data);
      });

      final exitCode = await process.exitCode;

      if (exitCode == 0) {
        _updateTask(id, status: DownloadStatus.completed, progress: 1.0, completedAt: DateTime.now());
      } else {
        final currentTask = state.firstWhere((t) => t.id == id);
        if (currentTask.status != DownloadStatus.cancelled) {
          _updateTask(id,
              status: DownloadStatus.error,
              error: 'Process exited with code $exitCode',
              completedAt: DateTime.now());
        }
      }
    } catch (e) {
      _updateTask(id, status: DownloadStatus.error, error: e.toString(), completedAt: DateTime.now());
    } finally {
      stdoutSub?.cancel();
      stderrSub?.cancel();
      _processQueue();
    }
  }

  final Map<String, int> _downloadedCounts = {};

  void startDownload({
    required String url,
    required String destination,
    required String title,
    String downloadType = 'generic',
    MediaFormat? format,
    bool audioOnly = false,
    bool mute = false,
    int? galleryIndex,
    String engine = 'auto',
    bool isPlaylist = false,
    bool isProfile = false,
    String? browser,
    bool isZip = false,
    String? filterType,
    int? totalItems,
  }) {

    final id = _uuid.v4();
    final newTask = DownloadTask(
      id: id,
      url: url,
      destination: destination,
      title: title,
      downloadType: downloadType,
      status: DownloadStatus.pending,
      createdAt: DateTime.now(),
    );

    _taskArgs[id] = {
      'url': url,
      'destination': destination,
      'title': title,
      'format': format,
      'audioOnly': audioOnly,
      'mute': mute,
      'galleryIndex': galleryIndex,
      'engine': engine,
      'isPlaylist': isPlaylist,
      'isProfile': isProfile,
      'browser': browser,
      'isZip': isZip,
      'filterType': filterType,
      'totalItems': totalItems,
    };

    if (totalItems != null) {
      _downloadedCounts[id] = 0;
    }

    state = [...state, newTask];
    _processQueue();
  }

  Future<void> _cleanupTempFiles(String destination) async {
    try {
      final dir = Directory(destination);
      if (await dir.exists()) {
        final files = dir.listSync(recursive: true);
        for (final file in files) {
          if (file is File) {
            if (file.path.endsWith('.temp') || file.path.endsWith('.part') || file.path.endsWith('.ytdl')) {
              try {
                await file.delete();
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> cancelDownload(String id) async {
    try {
        final task = state.firstWhere((t) => t.id == id);
        if (task.status == DownloadStatus.running && task.process != null) {
          // Show cancelling state for UI feedback
          _updateTask(id, status: DownloadStatus.cancelling);
          await ProcessUtils.killProcessTree(task.process!.pid);
          
          final args = _taskArgs[id];
          if (args != null) {
            final destination = args['destination'] as String?;
            if (destination != null) {
              await _cleanupTempFiles(destination);
            }
          }
        }
        _updateTask(id, status: DownloadStatus.cancelled, completedAt: DateTime.now());
    } catch (_) {}
  }

  void removeTask(String id) {
    _taskArgs.remove(id);
    _downloadedCounts.remove(id);
    state = state.where((t) => t.id != id).toList();
  }

  void clearHistory() {
     state = state.where((t) => t.status == DownloadStatus.running || t.status == DownloadStatus.pending || t.status == DownloadStatus.cancelling).toList();
  }

  final Map<String, Timer> _removalTimers = {};

  void onHydrationFinished(String url, List<MediaInfo> items) {
    for (final task in state) {
      if (task.url == url && (task.status == DownloadStatus.running || task.status == DownloadStatus.pending)) {
        final filterType = _taskArgs[task.id]?['filterType'] as String?;
        int newTotal = 0;
        
        if (filterType == 'images') {
          newTotal = items.where((item) => !item.isVideo && !item.isProfile).length;
        } else if (filterType == 'videos') {
          newTotal = items.where((item) => item.isVideo && !item.isProfile).length;
        } else {
          newTotal = items.where((item) => !item.isProfile).length;
        }
        
        if (newTotal > 0) {
          _taskArgs[task.id]?['totalItems'] = newTotal;
          
          if (!_downloadedCounts.containsKey(task.id)) {
            _downloadedCounts[task.id] = 0;
          }
          
          // Force UI update to show progress bar if it just switched from indeterminate
          _updateTask(task.id, 
              progress: _downloadedCounts[task.id]! / newTotal,
              totalSize: '${_downloadedCounts[task.id]!} / $newTotal'
          );
        }
      }
    }
  }

  void _startAutoRemovalTimer(String id) {
    if (_removalTimers.containsKey(id)) return;

    _removalTimers[id] = Timer(const Duration(seconds: 3), () {
      final task = state.where((t) => t.id == id).firstOrNull;
      if (task != null && (task.status == DownloadStatus.completed || task.status == DownloadStatus.error || task.status == DownloadStatus.cancelled)) {
        ref.read(downloadHistoryProvider.notifier).addEntry(task);
        removeTask(id);
      }
      _removalTimers.remove(id);
    });
  }

  void _updateTask(String id,
      {DownloadStatus? status,
      double? progress,
      String? speed,
      String? eta,
      String? totalSize,
      String? error,
      Process? process,
      DateTime? completedAt}) {
    state = state.map((task) {
      if (task.id == id) {
        final updated = task.copyWith(
          status: status,
          progress: progress,
          speed: speed,
          eta: eta,
          totalSize: totalSize,
          error: error,
          process: process,
          completedAt: completedAt,
        );
        if (status == DownloadStatus.completed || status == DownloadStatus.error || status == DownloadStatus.cancelled) {
          _startAutoRemovalTimer(id);
        }
        return updated;
      }
      return task;
    }).toList();
  }

  void _appendLog(String id, String data) {
    state = state.map((task) {
      if (task.id == id) {
        final newLogs = List<String>.from(task.logs);
        // Only add non-empty trimmed lines
        for (final line in data.split('\n')) {
          if (line.trim().isNotEmpty) {
            newLogs.add(line.trim());
          }
        }
        return task.copyWith(logs: newLogs);
      }
      return task;
    }).toList();
  }

  void _parseProgress(String id, String data) {
    // Handle standard yt-dlp output
    final RegExp progressRegExp = RegExp(
        r'\[download\]\s+([\d\.]+)\%\s+of\s+(.*?)\s+at\s+(.*?)\s+ETA\s+(.*)');
    final match = progressRegExp.firstMatch(data);

    if (match != null) {
      final percentage = double.tryParse(match.group(1) ?? '0.0') ?? 0.0;
      final size = match.group(2) ?? '';
      final speed = match.group(3) ?? '';
      final eta = match.group(4) ?? '';

      _updateTask(id,
          progress: percentage / 100.0, speed: speed.trim(), eta: eta.trim(), totalSize: size.trim());
      return;
    }

    // Handle aria2c output if injected
    final RegExp ariaRegExp = RegExp(r'\[.*?\((\d+)%\).*?DL:(.*?) ETA:(.*?)\]');
    final ariaMatch = ariaRegExp.firstMatch(data);
    if (ariaMatch != null) {
      final percentage = double.tryParse(ariaMatch.group(1) ?? '0.0') ?? 0.0;
      final speed = ariaMatch.group(2) ?? '';
      final eta = ariaMatch.group(3) ?? '';
      _updateTask(id,
          progress: percentage / 100.0, speed: speed.trim(), eta: eta.trim());
      return;
    }

    // Handle gallery-dl file output
    // gallery-dl usually prints the full file path to stdout when a file completes downloading.
    final currentTotal = _taskArgs[id]?['totalItems'] as int?;
    
    // Check if it's not a log message
    if (!data.trim().startsWith('[') && data.trim().isNotEmpty) {
      final extRegExp = RegExp(r'\.(mp4|webm|jpg|jpeg|png|webp|gif|mov|mkv)$', caseSensitive: false);
      if (extRegExp.hasMatch(data.trim()) || data.contains('/') || data.contains('\\')) {
        _downloadedCounts[id] = (_downloadedCounts[id] ?? 0) + 1;
        final count = _downloadedCounts[id]!;
        
        if (currentTotal != null && currentTotal > 0) {
          double prog = count / currentTotal;
          if (prog > 1.0) prog = 1.0;
          _updateTask(id, progress: prog, totalSize: '$count / $currentTotal');
        } else {
          _updateTask(id, progress: null, totalSize: '$count / ?');
        }
      }
    }
  }
}

final downloadTaskProvider =
    NotifierProvider<DownloadTaskNotifier, List<DownloadTask>>(DownloadTaskNotifier.new);

final activeDownloadTaskProvider = Provider<List<DownloadTask>>((ref) {
  final tasks = ref.watch(downloadTaskProvider);
  return tasks
      .where((t) =>
          t.status == DownloadStatus.running ||
          t.status == DownloadStatus.pending)
      .toList();
});

final completedDownloadTaskProvider = Provider<List<DownloadTask>>((ref) {
  final tasks = ref.watch(downloadTaskProvider);
  return tasks
      .where((t) =>
          t.status == DownloadStatus.completed ||
          t.status == DownloadStatus.error ||
          t.status == DownloadStatus.cancelled)
      .toList();
});
