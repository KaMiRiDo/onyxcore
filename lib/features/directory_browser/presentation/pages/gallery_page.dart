import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/directory_size_utils.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
import 'package:onyxcore/features/archive_manager/presentation/providers/archive_provider.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/directory_browser/presentation/pages/directory_analysis_page.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/background_panel_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/clipboard_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/conflict_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_analysis_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/conflict_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/context_menu.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/create_item_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/dialogs.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/error_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/file_grid.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/gnome_tab_bar.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/open_with_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/preview_container.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/properties_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/rename_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/rename_popover.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/rubber_band_overlay.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sidebar/sidebar.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/top_bar.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/unified_side_panel.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:path/path.dart' as p;

/// Main gallery page — slim orchestrator that composes all widgets.
class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key});

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage>
    with WidgetsBindingObserver {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode = ref.read(mainFocusNodeProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupReverseIpc();
      _focusNode.requestFocus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      ref.read(taskProvider.notifier).cancelAllTasks();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearReverseIpc();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearReverseIpc() {
    // IPC is no longer needed with native multi-view
  }

  void _setupReverseIpc() {
    // IPC is no longer needed with native multi-view
  }

  @override
  Widget build(BuildContext context) {
    // Watch search state at the top level to ensure rebuilds of shortcuts
    final isSearchActive = ref.watch(isSearchActiveProvider);
    final isLocationEditing = ref.watch(isLocationEditingProvider);
    final isMarkerEditorActive = ref.watch(isMarkerEditorActiveProvider);
    final isPreviewActive = ref.watch(previewFileProvider) != null;
    final isDownloadInputFocused = ref.watch(isDownloadInputFocusedProvider);
    final isDownloadsPanelFocused = ref.watch(isDownloadsPanelFocusedProvider);

    return CallbackShortcuts(
      bindings: _buildKeyBindings(
        isSearchActive,
        isLocationEditing,
        isMarkerEditorActive,
        isPreviewActive,
        isDownloadInputFocused || isDownloadsPanelFocused,
      ),
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: Listener(
          onPointerUp: (event) {
            if (ref.read(isDraggingProvider)) {
              Future.microtask(() {
                ref.read(isDraggingProvider.notifier).state = false;
                ref.read(draggingPathsProvider.notifier).state = {};
              });
            }
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: Consumer(
              builder: (context, ref, child) {
                final isDraggingPanel = ref.watch(
                  isDownloadsPanelDraggingProvider,
                );
                return MouseRegion(
                  cursor: isDraggingPanel
                      ? SystemMouseCursors.resizeLeftRight
                      : MouseCursor.defer,
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          const Sidebar(),
                          Expanded(
                            child: Stack(
                              children: [
                                Column(
                                  children: [
                                    const TopBar(),
                                    const GnomeTabBar(),
                                    Expanded(
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Expanded(
                                            child: Listener(
                                              onPointerDown: (_) =>
                                                  _focusNode.requestFocus(),
                                              child: MouseRegion(
                                                child: GestureDetector(
                                                  behavior:
                                                      HitTestBehavior.opaque,
                                                  onTap: () {
                                                    _focusNode.requestFocus();
                                                    final isModifierPressed =
                                                        HardwareKeyboard
                                                            .instance
                                                            .logicalKeysPressed
                                                            .contains(
                                                              LogicalKeyboardKey
                                                                  .shiftLeft,
                                                            ) ||
                                                        HardwareKeyboard
                                                            .instance
                                                            .logicalKeysPressed
                                                            .contains(
                                                              LogicalKeyboardKey
                                                                  .shiftRight,
                                                            ) ||
                                                        HardwareKeyboard
                                                            .instance
                                                            .logicalKeysPressed
                                                            .contains(
                                                              LogicalKeyboardKey
                                                                  .controlLeft,
                                                            ) ||
                                                        HardwareKeyboard
                                                            .instance
                                                            .logicalKeysPressed
                                                            .contains(
                                                              LogicalKeyboardKey
                                                                  .controlRight,
                                                            );
                                                    if (!isModifierPressed) {
                                                      ref
                                                          .read(
                                                            selectionProvider
                                                                .notifier,
                                                          )
                                                          .deselectAll();
                                                    }
                                                  },
                                                  onSecondaryTapUp: (details) {
                                                    final clipboard = ref.read(
                                                      clipboardProvider,
                                                    );
                                                    final currentPath = ref
                                                        .read(
                                                          currentPathProvider,
                                                        );
                                                    final tabId = ref.read(
                                                      tabIdProvider,
                                                    );
                                                    final items =
                                                        ref
                                                            .read(
                                                              filteredDirectoryItemsProvider,
                                                            )
                                                            .value ??
                                                        [];
                                                    final allPaths = items
                                                        .map((e) => e.path)
                                                        .toList();
                                                    final isInTrash =
                                                        currentPath.contains(
                                                          '.local/share/Trash/files',
                                                        ) ||
                                                        currentPath.endsWith(
                                                          'Trash/files',
                                                        ) ||
                                                        currentPath ==
                                                            'trash:///';

                                                    ContextMenu.show(
                                                      context,
                                                      details.globalPosition,
                                                      [
                                                        if (!isInTrash) ...[
                                                          ContextMenuItem(
                                                            title: 'New Folder',
                                                            icon: Icons
                                                                .create_new_folder_rounded,
                                                            shortcut:
                                                                'Ctrl+Shift+N',
                                                            onTap: _handleNewItem,
                                                          ),
                                                          ContextMenuItem(
                                                            title:
                                                                'New Document',
                                                            icon: Icons
                                                                .note_add_rounded,
                                                            onTap: () =>
                                                                _handleNewItem(
                                                                  initialIsFolder:
                                                                      false,
                                                                ),
                                                          ),
                                                        ],
                                                        if (isInTrash) ...[
                                                          ContextMenuItem(
                                                            title:
                                                                'Empty Trash',
                                                            icon: Icons
                                                                .delete_forever_rounded,
                                                            onTap:
                                                                _handleEmptyTrash,
                                                          ),
                                                          ContextMenuItem.divider(),
                                                        ],
                                                        ContextMenuItem(
                                                          title: 'Open With',
                                                          icon: Icons
                                                              .open_in_new_rounded,
                                                          onTap: () =>
                                                              OpenWithDialog.show(
                                                                context,
                                                                currentPath,
                                                              ),
                                                        ),
                                                        ContextMenuItem(
                                                          title: 'Sort By',
                                                          icon: Icons
                                                              .sort_rounded,
                                                          subItems: [
                                                            _buildSortItem(
                                                              'A to Z',
                                                              SortOption.aToZ,
                                                              tabId,
                                                            ),
                                                            _buildSortItem(
                                                              'Z to A',
                                                              SortOption.zToA,
                                                              tabId,
                                                            ),
                                                            ContextMenuItem.divider(),
                                                            _buildSortItem(
                                                              'Last Modified',
                                                              SortOption
                                                                  .lastModified,
                                                              tabId,
                                                            ),
                                                            _buildSortItem(
                                                              'First Modified',
                                                              SortOption
                                                                  .firstModified,
                                                              tabId,
                                                            ),
                                                            ContextMenuItem.divider(),
                                                            _buildSortItem(
                                                              'Size (Small to Large)',
                                                              SortOption
                                                                  .sizeSmallToLarge,
                                                              tabId,
                                                            ),
                                                            _buildSortItem(
                                                              'Size (Large to Small)',
                                                              SortOption
                                                                  .sizeLargeToSmall,
                                                              tabId,
                                                            ),
                                                          ],
                                                          onTap: () {},
                                                        ),
                                                        ContextMenuItem.divider(),
                                                        ContextMenuItem(
                                                          title: 'Refresh',
                                                          icon: Icons
                                                              .refresh_rounded,
                                                          shortcut:
                                                              'F5, Ctrl+R',
                                                          onTap: _refresh,
                                                        ),
                                                        ContextMenuItem(
                                                          title: 'Paste',
                                                          icon: Icons
                                                              .paste_rounded,
                                                          shortcut: 'Ctrl+V',
                                                          isEnabled: clipboard
                                                              .paths
                                                              .isNotEmpty,
                                                          onTap: _handlePaste,
                                                        ),
                                                        ContextMenuItem(
                                                          title: 'Select All',
                                                          icon: Icons
                                                              .select_all_rounded,
                                                          shortcut: 'Ctrl+A',
                                                          onTap: () => ref
                                                              .read(
                                                                selectionProvider
                                                                    .notifier,
                                                              )
                                                              .selectAll(
                                                                allPaths,
                                                              ),
                                                        ),
                                                        ContextMenuItem(
                                                          title:
                                                              'Open in Terminal',
                                                          icon: Icons
                                                              .terminal_rounded,
                                                          onTap: () => Process.start(
                                                            'gnome-terminal',
                                                            [
                                                              '--working-directory=$currentPath',
                                                            ],
                                                          ),
                                                        ),
                                                        ContextMenuItem.divider(),
                                                        ContextMenuItem(
                                                          title: 'Properties',
                                                          icon: Icons
                                                              .info_outline_rounded,
                                                          shortcut: 'Alt+Enter',
                                                          onTap:
                                                              _showProperties,
                                                        ),
                                                        ContextMenuItem(
                                                          title: 'Analyse',
                                                          icon: Icons
                                                              .analytics_rounded,
                                                          shortcut:
                                                              'Ctrl+Alt+Enter',
                                                          onTap:
                                                              _toggleAnalysis,
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                  child: _buildContentInner(),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const UnifiedSidePanel(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                // Immersive Media Preview Overlay (Covers tabs and top bar)
                                Consumer(
                                  builder: (context, ref, child) {
                                    final previewFile = ref.watch(
                                      previewFileProvider,
                                    );
                                    if (previewFile == null) {
                                      return const SizedBox.shrink();
                                    }
                                    return Positioned.fill(
                                      child: PreviewContainer(
                                        item: previewFile,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Consumer(
                        builder: (context, ref, child) {
                          final isDragging = ref.watch(isDraggingProvider);
                          if (!isDragging) return const SizedBox.shrink();

                          return Positioned(
                            top: 12,
                            left: 0,
                            right: 0,
                            child: Center(
                              child: RepaintBoundary(
                                child: DragTarget<List<String>>(
                                  onAcceptWithDetails: (_) {
                                    ref
                                            .read(isDraggingProvider.notifier)
                                            .state =
                                        false;
                                  },
                                  builder:
                                      (context, candidateData, rejectedData) {
                                        final isOver = candidateData.isNotEmpty;
                                        return ClipOval(
                                          clipBehavior:
                                              Clip.antiAliasWithSaveLayer,
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(
                                              sigmaX: 12,
                                              sigmaY: 12,
                                            ),
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              width: 56,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                color: isOver
                                                    ? Colors.red.withValues(
                                                        alpha: 0.6,
                                                      )
                                                    : Colors.white.withValues(
                                                        alpha: 0.08,
                                                      ),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isOver
                                                      ? Colors.white
                                                      : Colors.white10,
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  isOver
                                                      ? Icons.delete_forever
                                                      : Icons.close,
                                                  color: Colors.white,
                                                  size: 24,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }



  /// Same as _buildContent but without the Expanded wrapper (for inline Row layout).
  Widget _buildContentInner() {
    final tabState = ref.watch(tabManagerProvider);

    return IndexedStack(
      index: tabState.activeTabIndex,
      children: tabState.tabs.map((tab) {
        return ProviderScope(
          key: ValueKey(tab.id),
          overrides: [
            tabIdProvider.overrideWithValue(tab.id),
            // Override these to ensure they are local to the tab's scope
            directoryItemsProvider.overrideWith(DirectoryItemsNotifier.new),
            filteredDirectoryItemsProvider.overrideWith((ref) {
              final itemsAsync = ref.watch(directoryItemsProvider);
              final query = ref.watch(searchQueryProvider).toLowerCase();
              final showHidden = ref.watch(
                settingsProvider.select(
                  (s) => s.value?.showHiddenFiles ?? false,
                ),
              );

              return itemsAsync.whenData((items) {
                var filtered = items;
                if (!showHidden) {
                  filtered = filtered
                      .where((item) => !item.name.startsWith('.'))
                      .toList();
                }
                if (query.isNotEmpty) {
                  filtered = filtered
                      .where((item) => item.name.toLowerCase().contains(query))
                      .toList();
                }
                return filtered;
              });
            }),
          ],
          child: _TabBody(tabId: tab.id),
        );
      }).toList(),
    );
  }
}

class _TabBody extends ConsumerWidget {
  const _TabBody({required this.tabId});
  final String tabId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAnalysisActive = ref.watch(isAnalysisActiveProvider);
    final currentPath = ref.watch(currentPathProvider);

    return Column(
      children: [
        Expanded(
          child: isAnalysisActive
              ? DirectoryAnalysisPage(path: currentPath)
              : const RubberBandOverlay(
                  child: FileGrid(),
                ),
        ),
      ],
    );
  }
}

extension _GalleryPageStateShortcuts on _GalleryPageState {
  Map<ShortcutActivator, VoidCallback> _buildKeyBindings(
    bool isSearchActive,
    bool isLocationEditing,
    bool isMarkerEditorActive,
    bool isPreviewActive,
    bool isDownloadInputFocused,
  ) {
    return {
      // General Navigation
      if (!isLocationEditing &&
          !isSearchActive &&
          !isDownloadInputFocused &&
          !isPreviewActive) ...{
        const SingleActivator(LogicalKeyboardKey.backspace): _goBack,
        const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): _goBack,
        const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true):
            _goForward,
      },

      // Selection
      if (!isPreviewActive)
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            ref.read(selectionProvider.notifier).deselectAll(),
      if (!isSearchActive &&
          !isLocationEditing &&
          !isMarkerEditorActive &&
          !isPreviewActive &&
          !isDownloadInputFocused)
        const SingleActivator(LogicalKeyboardKey.keyA, control: true):
            _selectAll,

      // Properties
      if (!isSearchActive &&
          !isLocationEditing &&
          !isMarkerEditorActive &&
          !isPreviewActive &&
          !isDownloadInputFocused)
        const SingleActivator(LogicalKeyboardKey.enter, alt: true):
            _showProperties,

      // File Operations
      if (!isLocationEditing &&
          !isMarkerEditorActive &&
          !isPreviewActive &&
          !isDownloadInputFocused) ...{
        const SingleActivator(LogicalKeyboardKey.keyC, control: true):
            _handleCopy,
        const SingleActivator(LogicalKeyboardKey.keyX, control: true):
            _handleCut,
        const SingleActivator(LogicalKeyboardKey.keyV, control: true):
            _handlePaste,
        const SingleActivator(
          LogicalKeyboardKey.keyV,
          control: true,
          shift: true,
        ): _handlePreview,
        const SingleActivator(LogicalKeyboardKey.delete): () =>
            _handleDelete(permanent: false),
        const SingleActivator(LogicalKeyboardKey.delete, shift: true): () =>
            _handleDelete(permanent: true),
        const SingleActivator(LogicalKeyboardKey.f2): _onF2Pressed,
        const SingleActivator(
          LogicalKeyboardKey.keyN,
          control: true,
          shift: true,
        ): _handleNewItem,
        const SingleActivator(
          LogicalKeyboardKey.keyC,
          control: true,
          alt: true,
        ): _handleCompress,
      },

      // Zoom
      if (!isPreviewActive)
        const SingleActivator(LogicalKeyboardKey.equal, control: true): () =>
            _zoom(0.1),
      const SingleActivator(LogicalKeyboardKey.minus, control: true): () =>
          _zoom(-0.1),
      const SingleActivator(LogicalKeyboardKey.numpadAdd, control: true): () =>
          _zoom(0.1),
      const SingleActivator(
        LogicalKeyboardKey.numpadSubtract,
        control: true,
      ): () =>
          _zoom(-0.1),
      const SingleActivator(LogicalKeyboardKey.digit0, control: true):
          _resetZoom,

      // Global Shortcuts
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
          _toggleSearch(!isSearchActive),
      const SingleActivator(LogicalKeyboardKey.keyR, control: true): _refresh,
      const SingleActivator(LogicalKeyboardKey.period, control: true):
          _toggleHiddenFiles,
      const SingleActivator(LogicalKeyboardKey.enter, control: true, alt: true):
          _toggleAnalysis,
      const SingleActivator(LogicalKeyboardKey.f5): _refresh,
      const SingleActivator(LogicalKeyboardKey.keyB, control: true): () {
        final isOpen = ref.read(backgroundPanelOpenProvider);
        ref.read(backgroundPanelOpenProvider.notifier).state = !isOpen;
        if (!isOpen) {
          ref.read(downloadsPanelOpenProvider.notifier).state = false;
          ref.read(backgroundPanelViewProvider.notifier).state =
              BackgroundPanelView.tasks;
        }
      },
      const SingleActivator(LogicalKeyboardKey.keyD, control: true): () {
        final isOpen = ref.read(downloadsPanelOpenProvider);
        if (!isOpen) {
          ref.read(downloadsPanelOpenProvider.notifier).state = true;
          ref.read(backgroundPanelOpenProvider.notifier).state = false;
          ref.read(downloadsPanelViewProvider.notifier).state =
              DownloadsPanelView.tasks;
          ref.read(downloadUrlFocusRequestProvider.notifier).state++;
        } else {
          final isFocused = ref.read(isDownloadInputFocusedProvider);
          if (!isFocused) {
            ref.read(downloadsPanelViewProvider.notifier).state =
                DownloadsPanelView.tasks;
            ref.read(downloadUrlFocusRequestProvider.notifier).state++;
          } else {
            ref.read(downloadsPanelOpenProvider.notifier).state = false;
          }
        }
      },
      const SingleActivator(LogicalKeyboardKey.keyD, control: true, shift: true): () {
        final currentPath = ref.read(currentPathProvider);
        PersistentViewerManager.openMedia(
          WindowParams(
            viewerType: ViewerType.downloader,
            file: FileItem(
              name: 'Downloader',
              path: currentPath,
              type: FileItemType.other,
              modified: DateTime.now(),
              sizeBytes: 0,
            ),
            initParams: {
              'currentPath': currentPath,
              'width': max(950, ref.read(settingsProvider).value?.downloaderWidth.toInt() ?? 950),
              'height': max(700, ref.read(settingsProvider).value?.downloaderHeight.toInt() ?? 700),
            },
          ),
        );
      },
      const SingleActivator(LogicalKeyboardKey.keyD, alt: true): () {
        if (!isSearchActive) {
          ref.read(isLocationEditingProvider.notifier).toggle();
        }
      },

      // Tab Management
      const SingleActivator(LogicalKeyboardKey.keyT, control: true): _addNewTab,
      const SingleActivator(LogicalKeyboardKey.keyW, control: true):
          _closeActiveTab,
      const SingleActivator(LogicalKeyboardKey.tab, control: true):
          _switchToNextTab,
      const SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true):
          _switchToPreviousTab,

      // Item Opening
      if (!isLocationEditing &&
          !isDownloadInputFocused &&
          !isPreviewActive) ...{
        const SingleActivator(LogicalKeyboardKey.enter): _handleEnter,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _handleEnter,
      },
    };
  }

  void _addNewTab() {
    final activeTab = ref.read(tabManagerProvider).activeTab;
    ref
        .read(tabManagerProvider.notifier)
        .addTab(
          path: activeTab.currentPath,
          history: activeTab.history,
          historyIndex: activeTab.historyIndex,
        );
  }

  void _closeActiveTab() {
    final activeId = ref.read(activeTabIdProvider);
    ref.read(tabManagerProvider.notifier).closeTab(activeId);
  }

  void _switchToNextTab() {
    ref.read(tabManagerProvider.notifier).switchToNextTab();
  }

  void _switchToPreviousTab() {
    ref.read(tabManagerProvider.notifier).switchToPreviousTab();
  }

  void _toggleSearch(bool active) {
    if (active) {
      ref.read(isLocationEditingProvider.notifier).set(false);
    }
    ref.read(isSearchActiveProvider.notifier).set(active);
  }

  Future<void> _refresh() async {
    if (ref.read(isRefreshingProvider)) return;
    ref.read(isRefreshingProvider.notifier).state = true;

    final currentPath = ref.read(currentPathProvider);
    ref.read(directoryRepositoryProvider).invalidateCache(currentPath);
    ref.read(refreshCountProvider.notifier).state =
        ref.read(refreshCountProvider) + 1;
    
    ref.read(directoryItemsProvider.notifier).refresh();
    
    try {
      // Wait for both the data load and the minimum animation duration
      await Future.wait([
        ref.read(directoryItemsProvider.future),
        Future<void>.delayed(const Duration(milliseconds: 150)),
      ]);
    } catch (_) {}

    ref.read(isRefreshingProvider.notifier).state = false;
  }

  void _handlePreview() {
    final selection = ref.read(selectionProvider);
    if (selection.selectedPaths.isEmpty) return;

    final selectedPath = selection.selectedPaths.first;
    final items = ref.read(directoryItemsProvider).value ?? [];
    try {
      final selectedItem = items.firstWhere((i) => i.path == selectedPath);
      ref.read(previewFileProvider.notifier).state = selectedItem;
    } catch (_) {}
  }

  void _handleEnter() {
    final selection = ref.read(selectionProvider);
    if (selection.selectedPaths.length != 1) return;

    final selectedPath = selection.selectedPaths.first;
    final itemsAsync = ref.read(filteredDirectoryItemsProvider);

    itemsAsync.whenData((items) {
      try {
        final item = items.firstWhere((i) => i.path == selectedPath);
        _openItem(item);
      } catch (e) {
        // Item not found in current view (maybe hidden?)
      }
    });
  }

  void _openItem(FileItem item) {
    if (item.type == FileItemType.folder) {
      ref.read(selectionProvider.notifier).deselectAll();
      ref.read(navigationProvider.notifier).navigateTo(item.path);
      ref.read(currentPathProvider.notifier).state = item.path;
    } else if (item.type == FileItemType.archive) {
      final currentDir = ref.read(currentPathProvider);
      ref
          .read(archiveProvider.notifier)
          .extractArchive(context, item.path, currentDir);
    } else if (item.type == FileItemType.image ||
        item.type == FileItemType.video ||
        item.type == FileItemType.audio ||
        item.type == FileItemType.document) {
      ref.read(previewFileProvider.notifier).state = item;
    }
  }

  int _getDirectorySizeSync(String path) {
    var total = 0;
    try {
      final dir = Directory(path);
      if (dir.existsSync()) {
        for (final entity in dir.listSync(
          recursive: true,
          followLinks: false,
        )) {
          if (entity is File) {
            total += entity.lengthSync();
          }
        }
      }
    } catch (_) {
      // Ignore permission errors for specific files
    }
    return total;
  }

  void _showProperties() {
    final selection = ref.read(selectionProvider);
    final paths = selection.selectedPaths.isEmpty
        ? [ref.read(currentPathProvider)]
        : selection.selectedPaths.toList();

    showDialog<dynamic>(
      context: context,
      builder: (context) => PropertiesDialog(paths: paths),
    );
  }

  void _goBack() {
    if (ref.read(previewFileProvider) != null) return;

    if (ref.read(isAnalysisActiveProvider)) {
      ref.read(isAnalysisActiveProvider.notifier).set(false);
      final currentPath = ref.read(currentPathProvider);
      ref.invalidate(directoryAnalysisProvider(currentPath));
      ref.invalidate(analysisCurrentPathProvider(currentPath));
      ref.invalidate(displayedItemsProvider(currentPath));
      ref.invalidate(typeFilterProvider);
      ref.invalidate(sizeFilterProvider);
      ref.invalidate(extensionFilterProvider);
      return;
    }

    ref.read(isSearchActiveProvider.notifier).set(false);
    ref.read(selectionProvider.notifier).deselectAll();
    ref.read(navigationProvider.notifier).goBack();
  }

  void _goForward() {
    if (ref.read(previewFileProvider) != null) return;

    ref.read(isSearchActiveProvider.notifier).set(false);
    ref.read(selectionProvider.notifier).deselectAll();
    ref.read(navigationProvider.notifier).goForward();
  }

  ContextMenuItem _buildSortItem(
    String title,
    SortOption option,
    String tabId,
  ) {
    final tab = ref
        .read(tabManagerProvider)
        .tabs
        .firstWhere((t) => t.id == tabId);
    final currentSort = tab.sortSettings.option;
    return ContextMenuItem(
      title: title,
      isSelected: currentSort == option,
      onTap: () {
        ref
            .read(tabManagerProvider.notifier)
            .updateSortSettings(tabId, SortSettings(option: option));
      },
    );
  }

  void _selectAll() {
    final items = ref.read(filteredDirectoryItemsProvider).value ?? [];
    ref
        .read(selectionProvider.notifier)
        .selectAll(
          items.map((i) => i.path).toList(),
        );
  }

  void _handleCopy() {
    final selection = ref.read(selectionProvider);
    if (selection.selectedPaths.isNotEmpty) {
      ref
          .read(clipboardProvider.notifier)
          .copy(selection.selectedPaths.toList());
    }
  }

  void _handleCut() {
    final selection = ref.read(selectionProvider);
    if (selection.selectedPaths.isNotEmpty) {
      ref
          .read(clipboardProvider.notifier)
          .cut(selection.selectedPaths.toList());
    }
  }

  void _handleCompress() {
    final selection = ref.read(selectionProvider);
    if (selection.selectedPaths.isEmpty) return;

    final currentDir = ref.read(currentPathProvider);
    ref
        .read(archiveProvider.notifier)
        .compressItems(context, selection.selectedPaths.toList(), currentDir);
  }

  Future<void> _handlePaste() async { 
    final clipboard = ref.read(clipboardProvider);
    if (clipboard.paths.isEmpty) return;

    final targetDir = ref.read(currentPathProvider);
    final repo = ref.read(directoryRepositoryProvider);

    // Phase 1: Pre-check all items for conflicts and resolve them
    final operations = <_PasteOperation>[];
    ref.read(conflictProvider.notifier).clearGlobalResolution();

    for (final source in clipboard.paths) {
      final name = p.basename(source);
      final destPath = p.join(targetDir, name);
      final absSource = p.canonicalize(source);
      final absDest = p.canonicalize(destPath);
      final isFolder = Directory(source).existsSync();
      final typeStr = isFolder ? 'folder' : 'file';

      // 1. Circular reference check
      if (absDest.startsWith(absSource + p.separator)) {
        await showDialog<dynamic>(
          context: context,
          builder: (context) => ErrorDialog(
            title: 'You cannot copy a $typeStr into itself.',
            message: 'The destination is inside the source $typeStr.',
          ),
        );
        continue;
      }

      // 2. Parent-child overwrite check
      if (absSource.startsWith(absDest + p.separator)) {
        await showDialog<dynamic>(
          context: context,
          builder: (context) => ErrorDialog(
            title:
                'You cannot ${clipboard.isCut ? "move" : "copy"} a $typeStr over itself.',
            message:
                'The source $typeStr would be overwritten by the destination.',
          ),
        );
        continue;
      }

      // 3. Same path check
      if (absSource == absDest && clipboard.isCut) {
        await showDialog<dynamic>(
          context: context,
          builder: (context) => ErrorDialog(
            title: 'You cannot move a $typeStr over itself.',
            message:
                'The source $typeStr would be overwritten by the destination.',
          ),
        );
        continue;
      }

      // 4. Conflict check
      var finalDestPath = destPath;
      if (File(destPath).existsSync() || Directory(destPath).existsSync()) {
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
        } else if (resolution == ConflictResolution.replace &&
            (absSource == absDest ||
                absSource.startsWith(absDest + p.separator))) {
          await showDialog<dynamic>(
            context: context,
            builder: (context) => ErrorDialog(
              title: 'You cannot copy a $typeStr over itself.',
              message:
                  'The source $typeStr would be overwritten by the destination.',
            ),
          );
          continue;
        } else if (resolution == ConflictResolution.rename) {
          final ext = p.extension(name);
          final base = p.basenameWithoutExtension(name);
          var counter = 1;
          var newName = '$base($counter)$ext';
          while (File(p.join(targetDir, newName)).existsSync() ||
              Directory(p.join(targetDir, newName)).existsSync()) {
            counter++;
            newName = '$base($counter)$ext';
          }
          finalDestPath = p.join(targetDir, newName);
        }
      }

      // 5. Size calculation
      var size = 0;
      final stat = FileStat.statSync(source);
      if (stat.type == FileSystemEntityType.directory) {
        size = _getDirectorySizeSync(source);
      } else {
        size = stat.size;
      }

      operations.add(
        _PasteOperation(
          source: source,
          target: finalDestPath,
          name: name,
          size: size,
        ),
      );
    }

    if (operations.isEmpty) return;

    // Phase 2: Start background task for resolved operations
    final taskId = ref
        .read(taskProvider.notifier)
        .addTask(
          title: clipboard.isCut ? 'Moving Files' : 'Copying Files',
          subtitle: '${operations.length} items to ${p.basename(targetDir)}',
          totalCount: operations.length,
          sourcePaths: operations.map((o) => o.source).toList(),
          targetPath: targetDir,
        );

    final totalSizeBytes = operations.fold(0, (sum, o) => sum + o.size);
    ref.read(taskProvider.notifier).updateByteCounts(taskId, 0, totalSizeBytes);

    var totalBytesProcessed = 0;

    try {
      // Clear selection before starting
      if (ref.read(currentPathProvider) == targetDir) {
        ref.read(selectionProvider.notifier).deselectAll();
      }

      for (var i = 0; i < operations.length; i++) {
        if (ref.read(taskProvider.notifier).isTaskCancelled(taskId)) break;

        final op = operations[i];
        final operationVerb = clipboard.isCut ? 'Moving' : 'Copying';
        ref
            .read(taskProvider.notifier)
            .addLog(taskId, '$operationVerb ${op.name}...');
        ref.read(taskProvider.notifier).updateCurrentItem(taskId, op.name);

        var lastItemBytesProcessed = 0;

        void onProgress(int bytesCopied) {
          final delta = bytesCopied - lastItemBytesProcessed;
          lastItemBytesProcessed = bytesCopied;
          totalBytesProcessed += delta;

          ref
              .read(taskProvider.notifier)
              .updateByteCounts(taskId, totalBytesProcessed, totalSizeBytes);
          if (totalSizeBytes > 0) {
            ref
                .read(taskProvider.notifier)
                .updateProgress(taskId, totalBytesProcessed / totalSizeBytes);
          }
        }

        // Only signal the syncing phase for the very last operation in the batch.
        // For earlier files, the task is still actively processing more items.
        final isLastOperation = i == operations.length - 1;
        void onSyncing() {
          if (isLastOperation) {
            ref.read(taskProvider.notifier).setSyncing(taskId);
            ref
                .read(taskProvider.notifier)
                .addLog(taskId, 'Syncing to disk...');
          }
        }

        if (clipboard.isCut) {
          await repo.moveItemTo(
            op.source,
            op.target,
            onProgress: onProgress,
            onSyncing: onSyncing,
            taskId: taskId,
            onPort: (port, isolate) => ref
                .read(taskProvider.notifier)
                .registerPort(taskId, port, isolate: isolate),
          );
        } else {
          // Trigger a refresh at the start to show the file as soon as it's created
          if (ref.read(currentPathProvider) == targetDir) {
            ref.read(directoryItemsProvider.notifier).refresh();
          }
          await repo.copyItemTo(
            op.source,
            op.target,
            onProgress: onProgress,
            onSyncing: onSyncing,
            taskId: taskId,
            onPort: (port, isolate) => ref
                .read(taskProvider.notifier)
                .registerPort(taskId, port, isolate: isolate),
          );
        }

        ref.read(taskProvider.notifier).addLog(taskId, 'Completed: ${op.name}');

        if (ref.read(currentPathProvider) == targetDir) {
          ref.read(selectionProvider.notifier).select(op.target);
          // Refresh after each item to show progress in the gallery
          await ref.read(directoryItemsProvider.notifier).refresh();
          // Force UI rebuild
          ref.read(refreshCountProvider.notifier).state++;
        }

        ref
            .read(taskProvider.notifier)
            .updateItemCounts(taskId, i + 1, operations.length);
        ref
            .read(taskProvider.notifier)
            .updateProgress(taskId, (i + 1) / operations.length);
      }

      ref.read(taskProvider.notifier).completeTask(taskId);

      if (clipboard.isCut) {
        ref.read(clipboardProvider.notifier).clear();
      }
    } catch (e) {
      ref.read(taskProvider.notifier).addLog(taskId, 'ERROR: $e');
      ref.read(taskProvider.notifier).failTask(taskId, e.toString());
    }
  }

  Future<void> _handleDelete({required bool permanent}) async {
    final selection = ref.read(selectionProvider);
    if (selection.selectedPaths.isEmpty) return;

    final currentPath = ref.read(currentPathProvider);

    // If we are in trash, every delete is permanent
    final isDeletingFromTrash =
        currentPath.contains('.local/share/Trash/files') ||
        currentPath.endsWith('Trash/files') ||
        currentPath == 'trash:///';
    final effectivelyPermanent = permanent || isDeletingFromTrash;

    var confirmed = false;
    if (effectivelyPermanent) {
      // Calculate detailed stats for the confirmation dialog
      final stats = await _calculateSelectionStats(
        selection.selectedPaths.toList(),
      );

      if (!mounted) return;

      confirmed =
          await showDialog<bool>(
            context: context,
            builder: (context) => PermanentDeleteDialog(
              filesCount: stats.filesCount,
              foldersCount: stats.foldersCount,
              totalSize: StringUtils.formatBytes(stats.size),
            ),
          ) ??
          false;
    } else {
      confirmed = true;
    }

    if (!confirmed) return;

    final paths = selection.selectedPaths.toList();
    final taskId = ref
        .read(taskProvider.notifier)
        .addTask(
          title: effectivelyPermanent
              ? 'Deleting ${paths.length} items'
              : 'Moving ${paths.length} items to Trash',
          subtitle: effectivelyPermanent ? 'Permanent deletion' : 'Trash',
          sourcePaths: paths,
          isLight: true,
        );

    final repo = ref.read(directoryRepositoryProvider);
    try {
      if (effectivelyPermanent) {
        await repo.deleteItems(
          paths,
          permanent: true,
          taskId: taskId,
          onLog: (msg) => ref.read(taskProvider.notifier).addLog(taskId, msg),
          onProgress: (p, t) {
            ref.read(taskProvider.notifier).updateProgress(taskId, p / t);
            ref.read(taskProvider.notifier).updateItemCounts(taskId, p, t);
          },
        );
      } else {
        try {
          await repo.trashItems(
            paths,
            taskId: taskId,
            onLog: (msg) => ref.read(taskProvider.notifier).addLog(taskId, msg),
            onProgress: (p, t) {
              ref.read(taskProvider.notifier).updateProgress(taskId, p / t);
              ref.read(taskProvider.notifier).updateItemCounts(taskId, p, t);
            },
          );
        } catch (e) {
          ref.read(taskProvider.notifier).failTask(taskId, e.toString());
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'System trash utility not found. Use Shift+Delete.',
              ),
              backgroundColor: AppColors.error,
            ),
          );
          return;
        }
      }
      ref.read(taskProvider.notifier).completeTask(taskId);
      ref.read(selectionProvider.notifier).deselectAll();
      ref.read(directoryItemsProvider.notifier).refresh();
      ref.read(settingsProvider.notifier).cleanupFolderSorts(paths);
    } catch (e) {
      debugPrint('Delete error: $e');
    }
  }

  void _toggleHiddenFiles() {
    final current = ref.read(settingsProvider).value;
    if (current != null) {
      ref
          .read(settingsProvider.notifier)
          .setShowHiddenFiles(
            value: !current.showHiddenFiles,
          );
    }
  }

  void _toggleAnalysis() {
    ref.read(isAnalysisActiveProvider.notifier).toggle();
  }

  Future<void> _handleEmptyTrash() async {
    final currentPath = ref.read(currentPathProvider);
    final isInTrash =
        currentPath.contains('.local/share/Trash/files') ||
        currentPath.endsWith('Trash/files') ||
        currentPath == 'trash:///';
    if (!isInTrash) return;

    final items = ref.read(filteredDirectoryItemsProvider).value ?? [];
    if (items.isEmpty) return;

    final allPaths = items.map((e) => e.path).toList();
    final stats = await _calculateSelectionStats(allPaths);

    if (!mounted) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => PermanentDeleteDialog(
            filesCount: stats.filesCount,
            foldersCount: stats.foldersCount,
            totalSize: StringUtils.formatBytes(stats.size),
          ),
        ) ??
        false;

    if (!confirmed) return;

    final taskId = ref
        .read(taskProvider.notifier)
        .addTask(
          title: 'Emptying Trash',
          subtitle: 'Permanent deletion',
          sourcePaths: allPaths,
          isLight: true,
        );

    final repo = ref.read(directoryRepositoryProvider);
    try {
      await repo.deleteItems(
        allPaths,
        permanent: true,
        taskId: taskId,
        onLog: (msg) => ref.read(taskProvider.notifier).addLog(taskId, msg),
        onProgress: (p, t) {
          ref.read(taskProvider.notifier).updateProgress(taskId, p / t);
          ref.read(taskProvider.notifier).updateItemCounts(taskId, p, t);
        },
      );
      ref.read(taskProvider.notifier).completeTask(taskId);
      ref.read(selectionProvider.notifier).deselectAll();
      ref.read(directoryItemsProvider.notifier).refresh();
    } catch (e) {
      debugPrint('Empty trash error: $e');
      ref.read(taskProvider.notifier).failTask(taskId, e.toString());
    }
  }

  Future<void> _onF2Pressed() async {
    final selection = ref.read(selectionProvider);
    if (selection.selectedPaths.isEmpty) return;

    Offset? anchorPosition;
    final itemKeys = ref.read(itemKeysProvider);

    if (selection.selectedPaths.length == 1) {
      final path = selection.selectedPaths.first;
      final key = itemKeys[path];
      if (key?.currentContext != null) {
        final box = key!.currentContext!.findRenderObject()! as RenderBox;
        anchorPosition = box.localToGlobal(
          Offset(box.size.width / 2, box.size.height),
        );
      } else {
        debugPrint(
          '[GalleryPage] Anchor key not found or context null for: $path. Map size: ${itemKeys.length}',
        );
      }
    } else {
      var minX = double.infinity;
      var minY = double.infinity;
      var maxX = -double.infinity;
      var maxY = -double.infinity;
      var foundAny = false;

      for (final path in selection.selectedPaths) {
        final key = itemKeys[path];
        if (key?.currentContext != null) {
          final box = key!.currentContext!.findRenderObject()! as RenderBox;
          final pos = box.localToGlobal(Offset.zero);
          minX = min(minX, pos.dx);
          minY = min(minY, pos.dy);
          maxX = max(maxX, pos.dx + box.size.width);
          maxY = max(maxY, pos.dy + box.size.height);
          foundAny = true;
        }
      }

      if (foundAny) {
        anchorPosition = Offset((minX + maxX) / 2, maxY);
      }
    }

    if (selection.selectedPaths.length == 1 && anchorPosition != null) {
      final existingItems =
          ref.read(filteredDirectoryItemsProvider).value ?? [];
      final existingNames = existingItems.map((i) => i.name).toList();

      RenamePopover.show(
        context: context,
        position: anchorPosition,
        paths: selection.selectedPaths.toList(),
        existingNames: existingNames,
        onClose: () => _focusNode.requestFocus(),
        onRename: (result) async {
          final repo = ref.read(directoryRepositoryProvider);
          try {
            if (result is String) {
              final oldPath = selection.selectedPaths.first;
              final taskId = ref
                  .read(taskProvider.notifier)
                  .addTask(
                    title: 'Renaming item',
                    subtitle: '${p.basename(oldPath)} -> $result',
                    sourcePaths: [oldPath],
                    isLight: true,
                  );
              try {
                final newPath = await repo.renameItem(
                  oldPath,
                  result,
                  taskId: taskId,
                  onLog: (msg) =>
                      ref.read(taskProvider.notifier).addLog(taskId, msg),
                );
                ref.read(selectionProvider.notifier).deselectAll();
                ref.read(selectionProvider.notifier).selectMultiple([newPath]);
                ref.read(taskProvider.notifier).completeTask(taskId);
              } catch (e) {
                ref.read(taskProvider.notifier).failTask(taskId, e.toString());
                rethrow;
              }
            }
            ref.read(directoryItemsProvider.notifier).refresh();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Error renaming: $e')));
            }
          } finally {
            _focusNode.requestFocus();
          }
        },
      );
    } else {
      // Bulk rename or fallback: Centered Dialog
      final result = await showDialog<dynamic>(
        context: context,
        builder: (context) =>
            RenameDialog(paths: selection.selectedPaths.toList()),
      );

      if (result == null) {
        _focusNode.requestFocus();
        return;
      }

      final repo = ref.read(directoryRepositoryProvider);
      try {
        if (result is String) {
          final oldPath = selection.selectedPaths.first;
          final taskId = ref
              .read(taskProvider.notifier)
              .addTask(
                title: 'Renaming item',
                subtitle: '${p.basename(oldPath)} -> $result',
                sourcePaths: [oldPath],
                isLight: true,
              );
          try {
            final newPath = await repo.renameItem(
              oldPath,
              result,
              taskId: taskId,
              onLog: (msg) =>
                  ref.read(taskProvider.notifier).addLog(taskId, msg),
            );
            ref.read(selectionProvider.notifier).deselectAll();
            ref.read(selectionProvider.notifier).selectMultiple([newPath]);
            ref.read(taskProvider.notifier).completeTask(taskId);
          } catch (e) {
            ref.read(taskProvider.notifier).failTask(taskId, e.toString());
            rethrow;
          }
        } else if (result is Map) {
          final mode = result['mode'] as RenameMode;
          final value = result['value'] as String;
          var newPaths = <String>[];
          final paths = selection.selectedPaths.toList();
          final taskId = ref
              .read(taskProvider.notifier)
              .addTask(
                title: 'Bulk renaming ${paths.length} items',
                subtitle: mode == RenameMode.prefix
                    ? 'Prefix: $value'
                    : 'Index: $value',
                sourcePaths: paths,
                isLight: true,
              );

          try {
            if (mode == RenameMode.prefix) {
              newPaths = await repo.bulkRename(
                paths,
                prefix: value,
                taskId: taskId,
                onLog: (msg) =>
                    ref.read(taskProvider.notifier).addLog(taskId, msg),
              );
            } else {
              newPaths = await repo.bulkRename(
                paths,
                baseName: value,
                taskId: taskId,
                onLog: (msg) =>
                    ref.read(taskProvider.notifier).addLog(taskId, msg),
              );
            }
            ref.read(taskProvider.notifier).completeTask(taskId);
          } catch (e) {
            ref.read(taskProvider.notifier).failTask(taskId, e.toString());
            rethrow;
          }
          ref.read(selectionProvider.notifier).deselectAll();
          ref.read(selectionProvider.notifier).selectMultiple(newPaths);
        }
        ref.read(directoryItemsProvider.notifier).refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error renaming: $e')));
        }
      } finally {
        _focusNode.requestFocus();
      }
    }
  }

  Future<void> _handleNewItem({bool initialIsFolder = true}) async {
    final currentPath = ref.read(currentPathProvider);
    final items = ref.read(filteredDirectoryItemsProvider).value ?? [];
    final existingNames = items.map((i) => i.name).toList();

    final result = await CreateItemDialog.show(
      context: context,
      currentPath: currentPath,
      existingNames: existingNames,
      initialIsFolder: initialIsFolder,
    );

    if (result != null && result.contains(':')) {
      final parts = result.split(':');
      final type = parts[0];
      final name = parts[1];

      final taskId = ref
          .read(taskProvider.notifier)
          .addTask(
            title: type == 'folder' ? 'New Folder' : 'New Document',
            subtitle: name,
            isLight: true,
          );

      final repo = ref.read(directoryRepositoryProvider);
      final newItemPath = p.join(currentPath, name);

      try {
        if (type == 'folder') {
          await repo.createFolder(currentPath, name, taskId: taskId);
        } else {
          await repo.createFile(currentPath, name, taskId: taskId);
        }

        ref.read(taskProvider.notifier).completeTask(taskId);
        await ref.read(directoryItemsProvider.notifier).refresh();
        // Auto-select the new item
        ref.read(selectionProvider.notifier).selectMultiple([newItemPath]);
      } catch (e) {
        ref.read(taskProvider.notifier).failTask(taskId, e.toString());
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error creating $type: $e')));
        }
      }
    }
    _focusNode.requestFocus();
  }

  Future<DirectorySizeUpdate> _calculateSelectionStats(
    List<String> paths,
  ) async {
    final receivePort = ReceivePort();
    try {
      await Isolate.spawn(
        calculateDirectorySizeIncremental,
        DirectorySizeArgs(
          paths: paths,
          sendPort: receivePort.sendPort,
        ),
      );

      final result = await receivePort.firstWhere(
        (m) => m is DirectorySizeUpdate && m.isFinished,
      );
      return result as DirectorySizeUpdate;
    } finally {
      receivePort.close();
    }
  }

  void _zoom(double delta) {
    final path = ref.read(currentPathProvider);
    final zooms = Map<String, double>.from(ref.read(zoomProvider));
    final current = zooms[path] ?? 0.8;
    zooms[path] = (current + delta).clamp(0.5, 2.0);
    ref.read(zoomProvider.notifier).state = zooms;
  }

  void _resetZoom() {
    final path = ref.read(currentPathProvider);
    final zooms = Map<String, double>.from(ref.read(zoomProvider));
    zooms[path] = 0.8;
    ref.read(zoomProvider.notifier).state = zooms;
  }
}

class _PasteOperation {
  _PasteOperation({
    required this.source,
    required this.target,
    required this.name,
    required this.size,
  });
  final String source;
  final String target;
  final String name;
  final int size;
}
