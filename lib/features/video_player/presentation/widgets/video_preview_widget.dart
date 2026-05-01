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
import 'package:onyxcore/core/widgets/viewer_top_bar.dart';
import 'package:window_manager/window_manager.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/core/window_management/window_controller_extension.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'dart:convert';
import 'package:onyxcore/core/utils/file_type_classifier.dart';

class VideoPreviewWidget extends ConsumerStatefulWidget {
  const VideoPreviewWidget({
    required this.item, 
    this.initialPosition,
    this.isStandalone = false,
    this.windowId,
    this.parentWindowId,
    super.key,
  });

  final FileItem item;
  final Duration? initialPosition;
  final bool isStandalone;
  final String? windowId;
  final String? parentWindowId;

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
  bool _isClosing = false;
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
      // Standardize standalone window behavior
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
      windowManager.maximize();
      // Initialize title bar style for standalone mode
      windowManager.setTitleBarStyle(TitleBarStyle.hidden);
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
    final willBeFullScreen = !isFullScreen;
    
    await windowManager.setFullScreen(willBeFullScreen);
    if (willBeFullScreen) {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      setState(() {
        _isControlsVisible = false;
        _hideTimer?.cancel();
      });
    } else {
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      // Reveal controls when exiting fullscreen (returning to system UI)
      _onInteraction(forceShow: true);
    }
  }

  @override
  void didUpdateWidget(VideoPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path) {
      // Safely swap media: pause first, then open new media
      player.pause().then((_) {
        player.open(Media(widget.item.path));
        _fetchFps();
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  @override
  void onWindowClose() async {
    if (_isClosing || !widget.isStandalone) return;
    
    // In Persistent Viewer architecture, we just pause and hide.
    // The SecondaryWindowApp handles the actual hide logic via windowManager.
    debugPrint('[VideoPlayer] standalone hiding triggered.');
    try {
      await player.pause();
    } catch (e) {
      debugPrint('[VideoPlayer] Error pausing on hide: $e');
    }
  }

  @override
  void dispose() {
    if (widget.isStandalone) {
      windowManager.removeListener(this);
    }
    _hideTimer?.cancel();
    _fastSeekTimer?.cancel();
    _volumeTimer?.cancel();
    _volumeOverlayTimer?.cancel();
    _trackSubscription?.cancel();
    _completedSubscription?.cancel();
    _focusNode.dispose();
    player.dispose();
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
    
    // Pause immediately to avoid dual-playback audio overlap
    await player.pause();
    
    final windowParams = WindowParams(
      viewerType: ViewerType.video,
      file: widget.item,
      initParams: {
        'startPositionMs': position,
      },
    );

    try {
      // Use the singleton manager to handle persistent window logic
      await PersistentViewerManager.openMedia(windowParams);

      if (mounted) {
        ref.read(previewFileProvider.notifier).state = null;
      }
    } catch (e) {
      debugPrint('Error opening persistent viewer: $e');
      await player.play(); // Rescue playback on failure
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      player.setVolume(_isMuted ? 0 : 100);
    });
  }

  void _startVolumeAdjustment({required bool isIncrease}) {
    player.setVolume((player.state.volume + (isIncrease ? 5 : -5)).clamp(0, 200));
    _showVolumeOverlay();
    
    _volumeTimer?.cancel();
    _volumeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      player.setVolume((player.state.volume + (isIncrease ? 2 : -2)).clamp(0, 200));
      _showVolumeOverlay();
    });
  }

  void _stopVolumeAdjustment() {
    _volumeTimer?.cancel();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (_isClosing) return;
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
        }
        // Preview 'F' is now handled by PreviewContainer globally
      } else if (event.logicalKey == LogicalKeyboardKey.keyW && HardwareKeyboard.instance.isControlPressed) {
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

  void _navigateMedia(bool forward) {
    if (widget.windowId != null) {
      // 1. Standalone Mode: Send reverse IPC to Main Window (Window 0)
      final payload = jsonEncode({
        'direction': forward ? 'next' : 'prev',
        'currentPath': widget.item.path,
        'type': 'video',
        'targetWindowId': widget.windowId!,
      });
      WindowController.fromWindowId(widget.parentWindowId ?? '0').invokeMethod('request_navigation', payload);
    } else {
      // 2. Inline Mode: Local Riverpod state update
      final items = ref.read(directoryItemsProvider).value ?? [];
      if (items.isEmpty) return;

      final mediaItems = items.where((i) => i.type == FileItemType.video).toList();
      if (mediaItems.isEmpty) return;

      final currentIndex = mediaItems.indexWhere((i) => i.path == widget.item.path);
      if (currentIndex == -1) return;

      int nextIndex;
      if (forward) {
        nextIndex = (currentIndex + 1) % mediaItems.length;
      } else {
        nextIndex = (currentIndex - 1 + mediaItems.length) % mediaItems.length;
      }

      ref.read(previewFileProvider.notifier).state = mediaItems[nextIndex];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGlobalHudVisible = widget.windowId == null ? ref.watch(previewHudVisibleProvider) : true;
    final isVisible = _isControlsVisible && isGlobalHudVisible;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        _handleKeyEvent(event);
        return KeyEventResult.handled;
      },
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        onDoubleTap: !widget.isStandalone ? _openInNewWindow : null,
        child: Container(
          color: Colors.black,
          child: Stack(
            children: [
              // Interaction Trigger Zone (Full Viewport)
              Positioned.fill(
                child: MouseRegion(
                  cursor: isVisible ? MouseCursor.defer : SystemMouseCursors.none,
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

              // Top HUD (Standardized)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isVisible ? 1.0 : 0.0,
                  child: StreamBuilder<int?>(
                    stream: player.stream.width,
                    builder: (context, _) {
                      final state = player.state;
                      final res = (state.height ?? 0) > 0 ? '${state.height}p' : 'Loading...';
                      final fpsString = _fps != null ? ' • ${_fps!.toInt()} FPS' : '';
                      
                      return ViewerTopBar(
                        title: widget.item.name,
                        metadata: '$res$fpsString',
                        isStandalone: widget.isStandalone,
                        onPopOut: _openInNewWindow,
                        onClose: () => ref.read(previewFileProvider.notifier).state = null,
                      );
                    },
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
                                onPressed: () => _navigateMedia(false),
                                icon: const Icon(Icons.skip_previous, color: Colors.white, size: 24),
                                tooltip: 'Previous Video',
                              ),
                              const SizedBox(width: 8),
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
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => _navigateMedia(true),
                                icon: const Icon(Icons.skip_next, color: Colors.white, size: 24),
                                tooltip: 'Next Video',
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
                                    width: 100,
                                    child: StreamBuilder<double>(
                                      stream: player.stream.volume,
                                      builder: (context, snapshot) {
                                        final volume = snapshot.data ?? 100.0;
                                        return SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            trackHeight: 2,
                                            activeTrackColor: volume > 100 ? Colors.orange : Colors.white,
                                            inactiveTrackColor: Colors.white.withOpacity(0.2),
                                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 3),
                                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 6),
                                          ),
                                          child: Slider(
                                            value: volume.clamp(0.0, 200.0),
                                            min: 0,
                                            max: 200,
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
