import 'dart:ui';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:path/path.dart' as p;

import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/action_bar.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/dialogs.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/file_grid.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sidebar/sidebar.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/preview_container.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/top_bar.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/clipboard_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/rubber_band_overlay.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/rename_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/rename_popover.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/conflict_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/error_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/properties_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/context_menu.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/conflict_provider.dart';
import 'package:onyxcore/core/widgets/task_progress_overlay.dart';

/// Main gallery page — slim orchestrator that composes all widgets.
class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key});

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage> with WidgetsBindingObserver {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _focusNode = ref.read(mainFocusNodeProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String currentPath = ref.read(currentPathProvider);
      ref.read(navigationProvider.notifier).initialize(currentPath);
      _setupReverseIpc();
      _focusNode.requestFocus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached || state == AppLifecycleState.hidden) {
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

  void _clearReverseIpc() async {
    try {
      final controller = await WindowController.fromCurrentEngine();
      controller.setWindowMethodHandler(null);
    } catch (e) {
      debugPrint('[Main] Error clearing IPC handler: $e');
    }
  }

  void _setupReverseIpc() async {
    final controller = await WindowController.fromCurrentEngine();
    controller.setWindowMethodHandler((call) async {
      if (call.method == 'request_navigation') {
        debugPrint('[Main] Navigation request received: ${call.arguments}');
        try {
          final data = jsonDecode(call.arguments as String);
          final direction = data['direction'] as String;
          final currentPath = data['currentPath'] as String;
          final String typeStr = data['type'] as String;
          final String targetWindowId = data['targetWindowId'].toString();
          
          final self = await WindowController.fromCurrentEngine();
          final String selfId = self.windowId;

          final repo = ref.read(directoryRepositoryProvider);
          final items = await repo.listDirectory(p.dirname(currentPath));
          if (items.isEmpty) return 'error: no items';

          // Filter by requested media type
          final targetType = typeStr == 'video' 
              ? FileItemType.video 
              : (typeStr == "document" ? FileItemType.document : FileItemType.image);
          final mediaItems = items.where((i) => i.type == targetType).toList();
      
          if (mediaItems.isEmpty) return 'error: no media items';

          final currentIndex = mediaItems.indexWhere((i) => i.path == currentPath);
          if (currentIndex == -1) return 'error: current item not found';

          int nextIndex;
          if (direction == 'next') {
            nextIndex = (currentIndex + 1) % mediaItems.length;
          } else {
            nextIndex = (currentIndex - 1 + mediaItems.length) % mediaItems.length;
          }

          final nextItem = mediaItems[nextIndex];
          
          // Command the sub-window to load the new item
          final params = WindowParams(
            viewerType: nextItem.type == FileItemType.video ? ViewerType.video : ViewerType.image,
            file: nextItem,
            parentWindowId: selfId,
          );

          await WindowController.fromWindowId(targetWindowId).invokeMethod('load_media', params.toJson());
          return 'ok';
        } catch (e) {
          debugPrint('[Main] IPC Navigation Error: $e');
          return 'error: $e';
        }
      }
      return null;
    });
  }  @override
  Widget build(BuildContext context) {
    // Watch search state at the top level to ensure rebuilds of shortcuts
    final isSearchActive = ref.watch(isSearchActiveProvider);
    final isLocationEditing = ref.watch(isLocationEditingProvider);
    
    return CallbackShortcuts(
      bindings: _buildKeyBindings(isSearchActive, isLocationEditing),
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
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              _focusNode.requestFocus();
              ref.read(selectionProvider.notifier).deselectAll();
            },
            onSecondaryTapUp: (details) {
              _focusNode.requestFocus();
              ref.read(selectionProvider.notifier).deselectAll();
              ContextMenu.show(context, details.globalPosition, [
                ContextMenuItem(
                  title: 'New Folder',
                  icon: Icons.create_new_folder_rounded,
                  shortcut: 'Ctrl+Shift+N',
                  onTap: _handleNewFolder,
                ),
                ContextMenuItem(
                  title: 'New Document',
                  icon: Icons.note_add_rounded,
                  onTap: () {
                    // TODO: Implement new document
                  },
                ),
                ContextMenuItem(
                  title: 'Paste',
                  icon: Icons.paste_rounded,
                  shortcut: 'Ctrl+V',
                  onTap: _handlePaste,
                ),
                ContextMenuItem(
                  title: 'Properties',
                  icon: Icons.info_outline_rounded,
                  onTap: _showProperties,
                ),
              ]);
            },
            child: Scaffold(
              backgroundColor: AppColors.background,
              body: Stack(
                children: [
                  Row(
                    children: [
                      const Sidebar(),
                      Expanded(
                        child: Column(
                          children: [
                            const TopBar(),
                            _buildContent(),
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
                              onAccept: (_) {
                                ref.read(isDraggingProvider.notifier).state = false;
                              },
                              builder: (context, candidateData, rejectedData) {
                                final isOver = candidateData.isNotEmpty;
                                return ClipOval(
                                  clipBehavior: Clip.antiAliasWithSaveLayer,
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: isOver 
                                            ? Colors.red.withOpacity(0.6) 
                                            : Colors.white.withOpacity(0.08),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isOver ? Colors.white : Colors.white10,
                                          width: 1.5, // Slightly thicker for definition
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          isOver ? Icons.delete_forever : Icons.close,
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
            ),
          ),
        ),
      ),
    );
  } 

  Widget _buildContent() {
    final previewFile = ref.watch(previewFileProvider);
    if (previewFile != null) {
      return Expanded(child: PreviewContainer(item: previewFile));
    }
    
    return Expanded(
      child: Column(
        children: [
          // const ActionBar(), // Removed panel
          Expanded(
            child: RubberBandOverlay(
              child: const FileGrid(),
            ),
          ),
        ],
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _buildKeyBindings(bool isSearchActive, bool isLocationEditing) {
    return {
      // Basic Navigation
      if (!isSearchActive && !isLocationEditing)
        const SingleActivator(LogicalKeyboardKey.backspace): _goBack,
      const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): _goBack,
      const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): _goForward,

      // Selection
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          ref.read(selectionProvider.notifier).deselectAll(),
      const SingleActivator(LogicalKeyboardKey.keyA, control: true): _selectAll,

      // Properties
      const SingleActivator(LogicalKeyboardKey.enter, alt: true): _showProperties,

      // File Operations
      const SingleActivator(LogicalKeyboardKey.keyC, control: true): _handleCopy,
      const SingleActivator(LogicalKeyboardKey.keyX, control: true): _handleCut,
      const SingleActivator(LogicalKeyboardKey.keyV, control: true): _handlePaste,
      const SingleActivator(LogicalKeyboardKey.delete): () =>
          _handleDelete(permanent: false),
      const SingleActivator(LogicalKeyboardKey.delete, shift: true): () =>
          _handleDelete(permanent: true),
      const SingleActivator(LogicalKeyboardKey.f2): _onF2Pressed,
      const SingleActivator(LogicalKeyboardKey.keyN, control: true, shift: true): _handleNewFolder,

      // Zoom
      const SingleActivator(LogicalKeyboardKey.equal, control: true): () =>
          _zoom(0.1),
      const SingleActivator(LogicalKeyboardKey.minus, control: true): () =>
          _zoom(-0.1),
      const SingleActivator(LogicalKeyboardKey.numpadAdd, control: true): () =>
          _zoom(0.1),
      const SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true):
          () => _zoom(-0.1),
      const SingleActivator(LogicalKeyboardKey.digit0, control: true):
          _resetZoom,
      
      // Global Shortcuts
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): () => _toggleSearch(!isSearchActive),
      const SingleActivator(LogicalKeyboardKey.keyR, control: true): _refresh,
      const SingleActivator(LogicalKeyboardKey.keyD, alt: true): () {
        if (!isSearchActive) {
          ref.read(isLocationEditingProvider.notifier).update((state) => !state);
        }
      },

      // Item Opening
      if (!isLocationEditing) ...{
        const SingleActivator(LogicalKeyboardKey.enter): _handleEnter,
        const SingleActivator(LogicalKeyboardKey.numpadEnter): _handleEnter,
      },
    };
  }

  void _toggleSearch(bool active) {
    if (active) {
      ref.read(isLocationEditingProvider.notifier).state = false;
    }
    ref.read(isSearchActiveProvider.notifier).state = active;
  }

  void _refresh() async {
    debugPrint("Refresh triggered via Ctrl+R");
    final currentPath = ref.read(currentPathProvider);
    ref.read(directoryRepositoryProvider).invalidateCache(currentPath);
    ref.read(refreshCountProvider.notifier).update((state) => state + 1);
    ref.read(isRefreshingProvider.notifier).state = true;
    ref.read(directoryItemsProvider.notifier).refresh();
    // Subtle blink duration
    await Future.delayed(const Duration(milliseconds: 150));
    ref.read(isRefreshingProvider.notifier).state = false;
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
    } else if (item.type == FileItemType.image || 
               item.type == FileItemType.video || 
               item.type == FileItemType.document) {
      ref.read(previewFileProvider.notifier).state = item;
    }
  }

  void _showProperties() {
    final selection = ref.read(selectionProvider);
    final paths = selection.selectedPaths.isEmpty 
        ? [ref.read(currentPathProvider)]
        : selection.selectedPaths.toList();

    showDialog(
      context: context,
      builder: (context) => PropertiesDialog(paths: paths),
    );
  }

  void _goBack() {
    ref.read(isSearchActiveProvider.notifier).state = false;
    ref.read(selectionProvider.notifier).deselectAll();
    ref.read(navigationProvider.notifier).goBack();
    final nav = ref.read(navigationProvider);
    if (nav.currentPath.isNotEmpty) {
      ref.read(currentPathProvider.notifier).state = nav.currentPath;
    }
  }

  void _goForward() {
    ref.read(isSearchActiveProvider.notifier).state = false;
    ref.read(selectionProvider.notifier).deselectAll();
    ref.read(navigationProvider.notifier).goForward();
    final nav = ref.read(navigationProvider);
    if (nav.currentPath.isNotEmpty) {
      ref.read(currentPathProvider.notifier).state = nav.currentPath;
    }
  }

  void _selectAll() {
    final items = ref.read(filteredDirectoryItemsProvider).value ?? [];
    ref.read(selectionProvider.notifier).selectAll(
      items.map((i) => i.path).toList(),
    );
  }

  void _handleCopy() {
    final selection = ref.read(selectionProvider);
    if (selection.selectedPaths.isNotEmpty) {
      ref.read(clipboardProvider.notifier).copy(selection.selectedPaths.toList());
    }
  }

  void _handleCut() {
    final selection = ref.read(selectionProvider);
    if (selection.selectedPaths.isNotEmpty) {
      ref.read(clipboardProvider.notifier).cut(selection.selectedPaths.toList());
    }
  }

  void _handlePaste() async {
    final clipboard = ref.read(clipboardProvider);
    if (clipboard == null || clipboard.paths.isEmpty) return;

    final targetDir = ref.read(currentPathProvider);
    final repo = ref.read(directoryRepositoryProvider);

    final String taskId = ref.read(taskProvider.notifier).addTask(
      title: clipboard.isCut ? 'Moving Files' : 'Copying Files',
      subtitle: '${clipboard.paths.length} items to ${p.basename(targetDir)}',
    );

    try {
      // Clear selection before starting to ensure only new items are selected
      if (ref.read(currentPathProvider) == targetDir) {
        ref.read(selectionProvider.notifier).deselectAll();
      }

      for (int i = 0; i < clipboard.paths.length; i++) {
        if (ref.read(taskProvider.notifier).isTaskCancelled(taskId)) break;

        final source = clipboard.paths[i];
        final name = p.basename(source);
        final destPath = p.join(targetDir, name);
        final absSource = p.canonicalize(source);
        final absDest = p.canonicalize(destPath);
        final isFolder = Directory(source).existsSync();
        final typeStr = isFolder ? 'folder' : 'file';
        
        // Circular reference check: cannot copy/move a folder into one of its subdirectories
        if (absDest.startsWith(absSource + p.separator)) {
          await showDialog(
            context: context,
            builder: (context) => ErrorDialog(
              title: 'You cannot copy a $typeStr into itself.',
              message: 'The destination is inside the source $typeStr.',
            ),
          );
          continue;
        }

        // Parent-child overwrite check: cannot copy/move an item over one of its own parents
        // e.g. moving /root/new/new into /root where /root/new exists.
        if (absSource.startsWith(absDest + p.separator)) {
          await showDialog(
            context: context,
            builder: (context) => ErrorDialog(
              title: 'You cannot ${clipboard.isCut ? "move" : "copy"} a $typeStr over itself.',
              message: 'The source $typeStr would be overwritten by the destination.',
            ),
          );
          continue;
        }

        // Same path check
        if (absSource == absDest && clipboard.isCut) {
          await showDialog(
            context: context,
            builder: (context) => ErrorDialog(
              title: 'You cannot move a $typeStr over itself.',
              message: 'The source $typeStr would be overwritten by the destination.',
            ),
          );
          continue;
        }

        ConflictResolution? resolution;
        String finalDestPath = destPath;

        if (File(destPath).existsSync() || Directory(destPath).existsSync()) {
          resolution = await ref.read(conflictProvider.notifier).resolveConflict(
            fileName: name,
            destinationPath: destPath,
            isFolder: isFolder,
            context: context,
          );

          if (resolution == ConflictResolution.skip) {
            continue;
          } else if (resolution == ConflictResolution.replace && (absSource == absDest || absSource.startsWith(absDest + p.separator))) {
            await showDialog(
              context: context,
              builder: (context) => ErrorDialog(
                title: 'You cannot copy a $typeStr over itself.',
                message: 'The source $typeStr would be overwritten by the destination.',
              ),
            );
            continue;
          } else if (resolution == ConflictResolution.rename) {
            final ext = p.extension(name);
            final base = p.basenameWithoutExtension(name);
            var counter = 1;
            var newName = "$base($counter)$ext";
            while (File(p.join(targetDir, newName)).existsSync() || 
                   Directory(p.join(targetDir, newName)).existsSync()) {
              counter++;
              newName = "$base($counter)$ext";
            }
            finalDestPath = p.join(targetDir, newName);
          }
        }

        if (clipboard.isCut) {
          await repo.moveItemTo(source, finalDestPath);
        } else {
          await repo.copyItemTo(source, finalDestPath);
        }

        // Select the newly pasted item if we are still in the destination folder
        if (ref.read(currentPathProvider) == targetDir) {
          ref.read(selectionProvider.notifier).select(finalDestPath);
        }

        ref.read(taskProvider.notifier).updateProgress(taskId, (i + 1) / clipboard.paths.length);
      }

      ref.read(taskProvider.notifier).completeTask(taskId);
      ref.read(directoryItemsProvider.notifier).refresh();
      if (clipboard.isCut) {
        ref.read(clipboardProvider.notifier).clear();
      }
    } catch (e) {
      ref.read(taskProvider.notifier).failTask(taskId, e.toString());
    }
  }

  Future<void> _handleDelete({required bool permanent}) async {
    final selection = ref.read(selectionProvider);
    if (selection.selectedPaths.isEmpty) return;

    final currentPath = ref.read(currentPathProvider);
    final home = Platform.environment['HOME'] ?? '/';
    final trashPath = '$home/.local/share/Trash/files';
    
    // If we are in trash, every delete is permanent
    final isDeletingFromTrash = currentPath == trashPath;
    final effectivelyPermanent = permanent || isDeletingFromTrash;
    
    final count = selection.selectedPaths.length;
    bool confirmed = false;
    if (effectivelyPermanent) {
      confirmed = await showVibrantConfirmDialog(
        context: context,
        title: 'Delete Permanently',
        message: effectivelyPermanent && !permanent 
            ? 'Delete $count item(s) from Trash? This will permanently remove them.'
            : 'Permanently delete $count item(s)? This cannot be undone.',
        confirmLabel: 'Delete',
        confirmColor: AppColors.error,
      );
    } else {
      confirmed = true;
    }

    if (!confirmed) return;

    final repo = ref.read(directoryRepositoryProvider);
    try {
      if (effectivelyPermanent) {
        await repo.deleteItems(selection.selectedPaths.toList(), permanent: true);
      } else {
        try {
          await repo.trashItems(selection.selectedPaths.toList());
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("System trash utility not found. Use Shift+Delete."),
            backgroundColor: AppColors.error,
          ));
        }
      }
      ref.read(selectionProvider.notifier).deselectAll();
      ref.read(directoryItemsProvider.notifier).refresh();
    } catch (e) {
      debugPrint('Delete error: $e');
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
        final box = key!.currentContext!.findRenderObject() as RenderBox;
        anchorPosition = box.localToGlobal(Offset(box.size.width / 2, box.size.height));
      }
    } else {
      double minX = double.infinity, minY = double.infinity;
      double maxX = -double.infinity, maxY = -double.infinity;
      bool foundAny = false;

      for (final path in selection.selectedPaths) {
        final key = itemKeys[path];
        if (key?.currentContext != null) {
          final box = key!.currentContext!.findRenderObject() as RenderBox;
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
      final existingItems = ref.read(filteredDirectoryItemsProvider).value ?? [];
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
              final newPath = await repo.renameItem(selection.selectedPaths.first, result);
              ref.read(selectionProvider.notifier).deselectAll();
              ref.read(selectionProvider.notifier).selectMultiple([newPath]);
            }
            ref.read(directoryItemsProvider.notifier).refresh();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error renaming: $e')));
            }
          } finally {
            _focusNode.requestFocus();
          }
        },
      );
    } else {
      // Bulk rename or fallback: Centered Dialog
      final result = await showDialog(
        context: context,
        builder: (context) => RenameDialog(paths: selection.selectedPaths.toList()),
      );

      if (result == null) {
        _focusNode.requestFocus();
        return;
      }

      final repo = ref.read(directoryRepositoryProvider);
      try {
        if (result is String) {
          final newPath = await repo.renameItem(selection.selectedPaths.first, result);
          ref.read(selectionProvider.notifier).deselectAll();
          ref.read(selectionProvider.notifier).selectMultiple([newPath]);
        } else if (result is Map) {
          final mode = result['mode'] as RenameMode;
          final value = result['value'] as String;
          List<String> newPaths = [];
          if (mode == RenameMode.prefix) {
            newPaths = await repo.bulkRename(selection.selectedPaths.toList(), prefix: value);
          } else {
            newPaths = await repo.bulkRename(selection.selectedPaths.toList(), baseName: value);
          }
          ref.read(selectionProvider.notifier).deselectAll();
          ref.read(selectionProvider.notifier).selectMultiple(newPaths);
        }
        ref.read(directoryItemsProvider.notifier).refresh();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error renaming: $e')));
        }
      } finally {
        _focusNode.requestFocus();
      }
    }
  }

  Future<void> _handleNewFolder() async {
    final String currentPath = ref.read(currentPathProvider);
    final name = await showInputDialog(
      context: context,
      title: 'New Folder',
      hint: 'Folder name',
    );
    if (name != null && name.isNotEmpty) {
      final repo = ref.read(directoryRepositoryProvider);
      final newFolderPath = p.join(currentPath, name);
      await repo.createFolder(currentPath, name);
      await ref.read(directoryItemsProvider.notifier).refresh();
      // Auto-select the new folder
      ref.read(selectionProvider.notifier).selectMultiple([newFolderPath]);
    }
    _focusNode.requestFocus();
  }

  void _zoom(double delta) {
    final String path = ref.read(currentPathProvider);
    final zooms = Map<String, double>.from(ref.read(zoomProvider));
    final current = zooms[path] ?? 0.8;
    zooms[path] = (current + delta).clamp(0.5, 2.0);
    ref.read(zoomProvider.notifier).state = zooms;
  }

  void _resetZoom() {
    final String path = ref.read(currentPathProvider);
    final zooms = Map<String, double>.from(ref.read(zoomProvider));
    zooms[path] = 0.8;
    ref.read(zoomProvider.notifier).state = zooms;
  }
}
