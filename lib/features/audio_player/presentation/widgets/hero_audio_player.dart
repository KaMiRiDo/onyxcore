import 'dart:async';
import 'dart:typed_data';

import 'package:audiotags/audiotags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/audio_player/presentation/providers/audio_player_providers.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/audio_controls_bar.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/waveform_scrubber.dart';
import 'package:path/path.dart' as p;

class HeroAudioPlayer extends ConsumerWidget {

  const HeroAudioPlayer({
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
    final currentTrack = ref.watch(currentTrackProvider);
    if (currentTrack == null) return const SizedBox.shrink();

    final overrideTag = ref.watch(
      audioTagsOverridesProvider(currentTrack.path),
    );
    final tagAsync = ref.watch(audioTagsProvider(currentTrack.path));

    String? artistText;
    String? albumText;
    Widget? coverImage;

    Tag? tag;
    if (overrideTag != null) {
      tag = overrideTag;
    } else if (tagAsync.hasValue && tagAsync.value != null) {
      tag = tagAsync.value;
    }

    if (tag != null) {
      if (tag.trackArtist != null && tag.trackArtist!.isNotEmpty) {
        artistText = tag.trackArtist;
      }
      if (tag.album != null && tag.album!.isNotEmpty) {
        albumText = tag.album;
      }
      if (tag.pictures.isNotEmpty) {
        final pic = tag.pictures.first;
        coverImage = ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(
                Uint8List.fromList(pic.bytes),
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.15),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.4),
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }

    var subtitle = '';
    if (artistText != null && albumText != null) {
      subtitle = '$artistText | $albumText';
    } else if (artistText != null) {
      subtitle = artistText;
    } else if (albumText != null) {
      subtitle = albumText;
    } else {
      subtitle = 'Audio File';
    }

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
                  constraints: const BoxConstraints(
                    maxWidth: 380,
                    maxHeight: 380,
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.alphaBlend(
                              AppColors.magenta.withValues(alpha: 0.08),
                              const Color(0xFF181818),
                            ),
                            Color.alphaBlend(
                              AppColors.violet.withValues(alpha: 0.03),
                              const Color(0xFF181818),
                            ),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.04),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 40,
                            spreadRadius: 10,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child:
                            coverImage ??
                            ShaderMask(
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

              const Spacer(flex: 2),

              // Track Info
              AutoScrollingText(
                text: p.basenameWithoutExtension(currentTrack.name),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 2), // Space between track info and waveform
              // Waveform
              WaveformScrubber(fileName: currentTrack.name),

              const Spacer(),

              // Controls
              AudioControlsBar(
                onNextPressed: onNextPressed,
                onPreviousPressed: onPreviousPressed,
                isAudioPlayOnly: isAudioPlayOnly,
              ),

              const Spacer(
                flex: 2,
              ), // Space below the HUD to push it up slightly
            ],
          ),
        ),
      ],
    );
  }
}

class AutoScrollingText extends StatefulWidget {

  const AutoScrollingText({required this.text, required this.style, super.key});
  final String text;
  final TextStyle style;

  @override
  State<AutoScrollingText> createState() => _AutoScrollingTextState();
}

class _AutoScrollingTextState extends State<AutoScrollingText>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  Ticker? _ticker;
  double _offset = 0;
  Timer? _delayTimer;

  void _initTicker() {
    _ticker ??= createTicker((elapsed) {
      if (!_scrollController.hasClients) return;
      // Scroll speed: 1.0 logical pixel per frame (~60px per sec at 60fps)
      _offset += 1.0;
      _scrollController.jumpTo(_offset);
    });
  }

  @override
  void initState() {
    super.initState();
    _initTicker();
    // Add a slight delay before starting to scroll
    _delayTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _ticker != null && !_ticker!.isActive) {
        _ticker!.start();
      }
    });
  }

  @override
  void didUpdateWidget(AutoScrollingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initTicker();
    if (oldWidget.text != widget.text) {
      _offset = 0.0;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      _ticker?.stop();
      _delayTimer?.cancel();
      _delayTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && _ticker != null && !_ticker!.isActive) {
          _ticker!.start();
        }
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _ticker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36, // Fixed height for the title
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.only(right: 64),
            child: Text(
              widget.text,
              style: widget.style,
            ),
          );
        },
      ),
    );
  }
}
