import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/services/thumbnail_aspect_resolver.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_empty_state.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_shared_components.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_shared_dropdowns.dart';

class StandaloneWindowMediaGrid extends StatelessWidget {
  const StandaloneWindowMediaGrid({
    required this.listPath,
    required this.isTrashView,
    required this.groups,
    required this.currentGroup,
    required this.selectedIndices,
    required this.downloadingImageIndices,
    required this.getConfig,
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
    required this.getFormatBytes,
    required this.onTagItem,
    super.key,
    this.currentGroupRootIndex,
    this.scrollController,
    this.tagKeys = const {},
    this.trash = const [],
    this.onShowProperties,
    this.onCancelHydration,
  });

  final String listPath;
  final bool isTrashView;
  final List<MediaGroup> groups;
  final MediaGroup? currentGroup;
  final Set<int> selectedIndices;
  final Set<int> downloadingImageIndices;
  final DownloadConfig? Function(MediaGroup) getConfig;
  final int? currentGroupRootIndex;
  final bool Function(String) isHydratingItem;
  final void Function(String url)? onCancelHydration;

  final void Function(int index, {bool isCtrl, bool isShift}) onTapItem;
  final void Function(int index, MediaGroup group) onDoubleTapItem;
  final void Function(int index) onRestoreTrashItem;
  final void Function(MediaGroup group, MediaFormat format) onFormatChanged;
  final void Function(MediaGroup group, GroupDownloadType filter)
  onFilterChanged;
  final void Function(int index) onStartDownload;
  final FocusNode mainFocusNode;
  final MediaFormat? Function(MediaInfo, MediaFormat?) matchTargetFormat;
  final int Function(String) getHeight;
  final int? Function(MediaInfo, MediaFormat?, DownloadConfig)? getFormatBytes;
  final void Function(String url, String tag) onTagItem;
  final ScrollController? scrollController;
  final Map<String, GlobalKey> tagKeys;
  final List<dynamic> trash; // Or a specific type if available
  final void Function(dynamic)? onShowProperties;

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
        return const DownloadsEmptyState();
      }
    }

    final displayIndices = <int>[];
    for (var i = 0; i < groups.length; i++) {
      displayIndices.add(i);
    }

    return ListenableBuilder(
      listenable: ThumbnailAspectResolver.updates,
      builder: (context, _) {
        return GestureDetector(
          onTap: () {
            mainFocusNode.requestFocus();
            onTapItem(-1, isCtrl: false, isShift: false); // Signify clear selection
          },
          behavior: HitTestBehavior.opaque,
          child: CustomScrollView(
            // ignore: deprecated_member_use
            cacheExtent: 1000,
            controller: scrollController,
            key: PageStorageKey<String>(isTrashView ? 'trash_$listPath' : listPath),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverMasonryGrid.extent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childCount: displayIndices.length,
                  itemBuilder: (context, gridIndex) {
                    final index = displayIndices[gridIndex];
                    final group = groups[index];
                    final isHydrating = isHydratingItem(group.originalUrl);
                    final firstItem = group.items.isNotEmpty
                        ? group.items.first
                        : null;

                    DownloadConfig? config;
                    if (currentGroup == null) {
                      config = getConfig(group);
                    } else if (currentGroupRootIndex != null) {
                      config = getConfig(currentGroup!);
                    }

                    var typeIcon = Icons.image_rounded;
                    final isAudioFormat =
                        config != null &&
                        firstItem != null &&
                        (config.itemFormats[firstItem.id]?.isAudioOnly ?? false);

                    if (isAudioFormat) {
                      typeIcon = Icons.audiotrack_rounded;
                    } else if (group.first.isProfile) {
                      typeIcon = Icons.account_circle_rounded;
                    } else if (group.first.isPlaylist) {
                      typeIcon = Icons.video_library_rounded;
                    } else if (group.items.length > 1) {
                      typeIcon = Icons.filter_none_rounded;
                    } else if (firstItem?.isVideo ?? false) {
                      typeIcon = Icons.videocam_rounded;
                    }

                    final isSelected = selectedIndices.contains(index);
                    final tag = currentGroup == null ? group.tag : firstItem?.tag;
                    final isTagged = tag != null && tag.isNotEmpty;
                    final itemUrl = currentGroup == null
                        ? group.originalUrl
                        : (firstItem?.id ?? '');
                    final globalKey = isTagged
                        ? (tagKeys[itemUrl] ??= GlobalKey())
                        : null;

                    final thumbUrl = (firstItem?.thumbnail != null && firstItem!.thumbnail!.isNotEmpty)
                        ? firstItem.thumbnail
                        : (!(firstItem?.isVideo ?? true) && (firstItem?.directUrl != null && firstItem!.directUrl!.isNotEmpty)
                            ? firstItem.directUrl
                            : (!(firstItem?.isVideo ?? true) &&
                                    (firstItem != null && firstItem.originalUrl.isNotEmpty) &&
                                    (firstItem.originalUrl.startsWith('http://') ||
                                        firstItem.originalUrl.startsWith('https://'))
                                ? firstItem.originalUrl
                                : null));

                    double aspectRatio = 1;
                    if (firstItem != null) {
                      if (firstItem.width != null &&
                          firstItem.height != null &&
                          firstItem.width! > 0 &&
                          firstItem.height! > 0) {
                        aspectRatio = firstItem.width! / firstItem.height!;
                      } else if (firstItem.isVideo) {
                        aspectRatio = 16 / 9;
                      } else if (thumbUrl != null) {
                        final resolvedRatio = ThumbnailAspectResolver.getAspectRatio(thumbUrl);
                        if (resolvedRatio != null && resolvedRatio > 0) {
                          aspectRatio = resolvedRatio;
                        } else {
                          ThumbnailAspectResolver.probe(thumbUrl);
                        }
                      }
                    }
                    aspectRatio = aspectRatio.clamp(0.56, 1.8);

                    final isItemError = currentGroup == null
                        ? (group.isError || (firstItem?.isError ?? false) || (firstItem?.errorMessage?.isNotEmpty ?? false))
                        : ((firstItem?.isError ?? false) || (firstItem?.errorMessage?.isNotEmpty ?? false));

                    final Widget itemCard = RepaintBoundary(
                      key: globalKey,
                      child: GestureDetector(
                        onSecondaryTapDown: (details) {
                          final url = currentGroup == null
                              ? group.originalUrl
                              : (group.items.first.id);
                          _showTagInput(context, details.globalPosition, url);
                        },
                        onTap: () {
                          mainFocusNode.requestFocus();
                          final isCtrl = HardwareKeyboard.instance.isControlPressed;
                          final isShift = HardwareKeyboard.instance.isShiftPressed;
                          onTapItem(index, isCtrl: isCtrl, isShift: isShift);
                        },
                        onDoubleTap: () {
                          onDoubleTapItem(index, group);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.surfaceBase,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.violet
                                  : (isItemError
                                      ? AppColors.error
                                      : (isTagged
                                          ? Colors.amber
                                          : AppColors.borderColor)),
                              width: isSelected || isItemError || isTagged ? 2 : 1,
                            ),
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Builder(
                                builder: (context) {
                                  final showThumbnail =
                                      thumbUrl != null && thumbUrl.isNotEmpty;

                                  if (showThumbnail) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.network(
                                        thumbUrl,
                                        headers: const {
                                          'User-Agent':
                                              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
                                        },
                                        fit: BoxFit.cover,
                                        cacheWidth: 300,
                                        errorBuilder: (c, e, s) => const Center(
                                          child: Icon(
                                            Icons.broken_image_rounded,
                                            color: Colors.white24,
                                            size: 36,
                                          ),
                                        ),
                                      ),
                                    );
                                  } else {
                                    return const Center(
                                      child: Icon(
                                        Icons.image,
                                        size: 48,
                                        color: Colors.white10,
                                      ),
                                    );
                                  }
                                },
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
                              child: Icon(
                                typeIcon,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                          if (isTagged)
                            Positioned(
                              top: 8,
                              left: 36,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.sell,
                                      color: Colors.black,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      tag,
                                      style: GoogleFonts.outfit(
                                        color: Colors.black,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
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
                                    sizeInMB =
                                        group.totalFilesize / (1024 * 1024);
                                    hasSize = sizeInMB > 0;
                                  } else if (firstItem != null) {
                                    int? bytes;
                                    if (firstItem.formats.isNotEmpty) {
                                      MediaFormat? selectedFormat;
                                      if (currentGroup != null) {
                                        selectedFormat =
                                            config?.itemFormats[firstItem.id];
                                      } else {
                                        selectedFormat = config?.format;
                                      }
                                      selectedFormat ??=
                                          firstItem.formats
                                              .where((f) {
                                                final h = getHeight(
                                                  f.resolution,
                                                );
                                                return h > 0 && h <= 1080;
                                              })
                                              .fold<MediaFormat?>(
                                                null,
                                                (a, b) => a == null
                                                    ? b
                                                    : ((a.filesize ?? 0) >
                                                              (b.filesize ?? 0)
                                                          ? a
                                                          : b),
                                              ) ??
                                          firstItem.formats.first;

                                      bytes =
                                          getFormatBytes != null &&
                                              config != null
                                          ? getFormatBytes!(
                                              firstItem,
                                              selectedFormat,
                                              config,
                                            )
                                          : selectedFormat.filesize;
                                    }

                                    bytes ??= firstItem.filesize;

                                    if (bytes == null &&
                                        firstItem.formats.isNotEmpty) {
                                      for (final f in firstItem.formats) {
                                        if (f.filesize != null &&
                                            f.filesize! > 0) {
                                          bytes = f.filesize;
                                          break;
                                        }
                                      }
                                    }

                                    if (bytes != null && bytes > 0) {
                                      sizeInMB = bytes / (1024 * 1024);
                                      hasSize = true;
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
                          if (isItemError)
                            Center(
                              child: MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapDown: (_) {
                                    onShowProperties?.call(
                                      currentGroup == null ? group : firstItem,
                                    );
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.6),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.error,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.error_outline,
                                      color: AppColors.error,
                                      size: 32,
                                    ),
                                  ),
                                ),
                              ),
                            ),

                          Positioned(

                            bottom: 8,
                            left: 8,
                            right: 8,
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                CopyUrlButton(
                                  url:
                                      firstItem?.webpageUrl ??
                                      firstItem?.directUrl ??
                                      firstItem?.originalUrl ??
                                      group.originalUrl,
                                ),
                              ],
                            ),
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
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const BubbleLoader(size: 48),
                                    if ((isHydrating ||
                                            firstItem?.id ==
                                                'hydration_loading') &&
                                        onCancelHydration != null) ...[
                                      const SizedBox(height: 6),
                                      MouseRegion(
                                        cursor: SystemMouseCursors.click,
                                        child: GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {
                                            final targetUrl =
                                                currentGroup != null
                                                    ? currentGroup!.originalUrl
                                                    : group.originalUrl;
                                            onCancelHydration!(targetUrl);
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.violet,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: AppColors.violet
                                                      .withValues(alpha: 0.4),
                                                  blurRadius: 6,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.close_rounded,
                                                  size: 13,
                                                  color: Colors.white,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Cancel',
                                                  style: GoogleFonts.outfit(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );

                return Column(
                  key: ValueKey('${group.originalUrl}_${firstItem?.id ?? index}'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(aspectRatio: aspectRatio, child: itemCard),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (isTrashView)
                          Expanded(
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
                          )
                        else ...[
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                if (currentGroup == null &&
                                    (group.first.isProfile ||
                                        group.first.isPlaylist ||
                                        group.items.length > 1)) {
                                  final hasImages = group.items.any(
                                    (i) => !i.isVideo,
                                  );
                                  final hasVideos = group.items.any(
                                    (i) => i.isVideo,
                                  );

                                  return SizedBox(
                                    height: 32,
                                    child: GroupFilterDropdown(
                                      selectedFilter:
                                          config?.groupFilter ??
                                          GroupDownloadType.all,
                                      isEnabled: true,
                                      hasImages: hasImages,
                                      hasVideos: hasVideos,
                                      onChanged: (val) =>
                                          onFilterChanged(group, val),
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
                                      getFormatBytes: getFormatBytes,
                                      matchTargetFormat:
                                          matchTargetFormat,
                                      onChanged: (val) =>
                                          onFormatChanged(group, val),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 32,
                            width: 32,
                            decoration: BoxDecoration(
                              color: isItemError
                                  ? AppColors.surfaceBase
                                  : AppColors.violet.withValues(
                                      alpha: 0.2,
                                    ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: IconButton(
                              icon: Icon(
                                Icons.download_rounded,
                                size: 16,
                                color: isItemError
                                    ? Colors.white38
                                    : AppColors.violet,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: isItemError
                                  ? null
                                  : () => onStartDownload(index),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  void _showTagInput(BuildContext context, Offset position, String url) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    final focusNode = FocusNode();
    final controller = TextEditingController();

    entry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  entry.remove();
                  focusNode.dispose();
                  controller.dispose();
                },
                behavior: HitTestBehavior.opaque,
              ),
            ),
            Positioned(
              left: position.dx,
              top: position.dy,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 150,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber, width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 8, right: 4),
                        child: Icon(Icons.sell, size: 14, color: Colors.amber),
                      ),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          maxLength: 15,
                          textAlignVertical: TextAlignVertical.center,
                          style: GoogleFonts.outfit(
                            color: Colors.amber,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Enter tag...',
                            hintStyle: TextStyle(
                              color: Colors.amber.withValues(alpha: 0.5),
                            ),
                            isDense: true,
                            counterText: '',
                            contentPadding: EdgeInsets.zero,
                            border: InputBorder.none,
                          ),
                          onSubmitted: (val) {
                            if (val.trim().isNotEmpty) {
                              onTagItem(url, val.trim());
                            }
                            entry.remove();
                            focusNode.dispose();
                            controller.dispose();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(entry);
    focusNode.requestFocus();
  }
}
