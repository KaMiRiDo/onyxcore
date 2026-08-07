import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/core/platform/process_priority.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

/// Top-level function for background image thumbnail generation via [compute].
Future<bool> _generateImageThumbnail(List<String> args) async {
  final sourcePath = args[0];
  final destPath = args[1];
  try {
    final bytes = File(sourcePath).readAsBytesSync();
    final image = img.decodeImage(bytes);
    if (image == null) return false;

    final resized = img.copyResize(image, width: 320);
    final jpegBytes = img.encodeJpg(resized, quality: 85);
    File(destPath).writeAsBytesSync(jpegBytes);
    return true;
  } catch (e) {
    return false;
  }
}

/// Generates a media thumbnail file and caches it via [ThumbnailCacheService].
Future<void> generateMediaThumbnail({
  required FileItem item,
  required ThumbnailCacheService cacheService,
  required ThumbnailSession session,
}) async {
  if (session.isCancelled || session.isDisposed) return;

  final filePath = item.path;
  final mtime = item.modified.millisecondsSinceEpoch;
  final sizeBytes = item.sizeBytes ?? 0;

  final lookup = cacheService.lookup(
    filePath: filePath,
    mtime: mtime,
    sizeBytes: sizeBytes,
  );

  if (lookup == ThumbnailLookupResult.hit ||
      lookup == ThumbnailLookupResult.failed) {
    return;
  }

  await ThumbnailCacheService.ensureCacheDirs();
  final tempThumbPath = ThumbnailCacheService.computeCachePath(
    filePath,
    ThumbnailSize.normal,
  );
  final jobKey = '$filePath::${ThumbnailSize.normal.name}';

  try {
    final isImage = item.type == FileItemType.image;
    final ext = filePath.toLowerCase();
    final isCommonImage =
        isImage &&
        (ext.endsWith('.jpg') ||
            ext.endsWith('.jpeg') ||
            ext.endsWith('.png') ||
            ext.endsWith('.webp') ||
            ext.endsWith('.gif') ||
            ext.endsWith('.bmp') ||
            ext.endsWith('.tiff') ||
            ext.endsWith('.tif') ||
            ext.endsWith('.dng'));

    var generated = false;

    // 1. Try Dart image package for common image formats (up to 5MB)
    if (isCommonImage &&
        sizeBytes > 0 &&
        sizeBytes <= ThumbnailSession.dartDecodeMaxBytes) {
      generated = await compute(_generateImageThumbnail, [
        filePath,
        tempThumbPath,
      ]);
    }

    // 2. Try heif-thumbnailer for HEIC/HEIF/AVIF
    if (!generated &&
        (ext.endsWith('.heic') ||
            ext.endsWith('.heif') ||
            ext.endsWith('.avif'))) {
      final process = await Process.start(
        'heif-thumbnailer',
        ['-s', '320', filePath, tempThumbPath],
      );
      unawaited(setLowProcessPriority(process.pid));
      session.registerRunningProcess(jobKey, process);
      process.stdout.drain<void>().ignore();
      process.stderr.drain<void>().ignore();
      await process.exitCode;
      session.unregisterRunningProcess(jobKey);

      final file = File(tempThumbPath);
      try {
        // ignore: avoid_slow_async_io
        generated = file.existsSync() && file.lengthSync() > 0;
      } catch (_) {
        generated = false;
      }
    }

    // 3. Fallback to FFmpeg for videos and RAW/large images
    if (!generated) {
      final ffmpegArgs = isImage
          ? [
              '-y',
              '-i',
              filePath,
              '-vframes',
              '1',
              '-update',
              '1',
              '-vf',
              'scale=320:-1',
              '-q:v',
              '5',
              '-loglevel',
              'error',
              tempThumbPath,
            ]
          : [
              '-y',
              '-ss',
              '00:00:01',
              '-i',
              filePath,
              '-vframes',
              '1',
              '-an',
              '-vf',
              'scale=320:-1',
              '-q:v',
              '5',
              '-loglevel',
              'error',
              tempThumbPath,
            ];

      final process = await Process.start('ffmpeg', ffmpegArgs);
      unawaited(setLowProcessPriority(process.pid));
      session.registerRunningProcess(jobKey, process);
      process.stdout.drain<void>().ignore();
      process.stderr.drain<void>().ignore();
      final exitCode = await process.exitCode;
      session.unregisterRunningProcess(jobKey);
      generated = (exitCode == 0);
    }

    if (session.isCancelled || session.isDisposed) {
      try {
        final partialFile = File(tempThumbPath);
        if (partialFile.existsSync()) {
          partialFile.deleteSync();
        }
      } catch (_) {}
      return;
    }

    final thumbFile = File(tempThumbPath);
    var thumbExists = false;
    try {
      thumbExists = thumbFile.existsSync() && thumbFile.lengthSync() > 0;
    } catch (_) {
      thumbExists = false;
    }

    if (generated && thumbExists) {
      await cacheService.storeThumbnail(
        filePath: filePath,
        mtime: mtime,
        sizeBytes: sizeBytes,
        kind: isImage ? 'image' : 'video',
        thumbnailFile: thumbFile,
      );
    } else {
      await cacheService.markFailed(
        filePath: filePath,
        mtime: mtime,
        sizeBytes: sizeBytes,
        kind: isImage ? 'image' : 'video',
      );
    }
  } catch (e) {
    if (!session.isCancelled && !session.isDisposed) {
      await cacheService.markFailed(
        filePath: filePath,
        mtime: mtime,
        sizeBytes: sizeBytes,
        kind: item.type == FileItemType.image ? 'image' : 'video',
      );
    }
  }
}

/// Represents a single unit of work for thumbnail generation.
class ThumbnailJob {
  ThumbnailJob({
    required this.filePath,
    required this.size,
    required this.task,
    this.priority = 100,
    bool? isVideo,
  }) : isVideo = isVideo ?? (classifyFileType(filePath) == FileItemType.video);

  final String filePath;
  final ThumbnailSize size;
  final Future<void> Function() task;
  final bool isVideo;
  int priority;

  String get key => '$filePath::${size.name}';
}

class _ThumbnailQueueEntry {
  _ThumbnailQueueEntry({required this.job, required this.completer});

  final ThumbnailJob job;
  final Completer<void> completer;
}

/// Represents a session-scoped thumbnail generation queue for an active folder in a tab.
class ThumbnailSession {
  ThumbnailSession({
    required this.folderPath,
    required this.tabId,
    this.cacheService,
  });

  /// Grace period in milliseconds to allow child process to terminate on SIGTERM
  /// before escalating to SIGKILL.
  static const int graceMillis = 300;

  /// Maximum file size in bytes for in-memory Dart image decoding. Images larger than
  /// this threshold route directly to FFmpeg to preserve memory stability and responsiveness.
  static const int dartDecodeMaxBytes = 5 * 1024 * 1024;

  /// Maximum concurrent background workers for image thumbnail generation.
  /// Bounded to 2 to prevent UI stutters and CPU starvation.
  static const int maxImageWorkers = 2;

  /// Maximum concurrent background workers for video thumbnail generation.
  /// Bounded to 1 because video demuxing/decoding is compute-heavy.
  static const int maxVideoWorkers = 1;

  /// Debounce duration in milliseconds before full folder thumbnail queueing triggers
  /// after user scrolling settles.
  static const int scrollSettleDebounceMillis = 150;

  final String folderPath;
  final String tabId;
  final ThumbnailCacheService? cacheService;

  bool _isCancelled = false;
  bool _isDisposed = false;
  int _activeImageCount = 0;
  int _activeVideoCount = 0;

  final List<_ThumbnailQueueEntry> _queue = [];
  final Map<String, _ThumbnailQueueEntry> _queueMap = {};
  final Set<String> _queuedKeys = {};
  final Set<String> _runningKeys = {};
  final Set<String> _completedKeys = {};
  final Map<String, ThumbnailJob> _runningJobs = {};
  final Map<String, Future<void>> _inFlightFutures = {};
  final Map<String, Process> _runningProcesses = {};

  bool get isCancelled => _isCancelled;
  bool get isDisposed => _isDisposed;

  bool isJobActiveOrQueued(String filePath, ThumbnailSize size) {
    final key = '$filePath::${size.name}';
    return _queuedKeys.contains(key) || _runningKeys.contains(key);
  }

  bool isJobCompleted(String filePath, ThumbnailSize size) {
    final key = '$filePath::${size.name}';
    return _completedKeys.contains(key);
  }

  /// Creates a [ThumbnailJob] for a given [FileItem].
  ThumbnailJob createJobForFileItem({
    required FileItem item,
    required ThumbnailCacheService cacheService,
    int priority = 100,
  }) {
    return ThumbnailJob(
      filePath: item.path,
      size: ThumbnailSize.normal,
      priority: priority,
      isVideo: item.type == FileItemType.video,
      task: () => generateMediaThumbnail(
        item: item,
        cacheService: cacheService,
        session: this,
      ),
    );
  }

  /// Enqueues a thumbnail generation job.
  /// If the job is already in queue, updates its priority if the new priority is higher.
  Future<void> enqueue(ThumbnailJob job) {
    if (_isCancelled || _isDisposed) {
      return Future.value();
    }

    final key = job.key;
    if (_completedKeys.contains(key)) {
      return Future.value();
    }

    final existing = _queueMap[key];
    if (existing != null) {
      if (existing.job.priority != job.priority) {
        existing.job.priority = job.priority;
        _queue.sort((a, b) => a.job.priority.compareTo(b.job.priority));
        _preemptLowPriorityJobsIfNeeded();
      }
      return _inFlightFutures[key] ?? Future.value();
    }

    if (_inFlightFutures.containsKey(key)) {
      return _inFlightFutures[key]!;
    }

    final completer = Completer<void>();
    final entry = _ThumbnailQueueEntry(job: job, completer: completer);

    _queue.add(entry);
    _queueMap[key] = entry;
    _queuedKeys.add(key);
    _inFlightFutures[key] = completer.future;

    _preemptLowPriorityJobsIfNeeded();
    _processNext();
    return completer.future;
  }

  /// Enqueues all media items in the active folder with distance-aware priorities:
  /// - Exact viewport items: Priority 0..N
  /// - Buffer rows above/below: Priority 50..M
  /// - Rest of folder: Priority 200..Z
  void enqueueAllFolderItems({
    required List<FileItem> items,
    required ThumbnailCacheService cacheService,
    required int firstVisibleIndex,
    required int lastVisibleIndex,
    required int firstBufferIndex,
    required int lastBufferIndex,
  }) {
    if (_isCancelled || _isDisposed) return;

    final centerVisibleIndex = (firstVisibleIndex < lastVisibleIndex)
        ? firstVisibleIndex + ((lastVisibleIndex - firstVisibleIndex) ~/ 2)
        : firstVisibleIndex;

    var modified = false;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item.type != FileItemType.image && item.type != FileItemType.video) {
        continue;
      }

      final key = '${item.path}::${ThumbnailSize.normal.name}';
      if (_completedKeys.contains(key)) continue;

      int priority;
      if (i >= firstVisibleIndex && i < lastVisibleIndex) {
        // Viewport items: start from center and radiate outward
        priority = (i - centerVisibleIndex).abs();
      } else if (i >= firstBufferIndex && i < lastBufferIndex) {
        // Buffer items: radiate outward around viewport
        priority = 50 + (i - centerVisibleIndex).abs();
      } else {
        // Remaining folder items: radiate outward until all items in folder are processed
        priority = 200 + (i - centerVisibleIndex).abs();
      }

      final existing = _queueMap[key];
      if (existing != null) {
        if (existing.job.priority != priority) {
          existing.job.priority = priority;
          modified = true;
        }
      } else if (!_runningKeys.contains(key) && !_inFlightFutures.containsKey(key)) {
        final job = createJobForFileItem(
          item: item,
          cacheService: cacheService,
          priority: priority,
        );
        final completer = Completer<void>();
        final entry = _ThumbnailQueueEntry(job: job, completer: completer);
        _queue.add(entry);
        _queueMap[key] = entry;
        _queuedKeys.add(key);
        _inFlightFutures[key] = completer.future;
        modified = true;
      }
    }

    if (modified) {
      _queue.sort((a, b) => a.job.priority.compareTo(b.job.priority));
    }

    _preemptLowPriorityJobsIfNeeded();
    _processNext();
  }

  /// Re-orders pending queue entries based on which items are currently visible in the viewport.
  void reprioritize(Set<String> visiblePaths) {
    if (_isCancelled || _isDisposed) return;

    var modified = false;
    for (final entry in _queue) {
      if (visiblePaths.contains(entry.job.filePath)) {
        if (entry.job.priority != 0) {
          entry.job.priority = 0;
          modified = true;
        }
      } else if (entry.job.priority < 50) {
        entry.job.priority = 200;
        modified = true;
      }
    }

    if (modified) {
      _queue.sort((a, b) => a.job.priority.compareTo(b.job.priority));
      _preemptLowPriorityJobsIfNeeded();
    }
  }

  /// If high-priority viewport items are waiting and workers are busy on off-screen jobs,
  /// terminate the off-screen process immediately so viewport items start without delay.
  void _preemptLowPriorityJobsIfNeeded() {
    if (_isCancelled || _isDisposed) return;
    if (_queue.isEmpty) return;

    for (final entry in _queue) {
      if (entry.job.priority >= 50) break;

      final isVideo = entry.job.isVideo;
      final isPoolFull = isVideo
          ? _activeVideoCount >= maxVideoWorkers
          : _activeImageCount >= maxImageWorkers;

      if (isPoolFull) {
        String? victimKey;
        var worstPriority = -1;
        for (final running in _runningJobs.entries) {
          if (running.value.isVideo == isVideo &&
              running.value.priority >= 50 &&
              running.value.priority > worstPriority) {
            worstPriority = running.value.priority;
            victimKey = running.key;
          }
        }

        if (victimKey != null && _runningProcesses.containsKey(victimKey)) {
          final proc = _runningProcesses[victimKey];
          if (proc != null) {
            _terminateProcess(proc);
          }
        }
      }
    }
  }

  /// Registers an external process handle so it can be gracefully terminated if cancelled.
  void registerRunningProcess(String jobKey, Process process) {
    if (_isCancelled || _isDisposed) {
      _terminateProcess(process);
      return;
    }
    _runningProcesses[jobKey] = process;
  }

  /// Unregisters a completed process handle.
  void unregisterRunningProcess(String jobKey) {
    _runningProcesses.remove(jobKey);
  }

  void _terminateProcess(Process process) {
    try {
      var hasExited = false;
      process.exitCode.then((_) {
        hasExited = true;
      }).catchError((dynamic _) => null);

      // 1. Send graceful SIGTERM first
      process.kill();

      // 2. Wait up to graceMillis (300ms) before escalating to SIGKILL
      Future<void>.delayed(const Duration(milliseconds: graceMillis), () {
        if (!hasExited) {
          try {
            process.kill(ProcessSignal.sigkill);
          } catch (_) {
            // Process may have already exited
          }
        }
      });
    } catch (e) {
      debugPrint('[ThumbnailSession] Error terminating process: $e');
    }
  }

  void _processNext() {
    if (_isCancelled || _isDisposed) return;

    for (var i = 0; i < _queue.length;) {
      final entry = _queue[i];
      final isVideo = entry.job.isVideo;

      final canRun = isVideo
          ? _activeVideoCount < maxVideoWorkers
          : _activeImageCount < maxImageWorkers;

      if (!canRun) {
        i++;
        continue;
      }

      _queue.removeAt(i);
      final key = entry.job.key;
      _queuedKeys.remove(key);
      _queueMap.remove(key);
      _runningKeys.add(key);
      _runningJobs[key] = entry.job;

      if (isVideo) {
        _activeVideoCount++;
      } else {
        _activeImageCount++;
      }

      () async {
        try {
          if (!_isCancelled && !_isDisposed) {
            await entry.job.task();
          }
        } catch (e) {
          debugPrint(
            '[ThumbnailSession] Error generating thumbnail for ${entry.job.filePath}: $e',
          );
        } finally {
          _runningJobs.remove(key);
          _runningProcesses.remove(key);
          _runningKeys.remove(key);
          if (!_isCancelled && !_isDisposed) {
            _completedKeys.add(key);
          }

          if (isVideo) {
            _activeVideoCount--;
          } else {
            _activeImageCount--;
          }

          final _ = _inFlightFutures.remove(key);

          if (!entry.completer.isCompleted) {
            entry.completer.complete();
          }

          _processNext();
        }
      }();
      i = 0;
    }
  }

  /// Cancels all pending jobs and terminates active processes gracefully.
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;

    // Drain queued entries
    for (final entry in _queue) {
      _queuedKeys.remove(entry.job.key);
      if (!entry.completer.isCompleted) {
        entry.completer.complete();
      }
    }
    _queue.clear();
    _queueMap.clear();
    _inFlightFutures.clear();

    // Terminate all running processes
    for (final process in _runningProcesses.values) {
      _terminateProcess(process);
    }
    _runningProcesses.clear();
  }

  /// Disposes the session.
  void dispose() {
    if (_isDisposed) return;
    cancel();
    _isDisposed = true;
    _inFlightFutures.clear();
  }
}
