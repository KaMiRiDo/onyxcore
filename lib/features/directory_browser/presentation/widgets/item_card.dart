import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path/path.dart' as p;
import 'package:google_fonts/google_fonts.dart';

import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_utils.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';

/// Individual file/folder card — pixel-perfect replica of original _buildItemCard().
class ItemCard extends ConsumerStatefulWidget {
  const ItemCard({
    required this.item,
    required this.zoom,
    required this.isSelected,
    required this.isHovered,
    required this.onTap,
    required this.onDoubleTap,
    required this.onHoverChanged,
    super.key,
  });

  final FileItem item;
  final double zoom;
  final bool isSelected;
  final bool isHovered;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final ValueChanged<bool> onHoverChanged;

  @override
  ConsumerState<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends ConsumerState<ItemCard> {
  Timer? _hoverTimer;

  @override
  void dispose() {
    _hoverTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: widget.isSelected
            ? AppColors.violet.withOpacity(0.12)
            : (widget.isHovered ? Colors.white.withOpacity(0.04) : Colors.transparent),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.isSelected
              ? AppColors.violet.withOpacity(0.2)
              : Colors.transparent,
          strokeAlign: BorderSide.strokeAlignOutside,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            height: 120 * widget.zoom,
            child: Center(
              child: _buildItemPreview(),
            ),
          ),
          SizedBox(height: 8 * widget.zoom),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _truncateMiddle(widget.item.name),
              maxLines: widget.zoom < 0.8 ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 13 * (widget.zoom < 1 ? widget.zoom.clamp(0.85, 1.0) : (widget.zoom > 1.2 ? 1.1 : 1.0)),
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    // DND Logic
    final isFolder = widget.item.type == FileItemType.folder;
    
    final Widget draggableWidget = Draggable<List<String>>(
      data: widget.isSelected 
          ? ref.read(selectionProvider).selectedPaths.toList()
          : [widget.item.path],
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.7,
          child: Transform.scale(
            scale: 0.8,
            child: cardContent,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: cardContent,
      ),
      onDragStarted: () {
        if (!widget.isSelected) {
          ref.read(selectionProvider.notifier).selectMultiple([widget.item.path], isCtrl: false);
        }
      },
      child: cardContent,
    );

    Widget result = draggableWidget;

    if (isFolder) {
      result = DragTarget<List<String>>(
        onWillAcceptWithDetails: (details) {
          if (details.data.contains(widget.item.path)) return false;
          
          _hoverTimer?.cancel();
          _hoverTimer = Timer(const Duration(milliseconds: 700), () {
            ref.read(navigationProvider.notifier).navigateTo(widget.item.path);
            ref.read(currentPathProvider.notifier).state = widget.item.path;
          });
          return true;
        },
        onLeave: (_) {
          _hoverTimer?.cancel();
        },
        onAcceptWithDetails: (details) async {
          _hoverTimer?.cancel();
          final repo = ref.read(directoryRepositoryProvider);
          final taskId = ref.read(taskProvider.notifier).addTask(
            title: 'Moving Files',
            subtitle: '${details.data.length} items to ${widget.item.name}',
          );
          try {
            await repo.moveItems(details.data, widget.item.path);
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
              borderRadius: BorderRadius.circular(12),
              color: isOver ? AppColors.violet.withOpacity(0.1) : null,
            ),
            child: draggableWidget,
          );
        },
      );
    }

    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => widget.onHoverChanged(true),
        onExit: (_) => widget.onHoverChanged(false),
        child: GestureDetector(
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          child: result,
        ),
      ),
    );
  }

  Widget _buildItemPreview() {
    if (widget.item.type == FileItemType.folder) {
      final config = getFolderIconConfig(widget.item.name);
      return _buildArchivalIcon(config.icon, config.colors, hasTab: true);
    } else if (widget.item.type == FileItemType.image) {
      final isSvg = widget.item.name.toLowerCase().endsWith('.svg');
      if (isSvg) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SvgPicture.file(
            File(widget.item.path),
            fit: BoxFit.contain,
          ),
        );
      }
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(widget.item.path),
          fit: BoxFit.contain,
          cacheWidth: 300,
          errorBuilder: (_, __, ___) => _buildSvgIcon('assets/icons/image.svg', isVertical: false),
        ),
      );
    } else if (widget.item.type == FileItemType.video) {
      return _buildSvgIcon('assets/icons/video.svg', isVertical: false);
    } else {
      return _buildFileFallback();
    }
  }

  Widget _buildFileFallback() {
    final name = widget.item.name.toLowerCase();
    final ext = name.split('.').length > 1 ? '.${name.split('.').last}' : '';
    if (name.contains('readme') || ext == '.md') {
      return _buildSvgIcon('assets/icons/readme.svg', isVertical: true);
    } else if (['.exe', '.sh', '.bin', '.appimage', '.deb', '.rpm'].contains(ext)) {
      return _buildSvgIcon('assets/icons/exe.svg', isVertical: true);
    } else if (ext == '.zip' || ext == '.rar' || ext == '.7z') {
      return _buildSvgIcon('assets/icons/zip.svg', isVertical: false);
    }
    final config = getFileIconConfig(widget.item.name);
    return _buildArchivalIcon(config.icon, config.colors, isVertical: true);
  }

  Widget _buildSvgIcon(String assetPath, {required bool isVertical}) {
    return SizedBox(
      width: (isVertical ? 90 : 110) * widget.zoom,
      height: (isVertical ? 120 : 110) * widget.zoom,
      child: SvgPicture.asset(assetPath, fit: BoxFit.contain),
    );
  }

  Widget _buildArchivalIcon(IconData icon, List<Color> colors, {bool hasTab = false, bool isVertical = false}) {
    return SizedBox(
      width: (isVertical ? 90 : 110) * widget.zoom,
      height: (isVertical ? 120 : 110) * widget.zoom,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (hasTab)
            Positioned(
              top: 0,
              left: 10 * widget.zoom,
              child: Container(
                width: 38 * widget.zoom,
                height: 14 * widget.zoom,
                decoration: BoxDecoration(
                  color: colors.first.withOpacity(0.9),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(6 * widget.zoom)),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            top: (hasTab ? 10 : 0) * widget.zoom,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: colors),
                borderRadius: BorderRadius.circular(12 * widget.zoom),
              ),
              child: Center(
                child: Icon(icon, color: Colors.white, size: (isVertical ? 48 : 42) * widget.zoom),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _truncateMiddle(String title, {int maxLength = 50}) {
    if (title.length <= maxLength) return title;
    return '${title.substring(0, 25)}...${title.substring(title.length - 10)}';
  }
}
