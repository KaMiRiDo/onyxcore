import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;

import '../../../../core/cache/thumbnail_cache_service.dart';
import '../../../../features/settings/presentation/providers/settings_providers.dart';
import '../../../../core/utils/file_type_classifier.dart';
import '../../domain/entities/file_item.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Thumbnail Generation Queue — viewport-aware, with reprioritization
// ─────────────────────────────────────────────────────────────────────────────

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

/// Entry in the thumbnail generation queue.
class _QueueEntry {
  _QueueEntry({
    required this.filePath,
    required this.task,
    required this.completer,
    this.priority = 999999,
  });

  final String filePath;
  final Future<void> Function() task;
  final Completer<void> completer;
  int priority;
}

/// Concurrency-bounded thumbnail generation queue with viewport-aware
/// reprioritization.
///
/// Items currently visible on screen are processed before off-screen items.
/// When the user scrolls, [reprioritize] reorders pending tasks so visible
/// items jump to the front of the queue.
class ThumbnailGenerationQueue {
  static final List<_QueueEntry> _queue = [];
  static int _activeCount = 0;
  static const int _maxConcurrent = 4;

  /// Enqueue a thumbnail generation task.
  ///
  /// [filePath] identifies the file for reprioritization.
  /// [priority] is the item's index in the grid (lower = higher priority).
  static Future<void> enqueue(
    Future<void> Function() task, {
    required String filePath,
    int priority = 999999,
  }) async {
    final completer = Completer<void>();
    _queue.add(_QueueEntry(
      filePath: filePath,
      task: task,
      completer: completer,
      priority: priority,
    ));
    _sortQueue();
    _processQueue();
    return completer.future;
  }

  /// Reprioritize the queue: items with paths in [visiblePaths] get
  /// priority 0 (front of queue), others get pushed back.
  ///
  /// Only affects items that haven't started processing yet.
  static void reprioritize(Set<String> visiblePaths) {
    for (final entry in _queue) {
      entry.priority = visiblePaths.contains(entry.filePath) ? 0 : 999999;
    }
    _sortQueue();
  }

  /// Sort queue by priority (lower first).
  static void _sortQueue() {
    _queue.sort((a, b) => a.priority.compareTo(b.priority));
  }

  static void _processQueue() {
    while (_activeCount < _maxConcurrent && _queue.isNotEmpty) {
      _activeCount++;
      final entry = _queue.removeAt(0);
      unawaited(_runEntry(entry));
    }
  }

  static Future<void> _runEntry(_QueueEntry entry) async {
    try {
      await entry.task();
    } finally {
      entry.completer.complete();
      _activeCount--;
      _processQueue();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MediaThumbnailPreview — uses global ThumbnailCacheService
// ─────────────────────────────────────────────────────────────────────────────

class MediaThumbnailPreview extends ConsumerStatefulWidget {
  const MediaThumbnailPreview({
    required this.item,
    required this.zoom,
    super.key,
  });

  final FileItem item;
  final double zoom;

  @override
  ConsumerState<MediaThumbnailPreview> createState() =>
      _MediaThumbnailPreviewState();
}

class _MediaThumbnailPreviewState extends ConsumerState<MediaThumbnailPreview> {
  String? _cachedThumbPath;
  bool _isLandscape = true;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    debugPrint('MediaThumbnailPreview: initState for ${widget.item.name}');
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(MediaThumbnailPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path) {
      debugPrint(
        'MediaThumbnailPreview: didUpdateWidget from '
        '${oldWidget.item.name} to ${widget.item.name}',
      );
      _cachedThumbPath = null;
      _loadThumbnail();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _loadThumbnail() async {
    final cacheService = ref.read(thumbnailCacheServiceProvider);
    final filePath = widget.item.path;

    final mtime = widget.item.modified.millisecondsSinceEpoch;
    final sizeBytes = widget.item.sizeBytes ?? 0;

    // 1. Wait for index to load, then check the global cache
    await cacheService.ensureLoaded();
    if (_disposed || !mounted) return;

    final result = cacheService.lookup(
      filePath: filePath,
      mtime: mtime,
      sizeBytes: sizeBytes,
    );

    switch (result) {
      case ThumbnailLookupResult.hit:
        // Cache hit — use immediately
        final cachedPath = cacheService.getCachedPath(filePath);
        if (cachedPath != null) {
          final file = File(cachedPath);
          if (file.existsSync()) {
            final isLandscape = await _checkIsLandscape(file);
            if (!_disposed && mounted) {
              setState(() {
                _isLandscape = isLandscape;
                _cachedThumbPath = cachedPath;
              });
            }
            return;
          }
        }
        // Cached file missing from disk — fall through to regenerate
        break;

      case ThumbnailLookupResult.failed:
        // Previously failed — don't retry, show fallback
        return;

      case ThumbnailLookupResult.miss:
        // No valid cache — fall through to generate
        break;
    }

    // 2. Queue for generation
    unawaited(ThumbnailGenerationQueue.enqueue(
      () async {
        if (_disposed || !mounted) return;

        await ThumbnailCacheService.ensureCacheDirs();

        // Generate to a temp path first
        final tempThumbPath =
            ThumbnailCacheService.computeCachePath(filePath, ThumbnailSize.normal);

        try {
          final isImage = widget.item.type == FileItemType.image;
          final ext = filePath.toLowerCase();
          final isCommonImage = isImage && (
             ext.endsWith('.jpg') || ext.endsWith('.jpeg') ||
             ext.endsWith('.png') || ext.endsWith('.webp') ||
             ext.endsWith('.gif') || ext.endsWith('.bmp') ||
             ext.endsWith('.tiff') || ext.endsWith('.tif')
          );

          bool generated = false;

          // 1. Try Dart image package for common image formats
          if (isCommonImage) {
            generated = await compute(_generateImageThumbnail, [filePath, tempThumbPath]);
          }

          // 2. Try heif-thumbnailer for HEIC/HEIF
          if (!generated && (ext.endsWith('.heic') || ext.endsWith('.heif'))) {
            final process = await Process.start('heif-thumbnailer', [
              '-s', '320',
              filePath,
              tempThumbPath,
            ]);
            final exitCode = await process.exitCode;
            generated = exitCode == 0 && File(tempThumbPath).existsSync();
          }

          // 3. Fallback to FFmpeg for videos and RAW images
          if (!generated) {
            final ffmpegArgs = isImage ? [
              '-y',
              '-i', filePath,
              '-vf', 'scale=320:-1',
              '-q:v', '5',
              '-loglevel', 'error',
              tempThumbPath,
            ] : [
              '-y',
              '-ss', '00:00:01',
              '-i', filePath,
              '-vframes', '1',
              '-an',
              '-vf', 'scale=320:-1',
              '-q:v', '5',
              '-loglevel', 'error',
              tempThumbPath,
            ];

            final process = await Process.start('ffmpeg', ffmpegArgs);
            final exitCode = await process.exitCode;
            debugPrint(
              'MediaThumbnailPreview: FFmpeg exit code: $exitCode for $tempThumbPath',
            );
            generated = (exitCode == 0);
          }

          final thumbFile = File(tempThumbPath);
          if (generated && thumbFile.existsSync()) {
            debugPrint(
              'MediaThumbnailPreview: Thumbnail created successfully '
              'for ${widget.item.name}',
            );

            // Store in global cache
            await cacheService.storeThumbnail(
              filePath: filePath,
              mtime: mtime,
              sizeBytes: sizeBytes,
              kind: isImage ? 'image' : 'video',
              thumbnailFile: thumbFile,
            );

            final isLandscape = await _checkIsLandscape(thumbFile);
            if (!_disposed && mounted) {
              setState(() {
                _isLandscape = isLandscape;
                _cachedThumbPath = tempThumbPath;
              });
            }
          } else {
            debugPrint(
              'MediaThumbnailPreview: Thumbnail generation failed '
              'for ${widget.item.name}',
            );
            // Mark as failed so we don't retry
            await cacheService.markFailed(
              filePath: filePath,
              mtime: mtime,
              sizeBytes: sizeBytes,
              kind: isImage ? 'image' : 'video',
            );
          }
        } catch (e) {
          debugPrint(
            'MediaThumbnailPreview: FFmpeg failed for '
            '${widget.item.name} with error $e',
          );
          // Mark as failed
          await cacheService.markFailed(
            filePath: filePath,
            mtime: mtime,
            sizeBytes: sizeBytes,
            kind: 'video',
          );
        }
      },
      filePath: filePath,
    ));
  }

  Future<bool> _checkIsLandscape(File file) async {
    if (widget.item.type == FileItemType.image) return true;
    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image.width >= frame.image.height;
    } catch (e) {
      return true;
    }
  }

  Widget _buildSvgIcon(String path) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        color: Colors.white.withOpacity(0.02),
      ),
      child: Center(
        child: SvgPicture.asset(
          path,
          width: 42 * widget.zoom,
          height: 42 * widget.zoom,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cachedThumbPath != null) {
      if (widget.item.type == FileItemType.image) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Image.file(
              File(_cachedThumbPath!),
              fit: widget.item.imageAspectRatio != null && widget.item.imageAspectRatio! < 1
                  ? BoxFit.contain
                  : BoxFit.cover,
              cacheWidth: 300,
            ),
          ),
        );
      }

      // 16:9 for landscape, 3:4 for portrait (so it's not too narrow/sleek in the grid)
      final double aspectRatio = _isLandscape ? (16 / 9) : (3 / 4);
      final double innerWidth = 140.0;
      final double innerHeight = innerWidth / aspectRatio;

      // Because portrait is taller, it gets scaled down more to fit the grid height.
      // We scale up its borders/holes so they appear the same visual size as landscape on screen.
      final double borderScale =
          _isLandscape ? 1.0 : (innerHeight / 140.0);

      return Center(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: innerWidth,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 6.0,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: CustomPaint(
                foregroundPainter: FilmstripHolesPainter(scale: borderScale),
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 14.0 * borderScale,
                    right: 14.0 * borderScale,
                    top: 4.0 * borderScale,
                    bottom: 4.0 * borderScale,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4.0 * borderScale),
                    child: SizedBox(
                      width: innerWidth - (28.0 * borderScale),
                      height: innerHeight - (8.0 * borderScale),
                      child: Image.file(
                        File(_cachedThumbPath!),
                        fit: BoxFit.cover,
                        cacheWidth: 300,
                        frameBuilder: (context, child, frame,
                            wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded) return child;
                          if (frame == null) {
                            return SizedBox(
                              width: 112.0,
                              height: 63.0,
                              child: Center(
                                child: SvgPicture.asset(
                                  'assets/icons/video.svg',
                                  width: 42.0,
                                  height: 42.0,
                                ),
                              ),
                            );
                          }
                          return child;
                        },
                        errorBuilder: (_, __, ___) => SizedBox(
                          width: 112.0,
                          height: 63.0,
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/video.svg',
                              width: 42.0,
                              height: 42.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return _buildSvgIcon(widget.item.type == FileItemType.image ? 'assets/icons/image.svg' : 'assets/icons/video.svg');
  }
}

class FilmstripHolesPainter extends CustomPainter {
  final double scale;

  FilmstripHolesPainter({this.scale = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final holePaint = Paint()..color = const Color(0xFFEEEEEE); // Light holes

    final double stripWidth = 14.0 * scale;
    final double holeWidth = 8.0 * scale;
    final double holeHeight = 6.0 * scale;
    final double spacing = 6.0 * scale;

    final double holeXLeft = (stripWidth - holeWidth) / 2;
    final double holeXRight =
        size.width - stripWidth + (stripWidth - holeWidth) / 2;

    final int holeCount =
        ((size.height - spacing) / (holeHeight + spacing)).floor();
    final double totalHolesHeight =
        holeCount * holeHeight + (holeCount - 1) * spacing;
    double y = (size.height - totalHolesHeight) / 2;

    for (int i = 0; i < holeCount; i++) {
      final leftRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(holeXLeft, y, holeWidth, holeHeight),
        Radius.circular(1.5 * scale),
      );
      final rightRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(holeXRight, y, holeWidth, holeHeight),
        Radius.circular(1.5 * scale),
      );
      canvas.drawRRect(leftRect, holePaint);
      canvas.drawRRect(rightRect, holePaint);
      y += holeHeight + spacing;
    }
  }

  @override
  bool shouldRepaint(covariant FilmstripHolesPainter oldDelegate) => false;
}
