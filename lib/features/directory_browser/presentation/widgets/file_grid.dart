import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_utils.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/item_card.dart';

/// Main file grid — pixel-perfect replica of original _buildMainContent().
class FileGrid extends ConsumerStatefulWidget {
  const FileGrid({super.key});

  @override
  ConsumerState<FileGrid> createState() => _FileGridState();
}

class _FileGridState extends ConsumerState<FileGrid> {
  String? _hoveredPath;

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(directoryItemsProvider);
    final zoom = ref.watch(currentZoomProvider);
    final selection = ref.watch(selectionProvider);
    final String currentPath = ref.watch(currentPathProvider);

    final content = itemsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(
          'Error: $error',
          style: const TextStyle(color: AppColors.textMuted),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          String message = 'This folder is empty';
          if (currentPath == 'virtual:recent') message = 'No recent files found';
          if (currentPath == 'virtual:starred') message = 'No starred items yet';
          return Center(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        return GridView.builder(
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
    );

    if (currentPath.startsWith('virtual:')) return content;

    return DragTarget<List<String>>(
      onWillAcceptWithDetails: (details) {
        // Can't drop if current path is virtual or if all items are already in currentPath
        return !details.data.every((path) {
          final parts = (path.endsWith('/') ? path.substring(0, path.length - 1) : path).split('/');
          final parent = parts.take(parts.length > 1 ? parts.length - 1 : 0).join('/');
          final curr = currentPath.endsWith('/') ? currentPath.substring(0, currentPath.length - 1) : currentPath;
          return parent == curr;
        });
      },
      onAcceptWithDetails: (details) async {
        final repo = ref.read(directoryRepositoryProvider);
        final taskId = ref.read(taskProvider.notifier).addTask(
          title: 'Moving Files',
          subtitle: '${details.data.length} items to current folder',
        );
        try {
          await repo.moveItems(details.data, currentPath);
          ref.read(taskProvider.notifier).completeTask(taskId);
          ref.read(directoryItemsProvider.notifier).refresh();
          ref.read(selectionProvider.notifier).deselectAll();
        } catch (e) {
          ref.read(taskProvider.notifier).failTask(taskId, e.toString());
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isOver = candidateData.isNotEmpty;
        return Container(
          decoration: BoxDecoration(
            color: isOver ? AppColors.violet.withOpacity(0.05) : null,
          ),
          child: content,
        );
      },
    );
  }

  void _handleTap(List<FileItem> items, int index) {
    final isShift = HardwareKeyboard.instance.logicalKeysPressed
            .contains(LogicalKeyboardKey.shiftLeft) ||
        HardwareKeyboard.instance.logicalKeysPressed
            .contains(LogicalKeyboardKey.shiftRight);

    final isCtrl = HardwareKeyboard.instance.logicalKeysPressed
            .contains(LogicalKeyboardKey.controlLeft) ||
        HardwareKeyboard.instance.logicalKeysPressed
            .contains(LogicalKeyboardKey.controlRight);

    ref.read(selectionProvider.notifier).onItemTap(
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
        item.type == FileItemType.document) {
      ref.read(previewFileProvider.notifier).state = item;
      return;
    }
  }
}
