import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';

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

/// Main gallery page — slim orchestrator that composes all widgets.
class GalleryPage extends ConsumerStatefulWidget {
  const GalleryPage({super.key});

  @override
  ConsumerState<GalleryPage> createState() => _GalleryPageState();
}

class _GalleryPageState extends ConsumerState<GalleryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String currentPath = ref.read(currentPathProvider);
      ref.read(navigationProvider.notifier).initialize(currentPath);
      _setupReverseIpc();
    });
  }

  @override
  void dispose() {
    _clearReverseIpc();
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
          final String direction = data['direction'];
          final String currentPath = data['currentPath'];
          final String typeStr = data['type'] as String;
          final String targetWindowId = data['targetWindowId'].toString();
          
          final self = await WindowController.fromCurrentEngine();
          final String selfId = self.windowId;

          final items = ref.read(directoryItemsProvider).value ?? [];
          if (items.isEmpty) return 'error: no items';

          // Filter by requested media type
          final targetType = typeStr == 'video' ? FileItemType.video : FileItemType.image;
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
    final previewFile = ref.watch(previewFileProvider);

    return CallbackShortcuts(
      bindings: _buildKeyBindings(),
      child: Focus(
        autofocus: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            ref.read(selectionProvider.notifier).deselectAll();
            // Optional: clicking background also closes preview?
            // ref.read(previewFileProvider.notifier).state = null;
          },
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: Row(
              children: [
                const Sidebar(),
                Expanded(
                  child: Column(
                    children: [
                      const TopBar(),
                      Expanded(
                        child: previewFile != null
                            ? PreviewContainer(item: previewFile)
                            : Column(
                                children: const [
                                  ActionBar(),
                                  Expanded(child: FileGrid()),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _buildKeyBindings() {
    return {
      const SingleActivator(LogicalKeyboardKey.backspace): _goBack,
      const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): _goBack,
      const SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): _goForward,
      const SingleActivator(LogicalKeyboardKey.escape): () =>
          ref.read(selectionProvider.notifier).deselectAll(),
      const SingleActivator(LogicalKeyboardKey.keyA, control: true): _selectAll,
      const SingleActivator(LogicalKeyboardKey.delete): () =>
          _handleDelete(permanent: false),
      const SingleActivator(LogicalKeyboardKey.delete, shift: true): () =>
          _handleDelete(permanent: true),
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
    if (permanent) {
      await repo.deleteItems(
        selection.selectedPaths.toList(),
        permanent: true,
      );
    } else {
      await repo.moveToTrash(selection.selectedPaths.toList());
    }

    ref.read(selectionProvider.notifier).deselectAll();
    await ref.read(directoryItemsProvider.notifier).refresh();
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
