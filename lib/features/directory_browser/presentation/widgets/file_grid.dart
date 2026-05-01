import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import "package:path/path.dart" as p;

import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
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
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = ref.read(mainFocusNodeProvider);
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(filteredDirectoryItemsProvider);
    final zoom = ref.watch(currentZoomProvider);
    final selection = ref.watch(selectionProvider);
    final String currentPath = ref.watch(currentPathProvider);
    final refreshCount = ref.watch(refreshCountProvider);

    final isRefreshing = ref.watch(isRefreshingProvider);

    final content = AnimatedOpacity(
      duration: const Duration(milliseconds: 150),
      opacity: isRefreshing ? 0.2 : 1.0,
      curve: Curves.easeInOut,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: itemsAsync.when(
        loading: () => Center(
          key: const ValueKey('loading'),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.violet.withOpacity(0.4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Reading disk...',
                style: GoogleFonts.manrope(
                  color: Colors.white24,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
        error: (error, _) => Center(
          key: const ValueKey('error'),
          child: Text(
            'Error: $error',
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            final isSearchActive = ref.watch(isSearchActiveProvider);
            final query = ref.watch(searchQueryProvider);
            
            if (isSearchActive && query.isNotEmpty) {
              return Center(
                key: const ValueKey('no-results'),
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(40),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.02),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: ShaderMask(
                      shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                      child: const Icon(
                        Icons.manage_search_rounded,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'No Results Found',
                    style: GoogleFonts.manrope(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.manrope(
                        fontSize: 16,
                        color: Colors.white38,
                        fontWeight: FontWeight.w500,
                      ),
                      children: [
                        const TextSpan(text: 'No matches for "'),
                        TextSpan(
                          text: query,
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: '" in ${p.basename(currentPath)}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  OutlinedButton(
                    onPressed: () {
                      ref.read(isSearchActiveProvider.notifier).state = false;
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Clear Search',
                      style: GoogleFonts.manrope(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

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
            key: ValueKey('grid-refreshed-$refreshCount'),
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
  ),
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

    ref.read(mainFocusNodeProvider).requestFocus();
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
