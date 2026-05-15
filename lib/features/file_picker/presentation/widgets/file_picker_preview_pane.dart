import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:path/path.dart' as p;

class FilePickerPreviewPane extends StatefulWidget {
  final List<String> selectedPaths;

  const FilePickerPreviewPane({
    required this.selectedPaths,
    super.key,
  });

  @override
  State<FilePickerPreviewPane> createState() => _FilePickerPreviewPaneState();
}

class _FilePickerPreviewPaneState extends State<FilePickerPreviewPane> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(FilePickerPreviewPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPaths.length > oldWidget.selectedPaths.length) {
      // Auto-scroll to bottom on new selection
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: Colors.black.withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'PREVIEW (${widget.selectedPaths.length})',
              style: AppTheme.labelStyle.copyWith(
                fontSize: 10,
                letterSpacing: 1.2,
                color: AppColors.magenta,
              ),
            ),
          ),
          Expanded(
            child: widget.selectedPaths.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                    itemCount: widget.selectedPaths.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 20),
                    itemBuilder: (context, index) => _PreviewItem(path: widget.selectedPaths[index]),
                  ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.remove_red_eye_rounded, size: 40, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 12),
          Text(
            'Select files to preview',
            style: GoogleFonts.manrope(color: Colors.white24, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PreviewItem extends StatelessWidget {
  final String path;

  const _PreviewItem({required this.path});

  bool _isImage(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp'].contains(ext);
  }

  String _getFileSize() {
    try {
      final file = File(path);
      if (file.existsSync()) {
        final bytes = file.lengthSync();
        if (bytes < 1024) return '$bytes B';
        if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
        if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
        return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
      }
    } catch (_) {}
    return 'Size unknown';
  }

  @override
  Widget build(BuildContext context) {
    final fileName = p.basename(path);
    final fileSize = _getFileSize();
    final isImg = _isImage(path);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              color: Colors.white.withOpacity(0.03),
              child: isImg
                  ? Image.file(
                      File(path),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          fileName,
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          fileSize,
          style: GoogleFonts.manrope(
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() {
    IconData icon;
    Color color;
    final ext = p.extension(path).toLowerCase();

    if (['.mp4', '.mkv', '.mov', '.avi'].contains(ext)) {
      icon = Icons.movie_rounded;
      color = AppColors.violet;
    } else if (['.pdf', '.doc', '.docx', '.txt'].contains(ext)) {
      icon = Icons.description_rounded;
      color = AppColors.cyan;
    } else if (['.mp3', '.wav', '.flac', '.m4a'].contains(ext)) {
      icon = Icons.audiotrack_rounded;
      color = AppColors.magenta;
    } else {
      icon = Icons.insert_drive_file_rounded;
      color = Colors.white24;
    }

    return Center(
      child: Icon(icon, size: 32, color: color.withOpacity(0.5)),
    );
  }
}
