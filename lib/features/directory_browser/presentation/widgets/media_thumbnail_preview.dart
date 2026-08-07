import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/data/datasources/media_metadata_datasource.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/thumbnail_session.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/thumbnail_session_manager.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MediaThumbnailPreview — uses session-based thumbnail lifecycle & global cache
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

    // Direct display if browsing inside thumbnail cache folder
    if (ThumbnailCacheService.isThumbnailCachePath(widget.item.path)) {
      if (widget.item.type == FileItemType.image) {
        _cachedThumbPath = widget.item.path;
        _isLandscape = _checkIsLandscape(widget.item.path);
        return;
      }
    }

    // Fast synchronous cache hit check
    try {
      final cacheService = ref.read(thumbnailCacheServiceProvider);
      final filePath = widget.item.path;
      final mtime = widget.item.modified.millisecondsSinceEpoch;
      final sizeBytes = widget.item.sizeBytes ?? 0;

      final syncHit = cacheService.lookup(
        filePath: filePath,
        mtime: mtime,
        sizeBytes: sizeBytes,
      );
      if (syncHit == ThumbnailLookupResult.hit) {
        final cachedPath = cacheService.getCachedPath(filePath);
        if (cachedPath != null) {
          _cachedThumbPath = cachedPath;
          _isLandscape = _checkIsLandscape(cachedPath);
          return;
        }
      }
    } catch (_) {}

    _loadThumbnail();
  }

  @override
  void didUpdateWidget(MediaThumbnailPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path) {
      // Direct display if browsing inside thumbnail cache folder
      if (ThumbnailCacheService.isThumbnailCachePath(widget.item.path)) {
        if (widget.item.type == FileItemType.image) {
          _cachedThumbPath = widget.item.path;
          _isLandscape = _checkIsLandscape(widget.item.path);
          return;
        }
      }

      try {
        final cacheService = ref.read(thumbnailCacheServiceProvider);
        final filePath = widget.item.path;
        final mtime = widget.item.modified.millisecondsSinceEpoch;
        final sizeBytes = widget.item.sizeBytes ?? 0;

        final syncHit = cacheService.lookup(
          filePath: filePath,
          mtime: mtime,
          sizeBytes: sizeBytes,
        );
        if (syncHit == ThumbnailLookupResult.hit) {
          final cachedPath = cacheService.getCachedPath(filePath);
          if (cachedPath != null) {
            _cachedThumbPath = cachedPath;
            _isLandscape = _checkIsLandscape(cachedPath);
            return;
          }
        }
      } catch (_) {}

      _cachedThumbPath = null;
      _isLandscape = true;
      _loadThumbnail();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _loadThumbnail() async {
    if (_disposed || !mounted) return;

    final filePath = widget.item.path;
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return;
    }

    if (ThumbnailCacheService.isThumbnailCachePath(filePath)) {
      if (widget.item.type == FileItemType.image) {
        if (!_disposed && mounted) {
          setState(() {
            _cachedThumbPath = filePath;
            _isLandscape = _checkIsLandscape(filePath);
          });
        }
        return;
      }
    }

    // Read provider state synchronously before any async gap
    final cacheService = ref.read(thumbnailCacheServiceProvider);
    final session = ref.read(activeThumbnailSessionProvider);
    final mtime = widget.item.modified.millisecondsSinceEpoch;
    final sizeBytes = widget.item.sizeBytes ?? 0;

    // 1. Wait for index to load, then check the global cache
    await cacheService.ensureLoaded();
    if (_disposed || !mounted) return;

    final result = await cacheService.lookupAsync(
      filePath: filePath,
      mtime: mtime,
      sizeBytes: sizeBytes,
    );
    if (_disposed || !mounted) return;

    switch (result) {
      case ThumbnailLookupResult.hit:
        // Cache hit — use immediately
        final cachedPath = await cacheService.getCachedPathAsync(filePath);
        if (_disposed || !mounted) return;
        if (cachedPath != null) {
          final file = File(cachedPath);
          try {
            // ignore: avoid_slow_async_io
            if (await file.exists()) {
              if (!_disposed && mounted) {
                setState(() {
                  _cachedThumbPath = cachedPath;
                  _isLandscape = _checkIsLandscape(cachedPath);
                });
              }
              return;
            }
          } catch (_) {}
        }
      // Cached file missing from disk — fall through to regenerate

      case ThumbnailLookupResult.failed:
        // Previously failed — don't retry, show fallback
        return;

      case ThumbnailLookupResult.miss:
        // No valid cache — fall through to generate
        break;
    }

    if (_disposed || !mounted) return;

    // 2. Enqueue in active thumbnail session
    if (session == null || session.isCancelled || session.isDisposed) {
      return;
    }

    final job = session.createJobForFileItem(
      item: widget.item,
      cacheService: cacheService,
      priority: 0,
    );

    await session.enqueue(job);
    if (_disposed || !mounted) return;

    if (_cachedThumbPath == null) {
      try {
        final cachedPath = await cacheService.getCachedPathAsync(filePath);
        if (_disposed || !mounted) return;
        if (cachedPath != null) {
          final file = File(cachedPath);
          // ignore: avoid_slow_async_io
          if (await file.exists()) {
            if (!_disposed && mounted) {
              setState(() {
                _cachedThumbPath = cachedPath;
                _isLandscape = _checkIsLandscape(cachedPath);
              });
            }
          }
        }
      } catch (_) {}
    }
  }

  bool _checkIsLandscape([String? thumbPath]) {
    if (widget.item.imageAspectRatio != null) {
      return widget.item.imageAspectRatio! >= 1.0;
    }
    final path = thumbPath ?? _cachedThumbPath;
    if (path != null) {
      final ratio = MediaMetadataDatasource.parseImageDimensions(path);
      if (ratio != null) {
        return ratio >= 1.0;
      }
    }
    return true;
  }

  Widget _buildSvgIcon(String path) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        color: Colors.white.withValues(alpha: 0.02),
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
    ref.listen<ThumbnailSession?>(activeThumbnailSessionProvider, (prev, next) {
      if (next != null &&
          !next.isCancelled &&
          !next.isDisposed &&
          _cachedThumbPath == null) {
        _loadThumbnail();
      }
    });

    if (_cachedThumbPath != null) {
      if (widget.item.type == FileItemType.image) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox.expand(
            child: Image.file(
              File(_cachedThumbPath!),
              fit:
                  widget.item.imageAspectRatio != null &&
                      widget.item.imageAspectRatio! < 1
                  ? BoxFit.contain
                  : BoxFit.cover,
              cacheWidth: 300,
              errorBuilder: (context, error, stackTrace) {
                return _buildSvgIcon(
                  widget.item.type == FileItemType.image
                      ? 'assets/icons/image.svg'
                      : 'assets/icons/video.svg',
                );
              },
            ),
          ),
        );
      }

      // Target dimensions: 16:9 for landscape, 3:4 for portrait.
      // Sizing them directly ensures filmstrip borders and holes are identical in pixel size on screen.
      final double targetWidth;
      final double targetHeight;
      if (_isLandscape) {
        targetWidth = 140.0;
        targetHeight = 140.0 / (16 / 9); // ~78.75
      } else {
        targetHeight = 112.0;
        targetWidth = targetHeight * (3 / 4); // 84.0
      }

      return Center(
        child: FittedBox(
          child: SizedBox(
            width: targetWidth,
            height: targetHeight,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF333333),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: CustomPaint(
                foregroundPainter: FilmstripHolesPainter(),
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 14,
                    right: 14,
                    top: 4,
                    bottom: 4,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      width: targetWidth - 28,
                      height: targetHeight - 8,
                      child: Image.file(
                        File(_cachedThumbPath!),
                        fit: BoxFit.cover,
                        cacheWidth: 300,
                        frameBuilder:
                            (context, child, frame, wasSynchronouslyLoaded) {
                              if (wasSynchronouslyLoaded) return child;
                              if (frame == null) {
                                return SizedBox(
                                  width: targetWidth - 28.0,
                                  height: targetHeight - 8.0,
                                  child: Center(
                                    child: SvgPicture.asset(
                                      'assets/icons/video.svg',
                                      width: 42,
                                      height: 42,
                                    ),
                                  ),
                                );
                              }
                              return child;
                            },
                        errorBuilder: (_, __, ___) => SizedBox(
                          width: targetWidth - 28.0,
                          height: targetHeight - 8.0,
                          child: Center(
                            child: SvgPicture.asset(
                              'assets/icons/video.svg',
                              width: 42,
                              height: 42,
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

    final netUrl =
        ((widget.item.thumbnailPath?.isNotEmpty ?? false) &&
            (widget.item.thumbnailPath!.startsWith('http://') ||
                widget.item.thumbnailPath!.startsWith('https://')))
        ? widget.item.thumbnailPath
        : ((widget.item.type == FileItemType.image &&
                  (widget.item.path.startsWith('http://') ||
                      widget.item.path.startsWith('https://')))
              ? widget.item.path
              : null);

    if (netUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox.expand(
          child: Image.network(
            netUrl,
            fit: BoxFit.cover,
            cacheWidth: 300,
            errorBuilder: (c, e, s) => _buildSvgIcon(
              widget.item.type == FileItemType.image
                  ? 'assets/icons/image.svg'
                  : 'assets/icons/video.svg',
            ),
          ),
        ),
      );
    }

    return _buildSvgIcon(
      widget.item.type == FileItemType.image
          ? 'assets/icons/image.svg'
          : 'assets/icons/video.svg',
    );
  }
}

class FilmstripHolesPainter extends CustomPainter {
  FilmstripHolesPainter({this.scale = 1.0});
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    final holePaint = Paint()..color = const Color(0xFFEEEEEE); // Light holes

    final stripWidth = 14.0 * scale;
    final holeWidth = 8.0 * scale;
    final holeHeight = 6.0 * scale;
    final spacing = 6.0 * scale;

    final holeXLeft = (stripWidth - holeWidth) / 2;
    final holeXRight = size.width - stripWidth + (stripWidth - holeWidth) / 2;

    final holeCount = ((size.height - spacing) / (holeHeight + spacing))
        .floor();
    final totalHolesHeight = holeCount * holeHeight + (holeCount - 1) * spacing;
    var y = (size.height - totalHolesHeight) / 2;

    for (var i = 0; i < holeCount; i++) {
      final leftRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(holeXLeft, y, holeWidth, holeHeight),
        Radius.circular(1.5 * scale),
      );
      final rightRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(holeXRight, y, holeWidth, holeHeight),
        Radius.circular(1.5 * scale),
      );
      canvas
        ..drawRRect(leftRect, holePaint)
        ..drawRRect(rightRect, holePaint);
      y += holeHeight + spacing;
    }
  }

  @override
  bool shouldRepaint(covariant FilmstripHolesPainter oldDelegate) => false;
}
