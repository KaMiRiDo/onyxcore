import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_utils.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/archive_manager/presentation/providers/archive_provider.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/filter_settings.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/selection_state.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/conflict_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/thumbnail_session_manager.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/conflict_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/empty_state_view.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/item_card.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:path/path.dart' as p;

/// Main file grid — pixel-perfect replica of original _buildMainContent().
class FileGrid extends ConsumerStatefulWidget {
  const FileGrid({super.key});

  @override
  ConsumerState<FileGrid> createState() => _FileGridState();
}

class _FileGridState extends ConsumerState<FileGrid>
    with WidgetsBindingObserver {
  String? _hoveredPath;
  String? _lastLoadedPath;
  final ScrollController _scrollController = ScrollController();
  Timer? _throttleTimer;
  BoxConstraints? _lastConstraints;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      ref.read(taskProvider.notifier).cancelAllTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(sortedDirectoryItemsProvider);
    final filteredAsync = ref.watch(filteredDirectoryItemsProvider);
    final zoom = ref.watch(currentZoomProvider);
    final selection = ref.watch(selectionProvider);
    final currentPath = ref.watch(currentPathProvider);
    final isRefreshing = ref.watch(isRefreshingProvider);

    final tabId = ref.watch(tabIdProvider);

    final isDataLoading = itemsAsync.isLoading || filteredAsync.isLoading;

    if (!isDataLoading && itemsAsync.hasValue) {
      _lastLoadedPath = currentPath;
    }

    Widget contentBody;
    if (itemsAsync.hasValue && _lastLoadedPath == currentPath) {
      final items = itemsAsync.value!;
      final gridWidget = _buildGrid(items, selection, zoom, currentPath, tabId);

      contentBody = isRefreshing
          ? Stack(
              children: [
                Opacity(opacity: 0.6, child: gridWidget),
                const Positioned.fill(
                  child: Center(child: BubbleLoader(size: 60)),
                ),
              ],
            )
          : gridWidget;
    } else if (itemsAsync.hasError && !itemsAsync.hasValue) {
      contentBody = Center(
        child: Text(
          'Error: ${itemsAsync.error}',
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    } else {
      contentBody = const Center(child: BubbleLoader(size: 60));
    }

    final content = contentBody;

    if (currentPath.startsWith('virtual:')) return content;

    return DragTarget<List<String>>(
      onWillAcceptWithDetails: (details) {
        return !details.data.every((path) {
          final parts =
              (path.endsWith('/') ? path.substring(0, path.length - 1) : path)
                  .split('/');
          final parent = parts
              .take(parts.length > 1 ? parts.length - 1 : 0)
              .join('/');
          final curr = currentPath.endsWith('/')
              ? currentPath.substring(0, currentPath.length - 1)
              : currentPath;
          return parent == curr;
        });
      },
      onAcceptWithDetails: (details) async {
        final repo = ref.read(directoryRepositoryProvider);
        final sources = details.data;

        final taskId = ref
            .read(taskProvider.notifier)
            .addTask(
              title: 'Moving Files',
              subtitle: '${sources.length} items to current folder',
              totalCount: sources.length,
              sourcePaths: sources,
              targetPath: currentPath,
            );

        try {
          ref.read(selectionProvider.notifier).deselectAll();
          ref.read(conflictProvider.notifier).clearGlobalResolution();

          for (var i = 0; i < sources.length; i++) {
            if (ref.read(taskProvider.notifier).isTaskCancelled(taskId)) break;

            final source = sources[i];
            final name = p.basename(source);
            final destPath = p.join(currentPath, name);
            final isFolder = Directory(source).existsSync();

            var finalDestPath = destPath;

            if (!context.mounted) break;
            if (File(destPath).existsSync() ||
                Directory(destPath).existsSync()) {
              final resolution = await ref
                  .read(conflictProvider.notifier)
                  .resolveConflict(
                    fileName: name,
                    destinationPath: destPath,
                    isFolder: isFolder,
                    context: context,
                  );

              if (resolution == ConflictResolution.skip) {
                continue;
              } else if (resolution == ConflictResolution.rename) {
                final ext = p.extension(name);
                final base = p.basenameWithoutExtension(name);
                var counter = 1;
                var newName = '$base($counter)$ext';
                while (File(p.join(currentPath, newName)).existsSync() ||
                    Directory(p.join(currentPath, newName)).existsSync()) {
                  counter++;
                  newName = '$base($counter)$ext';
                }
                finalDestPath = p.join(currentPath, newName);
              }
            }

            ref.read(taskProvider.notifier).addLog(taskId, 'Moving $name...');
            ref.read(taskProvider.notifier).updateCurrentItem(taskId, name);

            await repo.moveItemTo(
              source,
              finalDestPath,
              taskId: taskId,
              onPort: (port, isolate) => ref
                  .read(taskProvider.notifier)
                  .registerPort(taskId, port, isolate: isolate),
            );
            ref.read(taskProvider.notifier).addLog(taskId, 'Completed: $name');
            ref.read(selectionProvider.notifier).select(finalDestPath);
            ref
                .read(taskProvider.notifier)
                .updateItemCounts(taskId, i + 1, sources.length);
            ref
                .read(taskProvider.notifier)
                .updateProgress(taskId, (i + 1) / sources.length);
          }

          ref.read(taskProvider.notifier).completeTask(taskId);
          await ref.read(directoryItemsProvider.notifier).refresh();
          ref.read(selectionProvider.notifier).deselectAll();
        } catch (e) {
          ref.read(taskProvider.notifier).addLog(taskId, 'ERROR: $e');
          ref.read(taskProvider.notifier).failTask(taskId, e.toString());
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isOver = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isOver ? AppColors.violet.withValues(alpha: 0.05) : null,
          ),
          child: content,
        );
      },
    );
  }

  void _handleTap(List<FileItem> items, int index) {
    final isShift =
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.shiftRight,
        );

    final isCtrl =
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.controlLeft,
        ) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(
          LogicalKeyboardKey.controlRight,
        );

    ref.read(mainFocusNodeProvider).requestFocus();
    ref
        .read(selectionProvider.notifier)
        .onItemTap(
          currentIndex: index,
          allPaths: items.map((i) => i.path).toList(),
          isShift: isShift,
          isCtrl: isCtrl,
        );
  }

  void _handleDoubleTap(List<FileItem> items, int index) {
    final item = items[index];

    if (item.type == FileItemType.folder) {
      ref.read(selectionProvider.notifier).deselectAll();
      ref.read(navigationProvider.notifier).navigateTo(item.path);
      ref.read(currentPathProvider.notifier).state = item.path;
      return;
    }

    if (item.type == FileItemType.image ||
        item.type == FileItemType.video ||
        item.type == FileItemType.audio ||
        item.type == FileItemType.document) {
      final openInStandalone =
          ref.read(settingsProvider).value?.openInStandaloneMode ?? true;
      if (openInStandalone) {
        final preloadPaths = <String>[];
        final allItems = ref.read(sortedDirectoryItemsProvider).value ?? [];
        final mediaItems = allItems.where((i) => i.type == item.type).toList();
        final currentIndex = mediaItems.indexWhere((i) => i.path == item.path);

        if (item.type == FileItemType.image && currentIndex != -1 && mediaItems.isNotEmpty) {
          for (var i = 1; i <= 1; i++) {
            preloadPaths
              ..add(mediaItems[(currentIndex + i) % mediaItems.length].path)
              ..add(
                mediaItems[(currentIndex - i + mediaItems.length) %
                        mediaItems.length]
                    .path,
              );
          }
        }
        final windowParams = WindowParams(
          viewerType: item.type == FileItemType.video
              ? ViewerType.video
              : (item.type == FileItemType.audio
                    ? ViewerType.audio
                    : (item.type == FileItemType.document
                          ? ViewerType.markdown
                          : ViewerType.image)),
          file: item,
          initParams: {
            'preloadPaths': preloadPaths,
            if (item.type == FileItemType.image ||
                item.type == FileItemType.video)
              'playlistPaths': mediaItems.map((i) => i.path).toList(),
            if (item.type == FileItemType.image) ...{
              'currentIndex': currentIndex != -1 ? currentIndex + 1 : 1,
              'totalCount': mediaItems.length,
            },
          },
        );
        PersistentViewerManager.openMedia(windowParams);
      } else {
        ref.read(previewFileProvider.notifier).state = item;
      }
      return;
    }

    if (item.type == FileItemType.archive) {
      final currentPath = ref.read(currentPathProvider);
      ref
          .read(archiveProvider.notifier)
          .extractArchive(context, item.path, currentPath);
      return;
    }
  }

  IconData _getEmptyIcon(String path) {
    if (path == 'virtual:recent') return Icons.access_time_rounded;
    if (path == 'virtual:starred') return Icons.star_outline_rounded;
    if (path.contains('Trash')) return Icons.delete_outline_rounded;
    return Icons.folder_open_rounded;
  }

  Widget _buildGrid(
    List<FileItem> items,
    SelectionState selection,
    double zoom,
    String currentPath,
    String tabId,
  ) {
    if (items.isEmpty) {
      final isSearchActive = ref.watch(isSearchActiveProvider);
      final query = ref.watch(searchQueryProvider);
      final filter = ref.watch(filterSettingsProvider);
      final isFilterActive = !filter.isEmpty;

      if (isSearchActive && query.isNotEmpty) {
        return EmptyStateView(
          icon: Icons.manage_search_rounded,
          title: 'No Results Found',
          subtitle: 'No matches for "$query" in ${p.basename(currentPath)}',
          actionLabel: 'Clear Search',
          onAction: () => ref.read(isSearchActiveProvider.notifier).set(false),
        );
      }

      if (isFilterActive) {
        return EmptyStateView(
          icon: Icons.filter_list_off_rounded,
          title: 'No Items Match',
          subtitle:
              "Try adjusting your filters to find what you're looking for",
          actionLabel: 'Clear All Filters',
          onAction: () {
            final tabId = ref.read(tabIdProvider);
            ref
                .read(tabManagerProvider.notifier)
                .updateFilterSettings(tabId, const FilterSettings());
          },
        );
      }

      var message = 'This folder is empty';
      if (currentPath == 'virtual:recent') message = 'No recent files found';
      if (currentPath == 'virtual:starred') message = 'No starred items yet';

      return EmptyStateView(
        icon: _getEmptyIcon(currentPath),
        title: 'Empty Folder',
        subtitle: message,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _reprioritizeThumbnails(items, zoom);
      }
    });

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) {
          _throttleTimer?.cancel();
          _reprioritizeThumbnails(items, zoom);
        } else if (notification is ScrollUpdateNotification) {
          _throttledReprioritize(items, zoom);
        }
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          _lastConstraints = constraints;
          return GridView.builder(
            key: PageStorageKey<String>('file_grid_${tabId}_$currentPath'),
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 180 * zoom,
              mainAxisSpacing: 16 * zoom,
              crossAxisSpacing: 24 * zoom,
              mainAxisExtent: 215 * zoom,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ItemCard(
                key: ValueKey(item.path),
                item: item,
                zoom: zoom,
                isSelected: selection.selectedPaths.contains(item.path),
                isHovered: _hoveredPath == item.path,
                onTap: () => _handleTap(items, index),
                onDoubleTap: () => _handleDoubleTap(items, index),
                onHoverChanged: (hovered) {
                  setState(() => _hoveredPath = hovered ? item.path : null);
                },
              );
            },
          );
        },
      ),
    );
  }

  /// Compute which items are visible on screen plus outer buffer rows and tell
  /// the thumbnail session queue to prioritize viewport items, then buffer rows,
  /// and progressively generate remaining items in the folder.
  void _reprioritizeThumbnails(List<FileItem> items, double zoom) {
    if (!_scrollController.hasClients) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    final totalWidth = _lastConstraints?.maxWidth ??
        ((renderBox?.hasSize ?? false)
            ? renderBox!.size.width
            : MediaQuery.of(context).size.width);
    final totalHeight = _lastConstraints?.maxHeight ??
        ((renderBox?.hasSize ?? false)
            ? renderBox!.size.height
            : _scrollController.position.viewportDimension);

    final scrollOffset = _scrollController.hasClients
        ? _scrollController.offset.clamp(
            0.0,
            _scrollController.position.maxScrollExtent,
          )
        : 0.0;

    final indices = calculateGridViewportIndices(
      gridWidth: totalWidth,
      gridHeight: totalHeight,
      scrollOffset: scrollOffset,
      itemCount: items.length,
      zoom: zoom,
    );

    try {
      final session = ref.read(activeThumbnailSessionProvider);
      final cacheService = ref.read(thumbnailCacheServiceProvider);
      if (session != null && !session.isCancelled && !session.isDisposed) {
        session.enqueueAllFolderItems(
          items: items,
          cacheService: cacheService,
          firstVisibleIndex: indices.firstVisibleIndex,
          lastVisibleIndex: indices.lastVisibleIndex,
          firstBufferIndex: indices.firstBufferIndex,
          lastBufferIndex: indices.lastBufferIndex,
        );
      }
    } catch (_) {
      // In test environments or uninitialized provider trees
    }
  }

  void _throttledReprioritize(List<FileItem> items, double zoom) {
    if (_throttleTimer?.isActive ?? false) return;
    _throttleTimer = Timer(const Duration(milliseconds: 30), () {
      _reprioritizeThumbnails(items, zoom);
    });
  }
}

class GridViewportIndices {
  const GridViewportIndices({
    required this.firstVisibleIndex,
    required this.lastVisibleIndex,
    required this.firstBufferIndex,
    required this.lastBufferIndex,
    required this.cols,
  });

  final int firstVisibleIndex;
  final int lastVisibleIndex;
  final int firstBufferIndex;
  final int lastBufferIndex;
  final int cols;
}

GridViewportIndices calculateGridViewportIndices({
  required double gridWidth,
  required double gridHeight,
  required double scrollOffset,
  required int itemCount,
  required double zoom,
  double horizontalPadding = 32.0,
  double verticalPadding = 24.0,
  double maxCrossAxisExtent = 180.0,
  double crossAxisSpacing = 24.0,
  double mainAxisSpacing = 16.0,
  double mainAxisExtent = 215.0,
}) {
  if (itemCount <= 0) {
    return const GridViewportIndices(
      firstVisibleIndex: 0,
      lastVisibleIndex: 0,
      firstBufferIndex: 0,
      lastBufferIndex: 0,
      cols: 1,
    );
  }

  final effectiveMaxCrossAxisExtent = maxCrossAxisExtent * zoom;
  final effectiveCrossAxisSpacing = crossAxisSpacing * zoom;
  final effectiveMainAxisSpacing = mainAxisSpacing * zoom;
  final effectiveMainAxisExtent = mainAxisExtent * zoom;

  final availableWidth = math.max(0, gridWidth - (horizontalPadding * 2));

  // Exact Flutter SDK SliverGridDelegateWithMaxCrossAxisExtent formula:
  // int crossAxisCount = (constraints.crossAxisExtent / (maxCrossAxisExtent + crossAxisSpacing)).ceil();
  final cols = (availableWidth / (effectiveMaxCrossAxisExtent + effectiveCrossAxisSpacing))
      .ceil()
      .clamp(1, 100);

  final rowHeight = effectiveMainAxisExtent + effectiveMainAxisSpacing;
  final effectiveScrollOffset = math.max(0, scrollOffset);

  // Lowest row visible in [scrollOffset, scrollOffset + gridHeight]
  final firstVisibleRow = math.max(
    0,
    ((effectiveScrollOffset - verticalPadding) / rowHeight).floor(),
  );

  // Highest row visible in [scrollOffset, scrollOffset + gridHeight]
  final lastVisibleRow = math.max(
    firstVisibleRow,
    ((effectiveScrollOffset + gridHeight - verticalPadding) / rowHeight).ceil(),
  );

  final firstVisibleIndex = (firstVisibleRow * cols).clamp(0, itemCount);
  final lastVisibleIndex = ((lastVisibleRow + 1) * cols).clamp(0, itemCount);

  // 2 buffer rows above, 2 buffer rows below
  final firstBufferRow = math.max(0, firstVisibleRow - 2);
  final lastBufferRow = lastVisibleRow + 2;

  final firstBufferIndex = (firstBufferRow * cols).clamp(0, itemCount);
  final lastBufferIndex = ((lastBufferRow + 1) * cols).clamp(0, itemCount);

  return GridViewportIndices(
    firstVisibleIndex: firstVisibleIndex,
    lastVisibleIndex: lastVisibleIndex,
    firstBufferIndex: firstBufferIndex,
    lastBufferIndex: lastBufferIndex,
    cols: cols,
  );
}
