import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import '../providers/audio_player_providers.dart';
import 'waveform_scrubber.dart';
import 'audio_controls_bar.dart';

class HeroAudioPlayer extends ConsumerWidget {
  const HeroAudioPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTrack = ref.watch(currentTrackProvider);
    if (currentTrack == null) return const SizedBox.shrink();

    return Stack(
      children: [
        // Background Glow
        Center(
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.violet.withOpacity(0.15),
                  AppColors.violet.withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Main UI
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 64),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3), // More space at the top
              
              // Album Art
              Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.violet.withOpacity(0.2),
                      AppColors.indigo.withOpacity(0.1),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.violet.withOpacity(0.15),
                      blurRadius: 60,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.white.withOpacity(0.05),
                            Colors.white.withOpacity(0.01),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.music_note_rounded,
                          size: 100,
                          color: Colors.white.withOpacity(0.15),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 48),

              // Track Info
              Text(
                currentTrack.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              const Text(
                "Unknown Artist",
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 1),

              // Waveform
              WaveformScrubber(fileName: currentTrack.name),
              
              const SizedBox(height: 40),

              // Controls
              const AudioControlsBar(),
              
              const Spacer(flex: 4), // More space at the bottom to push controls down
            ],
          ),
        ),
      ],
    );
  }
}
