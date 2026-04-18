import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/gradient_slider_track.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/video_volume_overlay.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'dart:convert';

class VideoPreviewWidget extends ConsumerStatefulWidget {
  const VideoPreviewWidget({
    required this.item, 
    this.initialPosition,
    this.isStandalone = false,
    super.key,
  });

  final FileItem item;
  final Duration? initialPosition;
  final bool isStandalone;

  @override
  ConsumerState<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends ConsumerState<VideoPreviewWidget> with WindowListener {
  late final Player player;
  late final VideoController controller;
  bool _isMuted = false;
  bool _isControlsVisible = true;
  bool _showRemainingTime = false;
  bool _isVolumeOverlayVisible = false;
  bool _isSeekingToInitial = false;
  double? _fps;
  Timer? _hideTimer;
  Timer? _fastSeekTimer;
  Timer? _volumeTimer;
  Timer? _volumeOverlayTimer;
  DateTime? _lastManualHide;
  StreamSubscription? _trackSubscription;
  StreamSubscription? _completedSubscription;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.isStandalone) {
      // Start the pop-out window in a maximized state by default
      windowManager.maximize();
      // No listener needed as GTK handles closure naturally
    }
    
    player = Player();
    controller = VideoController(player);
    player.open(Media(widget.item.path));
    
    // Resume from initial position if provided
    if (widget.initialPosition != null) {
      debugPrint('[VideoPlayer] Target initial position: ${widget.initialPosition}');
      setState(() => _isSeekingToInitial = true);
      
      // Wait for player to be truly ready for seeking
      player.stream.duration.firstWhere((d) => d > Duration.zero).then((_) async {
        // Small stability delay to ensure engine-level media initialization
        await Future.delayed(const Duration(milliseconds: 200));
        
        if (mounted) {
          debugPrint('[VideoPlayer] Applying seek to ${widget.initialPosition}');
          await player.seek(widget.initialPosition!);
          
          setState(() {
            _isSeekingToInitial = false;
            // Initially hide controls for a clean startup
            _isControlsVisible = false;
          });
        }
      });
    }
    
    _trackSubscription = player.stream.track.listen((_) {
      _fetchFps();
    });

    _completedSubscription = player.stream.completed.listen((completed) {
      if (completed && widget.isStandalone) {
        windowManager.close();
      }
    });

    _startHideTimer();
    _fetchFps(); // Initial fetch
    
    // Request focus for keyboard shortcuts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _toggleFullscreen() async {
    final isFullScreen = await windowManager.isFullScreen();
    final newFullScreen = !isFullScreen;
    await windowManager.setFullScreen(newFullScreen);
    if (newFullScreen) {
      setState(() {
        _isControlsVisible = false;
        _hideTimer?.cancel();
      });
    } else {
      // Reveal controls when exiting fullscreen (returning to system UI)
      _onInteraction(forceShow: true);
    }
  }

  // onWindowClose removal - relying on standard widget lifecycle for stability

  @override
  void dispose() {
    if (widget.isStandalone) {
      // No listener to remove anymore
    }
    _hideTimer?.cancel();
    _fastSeekTimer?.cancel();
    _volumeTimer?.cancel();
    _volumeOverlayTimer?.cancel();
    _trackSubscription?.cancel();
    _completedSubscription?.cancel();
    _focusNode.dispose();
    if (!widget.isStandalone) {
      player.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchFps() async {
    try {
      // Small delay to allow mpv to parse container metadata
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Attempt to get FPS from track state first (high-level)
      double? fps = player.state.track.video.fps;
      
      // Fallback to native property if high-level is null
      if (fps == null) {
        final dynamic platform = player.platform;
        // Accessing getProperty via dynamic to avoid platform-specific import issues
        // while still reaching libmpv's container-fps
        final dynamic result = await platform.getProperty('container-fps');
        if (result is num) {
          fps = result.toDouble();
        } else if (result is String) {
          fps = double.tryParse(result);
        }
      }
      
      if (mounted && fps != null && fps > 0) {
        setState(() => _fps = fps);
      }
    } catch (e) {
      debugPrint('Error fetching FPS: $e');
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isControlsVisible = false);
      }
    });
  }

  void _showVolumeOverlay() {
    _volumeOverlayTimer?.cancel();
    setState(() => _isVolumeOverlayVisible = true);
    _volumeOverlayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isVolumeOverlayVisible = false);
      }
    });
  }

  void _onInteraction({bool forceShow = false}) {
    // Grace period check: If manually hidden in the last 2 seconds, ignore hover unless forceShow
    if (!forceShow && _lastManualHide != null && 
        DateTime.now().difference(_lastManualHide!) < const Duration(seconds: 2)) {
      return;
    }

    if (!_isControlsVisible) {
      setState(() => _isControlsVisible = true);
    }
    _startHideTimer();
  }

  void _toggleControls({bool isKeyboard = false}) {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
      if (!_isControlsVisible) {
        // Only implement grace period for button hide, not keyboard 'F' hide
        if (!isKeyboard) {
          _lastManualHide = DateTime.now();
        } else {
          _lastManualHide = null;
        }
      } else {
        _lastManualHide = null; // Reset if shown manually
        _startHideTimer();
      }
    });
  }

  Future<void> _openInNewWindow() async {
    final position = player.state.position.inMilliseconds;
    
    // Prepare arguments
    final args = {
      'file': {
        'name': widget.item.name,
        'path': widget.item.path,
        'sizeBytes': widget.item.sizeBytes,
        'modified': widget.item.modified.millisecondsSinceEpoch,
      },
      'position': position,
    };

    try {
      // Create new window
      final window = await WindowController.create(
        WindowConfiguration(arguments: jsonEncode(args)),
      );
      
      // Window is hidden at launch by default in 0.3.0, call show.
      await window.show();

      // Close current preview
      if (mounted) {
        ref.read(previewFileProvider.notifier).state = null;
      }
    } catch (e) {
      debugPrint('Error opening new window: $e');
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      player.setVolume(_isMuted ? 0 : 100);
    });
  }

  void _startVolumeAdjustment({required bool isIncrease}) {
    player.setVolume((player.state.volume + (isIncrease ? 5 : -5)).clamp(0, 100));
    _showVolumeOverlay();
    
    _volumeTimer?.cancel();
    _volumeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      player.setVolume((player.state.volume + (isIncrease ? 2 : -2)).clamp(0, 100));
      _showVolumeOverlay();
    });
  }

  void _stopVolumeAdjustment() {
    _volumeTimer?.cancel();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        player.playOrPause();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _startFastSeek(isForward: false);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _startFastSeek(isForward: true);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _startVolumeAdjustment(isIncrease: true);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _startVolumeAdjustment(isIncrease: false);
      } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
        if (widget.isStandalone) {
          _toggleFullscreen();
        } else {
          // In preview mode, 'F' just toggles UI visibility for a clean look
          _toggleControls(isKeyboard: true);
        }
      } else if (event.logicalKey == LogicalKeyboardKey.keyW && HardwareKeyboard.instance.isControlPressed) {
        ref.read(previewFileProvider.notifier).state = null;
        ref.read(navigationProvider.notifier).goBack();
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _stopFastSeek();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                 event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _stopVolumeAdjustment();
      }
    }
  }

  void _startFastSeek({required bool isForward}) {
    _fastSeekTimer?.cancel();
    // Initial seek
    player.seek(player.state.position + Duration(seconds: isForward ? 5 : -5));
    
    _fastSeekTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      player.seek(player.state.position + Duration(seconds: isForward ? 10 : -10));
    });
  }

  void _stopFastSeek() {
    _fastSeekTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: Container(
          color: Colors.black,
          child: Stack(
            children: [
              // Interaction Trigger Zone (Full Viewport)
              Positioned.fill(
                child: MouseRegion(
                  onEnter: (_) => _onInteraction(),
                  onHover: (_) => _onInteraction(),
                  child: Stack(
                    children: [
                      // Video Player
                      Center(
                        child: Video(
                          controller: controller,
                          controls: (state) => const SizedBox.shrink(),
                        ),
                      ),

                      // Bubble Loader during initial seek
                      if (_isSeekingToInitial)
                        const BubbleLoader(size: 100),
                    ],
                  ),
                ),
              ),
              
              // Volume Overlay (Right side)
              Positioned(
                right: 32,
                top: 0,
                bottom: 0,
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _isVolumeOverlayVisible ? 1.0 : 0.0,
                    child: StreamBuilder<double>(
                      stream: player.stream.volume,
                      builder: (context, snapshot) {
                        final vol = snapshot.data ?? player.state.volume;
                        return VideoVolumeOverlay(
                          volume: vol,
                          onVolumeChanged: (v) => player.setVolume(v),
                        );
                      }
                    ),
                  ),
                ),
              ),

              // Top HUD (Title & Metadata)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _isControlsVisible ? 1.0 : 0.0,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.item.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            StreamBuilder<int?>(
                              stream: player.stream.width,
                              builder: (context, _) {
                                final state = player.state;
                                final res = '${state.height}p';
                                final fpsString = _fps != null ? ' • ${_fps!.toInt()} FPS' : '';
                                return Text(
                                  '$res$fpsString',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (!widget.isStandalone) ...[
                          IconButton(
                            onPressed: _openInNewWindow,
                            icon: const Icon(Icons.open_in_new, color: Colors.white, size: 20),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.1),
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (!widget.isStandalone)
                          Consumer(
                            builder: (context, ref, child) {
                              return IconButton(
                                onPressed: () => ref.read(previewFileProvider.notifier).state = null,
                                icon: const Icon(Icons.close, color: Colors.white, size: 24),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.white.withOpacity(0.1),
                                  padding: const EdgeInsets.all(12),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Custom Bottom Controls
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _isControlsVisible ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: !_isControlsVisible,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.8),
                            Colors.black.withOpacity(0.4),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Progress Slider & Timers Row
                          StreamBuilder<Duration>(
                            stream: player.stream.position,
                            builder: (context, snapshot) {
                              final position = snapshot.data ?? Duration.zero;
                              final duration = player.state.duration;
                              final remaining = duration - position;
                              final progress = duration.inMilliseconds > 0 
                                ? position.inMilliseconds / duration.inMilliseconds 
                                : 0.0;
                              
                              return Row(
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: SliderTheme(
                                      data: SliderTheme.of(context).copyWith(
                                        trackShape: GradientRectSliderTrackShape(gradient: AppTheme.primaryGradient),
                                        activeTrackColor: Colors.white,
                                        inactiveTrackColor: Colors.white.withOpacity(0.1),
                                        thumbShape: SliderComponentShape.noThumb,
                                        overlayShape: SliderComponentShape.noOverlay,
                                        trackHeight: 10.0,
                                      ),
                                      child: Slider(
                                        value: progress.clamp(0.0, 1.0),
                                        onChanged: (v) {
                                          _onInteraction();
                                          player.seek(Duration(milliseconds: (v * duration.inMilliseconds).toInt()));
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  GestureDetector(
                                    onTap: () => setState(() => _showRemainingTime = !_showRemainingTime),
                                    child: Text(
                                      _showRemainingTime ? '-${_formatDuration(remaining)}' : _formatDuration(duration),
                                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
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
                              // Left: Playlist & Subtitles
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.playlist_play, color: Colors.white70, size: 24),
                                tooltip: 'Playlist',
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.subtitles_outlined, color: Colors.white70, size: 20),
                                tooltip: 'Subtitles',
                              ),
                              
                              const Spacer(),
                              
                              // Center cluster
                              IconButton(
                                onPressed: () => player.seek(player.state.position - const Duration(seconds: 10)),
                                icon: const Icon(Icons.replay_10, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 16),
                              StreamBuilder<bool>(
                                stream: player.stream.playing,
                                builder: (context, snapshot) {
                                  final playing = snapshot.data ?? false;
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
                                            color: Colors.white.withOpacity(0.2),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          )
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
                              IconButton(
                                onPressed: () => player.seek(player.state.position + const Duration(seconds: 10)),
                                icon: const Icon(Icons.forward_10, color: Colors.white, size: 20),
                              ),
                              
                              const Spacer(),
                              
                              // Right: Volume, Settings, Fullscreen
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    onPressed: _toggleMute,
                                    icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white70, size: 24),
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
                                            activeTrackColor: Colors.white,
                                            inactiveTrackColor: Colors.white.withOpacity(0.2),
                                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 3),
                                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 6),
                                          ),
                                          child: Slider(
                                            value: volume,
                                            max: 100,
                                            onChanged: (v) => player.setVolume(v),
                                          ),
                                        );
                                      }
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    onPressed: () {},
                                    icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 20),
                                  ),
                                  IconButton(
                                    onPressed: _toggleControls,
                                    icon: Icon(_isControlsVisible ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white70, size: 20),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String mn = twoDigits(duration.inMinutes.remainder(60));
    String sc = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return "${twoDigits(duration.inHours)}:$mn:$sc";
    }
    return "$mn:$sc";
  }
}
