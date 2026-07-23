import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/audio_player/presentation/providers/audio_player_providers.dart';

class AudioControlsBar extends ConsumerWidget {

  const AudioControlsBar({
    super.key,
    this.onNextPressed,
    this.onPreviousPressed,
    this.isAudioPlayOnly = false,
  });
  final VoidCallback? onNextPressed;
  final VoidCallback? onPreviousPressed;
  final bool isAudioPlayOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlaying = ref.watch(audioPlayingProvider).value ?? false;
    final volume = ref.watch(audioVolumeProvider).value ?? 100.0;
    final player = ref.watch(audioPlayerProvider);

    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isAudioPlayOnly)
                  Consumer(
                    builder: (context, ref, child) {
                      final currentTrack = ref.watch(currentTrackProvider);
                      if (currentTrack == null) return const SizedBox(width: 48);
                      final isFavorite = ref
                          .watch(audioFavoritesProvider)
                          .contains(currentTrack.path);

                      return IconButton(
                        icon: Icon(
                          isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFavorite ? AppColors.magenta : Colors.white70,
                        ),
                        onPressed: () {
                          ref
                              .read(audioFavoritesProvider.notifier)
                              .toggleFavorite(currentTrack.path);
                        },
                      );
                    },
                  ),
                Consumer(
                  builder: (context, ref, child) {
                    final isAutoPlay = ref.watch(audioAutoPlaySessionProvider);
                    return IconButton(
                      icon: Icon(
                        isAutoPlay ? Icons.autorenew_rounded : Icons.sync_disabled_rounded,
                        color: isAutoPlay ? AppColors.magenta : Colors.white70,
                      ),
                      onPressed: () {
                        ref.read(audioAutoPlaySessionProvider.notifier).state = !isAutoPlay;
                      },
                      tooltip: isAutoPlay ? 'Autoplay Next: ON' : 'Autoplay Next: OFF',
                    );
                  },
                ),
              ],
            ),

            // Right volume
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    final currentVol = player?.state.volume ?? 100.0;
                    player?.setVolume(currentVol > 0 ? 0 : 100);
                  },
                  child: Icon(
                    volume == 0
                        ? Icons.volume_off_rounded
                        : Icons.volume_up_rounded,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 100,
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 6,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 12,
                      ),
                      activeTrackColor: volume > 100
                          ? AppColors.magenta
                          : Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: volume > 100
                          ? AppColors.magenta
                          : Colors.white,
                    ),
                    child: Slider(
                      value: volume.clamp(0.0, 200.0),
                      max: 200,
                      onChanged: (val) => player?.setVolume(val),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${volume.toInt()}%',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Center controls (Strictly Centered)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.skip_previous_rounded,
                color: Colors.white,
                size: 32,
              ),
              onPressed: onPreviousPressed ?? () => player?.previous(),
            ),
            const SizedBox(width: 24),
            GestureDetector(
              onTap: () => player?.playOrPause(),
              child: Container(
                width: 64,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: Colors.black,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(width: 24),
            IconButton(
              icon: const Icon(
                Icons.skip_next_rounded,
                color: Colors.white,
                size: 32,
              ),
              onPressed: onNextPressed ?? () => player?.next(),
            ),
          ],
        ),
      ],
    );
  }
}
