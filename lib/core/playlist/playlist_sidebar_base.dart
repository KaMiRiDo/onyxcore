import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/platform/directory_watcher.dart';
import 'package:onyxcore/core/playlist/media_queue_isolate.dart';
import 'package:onyxcore/core/playlist/playlist_providers.dart';
import 'package:onyxcore/core/playlist/playlist_tile.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/context_menu.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sort_overlay.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:path/path.dart' as p;
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/file_picker/presentation/widgets/custom_file_picker_dialog.dart';
import 'dart:io';

/// Abstract base widget for media playlist sidebars.
///
/// Contains all shared logic for directory watching, queue refresh, selection,
/// folder navigation, breadcrumbs, search, sort, favorites, and layout.
///
/// Subclasses override abstract methods to customise:
/// - Context menu items
/// - Double-tap behavior
/// - Tile metadata (subtitle, cover art, active indicator)
/// - The media file type filter
abstract class PlaylistSidebarBase extends ConsumerStatefulWidget {
  final void Function(List<String> paths)? onDelete;
  final void Function(List<String> paths)? onMove;
  final VoidCallback? onReload;

  const PlaylistSidebarBase({
    super.key,
    this.onDelete,
    this.onMove,
    this.onReload,
  });
}

abstract class PlaylistSidebarBaseState<T extends PlaylistSidebarBase>
    extends ConsumerState<T> {
  final ScrollController scrollController = ScrollController();
  final ScrollController breadcrumbController = ScrollController();
  StreamSubscription<FileChangeEvent>? _watcherSub;
  String? _watchedPath;
  Timer? _hoverTimer;

  // ── Configuration ──────────────────────────────────────────────────────────

  /// The provider configuration object containing all Riverpod provider
  /// references for this sidebar instance.
  PlaylistProviderConfig get config;

  /// The [FileItemType] this sidebar filters for (e.g. `FileItemType.audio`).
  FileItemType get targetMediaType;

  /// The header title shown when NOT in favorites mode.
  String get homeTitle => 'Home';

  /// The header title shown when in favorites mode.
  String get favoritesTitle => 'Favorites';

  /// Empty state text when no media files are found.
  String get emptyStateText;

  /// Empty state text when favorites mode is active but empty.
  String get favoritesEmptyStateText;

  /// The icon used for non-folder media items when no thumbnail is available.
  IconData get defaultMediaIcon;

  /// Size of the default media icon. Override for larger icons (e.g. video).
  double get defaultMediaIconSize => 24;

  // ── Abstract Hooks ─────────────────────────────────────────────────────────

  /// Build context menu items for the given [item] and [selection].
  List<ContextMenuItem> buildContextMenuItems(
    BuildContext context,
    FileItem item,
    List<String> selection,
  );

  /// Called when a non-folder item is double-tapped.
  void onItemDoubleTap(FileItem item, int realIndex, List<FileItem> queue);

  /// Called when a non-folder item is tapped.
  void onItemTap(FileItem item, int realIndex, List<FileItem> queue) {}

  /// Build the subtitle text for a tile.
  String buildSubtitle(FileItem item);

  /// Build an optional cover art widget for a tile (e.g. ID3 album art).
  /// Return null to use the default thumbnail/icon.
  Widget? buildCoverArt(WidgetRef ref, FileItem item);

  /// Build the active indicator widget shown when a tile is the current track.
  Widget? buildActiveIndicator(bool isPlaying);

  /// Determine if the given [item] is the currently active/playing item.
  bool isItemActive(WidgetRef ref, FileItem item);

  /// Whether the current active item is playing (for the active indicator).
  bool get isCurrentlyPlaying;

  /// Called when the reload button is tapped. By default calls [refreshQueue].
  /// Audio overrides this to call widget.onReload.
  void onReloadTap() => refreshQueue();

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setupWatcher();
    });
  }

  @override
  void dispose() {
    _hoverTimer?.cancel();
    scrollController.dispose();
    breadcrumbController.dispose();
    _watcherSub?.cancel();
    super.dispose();
  }

  // ── Directory Watching ─────────────────────────────────────────────────────

  void setupWatcher() {
    final currentPath = ref.read(config.currentPathProvider);
    if (_watchedPath == currentPath) return;

    _watcherSub?.cancel();
    _watchedPath = currentPath;

    final repo = ref.read(directoryRepositoryProvider);
    _watcherSub = repo.watchDirectory(currentPath).listen((event) {
      if (!mounted) return;
      refreshQueue();
    });
  }

  void refreshQueue() {
    final currentPath = ref.read(config.currentPathProvider);
    final repo = ref.read(directoryRepositoryProvider);
    final showHidden = ref.read(config.showHiddenProvider);

    repo.invalidateCache(currentPath);
    repo.listDirectory(currentPath).then((items) {
      if (!mounted) return;
      compute(processMediaQueueIsolate, {
        'items': items.map((e) => e.toJson()).toList(),
        'showHidden': showHidden,
        'targetType': targetMediaType.index,
      }).then((files) {
        if (!mounted) return;
        ref.read(config.queueProvider.notifier).state = files;
      });
    });
  }

  // ── Selection ──────────────────────────────────────────────────────────────

  void handleSelect(WidgetRef ref, int index, List<FileItem> items) {
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isCtrl = HardwareKeyboard.instance.isControlPressed;

    final selection = ref.read(config.selectionProvider);
    int? anchor = ref.read(config.selectionAnchorProvider);
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
      ref.read(config.selectionAnchorProvider.notifier).state = index;
    } else {
      newSelection.clear();
      newSelection.add(items[index].path);
      ref.read(config.selectionAnchorProvider.notifier).state = index;
    }

    ref.read(config.selectionProvider.notifier).state = newSelection;
  }

  // ── Folder Navigation ──────────────────────────────────────────────────────

  void openFolder(WidgetRef ref, String path) async {
    final repo = ref.read(directoryRepositoryProvider);
    final showHidden = ref.read(config.showHiddenProvider);

    try {
      final items = await repo.listDirectory(path);

      final mediaFiles = await compute(processMediaQueueIsolate, {
        'items': items.map((e) => e.toJson()).toList(),
        'showHidden': showHidden,
        'targetType': targetMediaType.index,
      });

      final currentPath = ref.read(config.currentPathProvider);
      ref
          .read(config.pathHistoryProvider.notifier)
          .update((state) => [...state, currentPath]);
      ref.read(config.pathForwardHistoryProvider.notifier).state = [];

      ref.read(config.currentPathProvider.notifier).state = path;
      ref.read(config.queueProvider.notifier).state = mediaFiles;
      ref.read(config.selectionProvider.notifier).state = {};
      ref.read(config.selectionAnchorProvider.notifier).state = null;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (breadcrumbController.hasClients) {
          breadcrumbController.animateTo(
            breadcrumbController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint("Error opening folder: $e");
    }
  }

  // ── Context Menu ───────────────────────────────────────────────────────────

  void showContextMenu(BuildContext context, FileItem item, Offset position) {
    final isSelected = ref.read(config.selectionProvider).contains(item.path);
    final selection = isSelected
        ? ref.read(config.selectionProvider).toList()
        : [item.path];

    ContextMenu.show(
      context,
      position,
      buildContextMenuItems(context, item, selection),
    );
  }

  Future<void> handleMoveOrCopy(BuildContext context, List<String> paths, bool isMove) async {
    final result = await CustomFilePickerDialog.show(
      context,
      title: isMove ? 'SELECT DESTINATION TO MOVE' : 'SELECT DESTINATION TO COPY',
      pickDirectory: true,
      actionText: isMove ? 'MOVE HERE' : 'COPY HERE',
    );
    if (result == null || result.isEmpty) return;

    final targetDir = result.first;
    // Run in background after a slight delay so dialog can pop smoothly without stuttering
    Future.delayed(const Duration(milliseconds: 300), () {
      executeMoveOrCopy(paths, targetDir, isMove);
    });
  }

  Future<void> executeMoveOrCopy(List<String> paths, String targetDir, bool isMove) async {
    if (isMove && widget.onMove != null) {
      widget.onMove!(paths);
    }
    
    final repo = ref.read(directoryRepositoryProvider);
    final taskNotifier = ref.read(taskProvider.notifier);

    final String taskId = taskNotifier.addTask(
      title: isMove ? 'Moving items' : 'Copying items',
      subtitle: '${paths.length} items to ${p.basename(targetDir)}',
      totalCount: paths.length,
      sourcePaths: paths,
      targetPath: targetDir,
    );

    int totalSizeBytes = 0;
    for (final path in paths) {
      try {
        final stat = FileStat.statSync(path);
        totalSizeBytes += stat.size;
      } catch (_) {}
    }
    taskNotifier.updateByteCounts(taskId, 0, totalSizeBytes);

    int totalBytesProcessed = 0;

    try {
      for (int i = 0; i < paths.length; i++) {
        if (taskNotifier.isTaskCancelled(taskId)) break;

        final sourcePath = paths[i];
        final fileName = p.basename(sourcePath);
        final destPath = p.join(targetDir, fileName);

        taskNotifier.addLog(taskId, '${isMove ? "Moving" : "Copying"} $fileName...');
        taskNotifier.updateCurrentItem(taskId, fileName);

        int lastItemBytesProcessed = 0;
        void onProgress(int bytesCopied) {
          final delta = bytesCopied - lastItemBytesProcessed;
          lastItemBytesProcessed = bytesCopied;
          totalBytesProcessed += delta;

          taskNotifier.updateByteCounts(taskId, totalBytesProcessed, totalSizeBytes);
          if (totalSizeBytes > 0) {
            taskNotifier.updateProgress(taskId, totalBytesProcessed / totalSizeBytes);
          }
        }

        final isLastOperation = i == paths.length - 1;
        void onSyncing() {
          if (isLastOperation) {
            taskNotifier.setSyncing(taskId, true);
            taskNotifier.addLog(taskId, 'Syncing to disk...');
          }
        }

        if (isMove) {
          await repo.moveItemTo(
            sourcePath,
            destPath,
            onProgress: onProgress,
            onSyncing: onSyncing,
            taskId: taskId,
            onPort: (port, isolate) => taskNotifier.registerPort(taskId, port, isolate: isolate),
          );
        } else {
          await repo.copyItemTo(
            sourcePath,
            destPath,
            onProgress: onProgress,
            onSyncing: onSyncing,
            taskId: taskId,
            onPort: (port, isolate) => taskNotifier.registerPort(taskId, port, isolate: isolate),
          );
        }

        taskNotifier.addLog(taskId, 'Completed: $fileName');
        taskNotifier.updateItemCounts(taskId, i + 1, paths.length);
        taskNotifier.updateProgress(taskId, (i + 1) / paths.length);
      }

      taskNotifier.completeTask(taskId);
      refreshQueue(); // Refresh the current queue to reflect moved/copied items
    } catch (e) {
      taskNotifier.addLog(taskId, 'ERROR: $e');
      taskNotifier.failTask(taskId, e.toString());
    }
  }

  // ── Breadcrumbs ────────────────────────────────────────────────────────────

  Widget buildBreadcrumbs(String currentPath, String rootPath) {
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


      final inkWell = InkWell(
        onTap: isLast
            ? null
            : () {
                openFolder(ref, targetPath);
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
      );

      if (isLast) {
        breadcrumbWidgets.add(inkWell);
      } else {
        breadcrumbWidgets.add(
          DragTarget<List<String>>(
            onWillAcceptWithDetails: (details) {
              _hoverTimer?.cancel();
              _hoverTimer = Timer(const Duration(milliseconds: 1000), () {
                openFolder(ref, targetPath);
              });
              return true;
            },
            onLeave: (_) {
              _hoverTimer?.cancel();
            },
            onAcceptWithDetails: (details) {
              _hoverTimer?.cancel();
              if (details.data.every((path) => p.dirname(path) == targetPath)) return;
              executeMoveOrCopy(details.data, targetPath, true);
              ref.read(config.selectionProvider.notifier).state = {};
            },
            builder: (context, candidateData, rejectedData) {
              final isOver = candidateData.isNotEmpty;
              return Container(
                decoration: BoxDecoration(
                  color: isOver ? AppColors.violet.withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: inkWell,
              );
            },
          ),
        );
      }


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
              controller: breadcrumbController,
              scrollDirection: Axis.horizontal,
              child: Row(
                children: breadcrumbWidgets,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: ref.watch(config.showHiddenProvider)
                ? 'Hide hidden folders'
                : 'Show hidden folders',
            child: InkWell(
              onTap: () {
                final current = ref.read(config.showHiddenProvider);
                ref.read(config.showHiddenProvider.notifier).state = !current;
                // Re-fetch queue to reflect new visibility
                final repo = ref.read(directoryRepositoryProvider);
                repo.listDirectory(currentPath).then((items) {
                  compute(processMediaQueueIsolate, {
                    'items': items.map((e) => e.toJson()).toList(),
                    'showHidden': !current,
                    'targetType': targetMediaType.index,
                  }).then((files) {
                    ref.read(config.queueProvider.notifier).state = files;
                  });
                });
              },
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: ref.watch(config.showHiddenProvider)
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
              onTap: onReloadTap,
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

  // ── Bottom Nav Item ────────────────────────────────────────────────────────

  Widget buildNavItem({
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

  // ── Build ──────────────────────────────────────────────────────────────────

  /// Build additional listeners (e.g. `ref.listen`) in the build method.
  /// Override in subclasses that need listeners. Default is no-op.
  void buildListeners() {}

  @override
  Widget build(BuildContext context) {
    final queue = ref.watch(config.filteredAndSortedQueueProvider);
    final currentPath = ref.watch(config.currentPathProvider);
    final rootPath = ref.watch(config.rootPathProvider);
    final selection = ref.watch(config.selectionProvider);
    final isFavoritesMode =
        ref.watch(config.viewModeProvider) == config.favoritesValue;

    buildListeners();

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
          final currentSelection = ref.read(config.selectionProvider);
          if (currentSelection.isNotEmpty) {
            ref.read(config.selectionProvider.notifier).state = {};
            ref.read(config.selectionAnchorProvider.notifier).state = null;
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
                    isFavoritesMode ? favoritesTitle : homeTitle,
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
                          final sortOption = ref.watch(config.sortOptionProvider);
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
                                    ref.read(config.sortOptionProvider) ??
                                    SortOption.aToZ,
                                onSelected: (option) {
                                  ref
                                          .read(
                                            config.sortOptionProvider.notifier,
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
                      ref.read(config.searchQueryProvider.notifier).state = val,
                ),
              ),
            ),

            // Breadcrumbs
            buildBreadcrumbs(currentPath, rootPath),

            // Track List
            Expanded(
              child: Stack(
                children: [
                  queue.isEmpty
                      ? Center(
                          child: Text(
                            isFavoritesMode
                                ? favoritesEmptyStateText
                                : emptyStateText,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: queue.length,
                          itemBuilder: (context, index) {
                            final item = queue[index];
                            final isActive = isItemActive(ref, item);
                            final isItemSelected = selection.contains(item.path);

                            Widget tileWidget = MediaTile(
                              item: item,
                              isActive: isActive,
                              isSelected: isItemSelected,
                              subtitle: buildSubtitle(item),
                              defaultMediaIcon: defaultMediaIcon,
                              defaultMediaIconSize: defaultMediaIconSize,
                              coverArt: buildCoverArt(ref, item),
                              activeIndicator: isActive
                                  ? buildActiveIndicator(isCurrentlyPlaying)
                                  : null,
                              onSecondaryTapDown: (details, tileContext) {
                                if (!isItemSelected) {
                                  ref
                                      .read(config.selectionProvider.notifier)
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
                                showContextMenu(context, item, position);
                              },
                              onTap: () {
                                handleSelect(ref, index, queue);
                                
                                if (item.type != FileItemType.folder) {
                                  final originalQueue = ref.read(config.queueProvider);
                                  final realIndex = originalQueue.indexWhere((i) => i.path == item.path);
                                  if (realIndex != -1) {
                                    onItemTap(item, realIndex, originalQueue);
                                  }
                                }
                              },
                              onDoubleTap: () {
                                ref.read(config.selectionProvider.notifier).state = {};

                                if (item.type == FileItemType.folder) {
                                  openFolder(ref, item.path);
                                  return;
                                }

                                // Find the real index in the unfiltered queue
                                final originalQueue = ref.read(config.queueProvider);
                                final realIndex = originalQueue.indexWhere(
                                  (i) => i.path == item.path,
                                );
                                if (realIndex != -1) {
                                  onItemDoubleTap(item, realIndex, originalQueue);
                                }
                              },
                            );

                            Widget draggableWidget = Draggable<List<String>>(
                              data: isItemSelected
                                  ? selection.toList()
                                  : [item.path],
                              dragAnchorStrategy: (draggable, context, position) => const Offset(0, 0),
                              feedback: RepaintBoundary(
                                child: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    width: 250,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF181818).withOpacity(0.95),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: const Offset(0, 4)),
                                      ],
                                    ),
                                    child: Text(
                                      isItemSelected && selection.length > 1
                                          ? '${selection.length} items'
                                          : item.name,
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                              ),
                              childWhenDragging: Opacity(opacity: 0.3, child: tileWidget),
                              child: tileWidget,
                            );

                            if (item.type == FileItemType.folder) {
                              return DragTarget<List<String>>(
                                onWillAcceptWithDetails: (details) {
                                  if (details.data.contains(item.path)) return false;
                                  
                                  _hoverTimer?.cancel();
                                  _hoverTimer = Timer(const Duration(milliseconds: 1000), () {
                                    openFolder(ref, item.path);
                                  });
                                  
                                  return true;
                                },
                                onLeave: (_) {
                                  _hoverTimer?.cancel();
                                },
                                onAcceptWithDetails: (details) {
                                  _hoverTimer?.cancel();
                                  executeMoveOrCopy(details.data, item.path, true);
                                  ref.read(config.selectionProvider.notifier).state = {};
                                },
                                builder: (context, candidateData, rejectedData) {
                                  final isOver = candidateData.isNotEmpty;
                                  return Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      color: isOver ? AppColors.violet.withOpacity(0.15) : null,
                                    ),
                                    child: draggableWidget,
                                  );
                                },
                              );
                            }

                            return draggableWidget;
                          },
                        ),
                  if (ref.watch(config.isReloadingProvider))
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
            buildBottomNavBar(isFavoritesMode),
          ],
        ),
      ),
    );
  }

  /// Build the bottom navigation bar. Subclasses can override for custom nav items.
  Widget buildBottomNavBar(bool isFavoritesMode) {
    return Container(
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
          buildNavItem(
            icon: Icons.home_rounded,
            label: "Home",
            isSelected: !isFavoritesMode,
            onTap: () => onHomeNavTap(),
          ),
          buildNavItem(
            icon: Icons.favorite_rounded,
            label: "Favorites",
            isSelected: isFavoritesMode,
            onTap: () => onFavoritesNavTap(),
          ),
        ],
      ),
    );
  }

  /// Called when the Home nav item is tapped. Subclasses must set their view mode.
  void onHomeNavTap();

  /// Called when the Favorites nav item is tapped. Subclasses must set their view mode.
  void onFavoritesNavTap();
}
