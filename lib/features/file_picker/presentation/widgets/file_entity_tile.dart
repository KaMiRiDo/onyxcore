import 'package:file/file.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:path/path.dart' as p;

class FileEntityTile extends StatelessWidget {

  const FileEntityTile({
    required this.entity,
    required this.isSelected,
    required this.onTap,
    required this.onDoubleTap,
    super.key,
  });
  final FileSystemEntity entity;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final isDirectory = entity is Directory;
    final name = p.basename(entity.path);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.violet.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? AppColors.violet.withValues(alpha: 0.3)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              if (isDirectory)
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppColors.magenta, AppColors.violet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Icon(
                    Icons.folder_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                )
              else
                Icon(
                  _getFileIcon(name),
                  color: Colors.white70,
                  size: 20,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.manrope(
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getFileIcon(String name) {
    final ext = p.extension(name).toLowerCase();
    if (['.mp4', '.mkv', '.mov', '.avi'].contains(ext)) {
      return Icons.video_collection_rounded;
    }
    if (['.jpg', '.jpeg', '.png', '.svg', '.gif'].contains(ext)) {
      return Icons.image_rounded;
    }
    if (['.mp3', '.wav', '.flac', '.m4a'].contains(ext)) {
      return Icons.audiotrack_rounded;
    }
    if (['.pdf', '.doc', '.docx', '.txt', '.md'].contains(ext)) {
      return Icons.description_rounded;
    }
    return Icons.insert_drive_file_rounded;
  }
}
