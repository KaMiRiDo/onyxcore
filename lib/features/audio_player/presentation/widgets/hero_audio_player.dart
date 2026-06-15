import 'dart:ui';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:audiotags/audiotags.dart';
import '../providers/audio_player_providers.dart';
import 'waveform_scrubber.dart';
import 'audio_controls_bar.dart';

class HeroAudioPlayer extends ConsumerWidget {
  const HeroAudioPlayer({super.key});

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
      tag = tagAsync.value!;
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
                      Colors.white.withOpacity(0.15),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withOpacity(0.4),
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

    String subtitle = '';
    if (artistText != null && albumText != null) {
      subtitle = "$artistText | $albumText";
    } else if (artistText != null) {
      subtitle = artistText;
    } else if (albumText != null) {
      subtitle = albumText;
    } else {
      subtitle = "Audio File";
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
                    aspectRatio: 1.0,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.alphaBlend(
                              AppColors.magenta.withOpacity(0.08),
                              const Color(0xFF181818),
                            ),
                            Color.alphaBlend(
                              AppColors.violet.withOpacity(0.03),
                              const Color(0xFF181818),
                            ),
                          ],
                        ),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.04),
                          width: 1.5,
                        ),
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

              const Spacer(flex: 1),

              // Controls
              const AudioControlsBar(),

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
  final String text;
  final TextStyle style;

  const AutoScrollingText({super.key, required this.text, required this.style});

  @override
  State<AutoScrollingText> createState() => _AutoScrollingTextState();
}

class _AutoScrollingTextState extends State<AutoScrollingText>
    with SingleTickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  Ticker? _ticker;
  double _offset = 0.0;
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
        _scrollController.jumpTo(0.0);
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
            padding: const EdgeInsets.only(right: 64.0),
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
