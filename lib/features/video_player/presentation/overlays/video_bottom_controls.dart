// ignore_for_file: avoid_positional_boolean_parameters, cascade_invocations, avoid_dynamic_calls, unawaited_futures
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/file_picker/presentation/widgets/custom_file_picker_dialog.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/video_player/domain/entities/video_marker.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_markers_provider.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_playlist_providers.dart';
import 'package:onyxcore/features/video_player/presentation/state/video_player_state.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/gradient_slider_track.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/hover_preview.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/playback_speed_control.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/timeline_marker.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/track_selector_menu.dart';

class VideoBottomControls extends ConsumerStatefulWidget {
  const VideoBottomControls({
    required this.displayState,
    required this.player,
    required this.currentItem,
    required this.displayPosition,
    required this.availableFormats,
    required this.selectedFormatId,
    required this.onResolutionChanged,
    required this.onInteraction,
    required this.onShowSeekIndicator,
    required this.onToggleMute,
    required this.onToggleFullscreen,
    required this.onNavigateMedia,
    required this.onShowMenu,
    required this.onOpenMarkerEditor,
    required this.audioKey,
    required this.subtitleKey,
    required this.speedKey,
    required this.resolutionKey,
    required this.onMarkerMenuVisibilityChanged,
    required this.onStepSeek,
    required this.onStartFastSeek,
    required this.onStopFastSeek,
    required this.playingNotifier,
    required this.playbackSpeed,
    super.key,
  });
  final VideoPlayerDisplayState displayState;
  final Player player;
  final FileItem currentItem;
  final Duration displayPosition;
  final List<MediaFormat> availableFormats;
  final String? selectedFormatId;
  final void Function(MediaFormat) onResolutionChanged;
  final VoidCallback onInteraction;
  final VoidCallback onShowSeekIndicator;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleFullscreen;
  final void Function(bool) onNavigateMedia;
  final void Function({
    required GlobalKey key,
    required Widget child,
    required String type,
  })
  onShowMenu;
  final void Function(VideoMarker?) onOpenMarkerEditor;
  final GlobalKey audioKey;
  final GlobalKey subtitleKey;
  final GlobalKey speedKey;
  final GlobalKey resolutionKey;
  final ValueChanged<bool> onMarkerMenuVisibilityChanged;

  /// Delegated step-seek (forward/backward 10 s, settings-aware)
  final void Function({required bool isForward}) onStepSeek;

  /// Start fast seek on long-press
  final void Function({required bool isForward}) onStartFastSeek;

  /// Stop fast seek on long-press release
  final VoidCallback onStopFastSeek;

  /// Reactive playing state notifier from parent
  final ValueNotifier<bool> playingNotifier;

  /// Current playback speed from parent (mirrors parent _playbackSpeed)
  final double playbackSpeed;

  @override
  ConsumerState<VideoBottomControls> createState() =>
      _VideoBottomControlsState();
}

class _VideoBottomControlsState extends ConsumerState<VideoBottomControls> {
  Duration? _virtualScrubPosition;
  Duration? _pendingScrubPosition;

  bool _isScrubbing = false;
  bool _wasPlayingBeforeScrub = false;
  bool _showRemainingTime = false;
  bool _isSliderHovered = false;
  bool _isHoveringMarker = false;

  final ValueNotifier<double?> _hoverXNotifier = ValueNotifier<double?>(null);
  final GlobalKey _sliderKey = GlobalKey();
  final LayerLink _sliderLink = LayerLink();
  double _sliderWidth = 0;

  Timer? _scrubThrottleTimer;
  Timer? _smartDelayTimer;
  Timer? _hideTimer;
  Timer? _virtualSeekCleanupTimer;
  Timer? _engineSeekTimer;
  Timer? _fastSeekTimer;
  Timer? _hoverExitTimer;

  Player get player => widget.player;
  bool get isVisible => widget.displayState.isHudVisible;
  Duration get displayPosition => widget.displayPosition;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider).value;
    _showRemainingTime = settings?.videoShowRemainingTime ?? false;
  }

  @override
  void didUpdateWidget(VideoBottomControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.displayState.showRemainingTime !=
        widget.displayState.showRemainingTime) {
      _showRemainingTime = widget.displayState.showRemainingTime;
    }
  }

  void _cleanupVirtualSeeking() {
    if (mounted) {
      setState(() {
        _virtualScrubPosition = null;
        _pendingScrubPosition = null;
        _isScrubbing = false;
      });
    }
  }

  void _onInteraction() => widget.onInteraction();
  void _showSeekIndicator() => widget.onShowSeekIndicator();

  void _performSeek(Duration position) {
    if (player.platform != null) {
      (player.platform as dynamic).setProperty('hr-seek', 'yes');
    }
    player.seek(position);
  }

  void _performStepSeek({required bool isForward}) {
    // Delegate to parent — uses settings-aware seek seconds and
    // properly handles virtual seek position state in the parent.
    widget.onStepSeek(isForward: isForward);
  }

  Widget _buildSeekButton({
    required bool isForward,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onLongPressStart: (_) {
        _onInteraction();
        _showSeekIndicator();
        widget.onStartFastSeek(isForward: isForward);
      },
      onLongPressEnd: (_) {
        widget.onStopFastSeek();
      },
      onLongPressCancel: () {
        widget.onStopFastSeek();
      },
      child: IconButton(
        onPressed: () {
          onPressed();
          _showSeekIndicator();
        },
        icon: Icon(
          isForward ? Icons.forward_10 : Icons.replay_10,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}';
    }
    return '${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}';
  }

  @override
  void dispose() {
    _scrubThrottleTimer?.cancel();
    _smartDelayTimer?.cancel();
    _hideTimer?.cancel();
    _virtualSeekCleanupTimer?.cancel();
    _engineSeekTimer?.cancel();
    _fastSeekTimer?.cancel();
    _hoverExitTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isVisible ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: !isVisible,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.black.withValues(alpha: 0.4),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress Slider & Timers Row
                if (!widget.displayState.isEmpty)
                  StreamBuilder<Duration>(
                  stream: player.stream.position,
                  builder: (context, snapshot) {
                    final streamPos = snapshot.data ?? displayPosition;
                    final position =
                        (_isScrubbing && _virtualScrubPosition != null)
                        ? _virtualScrubPosition!
                        : streamPos;
                    final duration = player.state.duration;
                    final remaining = duration - position;
                    final progress = duration.inMilliseconds > 0
                        ? position.inMilliseconds / duration.inMilliseconds
                        : 0.0;

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 17),
                          child: Text(
                            _formatDuration(position),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              _sliderWidth = constraints.maxWidth;
                              return MouseRegion(
                                onEnter: (_) {
                                  _hoverExitTimer?.cancel();
                                  if (mounted && !_isSliderHovered) {
                                    setState(() => _isSliderHovered = true);
                                  }
                                },
                                onExit: (_) {
                                  _hoverExitTimer?.cancel();
                                  _hoverExitTimer = Timer(
                                    const Duration(milliseconds: 300),
                                    () {
                                      if (mounted) {
                                        setState(
                                          () => _isSliderHovered = false,
                                        );
                                        _hoverXNotifier.value = null;
                                      }
                                    },
                                  );
                                },
                                onHover: (event) {
                                  // Strictly show preview only when hovering over the progress bar (bottom area)
                                  // The track is at bottom: 20-30 of the 100px container (dy: 70-80)
                                  final dy = event.localPosition.dy;
                                  if (dy >= 65 &&
                                      dy <= 95 &&
                                      !_isHoveringMarker) {
                                    _hoverXNotifier.value =
                                        event.localPosition.dx;
                                  } else {
                                    _hoverXNotifier.value = null;
                                  }
                                },
                                child: CompositedTransformTarget(
                                  link: _sliderLink,
                                  key: _sliderKey,
                                  child: SizedBox(
                                    height:
                                        100, // Increased height for radial marker menu
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.bottomCenter,
                                      children: [
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom: 20, // Move slider up slightly
                                          child: StreamBuilder<Duration>(
                                            stream: player.stream.buffer,
                                            builder: (context, bufferSnapshot) {
                                              final bufferDuration =
                                                  bufferSnapshot.data ??
                                                  player.state.buffer;
                                              final bufferProgress =
                                                  duration.inMilliseconds > 0
                                                  ? bufferDuration
                                                            .inMilliseconds /
                                                        duration.inMilliseconds
                                                  : 0.0;
                                              return SliderTheme(
                                                data: SliderTheme.of(context)
                                                    .copyWith(
                                                      trackShape:
                                                          GradientRectSliderTrackShape(
                                                            gradient: AppTheme
                                                                .primaryGradient,
                                                            bufferProgress:
                                                                bufferProgress
                                                                    .clamp(
                                                                      0.0,
                                                                      1.0,
                                                                    ),
                                                          ),
                                                      activeTrackColor:
                                                          Colors.white,
                                                      inactiveTrackColor: Colors
                                                          .white
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                      thumbShape:
                                                          SliderComponentShape
                                                              .noThumb,
                                                      overlayShape:
                                                          SliderComponentShape
                                                              .noOverlay,
                                                      trackHeight: 10,
                                                    ),
                                                child: Slider(
                                                  value: progress.clamp(
                                                    0.0,
                                                    1.0,
                                                  ),
                                                  onChangeStart: (_) {
                                                    setState(() {
                                                      // 1. Explicitly kill all step-seek state

                                                      // 2. Kill all pending timers
                                                      _engineSeekTimer
                                                          ?.cancel();
                                                      _virtualSeekCleanupTimer
                                                          ?.cancel();
                                                      _fastSeekTimer?.cancel();

                                                      // 3. Initialize scrub state
                                                      _isScrubbing = true;
                                                      _wasPlayingBeforeScrub =
                                                          player.state.playing;
                                                    });
                                                    player.pause();
                                                  },
                                                  onChanged: (v) {
                                                    _onInteraction();
                                                    _showSeekIndicator();
                                                    final targetMs =
                                                        (v *
                                                                duration
                                                                    .inMilliseconds)
                                                            .toInt();
                                                    setState(() {
                                                      _virtualScrubPosition =
                                                          Duration(
                                                            milliseconds:
                                                                targetMs,
                                                          );
                                                      _pendingScrubPosition =
                                                          _virtualScrubPosition;
                                                    });
                                                    if (_scrubThrottleTimer
                                                            ?.isActive !=
                                                        true) {
                                                      _performSeek(
                                                        _pendingScrubPosition!,
                                                      );
                                                      _scrubThrottleTimer = Timer(
                                                        const Duration(
                                                          milliseconds: 100,
                                                        ),
                                                        () {
                                                          if (_pendingScrubPosition !=
                                                                  null &&
                                                              mounted &&
                                                              _isScrubbing) {
                                                            _performSeek(
                                                              _pendingScrubPosition!,
                                                            );
                                                          }
                                                        },
                                                      );
                                                    }
                                                  },
                                                  onChangeEnd: (v) {
                                                    _scrubThrottleTimer
                                                        ?.cancel();
                                                    _smartDelayTimer?.cancel();

                                                    // Final seek
                                                    _performSeek(
                                                      Duration(
                                                        milliseconds:
                                                            (v *
                                                                    duration
                                                                        .inMilliseconds)
                                                                .toInt(),
                                                      ),
                                                    );

                                                    if (_wasPlayingBeforeScrub) {
                                                      player.play();
                                                      _wasPlayingBeforeScrub =
                                                          false;
                                                    }

                                                    // Reset cleanup timer
                                                    _virtualSeekCleanupTimer
                                                        ?.cancel();
                                                    _virtualSeekCleanupTimer =
                                                        Timer(
                                                          const Duration(
                                                            seconds: 1,
                                                          ),
                                                          _cleanupVirtualSeeking,
                                                        );
                                                  },
                                                ),
                                              );
                                            },
                                          ),
                                        ),

                                        // EPX-009: Timeline Markers
                                        if (ref
                                                .watch(settingsProvider)
                                                .value
                                                ?.showMarkersOnTimeline ??
                                            true)
                                          ...ref
                                              .watch(
                                                videoMarkersProvider(
                                                  widget.currentItem.path,
                                                ),
                                              )
                                              .maybeWhen(
                                                data: (markers) => markers.map(
                                                  (m) => TimelineMarker(
                                                    marker: m,
                                                    totalDuration: duration,
                                                    sliderWidth: _sliderWidth,
                                                    videoPath:
                                                        widget.currentItem.path,
                                                    hoverXNotifier:
                                                        _hoverXNotifier,
                                                    isMarkerEditorActive: widget
                                                        .displayState
                                                        .isMarkerEditorActive,
                                                    onTap: () {
                                                      if (player.platform !=
                                                          null) {
                                                        (player.platform
                                                                as dynamic)
                                                            .setProperty(
                                                              'hr-seek',
                                                              'yes',
                                                            );
                                                      }
                                                      player.seek(m.timestamp);
                                                      player.play();
                                                      // Briefly keep high-precision seek active to ensure the frame is hit accurately
                                                      Future.delayed(
                                                        const Duration(
                                                          milliseconds: 200,
                                                        ),
                                                        () {
                                                          if (mounted &&
                                                              player.platform !=
                                                                  null) {
                                                            (player.platform
                                                                    as dynamic)
                                                                .setProperty(
                                                                  'hr-seek',
                                                                  'no',
                                                                );
                                                          }
                                                        },
                                                      );
                                                    },
                                                    onEdit: () => widget
                                                        .onOpenMarkerEditor(m),
                                                    onHoverChanged: (hovering) {
                                                      if (mounted) {
                                                        setState(
                                                          () =>
                                                              _isHoveringMarker =
                                                                  hovering,
                                                        );
                                                        if (hovering) {
                                                          _hideTimer?.cancel();
                                                        } else {
                                                          _onInteraction();
                                                        }
                                                      }
                                                    },
                                                    onMenuVisibilityChanged: (visible) {
                                                      if (mounted) {
                                                        widget
                                                            .onMarkerMenuVisibilityChanged(
                                                              visible,
                                                            );
                                                        if (visible) {
                                                          _onInteraction(); // Ensure HUD is visible when menu opens
                                                        } else {
                                                          _onInteraction(); // Start fade-out timer when menu closes
                                                        }
                                                      }
                                                    },
                                                  ),
                                                ),
                                                orElse: () => [],
                                              ),

                                        // BUG-001: Hover thumbnail preview
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom: 24,
                                          child: IgnorePointer(
                                            child: AnimatedOpacity(
                                              duration: const Duration(
                                                milliseconds: 150,
                                              ),
                                              opacity: _isSliderHovered
                                                  ? 1.0
                                                  : 0.0,
                                              child: HoverPreview(
                                                mediaPath:
                                                    widget.currentItem.path,
                                                totalDuration: duration,
                                                sliderWidth: _sliderWidth,
                                                hoverXNotifier: _hoverXNotifier,
                                                isVisible: _isSliderHovered,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 17),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _showRemainingTime = !_showRemainingTime;
                              });
                              final currentSettings = ref
                                  .read(settingsProvider)
                                  .value;
                              if (currentSettings != null) {
                                ref
                                    .read(settingsProvider.notifier)
                                    .saveSettings(
                                      currentSettings.copyWith(
                                        videoShowRemainingTime:
                                            _showRemainingTime,
                                      ),
                                    );
                              }
                            },
                            child: Text(
                              _showRemainingTime
                                  ? '-${_formatDuration(remaining)}'
                                  : _formatDuration(duration),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                // Control Buttons
                Row(
                  children: [
                    // Playlist button — always visible
                    Consumer(
                      builder: (context, sidebarRef, _) {
                        final isOpen = sidebarRef.watch(
                          videoPlaylistSidebarVisibleProvider,
                        );
                        return IconButton(
                          icon: const Icon(Icons.playlist_play, size: 24),
                          color: widget.displayState.isNetworkStream
                              ? Colors.white30
                              : (isOpen ? AppColors.magenta : Colors.white),
                          onPressed: widget.displayState.isNetworkStream
                              ? null
                              : () {
                                  sidebarRef
                                          .read(
                                            videoPlaylistSidebarVisibleProvider
                                                .notifier,
                                          )
                                          .state =
                                      !isOpen;
                                },
                          tooltip: 'Playlist',
                        );
                      },
                    ),

                    // All remaining left/center/right controls hidden in empty state
                    if (!widget.displayState.isEmpty) ...[ 
                      const SizedBox(width: 4),
                      if (!widget.displayState.isNetworkStream)
                        Consumer(
                          builder: (context, ref, _) {
                            final isFavorite = ref
                                .watch(videoFavoritesProvider)
                                .contains(widget.currentItem.path);
                            return IconButton(
                              icon: Icon(
                                isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 22,
                              ),
                              color: isFavorite
                                  ? AppColors.magenta
                                  : Colors.white70,
                              onPressed: () {
                                ref
                                    .read(videoFavoritesProvider.notifier)
                                    .toggleFavorite(widget.currentItem.path);
                              },
                              tooltip: isFavorite
                                  ? 'Remove from Favorites'
                                  : 'Add to Favorites',
                            );
                          },
                        ),
                      if (!widget.displayState.isNetworkStream)
                        const SizedBox(width: 4),
                      if (!widget.displayState.isNetworkStream)
                        Consumer(
                          builder: (context, ref, _) {
                            final isAutoPlay = ref.watch(
                              videoAutoPlaySessionProvider,
                            );
                            return IconButton(
                              icon: Icon(
                                isAutoPlay
                                    ? Icons.autorenew_rounded
                                    : Icons.sync_disabled_rounded,
                                size: 22,
                              ),
                              color: isAutoPlay
                                  ? AppColors.magenta
                                  : Colors.white70,
                              onPressed: () {
                                final newState = !isAutoPlay;
                                ref
                                        .read(
                                          videoAutoPlaySessionProvider.notifier,
                                        )
                                        .state =
                                    newState;

                                if (newState) {
                                  if (player.state.completed) {
                                    widget.onNavigateMedia(true);
                                  } else if (player
                                                  .state
                                                  .duration
                                                  .inMilliseconds >
                                              0 &&
                                      (player.state.position.inMilliseconds >=
                                          player.state.duration.inMilliseconds -
                                              500)) {
                                    widget.onNavigateMedia(true);
                                  }
                                }
                              },
                              tooltip: isAutoPlay
                                  ? 'Autoplay Next: ON'
                                  : 'Autoplay Next: OFF',
                            );
                          },
                        ),
                      if (!widget.displayState.isNetworkStream)
                        const SizedBox(width: 4),
                      IconButton(
                        key: widget.subtitleKey,
                        onPressed: () {
                          _onInteraction();
                          widget.onShowMenu(
                            key: widget.subtitleKey,
                            type: 'subtitle',
                            child: StreamBuilder<dynamic>(
                              stream: player.stream.track,
                              builder: (context, snapshot) {
                                final state = snapshot.data ?? player.state.track;
                                return TrackSelectorMenu(
                                  title: 'Subtitles',
                                  subtitleTracks: player.state.tracks.subtitle,
                                  selectedTrack: state.subtitle,
                                  onTrackSelected: (t) {
                                    player.setSubtitleTrack(t as SubtitleTrack);
                                  },
                                  onLoadExternal: () async {
                                    final result =
                                        await CustomFilePickerDialog.show(
                                          context,
                                          title: 'SELECT SUBTITLE',
                                          allowedExtensions: [
                                            'srt',
                                            'vtt',
                                            'ass',
                                          ],
                                        );
                                    if (result != null && result.isNotEmpty) {
                                      player.setSubtitleTrack(
                                        SubtitleTrack.uri(result.first),
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.subtitles_outlined,
                          color: widget.displayState.isSubtitleMenuVisible
                              ? AppColors.violet
                              : Colors.white70,
                          size: 20,
                        ),
                        tooltip: 'Subtitles',
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        key: widget.audioKey,
                        onPressed: () {
                          _onInteraction();
                          widget.onShowMenu(
                            key: widget.audioKey,
                            type: 'audio',
                            child: StreamBuilder<dynamic>(
                              stream: player.stream.track,
                              builder: (context, snapshot) {
                                final state = snapshot.data ?? player.state.track;
                                return TrackSelectorMenu(
                                  title: 'Audio Tracks',
                                  audioTracks: player.state.tracks.audio,
                                  selectedTrack: state.audio,
                                  onTrackSelected: (t) {
                                    player.setAudioTrack(t as AudioTrack);
                                  },
                                );
                              },
                            ),
                          );
                        },
                        icon: Icon(
                          Icons.audiotrack_rounded,
                          color: widget.displayState.isAudioMenuVisible
                              ? AppColors.violet
                              : Colors.white70,
                          size: 20,
                        ),
                        tooltip: 'Audio Tracks',
                      ),

                      const Spacer(),

                      // Center cluster
                      IconButton(
                        onPressed: () => widget.onNavigateMedia(false),
                        icon: const Icon(
                          Icons.skip_previous,
                          color: Colors.white,
                          size: 24,
                        ),
                        tooltip: 'Previous Video',
                      ),
                      const SizedBox(width: 8),
                      _buildSeekButton(
                        isForward: false,
                        onPressed: () => _performStepSeek(isForward: false),
                      ),
                      const SizedBox(width: 16),
                      ValueListenableBuilder<bool>(
                        valueListenable: widget.playingNotifier,
                        builder: (context, playing, _) {
                          return GestureDetector(
                            onTap: () {
                              _onInteraction();
                              player.playOrPause();
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Icon(
                                playing ? Icons.pause : Icons.play_arrow,
                                color: Colors.black,
                                size: 28,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 16),
                      _buildSeekButton(
                        isForward: true,
                        onPressed: () => _performStepSeek(isForward: true),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => widget.onNavigateMedia(true),
                        icon: const Icon(
                          Icons.skip_next,
                          color: Colors.white,
                          size: 24,
                        ),
                        tooltip: 'Next Video',
                      ),

                      const Spacer(),

                      // Right: Speed, Volume, Fullscreen
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.displayState.isNetworkStream &&
                              widget.availableFormats.isNotEmpty) ...[
                            PopupMenuButton<MediaFormat>(
                              key: widget.resolutionKey,
                              initialValue: widget.availableFormats.firstWhere(
                                (f) => f.formatId == widget.selectedFormatId,
                                orElse: () => widget.availableFormats.first,
                              ),
                              onSelected: widget.onResolutionChanged,
                              tooltip: 'Video Resolution',
                              color: const Color(0xFF2A2A35),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              offset: const Offset(0, -10),
                              itemBuilder: (context) {
                                return widget.availableFormats.map((f) {
                                  final isSelected =
                                      f.formatId == widget.selectedFormatId;
                                  return PopupMenuItem<MediaFormat>(
                                    value: f,
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isSelected
                                              ? Icons.check
                                              : Icons.circle,
                                          color: isSelected
                                              ? AppColors.violet
                                              : Colors.transparent,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          f.resolution,
                                          style: GoogleFonts.manrope(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList();
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.availableFormats
                                        .firstWhere(
                                          (f) =>
                                              f.formatId ==
                                              widget.selectedFormatId,
                                          orElse: () =>
                                              widget.availableFormats.first,
                                        )
                                        .resolution,
                                    style: GoogleFonts.manrope(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          TextButton(
                            key: widget.speedKey,
                            onPressed: () {
                              _onInteraction();
                              widget.onShowMenu(
                                key: widget.speedKey,
                                type: 'speed',
                                child: PlaybackSpeedControl(
                                  currentSpeed: widget.playbackSpeed,
                                  onSpeedSelected: (speed) {
                                    player.setRate(speed);
                                  },
                                ),
                              );
                            },
                            child: Text(
                              '${widget.playbackSpeed.toString().replaceAll(RegExp(r'\.0$'), '')}x',
                              style: GoogleFonts.manrope(
                                color: widget.displayState.isSpeedMenuVisible
                                    ? AppColors.violet
                                    : Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: widget.onToggleMute,
                            icon: Icon(
                              widget.displayState.isMuted
                                  ? Icons.volume_off
                                  : Icons.volume_up,
                              color: Colors.white70,
                              size: 24,
                            ),
                          ),
                          SizedBox(
                            width: 80,
                            child: StreamBuilder<double>(
                              stream: player.stream.volume,
                              builder: (context, snapshot) {
                                final volume = snapshot.data ?? 100.0;
                                return SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 2,
                                    activeTrackColor: volume > 100
                                        ? Colors.orange
                                        : Colors.white,
                                    inactiveTrackColor:
                                        Colors.white.withValues(alpha: 0.2),
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 3,
                                    ),
                                    overlayShape:
                                        const RoundSliderOverlayShape(
                                          overlayRadius: 6,
                                        ),
                                  ),
                                  child: Slider(
                                    value: volume.clamp(0.0, 200.0),
                                    max: 200,
                                    onChanged: (v) => player.setVolume(v),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: widget.onToggleFullscreen,
                            icon: Icon(
                              Icons.fullscreen_rounded,
                              color: Colors.white70,
                              size: 22,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
