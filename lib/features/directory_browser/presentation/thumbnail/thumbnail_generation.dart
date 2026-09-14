import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/core/platform/process_priority.dart';
import 'package:onyxcore/features/directory_browser/presentation/thumbnail/thumbnail_job.dart';
import 'package:onyxcore/features/directory_browser/presentation/thumbnail/thumbnail_scheduling_policy.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Process-lifecycle interface
// ─────────────────────────────────────────────────────────────────────────────

/// Narrow interface for registering and unregistering external thumbnailer
/// processes with the session. Implemented by [ThumbnailSession].
///
/// The generation layer uses this interface so it does not couple to [ThumbnailSession]
/// directly. The session remains the single owner of the jobKey → [Process] map.
abstract interface class ThumbnailProcessController {
  /// Register [process] under [jobKey] so that the session can terminate it on
  /// cancellation or preemption.
  ///
  /// If the session is already cancelled/disposed, the implementation must
  /// terminate [process] immediately and not store the reference.
  void registerRunningProcess(String jobKey, Process process);

  /// Remove the process associated with [jobKey] from the session's registry.
  /// Must be called in a `finally` block to cover all exit paths.
  void unregisterRunningProcess(String jobKey);
}

// ─────────────────────────────────────────────────────────────────────────────
// Common image format detection and thumbnailer command helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Returns `true` for file extensions eligible for in-process Dart image
/// decoding via the `image` package.
bool isCommonImageFormat(String filePath) {
  final ext = filePath.toLowerCase();
  return ext.endsWith('.jpg') ||
      ext.endsWith('.jpeg') ||
      ext.endsWith('.png') ||
      ext.endsWith('.webp') ||
      ext.endsWith('.gif') ||
      ext.endsWith('.bmp') ||
      ext.endsWith('.tiff') ||
      ext.endsWith('.tif');
}

/// Returns the external thumbnailer command for [filePath] → [tempThumbPath].
///
/// Routes:
/// - HEIC / HEIF / AVIF → `heif-thumbnailer`
/// - DNG → `gdk-pixbuf-thumbnailer`
/// - Everything else (images + videos) → `ffmpeg`
List<String> getThumbnailerCommand(
  String filePath,
  String tempThumbPath, {
  required bool isImage,
}) {
  final ext = filePath.toLowerCase();
  if (ext.endsWith('.heic') || ext.endsWith('.heif') || ext.endsWith('.avif')) {
    return ['heif-thumbnailer', '-s', '320', filePath, tempThumbPath];
  }
  if (ext.endsWith('.dng')) {
    return ['gdk-pixbuf-thumbnailer', '-s', '320', filePath, tempThumbPath];
  }
  return [
    'ffmpeg',
    '-y',
    if (!isImage) ...['-ss', '00:00:01'],
    '-i',
    filePath,
    '-vframes',
    '1',
    if (!isImage) '-an',
    if (isImage) ...['-update', '1'],
    '-vf',
    'scale=320:-1',
    '-q:v',
    '5',
    '-loglevel',
    'error',
    tempThumbPath,
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
// Top-level compute function — runs in a separate isolate
// ─────────────────────────────────────────────────────────────────────────────

/// Top-level function for background image thumbnail generation via [compute].
///
/// args[0] = source file path
/// args[1] = destination temp file path
Future<bool> generateImageThumbnailIsolate(List<String> args) async {
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

// ─────────────────────────────────────────────────────────────────────────────
// Main generation function
// ─────────────────────────────────────────────────────────────────────────────

/// Generates a thumbnail for [job.candidate], storing the result via [cacheService].
///
/// The [processController] is used to register/unregister any spawned external
/// thumbnailer process so the session can terminate it on cancellation/preemption.
///
/// [isCancelledOrDisposed] and [isJobRelevant] are evaluated before each cache
/// mutation to produce the correct [ThumbnailJobOutcome] per the result matrix:
///
/// | Outcome              | Cancelled/disposed | Obsolete | Current |
/// |----------------------|--------------------|----------|---------|
/// | Valid thumbnail      | cancelled          | obsolete | success |
/// | Generation fails     | cancelled          | obsolete | failed  |
/// | Process/compute error| cancelled          | obsolete | failed  |
///
/// A valid obsolete result is committed to the disk cache because it remains
/// reusable when the user scrolls back. Obsolete failures are never negative-cached.
Future<ThumbnailJobOutcome> generateMediaThumbnail({
  required ThumbnailJob job,
  required ThumbnailCacheService cacheService,
  required ThumbnailProcessController processController,
  required bool Function() isCancelledOrDisposed,
  required bool Function() isJobRelevant,
}) async {
  // ── Early exit: session gone ───────────────────────────────────────────────
  if (isCancelledOrDisposed()) return ThumbnailJobOutcome.cancelled;

  final candidate = job.candidate;
  final filePath = candidate.path;
  final mtime = candidate.modifiedEpochMs;
  final sizeBytes = candidate.sizeBytes;

  // ── Cache lookup: may have been written by another running job ─────────────
  final lookup = cacheService.lookup(
    filePath: filePath,
    mtime: mtime,
    sizeBytes: sizeBytes,
  );
  if (lookup == ThumbnailLookupResult.hit) return ThumbnailJobOutcome.success;
  if (lookup == ThumbnailLookupResult.failed) return ThumbnailJobOutcome.failed;

  await ThumbnailCacheService.ensureCacheDirs();

  final tempThumbPath = ThumbnailCacheService.computeTempPath(filePath, ThumbnailSize.normal);
  final finalCachePath = ThumbnailCacheService.computeCachePath(filePath, ThumbnailSize.normal);

  try {
    final isImage = candidate.isImage;
    final isCommon = isImage && isCommonImageFormat(filePath);
    var generated = false;

    // ── 1. Dart image package (common image formats ≤ 5 MB) ─────────────────
    if (isCommon &&
        sizeBytes > 0 &&
        sizeBytes <= ThumbnailSchedulingPolicy.dartDecodeMaxBytes) {
      generated = await compute(generateImageThumbnailIsolate, [filePath, tempThumbPath]);
    }

    // ── 2. External thumbnailer / FFmpeg fallback ────────────────────────────
    if (!generated) {
      final command = getThumbnailerCommand(
        filePath,
        tempThumbPath,
        isImage: isImage,
      );
      final executable = command.first;
      final args = command.sublist(1);

      Process? process;
      var processRegistered = false;
      try {
        process = await Process.start(executable, args);
        // Register immediately — session can now terminate it if needed.
        processController.registerRunningProcess(job.key, process);
        processRegistered = true;

        unawaited(setLowProcessPriority(process.pid));
        process.stdout.drain<void>().ignore();
        process.stderr.drain<void>().ignore();
        await process.exitCode;
      } finally {
        if (processRegistered) {
          processController.unregisterRunningProcess(job.key);
        }
      }

      final file = File(tempThumbPath);
      try {
        generated = file.existsSync() && file.lengthSync() > 0;
      } catch (_) {
        generated = false;
      }
    }

    // ── Evaluate relevance before any cache mutation ──────────────────────────
    final sessionGone = isCancelledOrDisposed();
    final relevant = !sessionGone && isJobRelevant();

    final thumbFile = File(tempThumbPath);
    var thumbExists = false;
    try {
      thumbExists = thumbFile.existsSync() && thumbFile.lengthSync() > 0;
    } catch (_) {}

    if (generated && thumbExists) {
      if (sessionGone) {
        // Session gone — discard partial file; no commit.
        _deleteSilently(thumbFile);
        return ThumbnailJobOutcome.cancelled;
      }

      // Atomic commit: rename temp → final cache path.
      final committedFile = thumbFile.renameSync(finalCachePath);
      await cacheService.storeThumbnail(
        filePath: filePath,
        mtime: mtime,
        sizeBytes: sizeBytes,
        kind: isImage ? 'image' : 'video',
        thumbnailFile: committedFile,
      );
      // Obsolete results are committed (reusable on re-scroll) but reported as obsolete.
      return relevant ? ThumbnailJobOutcome.success : ThumbnailJobOutcome.obsolete;
    } else {
      // Generation produced no usable output.
      _deleteSilently(thumbFile);

      if (sessionGone) return ThumbnailJobOutcome.cancelled;
      if (!relevant) return ThumbnailJobOutcome.obsolete;

      await cacheService.markFailed(
        filePath: filePath,
        mtime: mtime,
        sizeBytes: sizeBytes,
        kind: isImage ? 'image' : 'video',
      );
      return ThumbnailJobOutcome.failed;
    }
  } catch (e) {
    _deleteSilently(File(tempThumbPath));

    if (isCancelledOrDisposed()) return ThumbnailJobOutcome.cancelled;
    if (!isJobRelevant()) return ThumbnailJobOutcome.obsolete;

    await cacheService.markFailed(
      filePath: filePath,
      mtime: mtime,
      sizeBytes: sizeBytes,
      kind: candidate.isImage ? 'image' : 'video',
    );
    return ThumbnailJobOutcome.failed;
  }
}

void _deleteSilently(File file) {
  try {
    if (file.existsSync()) file.deleteSync();
  } catch (_) {}
}
