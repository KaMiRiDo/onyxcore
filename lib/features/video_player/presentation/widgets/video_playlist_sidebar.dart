import 'dart:io';
import 'dart:async';
import 'package:onyxcore/core/platform/directory_watcher.dart';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:onyxcore/core/utils/media_uri_helper.dart';
import 'package:onyxcore/features/video_player/domain/utils/video_queue_isolate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import '../providers/video_playlist_providers.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_markers_provider.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/context_menu.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sort_overlay.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/core/widgets/tooltip_if_truncated.dart';
import 'package:path/path.dart' as p;

class VideoPlaylistSidebar extends ConsumerStatefulWidget {
  final void Function(List<String> paths)? onDelete;
  final VoidCallback? onReload;
  final void Function(FileItem)? onVideoSelected;

  const VideoPlaylistSidebar({super.key, this.onDelete, this.onReload, this.onVideoSelected});

  @override
  ConsumerState<VideoPlaylistSidebar> createState() => _VideoPlaylistSidebarState();
}

class _VideoPlaylistSidebarState extends ConsumerState<VideoPlaylistSidebar> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _breadcrumbController = ScrollController();
  StreamSubscription<FileChangeEvent>? _watcherSub;
  String? _watchedPath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupWatcher();
      _refreshQueue();
    });
  }

  void _setupWatcher() {
    final currentPath = ref.read(videoCurrentPathProvider);
    if (_watchedPath == currentPath) return;

    _watcherSub?.cancel();
    _watchedPath = currentPath;

    final repo = ref.read(directoryRepositoryProvider);
    _watcherSub = repo.watchDirectory(currentPath).listen((event) {
      if (!mounted) return;
      _refreshQueue();
    });
  }

  void _refreshQueue() {
    final currentPath = ref.read(videoCurrentPathProvider);
    final repo = ref.read(directoryRepositoryProvider);
    final showHidden = ref.read(videoShowHiddenProvider);

    repo.invalidateCache(currentPath);
    repo.listDirectory(currentPath).then((items) {
      if (!mounted) return;
      compute(processVideoQueueIsolate, {
        'items': items.map((e) => e.toJson()).toList(),
        'showHidden': showHidden,
      }).then((files) {
        if (!mounted) return;
        ref.read(videoQueueProvider.notifier).state = files;
      });
    });
  }

  @override
  void dispose() {
    _watcherSub?.cancel();
    _scrollController.dispose();
    _breadcrumbController.dispose();
    super.dispose();
  }

  void _handleSelect(WidgetRef ref, int index, List<FileItem> items) {
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    final selection = ref.read(videoSelectionProvider);
    int? anchor = ref.read(videoSelectionAnchorProvider);
    final newSelection = Set<String>.from(selection);

    if (isShift && anchor != null) {
      final start = math.max(0, math.min(anchor, index));
      final end = math.min(items.length - 1, math.max(anchor, index));
      for (var i = start; i <= end; i++) {
        newSelection.add(items[i].path);
      }
    } else if (isCtrl) {
      final path = items[index].path;
      if (newSelection.contains(path)) {
        newSelection.remove(path);
      } else {
        newSelection.add(path);
      }
      ref.read(videoSelectionAnchorProvider.notifier).state = index;
    } else {
      newSelection.clear();
      newSelection.add(items[index].path);
      ref.read(videoSelectionAnchorProvider.notifier).state = index;
    }

    ref.read(videoSelectionProvider.notifier).state = newSelection;
  }

  void _openFolder(WidgetRef ref, String path) async {
    final repo = ref.read(directoryRepositoryProvider);
    final showHidden = ref.read(videoShowHiddenProvider);

    try {
      final items = await repo.listDirectory(path);

      final videoFiles = await compute(processVideoQueueIsolate, {
        'items': items.map((e) => e.toJson()).toList(),
        'showHidden': showHidden,
      });

      final currentPath = ref.read(videoCurrentPathProvider);
      ref
          .read(videoPathHistoryProvider.notifier)
          .update((state) => [...state, currentPath]);
      ref.read(videoPathForwardHistoryProvider.notifier).state = [];

      ref.read(videoCurrentPathProvider.notifier).state = path;
      ref.read(videoQueueProvider.notifier).state = videoFiles;
      ref.read(videoSelectionProvider.notifier).state = {};
      ref.read(videoSelectionAnchorProvider.notifier).state = null;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_breadcrumbController.hasClients) {
          _breadcrumbController.animateTo(
            _breadcrumbController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint("Error opening folder: $e");
    }
  }

  Widget _buildBreadcrumbs(String currentPath, String rootPath) {
    if (currentPath.isEmpty || rootPath.isEmpty) return const SizedBox.shrink();

    final baseDir = p.dirname(rootPath);
    final relativePath = p.relative(currentPath, from: baseDir);
    final allSegments = p.split(relativePath);

    List<Widget> breadcrumbWidgets = [];
    String accumulatedPath = baseDir;

    for (int i = 0; i < allSegments.length; i++) {
      final segment = allSegments[i];
      accumulatedPath = p.join(accumulatedPath, segment);
      final isLast = i == allSegments.length - 1;
      final targetPath = accumulatedPath;

      breadcrumbWidgets.add(
        InkWell(
          onTap: isLast
              ? null
              : () {
                  _openFolder(ref, targetPath);
                },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isLast
                  ? Colors.white.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              segment,
              style: TextStyle(
                color: isLast ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
      );

      if (!isLast) {
        breadcrumbWidgets.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '/',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(
            Icons.folder_open_rounded,
            color: Colors.white38,
            size: 14,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: SingleChildScrollView(
              controller: _breadcrumbController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: breadcrumbWidgets,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: ref.watch(videoShowHiddenProvider)
                ? 'Hide hidden folders'
                : 'Show hidden folders',
            child: InkWell(
              onTap: () {
                final current = ref.read(videoShowHiddenProvider);
                ref.read(videoShowHiddenProvider.notifier).state = !current;
                // Re-fetch queue to reflect new visibility
                final repo = ref.read(directoryRepositoryProvider);
                repo.listDirectory(currentPath).then((items) {
                  compute(processVideoQueueIsolate, {
                    'items': items.map((e) => e.toJson()).toList(),
                    'showHidden': !current,
                  }).then((files) {
                    ref.read(videoQueueProvider.notifier).state = files;
                  });
                });
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: ref.watch(videoShowHiddenProvider)
                    ? ShaderMask(
                        shaderCallback: (bounds) =>
                            AppTheme.primaryGradient.createShader(bounds),
                        child: const Icon(
                          Icons.visibility_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      )
                    : const Icon(
                        Icons.visibility_off_rounded,
                        color: Colors.white38,
                        size: 16,
                      ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'Reload',
            child: InkWell(
              onTap: _refreshQueue,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4.0),
                child: Icon(
                  Icons.refresh_rounded,
                  color: Colors.white38,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContextMenu(BuildContext context, FileItem item, Offset position) {
    final isSelected = ref.read(videoSelectionProvider).contains(item.path);
    final selection = isSelected
        ? ref.read(videoSelectionProvider).toList()
        : [item.path];

    final isMultiple = selection.length > 1;

    ContextMenu.show(
      context,
      position,
      [
        ContextMenuItem(
          title: 'Move to Trash',
          icon: Icons.delete_outline_rounded,
          isDestructive: true,
          shortcut: 'Del',
          onTap: () {
            if (widget.onDelete != null) {
              widget.onDelete!(selection);
            } else {
              ref.read(directoryRepositoryProvider).moveToTrash(selection);
            }
            ref.read(videoSelectionProvider.notifier).state = {};
          },
        ),

      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(filteredAndSortedVideoQueueProvider);
    final activeIndex = ref.watch(activeVideoIndexProvider);
    final player = ref.watch(previewFileProvider);
    final currentPath = ref.watch(videoCurrentPathProvider);
    final rootPath = ref.watch(videoRootPathProvider);
    final selection = ref.watch(videoSelectionProvider);

    ref.listen(videoCurrentPathProvider, (previous, next) {
      if (previous != next && next.isNotEmpty) {
        _setupWatcher();
        _refreshQueue();
      }
    });

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF181818), // Matte dark grey
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.03)),
        ),
      ),
      child: GestureDetector(
        onTap: () {
          final currentSelection = ref.read(videoSelectionProvider);
          if (currentSelection.isNotEmpty) {
            ref.read(videoSelectionProvider.notifier).state = {};
            ref.read(videoSelectionAnchorProvider.notifier).state = null;
          }
        },
        onDoubleTap: () {}, // Prevent stealing taps from inner GestureDetector

        behavior: HitTestBehavior.translucent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 64, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ref.watch(videoViewModeProvider) == VideoViewMode.favorites
                        ? "Favorites"
                        : "Home",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      Builder(
                        builder: (context) {
                          final sortOption = ref.watch(videoSortOptionProvider);
                          return IconButton(
                            icon: const Icon(
                              Icons.sort_rounded,
                              color: Colors.white70,
                              size: 20,
                            ),
                            tooltip: "Sort",
                            onPressed: () {
                              final RenderBox box =
                                  context.findRenderObject() as RenderBox;
                              final position = box.localToGlobal(Offset.zero);
                              SortOverlay.show(
                                context: context,
                                buttonPosition: position,
                                buttonSize: box.size,
                                currentOption:
                                    ref.read(videoSortOptionProvider) ??
                                    SortOption.aToZ,
                                onSelected: (option) {
                                  ref
                                          .read(
                                            videoSortOptionProvider.notifier,
                                          )
                                          .state =
                                      option;
                                },
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              child: SizedBox(
                height: 36,
                child: TextField(
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white38,
                      size: 18,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) =>
                      ref.read(videoSearchQueryProvider.notifier).state = val,
                ),
              ),
            ),

            // Breadcrumbs
            _buildBreadcrumbs(currentPath, rootPath),

            // Track List
            Expanded(
              child: Stack(
                children: [
                  queue.isEmpty
                      ? Center(
                          child: Text(
                            ref.watch(videoViewModeProvider) ==
                                    VideoViewMode.favorites
                                ? "No favorite files in this folder"
                                : "No video files found",
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: queue.length,
                          itemBuilder: (context, index) {
                            final item = queue[index];

                            final currentPlayingTrack = ref.watch(previewFileProvider);
                            bool isActive = false;
                            if (currentPlayingTrack != null) {
                              if (item.type == FileItemType.folder) {
                                // Check if the playing track is inside this folder (or any subfolder)
                                isActive = currentPlayingTrack.path.startsWith(
                                  '${item.path}/',
                                );
                              } else {
                                // Check if this exact file is the playing track
                                isActive =
                                    item.path == currentPlayingTrack.path;
                              }
                            }
                            final isSelected = selection.contains(item.path);

                            return _TrackTile(
                              item: item,
                              isActive: isActive,
                              isSelected: isSelected,
                              isPlaying: false,
                              onSecondaryTapDown: (details, tileContext) {
                                if (!isSelected) {
                                  ref
                                      .read(videoSelectionProvider.notifier)
                                      .state = {
                                    item.path,
                                  };
                                }
                                final RenderBox box =
                                    tileContext.findRenderObject() as RenderBox;
                                // Align context menu strictly to the right side of the list tile
                                final position = box.localToGlobal(
                                  Offset(box.size.width, 24),
                                );
                                _showContextMenu(context, item, position);
                              },
                              onTap: () {
                                _handleSelect(ref, index, queue);
                              },
                              onDoubleTap: () {
                                ref.read(videoSelectionProvider.notifier).state = {};
                                if (item.type == FileItemType.folder) {
                                  _openFolder(ref, item.path);
                                  return;
                                }
                                if (widget.onVideoSelected != null) {
                                  widget.onVideoSelected!(item);
                                }
                              },
                            );
                          },
                        ),
                  if (ref.watch(videoIsReloadingProvider))
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withOpacity(0.1),
                        child: const Center(
                          child: BubbleLoader(size: 48),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Bottom Navigation Bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.03)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavItem(
                    icon: Icons.home_rounded,
                    label: "Home",
                    isSelected:
                        ref.watch(videoViewModeProvider) == VideoViewMode.home,
                    onTap: () =>
                        ref.read(videoViewModeProvider.notifier).state =
                            VideoViewMode.home,
                  ),
                  _buildNavItem(
                    icon: Icons.favorite_rounded,
                    label: "Favorites",
                    isSelected:
                        ref.watch(videoViewModeProvider) ==
                        VideoViewMode.favorites,
                    onTap: () =>
                        ref.read(videoViewModeProvider.notifier).state =
                            VideoViewMode.favorites,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.magenta.withOpacity(0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: isSelected ? AppColors.magenta : Colors.white54,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white54,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackTile extends ConsumerWidget {
  final FileItem item;
  final bool isActive;
  final bool isSelected;
  final bool isPlaying;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final void Function(TapDownDetails details, BuildContext context)?
  onSecondaryTapDown;

  const _TrackTile({
    required this.item,
    required this.isActive,
    required this.isSelected,
    required this.isPlaying,
    this.onTap,
    this.onDoubleTap,
    this.onSecondaryTapDown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFolder = item.type == FileItemType.folder;
    Widget? coverImage;

    String subtitle = '';
    if (isFolder) {
      subtitle = item.itemCount != null
          ? "${item.itemCount} Video File${item.itemCount == 1 ? '' : 's'}"
          : "Folder";
    } else {
      subtitle = "Video File";
      if (item.sizeBytes != null && item.sizeBytes! > 0) {
        final sizeMB = (item.sizeBytes! / (1024 * 1024)).toStringAsFixed(1);
        subtitle += " • $sizeMB MB";
      }
    }

    return Builder(
      builder: (innerContext) {
        return GestureDetector(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          onSecondaryTapDown: onSecondaryTapDown != null
              ? (details) => onSecondaryTapDown!(details, innerContext)
              : null,
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withOpacity(0.1)
                  : (isActive
                        ? Colors.white.withOpacity(0.03)
                        : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: isSelected || isActive
                  ? Border.all(
                      color: isSelected
                          ? Colors.white.withOpacity(0.15)
                          : Colors.white.withOpacity(0.05),
                    )
                  : Border.all(color: Colors.transparent),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFF181818),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.04),
                      width: 1.0,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child:
                      coverImage ??
                      (item.thumbnailPath != null
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.file(
                                  File(item.thumbnailPath!),
                                  fit: BoxFit.cover,
                                  cacheWidth: 150,
                                  cacheHeight: 150,
                                  errorBuilder: (context, error, stackTrace) =>
                                      _buildDefaultIcon(isFolder),
                                ),
                                _buildDefaultIcon(isFolder, hasImage: true),
                              ],
                            )
                          : _buildDefaultIcon(isFolder)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TooltipIfTruncated(
                        text: item.name,
                        style: TextStyle(
                          color: isActive ? AppColors.magenta : Colors.white,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: isPlaying
                        ? const Icon(Icons.play_arrow, color: AppColors.violet, size: 16)
                        : const Icon(
                            Icons.pause_rounded,
                            color: AppColors.magenta,
                            size: 16,
                          ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultIcon(bool isFolder, {bool hasImage = false}) {
    if (isFolder) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.alphaBlend(
                AppColors.magenta.withOpacity(0.08),
                const Color(0xFF181818),
              ),
              Color.alphaBlend(
                AppColors.violet.withOpacity(0.03),
                const Color(0xFF181818),
              ),
            ],
          ),
        ),
        child: Center(
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [AppColors.magenta, AppColors.violet],
            ).createShader(bounds),
            child: const Icon(
              Icons.folder_rounded,
              size: 24,
              color: Colors.white,
            ),
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!hasImage)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(
                    AppColors.magenta.withOpacity(0.08),
                    const Color(0xFF181818),
                  ),
                  Color.alphaBlend(
                    AppColors.violet.withOpacity(0.03),
                    const Color(0xFF181818),
                  ),
                ],
              ),
            ),
          ),
        if (hasImage)
          Container(
            color: Colors.black.withOpacity(0.5),
          ),
        Center(
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [AppColors.magenta, AppColors.violet],
            ).createShader(bounds),
            child: const Icon(
              Icons.play_arrow_rounded,
              size: 32,
              color: Colors.white,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withOpacity(hasImage ? 0.4 : 0.2),
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
