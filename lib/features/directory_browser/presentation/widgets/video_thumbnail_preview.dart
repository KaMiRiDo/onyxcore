import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/file_item.dart';

class VideoThumbnailQueue {
  static final List<Future<void> Function()> _queue = [];
  static int _activeCount = 0;
  static const int _maxConcurrent = 2;

  static Future<void> enqueue(Future<void> Function() task) async {
    final completer = Completer<void>();
    _queue.add(() async {
      try {
        await task();
      } finally {
        completer.complete();
        _activeCount--;
        _processQueue();
      }
    });
    _processQueue();
    return completer.future;
  }

  static void _processQueue() {
    while (_activeCount < _maxConcurrent && _queue.isNotEmpty) {
      _activeCount++;
      final task = _queue.removeAt(0);
      unawaited(task());
    }
  }
}

class VideoThumbnailPreview extends StatefulWidget {
  const VideoThumbnailPreview({
    required this.item,
    required this.zoom,
    super.key,
  });

  final FileItem item;
  final double zoom;

  @override
  State<VideoThumbnailPreview> createState() => _VideoThumbnailPreviewState();
}

class _VideoThumbnailPreviewState extends State<VideoThumbnailPreview> {
  String? _cachedThumbPath;
  bool _isLandscape = true;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    debugPrint('VideoThumbnailPreview: initState for ${widget.item.name}');
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(VideoThumbnailPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path) {
      debugPrint('VideoThumbnailPreview: didUpdateWidget from ${oldWidget.item.name} to ${widget.item.name}');
      _cachedThumbPath = null;
      _loadThumbnail();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  String _getThumbnailPath(String videoPath) {
    final hash = videoPath.hashCode.toString();
    final fileName = p.basename(videoPath);
    final cacheDir = "${Platform.environment['HOME']}/.cache/onyxcore/thumbnails";
    return '$cacheDir/${hash}_$fileName.jpg';
  }

  Future<void> _loadThumbnail() async {
    final thumbPath = _getThumbnailPath(widget.item.path);
    final file = File(thumbPath);

    if (await file.exists()) {
      final isLandscape = await _checkIsLandscape(file);
      if (!_disposed && mounted) {
        setState(() {
          _isLandscape = isLandscape;
          _cachedThumbPath = thumbPath;
        });
      }
      return;
    }

    // Generate thumbnail using FFmpeg
    unawaited(VideoThumbnailQueue.enqueue(() async {
      if (_disposed || !mounted) return;

      final cacheDir = Directory("${Platform.environment['HOME']}/.cache/onyxcore/thumbnails");
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      try {
        final process = await Process.start('ffmpeg', [
          '-y', // Overwrite
          '-ss', '00:00:01', // Grab frame at 1 second
          '-i', widget.item.path,
          '-vframes', '1',
          '-an',
          '-vf', 'scale=320:-1',
          '-q:v', '5',
          '-loglevel', 'error',
          thumbPath,
        ]);

        debugPrint('VideoThumbnailPreview: FFmpeg exit code: ${await process.exitCode} for $thumbPath');

        if (await file.exists()) {
          debugPrint('VideoThumbnailPreview: Thumbnail created successfully for ${widget.item.name}');
          final isLandscape = await _checkIsLandscape(file);
          if (!_disposed && mounted) {
            setState(() {
              _isLandscape = isLandscape;
              _cachedThumbPath = thumbPath;
            });
          }
        } else {
          debugPrint('VideoThumbnailPreview: Thumbnail file does NOT exist after FFmpeg for ${widget.item.name}');
        }
      } catch (e) {
        debugPrint('VideoThumbnailPreview: FFmpeg failed for ${widget.item.name} with error $e');
        // Ignored
      }
    }));
  }

  Future<bool> _checkIsLandscape(File file) async {
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
      // 16:9 for landscape, 3:4 for portrait (so it's not too narrow/sleek in the grid)
      final double aspectRatio = _isLandscape ? (16 / 9) : (3 / 4);
      final double innerWidth = 140.0;
      final double innerHeight = innerWidth / aspectRatio;
      
      // Because portrait is taller, it gets scaled down more to fit the grid height.
      // We scale up its borders/holes so they appear the same visual size as landscape on screen.
      final double borderScale = _isLandscape ? 1.0 : (innerHeight / 140.0);

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
                        fit: BoxFit.cover, // Ensures uniform tile sizes
                        cacheWidth: 300,
                        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
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

    return _buildSvgIcon('assets/icons/video.svg');
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
    final double holeXRight = size.width - stripWidth + (stripWidth - holeWidth) / 2;

    final int holeCount = ((size.height - spacing) / (holeHeight + spacing)).floor();
    final double totalHolesHeight = holeCount * holeHeight + (holeCount - 1) * spacing;
    double y = (size.height - totalHolesHeight) / 2;

    for (int i = 0; i < holeCount; i++) {
      final leftRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(holeXLeft, y, holeWidth, holeHeight), 
        Radius.circular(1.5 * scale)
      );
      final rightRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(holeXRight, y, holeWidth, holeHeight), 
        Radius.circular(1.5 * scale)
      );
      canvas.drawRRect(leftRect, holePaint);
      canvas.drawRRect(rightRect, holePaint);
      y += holeHeight + spacing;
    }
  }

  @override
  bool shouldRepaint(covariant FilmstripHolesPainter oldDelegate) => false;
}
