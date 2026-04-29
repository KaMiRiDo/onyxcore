import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'dart:io';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:path/path.dart' as p;

import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
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
import 'package:onyxcore/features/directory_browser/presentation/widgets/conflict_dialog.dart';
import 'package:onyxcore/core/widgets/task_progress_overlay.dart';

/// Main gallery page — slim orchestrator that composes all widgets.
class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key});

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String currentPath = ref.read(currentPathProvider);
      ref.read(navigationProvider.notifier).initialize(currentPath);
      _setupReverseIpc();
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
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

          final items = ref.read(directoryItemsProvider).value ?? [];
          if (items.isEmpty) return 'error: no items';

          // Filter by requested media type
          final targetType = typeStr == 'video' 
              ? FileItemType.video 
              : (typeStr == 'document' ? FileItemType.document : FileItemType.image);
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
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: _buildKeyBindings(),
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _focusNode.requestFocus();
            ref.read(selectionProvider.notifier).deselectAll();
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

              ],
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
          const ActionBar(),
          Expanded(
            child: RubberBandOverlay(
              child: const FileGrid(),
            ),
          ),
        ],
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _buildKeyBindings() {
    return {
      // Basic Navigation
      const SingleActivator(LogicalKeyboardKey.backspace): _goBack,
      const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): _goBack,
      const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): _goForward,

      // Selection
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          ref.read(selectionProvider.notifier).deselectAll(),
      const SingleActivator(LogicalKeyboardKey.keyA, control: true): _selectAll,

      // File Operations
      const SingleActivator(LogicalKeyboardKey.keyC, control: true): _handleCopy,
      const SingleActivator(LogicalKeyboardKey.keyX, control: true): _handleCut,
      const SingleActivator(LogicalKeyboardKey.keyV, control: true): _handlePaste,
      const SingleActivator(LogicalKeyboardKey.delete): () =>
          _handleDelete(permanent: false),
      const SingleActivator(LogicalKeyboardKey.delete, shift: true): () =>
          _handleDelete(permanent: true),
      const SingleActivator(LogicalKeyboardKey.f2): _handleRename,
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
    };
  }

  void _goBack() {
    ref.read(selectionProvider.notifier).deselectAll();
    ref.read(navigationProvider.notifier).goBack();
    final nav = ref.read(navigationProvider);
    if (nav.currentPath.isNotEmpty) {
      ref.read(currentPathProvider.notifier).state = nav.currentPath;
    }
  }

  void _goForward() {
    ref.read(selectionProvider.notifier).deselectAll();
    ref.read(navigationProvider.notifier).goForward();
    final nav = ref.read(navigationProvider);
    if (nav.currentPath.isNotEmpty) {
      ref.read(currentPathProvider.notifier).state = nav.currentPath;
    }
  }

  void _selectAll() {
    final items = ref.read(directoryItemsProvider).value ?? [];
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

  Future<void> _handlePaste() async {
    final clipboard = ref.read(clipboardProvider);
    if (clipboard.paths.isEmpty) return;

    final targetDir = ref.read(currentPathProvider);
    final repo = ref.read(directoryRepositoryProvider);
    
    List<String> sourcesToProcess = [];
    
    for (final source in clipboard.paths) {
      final name = p.basename(source);
      final destPath = p.join(targetDir, name);
      
      if (File(destPath).existsSync() || Directory(destPath).existsSync()) {
        final resolution = await showDialog<ConflictResolution>(
          context: context,
          builder: (context) => ConflictDialog(fileName: name),
        );
        
        if (resolution == ConflictResolution.replace) {
          sourcesToProcess.add(source);
        } else if (resolution == ConflictResolution.rename) {
          final ext = p.extension(name);
          final base = p.basenameWithoutExtension(name);
          String newName = "${base}_copy$ext";
          int counter = 1;
          while (File(p.join(targetDir, newName)).existsSync()) {
            newName = "${base}_copy_$counter$ext";
            counter++;
          }
          await repo.copyItems([source], targetDir); 
        }
      } else {
        sourcesToProcess.add(source);
      }
    }

    if (sourcesToProcess.isEmpty) return;

    final taskId = ref.read(taskProvider.notifier).addTask(
      title: clipboard.type == FileOperationType.copy ? 'Copying Files' : 'Moving Files',
      subtitle: '${sourcesToProcess.length} items to ${p.basename(targetDir)}',
    );

    try {
      if (clipboard.type == FileOperationType.copy) {
        await repo.copyItems(sourcesToProcess, targetDir);
      } else {
        await repo.moveItems(sourcesToProcess, targetDir);
        ref.read(clipboardProvider.notifier).clear();
      }
      ref.read(taskProvider.notifier).completeTask(taskId);
      ref.read(directoryItemsProvider.notifier).refresh();
    } catch (e) {
      ref.read(taskProvider.notifier).failTask(taskId, e.toString());
    }
  }

  Future<void> _handleDelete({required bool permanent}) async {
    final selection = ref.read(selectionProvider);
    if (selection.selectedPaths.isEmpty) return;
    
    final count = selection.selectedPaths.length;
    final confirmed = await showVibrantConfirmDialog(
      context: context,
      title: permanent ? 'Delete Permanently' : 'Move to Trash',
      message: permanent 
          ? 'Permanently delete $count item(s)? This cannot be undone.'
          : 'Move $count item(s) to Trash?',
      confirmLabel: permanent ? 'Delete' : 'Move to Trash',
      confirmColor: permanent ? AppColors.error : AppColors.violet,
    );

    if (!confirmed) return;

    final repo = ref.read(directoryRepositoryProvider);
    try {
      if (permanent) {
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

  Future<void> _handleRename() async {
    final selection = ref.read(selectionProvider);
    if (selection.selectedPaths.isEmpty) return;

    final result = await showDialog(
      context: context,
      builder: (context) => RenameDialog(paths: selection.selectedPaths.toList()),
    );

    if (result == null) return;

    final repo = ref.read(directoryRepositoryProvider);
    try {
      if (result is String) {
        await repo.renameItem(selection.selectedPaths.first, result);
      } else if (result is Map) {
        final mode = result['mode'] as RenameMode;
        final value = result['value'] as String;
        if (mode == RenameMode.prefix) {
          await repo.bulkRename(selection.selectedPaths.toList(), prefix: value);
        } else {
          await repo.bulkRename(selection.selectedPaths.toList(), baseName: value);
        }
      }
      ref.read(selectionProvider.notifier).deselectAll();
      ref.read(directoryItemsProvider.notifier).refresh();
    } catch (e) {
      debugPrint('Rename error: $e');
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
      await repo.createFolder(currentPath, name);
      await ref.read(directoryItemsProvider.notifier).refresh();
    }
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
