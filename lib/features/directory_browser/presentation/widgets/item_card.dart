import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_utils.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

/// Individual file/folder card — pixel-perfect replica of original _buildItemCard().
/// Wrapped in RepaintBoundary for rendering performance.
class ItemCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: MouseRegion(
        onEnter: (_) => onHoverChanged(true),
        onExit: (_) => onHoverChanged(false),
        child: GestureDetector(
          onTap: onTap,
          onDoubleTap: onDoubleTap,
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.violet.withOpacity(0.12)
                  : (isHovered ? Colors.white.withOpacity(0.04) : Colors.transparent),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? AppColors.violet.withOpacity(0.2)
                    : Colors.transparent,
                strokeAlign: BorderSide.strokeAlignOutside,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Preview area — fixed height matching original
                SizedBox(
                  height: 120 * zoom,
                  child: Center(
                    child: _buildItemPreview(),
                  ),
                ),
                SizedBox(height: 8 * zoom),
                // Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    _truncateMiddle(item.name),
                    maxLines: zoom < 0.8 ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 13 * (zoom < 1 ? zoom.clamp(0.85, 1.0) : (zoom > 1.2 ? 1.1 : 1.0)),
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItemPreview() {
    if (item.type == FileItemType.folder) {
      final config = getFolderIconConfig(item.name);
      return _buildArchivalIcon(config.icon, config.colors, hasTab: true);
    } else if (item.type == FileItemType.image) {
      final isSvg = item.name.toLowerCase().endsWith('.svg');
      if (isSvg) return _buildSvgIcon('assets/icons/image.svg', isVertical: false);
      
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(item.path),
          fit: BoxFit.contain,
          cacheWidth: 300,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            if (frame == null) {
              return _buildSvgIcon('assets/icons/image_placeholder.svg', isVertical: false);
            }
            return child;
          },
          errorBuilder: (_, __, ___) => _buildSvgIcon('assets/icons/image.svg', isVertical: false),
        ),
      );
    } else if (item.type == FileItemType.video) {
        // We lack thumbnail previews temporarily, just show video svg
      return _buildSvgIcon('assets/icons/video.svg', isVertical: false);
    } else {
      return _buildFileFallback();
    }
  }

  Widget _buildFileFallback() {
    final name = item.name.toLowerCase();
    final ext = name.split('.').length > 1 ? '.${name.split('.').last}' : '';
    
    // Custom SVG Mappings (Priority)
    if (name.contains('readme') || ext == '.md') {
      return _buildSvgIcon('assets/icons/readme.svg', isVertical: true);
    } else if (['.exe', '.sh', '.bin', '.appimage', '.deb', '.rpm'].contains(ext) || name == 'starup' || name == 'startup') {
      return _buildSvgIcon('assets/icons/exe.svg', isVertical: true);
    } else if (ext == '.doc' || ext == '.docx' || ext == '.odt') {
      return _buildSvgIcon('assets/icons/doc.svg', isVertical: true);
    } else if (ext == '.pdf') {
      return _buildSvgIcon('assets/icons/pdf.svg', isVertical: true);
    } else if (ext == '.xlsx' || ext == '.xls' || ext == '.csv' || ext == '.ods') {
      return _buildSvgIcon('assets/icons/spreadsheet.svg', isVertical: true);
    } else if (ext == '.ppt' || ext == '.pptx' || ext == '.odp') {
      return _buildSvgIcon('assets/icons/presentation.svg', isVertical: true);
    } else if (['.mp3', '.wav', '.flac', '.m4a', '.aac', '.ogg', '.wma', '.opus'].contains(ext)) {
      return _buildSvgIcon('assets/icons/audio.svg', isVertical: true);
    } else if (ext == '.zip' || ext == '.rar' || ext == '.7z' || ext == '.tar' || ext == '.gz') {
      return _buildSvgIcon('assets/icons/zip.svg', isVertical: false);
    } else if (ext == '.txt' || ext == '.log') {
      return _buildSvgIcon('assets/icons/txt.svg', isVertical: false);
    }

    // Default Material Theme Style Fallback
    final config = getFileIconConfig(item.name);
    
    if (config.icon == Icons.insert_drive_file_rounded) {
      if (item.isExecutable) {
        return _buildSvgIcon('assets/icons/exe.svg', isVertical: true);
      }
      return _buildSvgIcon('assets/icons/unknown_file.svg', isVertical: true);
    }
    
    // Code/Data/Config usually vertical unless it's a 'package/container' style
    bool isVertical = true;
    if (['.json', '.yaml', '.yml', '.toml', '.xml', '.dart', '.py', '.java', '.c', '.cpp', '.js', '.ts', '.go', '.rs'].contains(ext)) {
      isVertical = true;
    }

    return _buildArchivalIcon(config.icon, config.colors, isVertical: isVertical);
  }

  Widget _buildSvgIcon(String assetPath, {required bool isVertical}) {
    // Scaling adjustments for perceived weight
    double weightScale = 1.0;
    if (assetPath.contains('pdf.svg') || assetPath.contains('txt.svg') || assetPath.contains('audio.svg')) {
      weightScale = 1.15; // 15% increase for smaller looking icons
    }

    return SizedBox(
      width: (isVertical ? 90 : 110) * zoom * weightScale,
      height: (isVertical ? 120 : 110) * zoom * weightScale,
      child: SvgPicture.asset(
        assetPath,
        fit: BoxFit.contain,
      ),
    );
  }

  // Helper for stylized archival icons (both Square Folders and Vertical Docs)
  Widget _buildArchivalIcon(IconData icon, List<Color> colors, {bool hasTab = false, bool isVertical = false}) {
    return SizedBox(
      width: (isVertical ? 90 : 110) * zoom,
      height: (isVertical ? 120 : 110) * zoom,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (hasTab)
            Positioned(
              top: 0,
              left: 10 * zoom,
              child: Container(
                width: 38 * zoom,
                height: 14 * zoom,
                decoration: BoxDecoration(
                  color: colors.first.withOpacity(0.9),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(6 * zoom)),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            top: (hasTab ? 10 : 0) * zoom,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12 * zoom),
                boxShadow: [
                  BoxShadow(color: colors.first.withOpacity(0.3), blurRadius: 10 * zoom, offset: Offset(0, 4 * zoom)),
                ],
              ),
              child: Center(
                child: Icon(icon, color: Colors.white, size: (isVertical ? 48 : 42) * zoom),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _truncateMiddle(String title, {int maxLength = 50}) {
    if (title.length <= maxLength) return title;
    final extIndex = title.lastIndexOf('.');
    var ext = '';
    var base = title;
    if (extIndex != -1 && (title.length - extIndex) <= 8) {
      ext = title.substring(extIndex);
      base = title.substring(0, extIndex);
    }
    final startChars = maxLength - ext.length - 3;
    if (startChars <= 10) return '${title.substring(0, maxLength - 3)}...';
    return '${base.substring(0, startChars)}...$ext';
  }
}
