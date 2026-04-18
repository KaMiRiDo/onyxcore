import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_utils.dart';
import 'package:onyxcore/features/image_viewer/presentation/pages/image_viewer_page.dart';
import 'package:onyxcore/features/video_player/presentation/pages/video_player_page.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
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

    return itemsAsync.when(
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

    if (item.type == FileItemType.image) {
      final imageItems =
          items.where((i) => i.type == FileItemType.image).toList();
      final imageIndex = imageItems.indexWhere((i) => i.path == item.path);

      Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(
          builder: (_) => ImageViewerPage(
            imagePaths: imageItems.map((i) => i.path).toList(),
            initialIndex: imageIndex >= 0 ? imageIndex : 0,
          ),
        ),
      ).then((deleted) {
        if (deleted == true) {
          ref.read(directoryItemsProvider.notifier).refresh();
        }
      });
      return;
    }

    if (item.type == FileItemType.video) {
      Navigator.push<dynamic>(
        context,
        MaterialPageRoute<dynamic>(
          builder: (_) => VideoPlayerPage(videoPath: item.path),
        ),
      ).then((_) {
        ref.read(directoryItemsProvider.notifier).refresh();
      });
    }
  }
}
