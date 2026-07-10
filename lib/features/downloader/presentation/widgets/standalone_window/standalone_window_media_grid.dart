import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_shared_dropdowns.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';

class StandaloneWindowMediaGrid extends StatelessWidget {
  const StandaloneWindowMediaGrid({
    super.key,
    required this.isTrashView,
    required this.groups,
    required this.currentGroup,
    required this.selectedIndices,
    required this.downloadingImageIndices,
    required this.configs,
    required this.isHydratingItem,
    required this.onTapItem,
    required this.onDoubleTapItem,
    required this.onRestoreTrashItem,
    required this.onFormatChanged,
    required this.onFilterChanged,
    required this.onStartDownload,
    required this.mainFocusNode,
    required this.matchTargetFormat,
    required this.getHeight,
    this.trash = const [],
  });

  final bool isTrashView;
  final List<MediaGroup> groups;
  final MediaGroup? currentGroup;
  final Set<int> selectedIndices;
  final Set<int> downloadingImageIndices;
  final Map<int, DownloadConfig> configs;
  final bool Function(String) isHydratingItem;

  final void Function(int index, bool isCtrl, bool isShift) onTapItem;
  final void Function(int index, MediaGroup group) onDoubleTapItem;
  final void Function(int index) onRestoreTrashItem;
  final void Function(int index, MediaFormat format) onFormatChanged;
  final void Function(int index, GroupDownloadType filter) onFilterChanged;
  final void Function(int index) onStartDownload;
  final FocusNode mainFocusNode;
  final MediaFormat? Function(MediaInfo, MediaFormat?) matchTargetFormat;
  final int Function(String) getHeight;
  final List<dynamic> trash; // Or a specific type if available

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      if (isTrashView) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_outline,
                size: 48,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 16),
              const Text(
                'Trash is empty',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        );
      } else {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox,
                size: 48,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 16),
              const Text(
                'List is empty',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        );
      }
    }

    return GestureDetector(
      onTap: () {
        mainFocusNode.requestFocus();
        onTapItem(-1, false, false); // Signify clear selection
      },
      behavior: HitTestBehavior.opaque,
      child: AlignedGridView.extent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        padding: const EdgeInsets.all(16),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          final isHydrating = isHydratingItem(group.originalUrl);
          final firstItem = group.items.isNotEmpty ? group.items.first : null;

          DownloadConfig? config;
          if (currentGroup == null) {
            if (index < configs.length) {
              config = configs[index];
            }
          } else {
            // Wait, we can't easily get root index without access to parsedItems list.
            // Passed in `configs` can be assumed to map correctly to groups or we can just find it.
            // For now, let's assume `configs` maps `index` -> `config`.
            config = configs[index]; 
          }

          var typeIcon = Icons.image_rounded;
          if (group.first.isProfile) {
            typeIcon = Icons.account_circle_rounded;
          } else if (group.first.isPlaylist) {
            typeIcon = Icons.video_library_rounded;
          } else if (group.items.length > 1) {
            typeIcon = Icons.filter_none_rounded;
          } else if (firstItem?.isVideo ?? false) {
            typeIcon = Icons.videocam_rounded;
          }

          final isSelected = selectedIndices.contains(index);

          double aspectRatio = 1;
          if (firstItem != null) {
            if (firstItem.width != null &&
                firstItem.height != null &&
                firstItem.width! > 0 &&
                firstItem.height! > 0) {
              aspectRatio = firstItem.width! / firstItem.height!;
            } else if (firstItem.isVideo) {
              aspectRatio = 16 / 9;
            }
          }

          final Widget itemCard = GestureDetector(
            onTap: () {
              mainFocusNode.requestFocus();
              final isCtrl = HardwareKeyboard.instance.isControlPressed;
              final isShift = HardwareKeyboard.instance.isShiftPressed;
              onTapItem(index, isCtrl, isShift);
            },
            onDoubleTap: () {
              onDoubleTapItem(index, group);
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.violet : AppColors.borderColor,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (firstItem?.thumbnail != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        firstItem!.thumbnail!,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.broken_image,
                          color: Colors.white24,
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: Icon(Icons.image, size: 48, color: Colors.white10),
                    ),

                  if (isHydrating ||
                      firstItem?.id == 'fetch_loading' ||
                      firstItem?.id == 'hydration_loading' ||
                      downloadingImageIndices.contains(index))
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.54),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: BubbleLoader()),
                    ),

                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(typeIcon, color: Colors.white, size: 14),
                    ),
                  ),

                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Builder(
                        builder: (context) {
                          double sizeInMB = 0;
                          var hasSize = false;

                          if (group.first.isProfile ||
                              group.first.isPlaylist ||
                              group.items.length > 1) {
                            sizeInMB = group.totalFilesize / (1024 * 1024);
                            hasSize = sizeInMB > 0;
                          } else if (firstItem != null) {
                            if (firstItem.filesize != null &&
                                firstItem.filesize! > 0) {
                              sizeInMB = firstItem.filesize! / (1024 * 1024);
                              hasSize = true;
                            } else if (firstItem.formats.isNotEmpty) {
                              MediaFormat? selectedFormat;
                              if (currentGroup != null) {
                                selectedFormat =
                                    config?.itemFormats[firstItem.id];
                              } else {
                                selectedFormat = config?.format;
                              }
                              selectedFormat ??= firstItem.formats
                                    .fold<MediaFormat>(
                                      firstItem.formats.first,
                                      (a, b) =>
                                          (a.filesize ?? 0) > (b.filesize ?? 0)
                                          ? a
                                          : b,
                                    );
                              if (selectedFormat.filesize != null &&
                                  selectedFormat.filesize! > 0) {
                                sizeInMB =
                                    selectedFormat.filesize! / (1024 * 1024);
                                hasSize = true;
                              }
                            }
                          }

                          if (hasSize) {
                            return Text(
                              '${sizeInMB.toStringAsFixed(2)}MB',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          } else if (firstItem?.isVideo == false &&
                              firstItem?.width != null) {
                            return Text(
                              '${firstItem!.width}x${firstItem.height}',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          } else if ((firstItem?.isVideo ?? false) &&
                              firstItem?.duration != null) {
                            return Text(
                              '${firstItem!.duration! ~/ 60}:${(firstItem.duration! % 60).toString().padLeft(2, '0')}',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          } else {
                            return Text(
                              'Unknown',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),

                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        stops: const [0.0, 0.3, 0.7, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          firstItem?.title ?? group.originalUrl,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (group.items.length > 1) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (group.videoCount > 0) ...[
                                Text(
                                  '${group.videoCount}',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.videocam_rounded,
                                  color: Colors.white70,
                                  size: 10,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  '·',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              if (group.imageCount > 0) ...[
                                Text(
                                  '${group.imageCount}',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.image_rounded,
                                  color: Colors.white70,
                                  size: 10,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(aspectRatio: aspectRatio, child: itemCard),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (isTrashView)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {},
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.restore, size: 14),
                              label: const Text('Restore'),
                              onPressed: () => onRestoreTrashItem(index),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.violet,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size.fromHeight(32),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        )
                      else ...[
                        Expanded(
                          child: GestureDetector(
                            onTap: () {},
                            child: Builder(
                              builder: (context) {
                                if (currentGroup == null &&
                                    (group.first.isProfile ||
                                        group.first.isPlaylist ||
                                        group.items.length > 1)) {
                                  final hasImages = group.items.any((i) => !i.isVideo);
                                  final hasVideos = group.items.any((i) => i.isVideo);

                                  return SizedBox(
                                    height: 32,
                                    child: GroupFilterDropdown(
                                      selectedFilter: config?.groupFilter ?? GroupDownloadType.all,
                                      isEnabled: true,
                                      hasImages: hasImages,
                                      hasVideos: hasVideos,
                                      onChanged: (val) => onFilterChanged(index, val),
                                    ),
                                  );
                                } else {
                                  return SizedBox(
                                    height: 32,
                                    child: FormatSelectionDropdown(
                                      item: firstItem!,
                                      config: config ?? DownloadConfig(),
                                      index: index,
                                      group: group,
                                      isItemLevel: currentGroup != null,
                                      getHeight: getHeight,
                                      matchTargetFormat: matchTargetFormat,
                                      onChanged: (val) => onFormatChanged(index, val),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            height: 32,
                            width: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.download_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () => onStartDownload(index),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
