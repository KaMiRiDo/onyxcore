import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/menu_tooltip.dart';

class PlaylistOverlay extends ConsumerWidget {
  final String currentPath;
  final List<FileItem>? videos;
  final Function(FileItem) onVideoSelected;

  const PlaylistOverlay({
    required this.currentPath,
    this.videos,
    required this.onVideoSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (videos != null) {
      return _buildContent(videos!);
    }

    final itemsAsync = ref.watch(sortedDirectoryItemsProvider);

    return itemsAsync.when(
      data: (items) {
        final filteredVideos = items
            .where((i) => i.type == FileItemType.video)
            .toList();
        return _buildContent(filteredVideos);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(
        child: Text('Error: $e', style: const TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildContent(List<FileItem> videoList) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          width: 320,
          height: 450,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E26).withOpacity(0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(videoList.length),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: videoList.length,
                  itemBuilder: (context, index) {
                    final video = videoList[index];
                    final isPlaying = video.path == currentPath;
                    return _buildPlaylistItem(video, isPlaying);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Text(
            'PLAYLIST',
            style: GoogleFonts.manrope(
              color: Colors.white30,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const Spacer(),
          Text(
            '$count Items',
            style: GoogleFonts.manrope(
              color: Colors.white30,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistItem(FileItem video, bool isPlaying) {
    return MenuTooltip(
      message: video.name,
      child: InkWell(
        onTap: () => onVideoSelected(video),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: isPlaying
                ? AppColors.violet.withOpacity(0.1)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isPlaying
                      ? AppColors.violet
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPlaying ? Icons.play_arrow_rounded : Icons.movie_outlined,
                  color: isPlaying ? Colors.white : Colors.white30,
                  size: 18,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.name,
                      style: GoogleFonts.manrope(
                        color: isPlaying ? Colors.white : Colors.white60,
                        fontSize: 13,
                        fontWeight: isPlaying
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (video.sizeBytes != null)
                      Text(
                        _formatSize(video.sizeBytes!),
                        style: GoogleFonts.manrope(
                          color: Colors.white24,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              if (isPlaying)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.violet,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
