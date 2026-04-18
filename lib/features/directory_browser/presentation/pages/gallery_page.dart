import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/action_bar.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/dialogs.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/file_grid.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sidebar/sidebar.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/preview_container.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sidebar/sidebar.dart';
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
