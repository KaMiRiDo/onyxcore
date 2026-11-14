import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/directory_browser/data/datasources/media_metadata_datasource.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage1_normalizer.dart';
import 'package:path/path.dart' as p;

/// Renders an individual source or destination candidate file in a duplicate match.
///
/// Lazily loads image previews with bounded memory decoding, displays media metadata,
/// indicates match confidence/type for destinations, and provides inspect/open actions.
class FileComparisonTile extends ConsumerWidget {
  const FileComparisonTile({
    required this.filePath,
    required this.isSource,
    this.matchType,
    this.similarityScore,
    this.onOpen,
    this.onLocate,
    super.key,
  });

  final String filePath;
  final bool isSource;
  final MatchType? matchType;
  final double? similarityScore;
  final VoidCallback? onOpen;
  final VoidCallback? onLocate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fileName = p.basename(filePath);
    final fileType = classifyFileType(filePath);
    final file = File(filePath);
    final exists = file.existsSync();
    final sizeBytes = exists ? _tryGetFileSize(file) : null;
    final aspectRatio = (exists && fileType == FileItemType.image)
        ? _tryGetAspectRatio(filePath)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSource
              ? AppColors.violet.withValues(alpha: 0.3)
              : Colors.tealAccent.withValues(alpha: 0.25),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Double-clickable tile body (preview + metadata)
            Expanded(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onDoubleTap: () {
                    if (onOpen != null) {
                      onOpen!();
                    } else {
                      _defaultOpenMedia(context, fileType, exists, sizeBytes);
                    }
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Thumbnail / Preview box
                      _buildPreview(fileType, exists),
                      const SizedBox(width: 12),
                      // Metadata and details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Top row: Source/Destination badge + Match Type badge (if dest)
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _buildRoleBadge(),
                                if (!isSource && matchType != null)
                                  _buildMatchBadge(),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // File name
                            Tooltip(
                              message: filePath,
                              child: Text(
                                fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            // Path
                            Tooltip(
                              message: filePath,
                              child: Text(
                                filePath,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Metadata chips row
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                _buildMetaChip(
                                  icon: Icons.data_usage_rounded,
                                  text: sizeBytes != null
                                      ? StringUtils.formatBytes(sizeBytes)
                                      : 'Unavailable',
                                  isError: !exists,
                                ),
                                _buildMetaChip(
                                  icon: _mediaTypeIcon(fileType),
                                  text: fileType.name.toUpperCase(),
                                ),
                                if (aspectRatio != null)
                                  _buildMetaChip(
                                    icon: Icons.aspect_ratio_rounded,
                                    text: aspectRatio,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Top link button: locates in directory browser, never opens viewer directly
            IconButton(
              icon: const Icon(
                Icons.link_rounded,
                size: 18,
                color: Colors.white70,
              ),
              tooltip: 'Locate in Directory',
              onPressed: () {
                if (onLocate != null) {
                  onLocate!();
                } else {
                  _defaultLocateInFolder(ref);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isSource
            ? AppColors.violet.withValues(alpha: 0.2)
            : Colors.tealAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        isSource ? 'SOURCE' : 'DESTINATION',
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isSource ? AppColors.violet : Colors.tealAccent,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMatchBadge() {
    final isExact = matchType == MatchType.exact;
    final scoreText = similarityScore != null
        ? '${(similarityScore! * 100).toInt()}% Similarity'
        : 'Perceptual Match';
    final text = isExact ? 'Exact Match' : scoreText;
    final color = isExact ? Colors.greenAccent : Colors.amberAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildPreview(FileItemType type, bool exists) {
    const previewSize = 80.0;

    if (!exists) {
      return Container(
        width: previewSize,
        height: previewSize,
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: const Icon(
          Icons.broken_image_rounded,
          color: Colors.white30,
          size: 28,
        ),
      );
    }

    if (type == FileItemType.image) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: previewSize,
          height: previewSize,
          color: Colors.black38,
          child: Image.file(
            File(filePath),
            cacheWidth: 300,
            cacheHeight: 300,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Center(
              child: Icon(
                Icons.image_not_supported_rounded,
                color: Colors.white30,
                size: 28,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      width: previewSize,
      height: previewSize,
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Center(
        child: Icon(_mediaTypeIcon(type), color: Colors.white54, size: 32),
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String text,
    bool isError = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 11,
            color: isError ? Colors.redAccent : Colors.white60,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: isError ? Colors.redAccent : Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _mediaTypeIcon(FileItemType type) {
    switch (type) {
      case FileItemType.image:
        return Icons.image_rounded;
      case FileItemType.video:
        return Icons.videocam_rounded;
      case FileItemType.audio:
        return Icons.audiotrack_rounded;
      case FileItemType.document:
        return Icons.description_rounded;
      case FileItemType.folder:
        return Icons.folder_rounded;
      case FileItemType.archive:
        return Icons.archive_rounded;
      case FileItemType.downloaderList:
        return Icons.download_rounded;
      case FileItemType.other:
        return Icons.insert_drive_file_rounded;
    }
  }

  int? _tryGetFileSize(File file) {
    try {
      return file.lengthSync();
    } catch (_) {
      return null;
    }
  }

  String? _tryGetAspectRatio(String path) {
    try {
      final ratio = MediaMetadataDatasource.parseImageDimensions(path);
      if (ratio != null) {
        return Stage1Normalizer.normalizeAspectRatioFromRatio(ratio);
      }
    } catch (_) {}
    return null;
  }

  void _defaultLocateInFolder(WidgetRef ref) {
    try {
      final exists =
          File(filePath).existsSync() || Directory(filePath).existsSync();
      final targetDir = Directory(filePath).existsSync()
          ? filePath
          : p.dirname(filePath);
      if (Directory(targetDir).existsSync()) {
        ref.read(navigationProvider.notifier).navigateTo(targetDir);
        ref.read(currentPathProvider.notifier).state = targetDir;
        if (exists && !Directory(filePath).existsSync()) {
          ref.read(selectionProvider.notifier).deselectAll();
          ref.read(selectionProvider.notifier).select(filePath);
        }
      }
      unawaited(PersistentViewerManager.presentWindow(0));
    } catch (e) {
      debugPrint('[FileComparisonTile] Failed to locate in folder: $e');
    }
  }

  void _defaultOpenMedia(
    BuildContext context,
    FileItemType type,
    bool exists,
    int? sizeBytes,
  ) {
    try {
      final file = File(filePath);
      final item = FileItem(
        path: filePath,
        name: p.basename(filePath),
        type: type,
        modified: exists ? file.lastModifiedSync() : DateTime.now(),
        sizeBytes: sizeBytes,
      );

      final viewerType = type == FileItemType.video
          ? ViewerType.video
          : (type == FileItemType.audio
                ? ViewerType.audio
                : (type == FileItemType.document
                      ? ViewerType.markdown
                      : (type == FileItemType.image
                            ? ViewerType.image
                            : ViewerType.unsupported)));

      unawaited(
        PersistentViewerManager.openMedia(
          WindowParams(
            viewerType: viewerType,
            file: item,
            initParams: {
              'preloadPaths': [filePath],
              if (type == FileItemType.image || type == FileItemType.video)
                'playlistPaths': [filePath],
              if (type == FileItemType.image) ...{
                'currentIndex': 1,
                'totalCount': 1,
              },
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('[FileComparisonTile] Failed to open media: $e');
    }
  }
}
