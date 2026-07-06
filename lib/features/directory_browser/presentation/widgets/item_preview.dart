import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/file_type_utils.dart';
import '../../domain/entities/file_item.dart';
import 'media_thumbnail_preview.dart';

/// Preview widget for items in the file grid — exact same UI as original
/// _buildItemPreview(), _buildFileFallback(), _buildArchivalIcon(), _buildSvgIcon().
class ItemPreview extends StatelessWidget {
  const ItemPreview({
    required this.item,
    required this.zoom,
    super.key,
  });

  final FileItem item;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    if (item.type == FileItemType.folder) {
      return _buildFolderPreview();
    }

    if (item.type == FileItemType.image) {
      return _buildImagePreview();
    }

    if (item.type == FileItemType.video) {
      return _buildVideoPreview();
    }

    return _buildFileFallback();
  }

  Widget _buildFolderPreview() {
    final config = getFolderIconConfig(item.name);
    return _buildArchivalIcon(config.icon, config.colors);
  }

  Widget _buildImagePreview() {
    return MediaThumbnailPreview(item: item, zoom: zoom);
  }

  Widget _buildVideoPreview() {
    return MediaThumbnailPreview(item: item, zoom: zoom);
  }

  Widget _buildFileFallback() {
    final name = item.name.toLowerCase();

    // SVG icon mappings — exact same as original _buildFileFallback()
    if (name.contains('readme') || name.endsWith('.md'))
      return _buildSvgIcon('assets/icons/readme.svg');
    if (name.endsWith('.pdf')) return _buildSvgIcon('assets/icons/pdf.svg');
    if (name.endsWith('.zip') ||
        name.endsWith('.rar') ||
        name.endsWith('.7z') ||
        name.endsWith('.tar') ||
        name.endsWith('.gz')) {
      return _buildSvgIcon('assets/icons/zip.svg');
    }
    if (name.endsWith('.doc') ||
        name.endsWith('.docx') ||
        name.endsWith('.odt')) {
      return _buildSvgIcon('assets/icons/doc.svg');
    }
    if (name.endsWith('.xlsx') ||
        name.endsWith('.xls') ||
        name.endsWith('.csv') ||
        name.endsWith('.ods')) {
      return _buildSvgIcon('assets/icons/spreadsheet.svg');
    }
    if (name.endsWith('.ppt') ||
        name.endsWith('.pptx') ||
        name.endsWith('.odp')) {
      return _buildSvgIcon('assets/icons/presentation.svg');
    }
    if (name.endsWith('.mp3') ||
        name.endsWith('.wav') ||
        name.endsWith('.flac') ||
        name.endsWith('.m4a') ||
        name.endsWith('.aac') ||
        name.endsWith('.ogg') ||
        name.endsWith('.wma') ||
        name.endsWith('.opus')) {
      return _buildSvgIcon('assets/icons/audio.svg');
    }
    if (name.endsWith('.txt') || name.endsWith('.log')) {
      return _buildSvgIcon('assets/icons/txt.svg');
    }
    if (name.endsWith('.exe') ||
        name.endsWith('.sh') ||
        name.endsWith('.bin') ||
        name.endsWith('.appimage') ||
        name.endsWith('.deb') ||
        name.endsWith('.rpm')) {
      return _buildSvgIcon('assets/icons/exe.svg');
    }

    // Material icon fallback for code and other files
    final config = getFileIconConfig(item.name);
    if (config.icon == Icons.insert_drive_file_rounded) {
      if (item.isExecutable) {
        return _buildSvgIcon('assets/icons/exe.svg');
      }
      return _buildSvgIcon('assets/icons/unknown_file.svg');
    }
    return _buildArchivalIcon(config.icon, config.colors);
  }

  Widget _buildArchivalIcon(IconData icon, List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        gradient: LinearGradient(
          colors: [colors[0].withOpacity(0.12), colors[1].withOpacity(0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(bounds),
          child: Icon(icon, size: 38 * zoom, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildSvgIcon(String path) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        color: Colors.white.withOpacity(0.02),
      ),
      child: Center(
        child: SvgPicture.asset(
          path,
          width: 42 * zoom,
          height: 42 * zoom,
        ),
      ),
    );
  }
}

/// Title text for items in the file grid.
class ItemTitle extends StatelessWidget {
  const ItemTitle({
    required this.name,
    required this.zoom,
    super.key,
  });

  final String name;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    return Text(
      name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: GoogleFonts.manrope(
        fontSize: 11 * zoom,
        fontWeight: FontWeight.w500,
        color: AppColors.textBody,
        height: 1.3,
      ),
    );
  }
}
