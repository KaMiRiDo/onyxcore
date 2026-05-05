import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import '../providers/audio_player_providers.dart';
import 'package:media_kit/media_kit.dart';

class PlaylistSidebar extends ConsumerWidget {
  const PlaylistSidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(audioQueueProvider);
    final activeIndex = ref.watch(activeTrackIndexProvider);
    final player = ref.watch(audioPlayerProvider);
    final shuffle = ref.watch(audioShuffleProvider);
    final repeat = ref.watch(audioRepeatProvider);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceBase.withOpacity(0.4),
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.03))),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 64, 16, 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Up Next",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: shuffle ? AppColors.violet : Colors.white70,
                        size: 20,
                      ),
                      onPressed: () {
                        ref.read(audioShuffleProvider.notifier).state = !shuffle;
                      },
                      tooltip: "Shuffle",
                    ),
                    IconButton(
                      icon: Icon(
                        repeat == PlaylistMode.loop ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                        color: repeat != PlaylistMode.none ? AppColors.violet : Colors.white70,
                        size: 20,
                      ),
                      onPressed: () {
                        final nextMode = repeat == PlaylistMode.none 
                            ? PlaylistMode.loop 
                            : (repeat == PlaylistMode.loop ? PlaylistMode.single : PlaylistMode.none);
                        ref.read(audioRepeatProvider.notifier).state = nextMode;
                        player?.setPlaylistMode(nextMode);
                      },
                      tooltip: "Repeat",
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Track List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: queue.length,
              itemBuilder: (context, index) {
                final item = queue[index];
                final isActive = index == activeIndex;

                return _TrackTile(
                  item: item,
                  index: index,
                  isActive: isActive,
                  onTap: () {
                    ref.read(activeTrackIndexProvider.notifier).state = index;
                    player?.jump(index);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  final FileItem item;
  final int index;
  final bool isActive;
  final VoidCallback onTap;

  const _TrackTile({
    required this.item,
    required this.index,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.05) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: isActive 
            ? Border.all(color: Colors.white.withOpacity(0.05))
            : null,
      ),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.08),
                Colors.white.withOpacity(0.03),
              ],
            ),
          ),
          child: const Center(
            child: Icon(Icons.music_note_rounded, color: Colors.white24, size: 20),
          ),
        ),
        title: isActive
            ? ShaderMask(
                shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                child: Text(
                  item.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : Text(
                item.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
        subtitle: const Text(
          "Unknown Artist",
          style: TextStyle(color: Colors.white38, fontSize: 12),
        ),
        trailing: isActive 
            ? const _AnimatedEQIcon()
            : const Text(
                "3:42",
                style: TextStyle(color: Colors.white24, fontSize: 11),
              ),
      ),
    );
  }
}

class _AnimatedEQIcon extends StatefulWidget {
  const _AnimatedEQIcon();

  @override
  State<_AnimatedEQIcon> createState() => _AnimatedEQIconState();
}

class _AnimatedEQIconState extends State<_AnimatedEQIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final val = (sin(_controller.value * 2 * pi + index * 1.5) + 1) / 2;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                width: 3,
                height: 4 + 12 * val.toDouble(),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
