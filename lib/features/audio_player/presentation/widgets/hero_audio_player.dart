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
        // Main UI
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 32),
          child: Column(
            children: [
              const Spacer(flex: 3), // Album top spacing
              // Album Art
              Flexible(
                flex: 10,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380, maxHeight: 380),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.alphaBlend(AppColors.magenta.withOpacity(0.08), const Color(0xFF181818)),
                      Color.alphaBlend(AppColors.violet.withOpacity(0.03), const Color(0xFF181818)),
                    ],
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.04), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 40,
                      spreadRadius: 10,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        AppColors.magenta,
                        AppColors.violet,
                      ],
                    ).createShader(bounds),
                    child: const Icon(
                      Icons.music_note_rounded,
                      size: 140,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),

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

              const Spacer(flex: 3), // Space between track info and waveform

              // Waveform
              WaveformScrubber(fileName: currentTrack.name),

              const SizedBox(height: 40),

              // Controls
              const AudioControlsBar(),
              
              const Spacer(flex: 2), // Space below the HUD to push it up slightly
            ],
          ),
        ),
      ],
    );
  }
}
