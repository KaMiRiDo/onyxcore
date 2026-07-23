import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/utils/process_utils.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_history_provider.dart';
import 'package:onyxcore/features/downloader/services/downloader_process_wrapper.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:uuid/uuid.dart';
import 'package:window_manager/window_manager.dart';

enum DownloadStatus {
  pending,
  running,
  cancelling,
  completed,
  error,
  cancelled,
}

class DownloadTask {

  const DownloadTask({
    required this.id,
    required this.url,
    required this.destination,
    required this.title,
    required this.createdAt, this.downloadType = 'generic',
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.speed = '',
    this.eta = '',
    this.totalSize = '',
    this.expectedBytes = 0,
    this.downloadedBytes = 0,
    this.completedItems = 0,
    this.totalItems = 0,
    this.error,
    this.process,
    this.logs = const [],
    this.completedAt,
  });
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
  final int expectedBytes;
  final int downloadedBytes;
  final int completedItems;
  final int totalItems;
  final String? error;
  final Process? process;
  final List<String> logs;
  final DateTime createdAt;
  final DateTime? completedAt;

  DownloadTask copyWith({
    String? title,
    String? downloadType,
    DownloadStatus? status,
    double? progress,
    String? speed,
    String? eta,
    String? totalSize,
    int? expectedBytes,
    int? downloadedBytes,
    int? completedItems,
    int? totalItems,
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
      expectedBytes: expectedBytes ?? this.expectedBytes,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      completedItems: completedItems ?? this.completedItems,
      totalItems: totalItems ?? this.totalItems,
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

  bool _mounted = true;

  @override
  List<DownloadTask> build() {
    windowManager.addListener(this);

    ref.onDispose(() {
      _mounted = false;
      windowManager.removeListener(this);
    });
    return [];
  }

  @override
  void onWindowClose() {
    // Zombie Process Prevention — must be sync since window is closing
    for (final task in state) {
      if ((task.status == DownloadStatus.running ||
              task.status == DownloadStatus.cancelling) &&
          task.process != null) {
        ProcessUtils.killProcessTreeSync(task.process!.pid);
      }
    }
  }

  final Map<String, Map<String, dynamic>> _taskArgs = {};
  final Map<String, Timer> _liveMonitors = {};

  int get _maxConcurrent {
    return ref.read(settingsProvider).value?.maxConcurrentDownloads ?? 3;
  }

  Future<void> _processQueue() async {
    final runningCount = state
        .where((t) => t.status == DownloadStatus.running)
        .length;
    if (runningCount >= _maxConcurrent) return;

    final pendingTasks = state
        .where((t) => t.status == DownloadStatus.pending)
        .toList();
    if (pendingTasks.isEmpty) return;

    final tasksToStart = pendingTasks
        .take(_maxConcurrent - runningCount)
        .toList();

    for (final task in tasksToStart) {
      _startProcessForTask(task.id);
    }
  }

  Future<void> _startProcessForTask(String id) async {
    _updateTask(id, status: DownloadStatus.running);
    final args = _taskArgs[id];
    if (args == null) return;

    StreamSubscription<String>? stdoutSub;
    StreamSubscription<String>? stderrSub;

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
        singleItemId: args['singleItemId'] as String?,
        directUrl: args['directUrl'] as String?,
      );

      _updateTask(id, process: process);

      if ((args['isProfile'] as bool? ?? false) ||
          (args['isPlaylist'] as bool? ?? false)) {
        _startFolderSizeMonitor(id, args['destination'] as String);
      }

      stdoutSub = process.stdout
          .transform(utf8.decoder)
          .map((s) => s.replaceAll('\r', '\n'))
          .transform(const LineSplitter())
          .listen((data) {
            _parseProgress(id, data);
            _appendLog(id, data);
          });

      stderrSub = process.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((data) {
            _appendLog(id, data);
          });

      final exitCode = await process.exitCode;

      // Stop live stream monitor if running
      _liveMonitors[id]?.cancel();
      _liveMonitors.remove(id);

      if (exitCode == 0) {
        _updateTask(
          id,
          status: DownloadStatus.completed,
          progress: 1,
          completedAt: DateTime.now(),
        );
      } else {
        final currentTask = state.firstWhere((t) => t.id == id);
        if (currentTask.status != DownloadStatus.cancelled) {
          _updateTask(
            id,
            status: DownloadStatus.error,
            error: 'Process exited with code $exitCode',
            completedAt: DateTime.now(),
          );
        }
      }
    } catch (e) {
      _updateTask(
        id,
        status: DownloadStatus.error,
        error: e.toString(),
        completedAt: DateTime.now(),
      );
    } finally {
      stdoutSub?.cancel();
      stderrSub?.cancel();
      _liveMonitors[id]?.cancel();
      _liveMonitors.remove(id);
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
    String? singleItemId,
    String? directUrl,
    int expectedBytes = 0,
  }) {
    if (!_mounted) return;
    final id = _uuid.v4();
    final newTask = DownloadTask(
      id: id,
      url: url,
      destination: destination,
      title: title,
      downloadType: downloadType,
      expectedBytes: expectedBytes,
      totalItems: totalItems ?? 0,
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
      'singleItemId': singleItemId,
      'directUrl': directUrl,
    };

    if (totalItems != null) {
      _downloadedCounts[id] = 0;
    }

    state = [...state, newTask];
    _processQueue();
  }

  Future<void> _cleanupTempFiles(
    String destination,
    String? title,
    bool isDedicatedFolder,
  ) async {
    try {
      final dir = Directory(destination);
      if (await dir.exists()) {
        final files = dir
            .listSync(); // non-recursive to avoid deleting files in subfolders
        final safeTitle = title?.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');

        for (final file in files) {
          if (file is File) {
            final fileName = file.path.split(Platform.pathSeparator).last;

            if (fileName.endsWith('.temp') ||
                fileName.endsWith('.part') ||
                fileName.endsWith('.ytdl') ||
                fileName.endsWith('.aria2') ||
                fileName.endsWith('.frag')) {
              if (isDedicatedFolder) {
                // If downloading into a dedicated playlist/profile folder, all temp files here belong to this task
                try {
                  await file.delete();
                } catch (_) {}
              } else if (safeTitle != null && fileName.contains(safeTitle)) {
                // Otherwise, ensure the temp file matches the task title to avoid deleting other active downloads
                try {
                  await file.delete();
                } catch (_) {}
              }
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

        // Live stream tasks (Streamlink) need SIGINT for clean container closure
        final isLive = _taskArgs[id]?['isLive'] as bool? ?? false;
        if (isLive) {
          task.process!.kill(ProcessSignal.sigint);
          await Future<void>.delayed(const Duration(seconds: 3));
          // If still running after 3s, force kill
          try {
            await task.process!.exitCode.timeout(const Duration(seconds: 1));
          } on TimeoutException {
            await ProcessUtils.killProcessTree(task.process!.pid);
          }
        } else {
          await ProcessUtils.killProcessTree(task.process!.pid);
        }

        final args = _taskArgs[id];
        if (args != null) {
          final destination = args['destination'] as String?;
          final title = args['title'] as String?;
          final isPlaylist = args['isPlaylist'] as bool? ?? false;
          final isProfile = args['isProfile'] as bool? ?? false;

          if (destination != null) {
            await _cleanupTempFiles(
              destination,
              title,
              isPlaylist || isProfile,
            );
          }
        }
      }
      // Stop live monitor if running
      _liveMonitors[id]?.cancel();
      _liveMonitors.remove(id);
      _updateTask(
        id,
        status: DownloadStatus.cancelled,
        completedAt: DateTime.now(),
      );
    } catch (_) {}
  }

  void removeTask(String id) {
    _taskArgs.remove(id);
    _downloadedCounts.remove(id);
    state = state.where((t) => t.id != id).toList();
  }

  void clearHistory() {
    state = state
        .where(
          (t) =>
              t.status == DownloadStatus.running ||
              t.status == DownloadStatus.pending ||
              t.status == DownloadStatus.cancelling,
        )
        .toList();
  }

  final Map<String, Timer> _removalTimers = {};

  void onHydrationFinished(String url, List<MediaInfo> items) {
    for (final task in state) {
      if (task.url == url &&
          (task.status == DownloadStatus.running ||
              task.status == DownloadStatus.pending)) {
        final filterType = _taskArgs[task.id]?['filterType'] as String?;
        var newTotal = 0;

        if (filterType == 'images') {
          newTotal = items
              .where((item) => !item.isVideo && !item.isProfile)
              .length;
        } else if (filterType == 'videos') {
          newTotal = items
              .where((item) => item.isVideo && !item.isProfile)
              .length;
        } else {
          newTotal = items.where((item) => !item.isProfile).length;
        }

        if (newTotal > 0) {
          _taskArgs[task.id]?['totalItems'] = newTotal;

          if (!_downloadedCounts.containsKey(task.id)) {
            _downloadedCounts[task.id] = 0;
          }

          // Force UI update to show progress bar if it just switched from indeterminate
          _updateTask(
            task.id,
            progress: _downloadedCounts[task.id]! / newTotal,
            completedItems: _downloadedCounts[task.id],
            totalItems: newTotal,
          );
        }
      }
    }
  }

  void _startAutoRemovalTimer(String id) {
    if (_removalTimers.containsKey(id)) return;

    _removalTimers[id] = Timer(const Duration(seconds: 3), () {
      if (!_mounted) return;
      final task = state.where((t) => t.id == id).firstOrNull;
      if (task != null &&
          (task.status == DownloadStatus.completed ||
              task.status == DownloadStatus.error ||
              task.status == DownloadStatus.cancelled)) {
        ref.read(downloadHistoryProvider.notifier).addEntry(task);
        removeTask(id);
      }
      _removalTimers.remove(id);
    });
  }

  void _updateTask(
    String id, {
    DownloadStatus? status,
    double? progress,
    String? speed,
    String? eta,
    String? totalSize,
    int? expectedBytes,
    int? downloadedBytes,
    int? completedItems,
    int? totalItems,
    String? error,
    Process? process,
    DateTime? completedAt,
  }) {
    if (!_mounted) return;
    state = state.map((task) {
      if (task.id == id) {
        final updated = task.copyWith(
          status: status,
          progress: progress,
          speed: speed,
          eta: eta,
          totalSize: totalSize,
          expectedBytes: expectedBytes,
          downloadedBytes: downloadedBytes,
          completedItems: completedItems,
          totalItems: totalItems,
          error: error,
          process: process,
          completedAt: completedAt,
        );
        if (status == DownloadStatus.completed ||
            status == DownloadStatus.error ||
            status == DownloadStatus.cancelled) {
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

  void _parseProgress(String id, String rawData) {
    // Strip ANSI escape codes (colors, clear lines) before parsing
    final data = rawData.replaceAll(RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'), '');

    void updateWithProgress(
      double percentage, {
      String? totalSize,
      String? speed,
      String? eta,
    }) {
      var finalProgress = percentage / 100.0;
      final finalTotalSize = totalSize;
      int? completedItems;
      int? updatedTotalItems;

      final currentTotal = _taskArgs[id]?['totalItems'] as int?;
      if (currentTotal != null && currentTotal > 1) {
        final count = _downloadedCounts[id] ?? 0;
        // Formula: (completedItems * 100 + currentItemPercent) / (totalCount * 100)
        // e.g. 3 done + 45% current out of 25 total → (300 + 45) / 2500 = 0.138
        final numerator = (count * 100) + percentage;
        final denominator = currentTotal * 100;
        finalProgress = numerator / denominator;
        if (finalProgress > 1.0) finalProgress = 1.0;
        completedItems = count;
        updatedTotalItems = currentTotal;

        // Enforce monotonic progress — never go backwards for multi-item downloads
        final currentTask = state.where((t) => t.id == id).firstOrNull;
        if (currentTask != null && finalProgress < currentTask.progress) {
          finalProgress = currentTask.progress;
        }
      }

      // Only update speed/eta when we have actual values to avoid clearing them
      final effectiveSpeed = (speed != null && speed.trim().isNotEmpty)
          ? speed.trim()
          : null;
      final effectiveEta = (eta != null && eta.trim().isNotEmpty)
          ? eta.trim()
          : null;

      _updateTask(
        id,
        progress: finalProgress,
        speed: effectiveSpeed,
        eta: effectiveEta,
        totalSize: finalTotalSize?.trim(),
        completedItems: completedItems,
        totalItems: updatedTotalItems,
      );
    }

    // 1. Handle standard yt-dlp output
    // Handles variants like:
    // [download]  13.0% of  107.0MiB at  16.0MiB/s ETA 00:05
    // [download]  13.0% of ~10.0MiB at Unknown B/s ETA Unknown
    // [download] 100% of 10.0MiB in 00:01
    final progressRegExp = RegExp(
      r'\[download\]\s+([\d\.]+)\%\s+of\s+([^\s]+)(?:.*?at\s+([^ ]+))?(?:.*?ETA\s+(.*))?',
    );
    final match = progressRegExp.firstMatch(data);

    if (match != null) {
      final percentage = double.tryParse(match.group(1) ?? '0.0') ?? 0.0;
      final size = match.group(2)?.trim() ?? '';
      final speed = match.group(3)?.trim() ?? '';
      final eta = match.group(4)?.trim() ?? '';

      updateWithProgress(
        percentage,
        speed: speed,
        eta: eta,
        totalSize: size,
      );
      return;
    }

    // 1.2 Track playlist item index: [download] Downloading video 1 of 25
    final itemIndexRegExp = RegExp(
      r'\[download\]\s+Downloading\s+(?:video|item)\s+(\d+)\s+of\s+(\d+)',
    );
    final indexMatch = itemIndexRegExp.firstMatch(data);
    if (indexMatch != null) {
      final index = int.tryParse(indexMatch.group(1) ?? '1') ?? 1;
      final total = int.tryParse(indexMatch.group(2) ?? '0') ?? 0;
      // Index is 1-based. Completed count is index - 1.
      if (index > 0) {
        _downloadedCounts[id] = index - 1;
        // Update totalItems from yt-dlp's own count if available
        if (total > 0) {
          _taskArgs[id]?['totalItems'] = total;
        }
        final currentTotal = _taskArgs[id]?['totalItems'] as int? ?? total;
        if (currentTotal > 0) {
          final count = index - 1;
          // Only update counts — don't set progress here to avoid juggling.
          // Progress will be set by updateWithProgress when the actual
          // per-item download percentage comes from yt-dlp/aria2c.
          _updateTask(
            id,
            completedItems: count,
            totalItems: currentTotal,
          );
        }
      }
      return;
    }

    // 1.5 Handle fragmented downloads: [download] Frag 1/10
    final fragRegExp = RegExp(r'\[download\]\s+Frag\s+(\d+)/(\d+)');
    final fragMatch = fragRegExp.firstMatch(data);
    if (fragMatch != null) {
      final frag = double.tryParse(fragMatch.group(1) ?? '0.0') ?? 0.0;
      final total = double.tryParse(fragMatch.group(2) ?? '0.0') ?? 1.0;
      updateWithProgress(
        (frag / total) * 100.0,
        totalSize: '${fragMatch.group(1)} / ${fragMatch.group(2)} Frags',
      );
      return;
    }

    // 1.6 Handle unknown total sizes: [download] 10.0MiB at 5.0MiB/s
    final unknownTotalRegExp = RegExp(
      r'\[download\]\s+([\d\.]+[a-zA-Z]+)\s+at\s+([^ ]+)(?:.*?ETA\s+(.*))?',
    );
    final unknownMatch = unknownTotalRegExp.firstMatch(data);
    if (unknownMatch != null) {
      final downloadedSize = unknownMatch.group(1) ?? '';
      final speed = unknownMatch.group(2) ?? '';
      final eta = unknownMatch.group(3) ?? '';
      updateWithProgress(
        0,
        speed: speed,
        eta: eta,
        totalSize: '$downloadedSize / ?',
      );
      return;
    }

    // 2. Handle aria2c output
    // Matches: [#bb8141 1.7MiB/113MiB(1%) CN:16 DL:2.7MiB ETA:41s]
    final ariaRegExp = RegExp(
      r'([\d.]+)([a-zA-Z]+)\s*/\s*([\d.]+)([a-zA-Z]+)\s*\(([\d.]+)%\).*?DL:\s*([^\s\]]+)(?:.*?ETA:\s*([^\s\]]+))?',
    );
    final ariaMatch = ariaRegExp.firstMatch(data);
    if (ariaMatch != null) {
      final percentage = double.tryParse(ariaMatch.group(5) ?? '0.0') ?? 0.0;
      final speed = ariaMatch.group(6) ?? '';
      final eta = ariaMatch.group(7) ?? '';
      final totalSize =
          '${ariaMatch.group(1)}${ariaMatch.group(2)} / ${ariaMatch.group(3)}${ariaMatch.group(4)}';
      updateWithProgress(
        percentage,
        speed: speed,
        eta: eta,
        totalSize: totalSize,
      );
      return;
    }

    // 4. Handle aria2c download complete
    if (data.contains('Download complete:')) {
      final currentTotal = _taskArgs[id]?['totalItems'] as int?;
      if (currentTotal == null || currentTotal <= 1) {
        _updateTask(id, progress: 1);
      }
      return;
    }

    // 5. Handle You-Get progress: 98.5% ( 24.0/ 24.4MB) [==============>]
    final youGetProgress = RegExp(
      r'(\d+\.?\d*)%\s+\(\s*[\d.]+/\s*([\d.]+\s*\w+)\)',
    );
    final youGetMatch = youGetProgress.firstMatch(data);
    if (youGetMatch != null) {
      final percentage = double.tryParse(youGetMatch.group(1) ?? '0.0') ?? 0.0;
      final totalSize = youGetMatch.group(2) ?? '';
      updateWithProgress(
        percentage,
        totalSize: totalSize,
      );
      return;
    }

    // 6. Handle You-Get download complete
    if (data.contains('(✓)') && data.contains('Downloaded to:')) {
      _updateTask(id, progress: 1);
      return;
    }

    // 7. Handle Lux progress: 50.00% |████████░░░░| 25.0/50.0 MiB 5.0 MiB/s 5s
    final luxProgress = RegExp(
      r'(\d+\.?\d*)%\s+\|.*?\|\s+([\d.]+/[\d.]+\s+\w+)\s+([\d.]+\s+\w+/s)\s+(\S+)',
    );
    final luxMatch = luxProgress.firstMatch(data);
    if (luxMatch != null) {
      final percentage = double.tryParse(luxMatch.group(1) ?? '0.0') ?? 0.0;
      final totalSize = luxMatch.group(2) ?? '';
      final speed = luxMatch.group(3) ?? '';
      final eta = luxMatch.group(4) ?? '';
      updateWithProgress(
        percentage,
        speed: speed,
        eta: eta,
        totalSize: totalSize,
      );
      return;
    }

    // 8. Handle FFmpeg progress (Playwright pipeline): time=00:01:30
    final ffmpegProgress = RegExp(r'time=(\d+:\d+:\d+)');
    final ffmpegMatch = ffmpegProgress.firstMatch(data);
    if (ffmpegMatch != null) {
      final time = ffmpegMatch.group(1) ?? '';
      // FFmpeg doesn't give percentage for streams — show elapsed time
      _updateTask(id, totalSize: 'Elapsed: $time');
      return;
    }

    // 9. Handle Streamlink output: Writing output to ...
    if (data.contains('Writing output to') || data.contains('Stream ended')) {
      // Start file-size monitoring for live streams
      final destination = _taskArgs[id]?['destination'] as String?;
      final title = _taskArgs[id]?['title'] as String?;
      if (destination != null && !_liveMonitors.containsKey(id)) {
        _startFileSizeMonitor(id, destination, title);
      }
      return;
    }

    // 10. Handle gallery-dl file output
    // gallery-dl usually prints the full file path to stdout when a file completes downloading.
    final currentTotal = _taskArgs[id]?['totalItems'] as int?;
    final engine = _taskArgs[id]?['engine'] as String?;

    if (engine == 'gallery-dl') {
      // Check if it's not a log message
      if (!data.trim().startsWith('[') && data.trim().isNotEmpty) {
        final extRegExp = RegExp(
          r'\.(mp4|webm|jpg|jpeg|png|webp|gif|mov|mkv|ts)$',
          caseSensitive: false,
        );
        if (extRegExp.hasMatch(data.trim()) ||
            data.contains('/') ||
            data.contains(r'\')) {
          _downloadedCounts[id] = (_downloadedCounts[id] ?? 0) + 1;
          final count = _downloadedCounts[id]!;

          if (currentTotal != null && currentTotal > 0) {
            var prog = count / currentTotal;
            if (prog > 1.0) prog = 1.0;
            _updateTask(
              id,
              progress: prog,
              completedItems: count,
              totalItems: currentTotal,
            );
          } else {
            _updateTask(
              id,
              completedItems: count,
            );
          }
        }
      }
    }
  }

  /// Monitor file size growth for live stream recordings (Streamlink).
  ///
  /// Polls the output file every 2 seconds and updates the task with
  /// current file size and recording speed.
  void _startFileSizeMonitor(String id, String destination, String? title) {
    final safeTitle =
        title?.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_') ?? 'live_recording';
    // Streamlink outputs to .ts files
    final possiblePaths = [
      '$destination/$safeTitle.ts',
      '$destination/$safeTitle.mp4',
    ];

    _liveMonitors[id] = Timer.periodic(const Duration(seconds: 2), (_) {
      for (final path in possiblePaths) {
        final file = File(path);
        if (file.existsSync()) {
          try {
            final size = file.lengthSync();
            final task = state.where((t) => t.id == id).firstOrNull;
            if (task != null && task.status == DownloadStatus.running) {
              final elapsed = DateTime.now().difference(task.createdAt);
              final speedBps = elapsed.inSeconds > 0
                  ? size ~/ elapsed.inSeconds
                  : 0;
              _updateTask(
                id,
                totalSize: StringUtils.formatBytes(size),
                speed: '${StringUtils.formatBytes(speedBps)}/s',
              );
            }
          } catch (_) {}
          return;
        }
      }
    });
  }

  void _startFolderSizeMonitor(String id, String destination) {
    if (_liveMonitors.containsKey(id)) return;

    _liveMonitors[id] = Timer.periodic(const Duration(seconds: 1), (_) {
      try {
        final dir = Directory(destination);
        if (dir.existsSync()) {
          var size = 0;
          for (final entity in dir.listSync(recursive: true)) {
            if (entity is File) {
              size += entity.lengthSync();
            }
          }
          final task = state.where((t) => t.id == id).firstOrNull;
          if (task != null && task.status == DownloadStatus.running) {
            // Only track downloaded bytes — progress is driven by yt-dlp/aria2c parser
            _updateTask(
              id,
              downloadedBytes: size,
            );
          }
        }
      } catch (_) {}
    });
  }

  @visibleForTesting
  void parseProgressForTesting(String id, String rawData) =>
      _parseProgress(id, rawData);

  @visibleForTesting
  void appendLogForTesting(String id, String data) => _appendLog(id, data);

  @visibleForTesting
  void processQueueForTesting() => _processQueue();

  @visibleForTesting
  void startProcessForTaskForTesting(String id) => _startProcessForTask(id);
}

final downloadTaskProvider =
    NotifierProvider<DownloadTaskNotifier, List<DownloadTask>>(
      DownloadTaskNotifier.new,
    );

final activeDownloadTaskProvider = Provider<List<DownloadTask>>((ref) {
  final tasks = ref.watch(downloadTaskProvider);
  return tasks
      .where(
        (t) =>
            t.status == DownloadStatus.running ||
            t.status == DownloadStatus.pending,
      )
      .toList();
});

final completedDownloadTaskProvider = Provider<List<DownloadTask>>((ref) {
  final tasks = ref.watch(downloadTaskProvider);
  return tasks
      .where(
        (t) =>
            t.status == DownloadStatus.completed ||
            t.status == DownloadStatus.error ||
            t.status == DownloadStatus.cancelled,
      )
      .toList();
});
