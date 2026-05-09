import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:media_kit_video/media_kit_video.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/gradient_slider_track.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/video_volume_overlay.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/track_selector_menu.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/playback_speed_control.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/playlist_overlay.dart';
import 'package:onyxcore/features/video_player/data/repositories/playback_memory_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/features/settings/presentation/widgets/settings_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/core/widgets/viewer_top_bar.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:window_manager/window_manager.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/core/window_management/window_controller_extension.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';

class VideoPreviewWidget extends ConsumerStatefulWidget {
  const VideoPreviewWidget({
    required this.item,
    this.initialPosition,
    this.initialRate,
    this.initialAudioTrackId,
    this.initialSubtitleTrackId,
    this.isStandalone = false,
    this.windowId,
    this.parentWindowId,
    this.initParams,
    super.key,
  });

  final FileItem item;
  final Duration? initialPosition;
  final double? initialRate;
  final String? initialAudioTrackId;
  final String? initialSubtitleTrackId;
  final bool isStandalone;
  final String? windowId;
  final String? parentWindowId;
  final Map<String, dynamic>? initParams;

  @override
  ConsumerState<VideoPreviewWidget> createState() => _VideoPreviewWidgetState();
}

class _VideoPreviewWidgetState extends ConsumerState<VideoPreviewWidget>
    with WindowListener, WidgetsBindingObserver {
  late final Player player;
  late final VideoController controller;
  late FileItem _currentItem;
  bool _isMuted = false;
  List<FileItem> _standalonePlaylist = [];
  bool _isControlsVisible = true;
  bool _showRemainingTime = false;
  bool _isVolumeOverlayVisible = false;
  bool _isSeekingToInitial = false;
  bool _isClosing = false;
  bool _isPlaylistVisible = false;
  bool _isAudioMenuVisible = false;
  bool _isSubtitleMenuVisible = false;
  bool _isSpeedMenuVisible = false;
  double _playbackSpeed = 1.0;
  double? _fps;
  Timer? _hideTimer;
  Timer? _fastSeekTimer;
  Timer? _volumeTimer;
  Timer? _volumeOverlayTimer;
  Timer? _seekIndicatorTimer;
  LogicalKeyboardKey? _activeSeekKey;
  LogicalKeyboardKey? _activeVolumeKey;
  bool _isSeekIndicatorVisible = false;
  bool _isOpening = false;
  bool _isBuffering = false;
  StreamSubscription? _trackSubscription;
  StreamSubscription? _completedSubscription;
  StreamSubscription? _bufferingSubscription;
  StreamSubscription? _errorSubscription;
  bool _showFlash = false;
  bool _showSnapshotToast = false;
  Timer? _snapshotToastTimer;
  StreamSubscription? _audioTrackInitSubscription;
  StreamSubscription? _subtitleTrackInitSubscription;

  late final GlobalKey _audioKey;
  late final GlobalKey _subtitleKey;
  late final GlobalKey _speedKey;
  late final GlobalKey _playlistKey;

  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _activeMenuEntry;

  bool get _isAnyMenuVisible =>
      _isAudioMenuVisible ||
      _isSubtitleMenuVisible ||
      _isSpeedMenuVisible ||
      _isPlaylistVisible;

  bool _isGlobalHudVisible = true;
  Offset? _doubleTapPosition;

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _playbackSpeed = widget.initialRate ?? 1.0;
    _isGlobalHudVisible = ref.read(previewHudVisibleProvider);

    if (widget.windowId != null || widget.isStandalone) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
      // Ensure true fullscreen to hide OS bars
      windowManager.setFullScreen(true);
      windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      
      // Initialize playlist from passed arguments if available
      if (widget.initParams?.containsKey('playlistJson') == true) {
        try {
          final List<dynamic> list = jsonDecode(
            widget.initParams!['playlistJson'],
          );
          _standalonePlaylist = list.map((e) => FileItem.fromJson(e)).toList();
        } catch (e) {
          debugPrint('[VideoPlayer] Error parsing standalone playlist: $e');
        }
      } else {
        _initStandalonePlaylist();
      }
    }
    WidgetsBinding.instance.addObserver(this);

    _currentItem = widget.item;
    player = Player();
    
    _audioKey = GlobalKey(debugLabel: 'video_audio_${widget.item.path}');
    _subtitleKey = GlobalKey(debugLabel: 'video_subtitle_${widget.item.path}');
    _speedKey = GlobalKey(debugLabel: 'video_speed_${widget.item.path}');
    _playlistKey = GlobalKey(debugLabel: 'video_playlist_${widget.item.path}');
    
    // Configure buffering properties for smooth seeking and performance
    if (player.platform is dynamic) {
      final dynamic platform = player.platform;
      platform.setProperty('demuxer-readahead-secs', '60');
      platform.setProperty('buffer-size', '134217728'); // 128MB
      platform.setProperty('cache', 'yes');
      platform.setProperty('cache-secs', '60');
      platform.setProperty('cache-pause', 'no');
      platform.setProperty('hr-seek', 'yes');
      platform.setProperty('hr-seek-framedrop', 'yes');
    }

    controller = VideoController(player);
    
    _isOpening = true;
    
    // Ensure the loader is rendered and animating before engine-level open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Increased delay to 300ms to ensure UI isolate is free and animation is running
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          player.open(Media(_currentItem.path), play: true).then((_) {
            if (mounted) setState(() => _isOpening = false);
          });
        }
      });
    });

    // Resume from initial position if provided
    if (widget.initialPosition != null) {
      debugPrint(
        '[VideoPlayer] Target initial position: ${widget.initialPosition}',
      );
      setState(() => _isSeekingToInitial = true);

      // Wait for player to be truly ready for seeking
      player.stream.duration.firstWhere((d) => d > Duration.zero).then((
        _,
      ) async {
        // Small stability delay to ensure engine-level media initialization
        await Future.delayed(const Duration(milliseconds: 200));

        if (mounted) {
          debugPrint(
            '[VideoPlayer] Applying seek to ${widget.initialPosition}',
          );
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
      if (completed) {
        final settings = ref.read(settingsProvider).value;
        final autoPlay = settings?.autoPlayNext ?? true;
        if (autoPlay) {
          _navigateMedia(true);
        } else {
          player.pause();
        }
      }
    });

    _bufferingSubscription = player.stream.buffering.listen((buffering) {
      if (mounted && _isBuffering != buffering) {
        setState(() => _isBuffering = buffering);
      }
    });

    _errorSubscription = player.stream.error.listen((error) {
      debugPrint('[VideoPlayer] Engine Error: $error');
      if (mounted) {
        setState(() {
          _isOpening = false;
          _isBuffering = false;
          _isSeekingToInitial = false;
        });
      }
    });

    _startHideTimer();
    _fetchFps(); // Initial fetch

    // Module 2 & External Subs
    _initMedia();

    // Request focus for keyboard shortcuts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();

      // Apply initial tracks and rate if provided
      if (widget.initialRate != null) {
        setState(() => _playbackSpeed = widget.initialRate!);
        player.setRate(widget.initialRate!);
      }
      if (widget.initialAudioTrackId != null) {
        // Find the track by ID once tracks are loaded
        _audioTrackInitSubscription = player.stream.tracks.listen((tracks) {
          if (tracks.audio.isNotEmpty) {
            final track = tracks.audio.firstWhere(
              (t) => t.id == widget.initialAudioTrackId,
              orElse: () => tracks.audio.first,
            );
            player.setAudioTrack(track);
            // Only apply once
            _audioTrackInitSubscription?.cancel();
            _audioTrackInitSubscription = null;
          }
        });
      }
      if (widget.initialSubtitleTrackId != null) {
        _subtitleTrackInitSubscription = player.stream.tracks.listen((tracks) {
          if (tracks.subtitle.isNotEmpty) {
            final track = tracks.subtitle.firstWhere(
              (t) => t.id == widget.initialSubtitleTrackId,
              orElse: () => tracks.subtitle.first,
            );
            player.setSubtitleTrack(track);
            // Only apply once
            _subtitleTrackInitSubscription?.cancel();
            _subtitleTrackInitSubscription = null;
          }
        });
      }
    });
  }

  Future<void> _loadMedia(FileItem item) async {
    if (_isClosing) return;

    // 1. Save current position
    await _savePlaybackPosition();

    // 2. Update state
    setState(() {
      _currentItem = item;
      _fps = null;
    });

    // 3. Open new media
    setState(() => _isOpening = true);
    
    // Give the UI time to render the loader before engine init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 100), () async {
        if (mounted) {
          await player.open(Media(item.path), play: true);
          if (mounted) setState(() => _isOpening = false);
        }
      });
    });

    // 4. Initialize new media (subs, memory)
    _initMedia();

    _onInteraction();
  }

  Future<void> _initMedia() async {
    final currentPath = _currentItem.path;
    
    // 1. External Subtitles
    _loadExternalSubtitles();

    // 2. Playback Memory
    final settings = ref.read(settingsProvider).value;
    if (settings?.resumePlayback ?? true) {
      final savedPos = await PlaybackMemoryRepository.getPosition(
        currentPath,
      );
      if (savedPos != null && savedPos > 0 && widget.initialPosition == null) {
        debugPrint('[VideoPlayer] Resuming from saved position: $savedPos');
        try {
          // Add 5s timeout to duration wait to prevent hanging UI
          await player.stream.duration
              .firstWhere((d) => d > Duration.zero)
              .timeout(const Duration(seconds: 5));
          
          if (mounted && _currentItem.path == currentPath) {
            await player.seek(Duration(milliseconds: savedPos));
          }
        } catch (e) {
          debugPrint('[VideoPlayer] Seek setup failed/timed out: $e');
        }
      }
    }
  }

  Future<void> _loadExternalSubtitles() async {
    try {
      final file = File(_currentItem.path);
      final dir = file.parent;
      final baseName = p.basenameWithoutExtension(_currentItem.path);
      final extensions = ['.srt', '.vtt', '.ass'];

      for (final ext in extensions) {
        final subPath = p.join(dir.path, '$baseName$ext');
        if (await File(subPath).exists()) {
          debugPrint('[VideoPlayer] Auto-loading subtitle: $subPath');
          player.setSubtitleTrack(SubtitleTrack.uri(subPath));
          break;
        }
      }
    } catch (e) {
      debugPrint('[VideoPlayer] Error auto-loading subtitles: $e');
    }
  }

  Future<void> _savePlaybackPosition() async {
    if (_isClosing) return;
    final position = player.state.position.inMilliseconds;
    final duration = player.state.duration.inMilliseconds;

    // Don't save if near the end (95%)
    if (duration > 0 && position < (duration * 0.95)) {
      await PlaybackMemoryRepository.savePosition(_currentItem.path, position);
    } else {
      await PlaybackMemoryRepository.savePosition(
        _currentItem.path,
        0,
      ); // Reset
    }
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
      _onInteraction();
    }
  }

  @override
  void didUpdateWidget(VideoPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path) {
      _loadMedia(widget.item);
    }
  }

  @override
  void onWindowClose() async {
    if (_isClosing || !widget.isStandalone) return;

    // Save position before closing
    await _savePlaybackPosition();

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
    _isClosing = true;
    WidgetsBinding.instance.removeObserver(this);
    if (widget.isStandalone) {
      windowManager.removeListener(this);
    }
    _savePlaybackPosition();
    _activeMenuEntry?.remove();
    _activeMenuEntry = null;
    _hideTimer?.cancel();
    _fastSeekTimer?.cancel();
    _volumeTimer?.cancel();
    _volumeOverlayTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    _trackSubscription?.cancel();
    _completedSubscription?.cancel();
    _bufferingSubscription?.cancel();
    _errorSubscription?.cancel();
    _snapshotToastTimer?.cancel();
    _audioTrackInitSubscription?.cancel();
    _subtitleTrackInitSubscription?.cancel();
    _focusNode.dispose();
    player.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (_activeMenuEntry != null) {
      _hideMenu();
    }
  }

  Future<void> _fetchFps() async {
    try {
      if (_isClosing || !mounted) return;
      // Small delay to allow mpv to parse container metadata
      await Future.delayed(const Duration(milliseconds: 500));
      if (_isClosing || !mounted) return;
      
      double? fps = player.state.track.video.fps;
      
      // Fallback to native property if high-level is null
      if (fps == null && mounted && !_isClosing) {
        final dynamic platform = player.platform;
        // Accessing getProperty via dynamic to avoid platform-specific import issues
        // while still reaching libmpv's container-fps
        final dynamic result = await platform.getProperty('container-fps');
        if (_isClosing) return;
        if (result is num) {
          fps = result.toDouble();
        } else if (result is String) {
          fps = double.tryParse(result);
        }
      }

      if (mounted && fps != null && fps > 0 && !_isClosing) {
        setState(() => _fps = fps);
      }
    } catch (e) {
      if (!_isClosing) debugPrint('Error fetching FPS: $e');
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();

    // If any selection menu is active, we MUST NOT hide the HUD.
    if (_isAnyMenuVisible) return;

    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      if (_isControlsVisible && !_isAnyMenuVisible) {
        setState(() => _isControlsVisible = false);
      }
    });
  }

  void _showVolumeOverlay() {
    _volumeOverlayTimer?.cancel();
    if (mounted) {
      setState(() => _isVolumeOverlayVisible = true);
    }
    _volumeOverlayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isVolumeOverlayVisible = false);
      }
    });
  }

  void _showSeekIndicator() {
    _seekIndicatorTimer?.cancel();
    if (mounted) {
      setState(() => _isSeekIndicatorVisible = true);
    }
    _seekIndicatorTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _isSeekIndicatorVisible = false);
      }
    });
  }

  void _onInteraction() {
    if (_isClosing || !mounted) return;

    // Wake up global HUD if it was manually hidden
    if (widget.windowId == null && !ref.read(previewHudVisibleProvider)) {
      // Immediate update is safe here because listeners handle 'mounted' check
      ref.read(previewHudVisibleProvider.notifier).state = true;
    }

    if (mounted && !_isControlsVisible) {
      setState(() => _isControlsVisible = true);
    }
    _startHideTimer();
  }

  void _hideMenu() {
    _activeMenuEntry?.remove();
    _activeMenuEntry = null;
    if (mounted) {
      setState(() {
        _isAudioMenuVisible = false;
        _isSubtitleMenuVisible = false;
        _isSpeedMenuVisible = false;
        _isPlaylistVisible = false;
      });
    }
    _startHideTimer();
  }

  void _showMenu({
    required GlobalKey key,
    required Widget child,
    required String type,
  }) {
    // Close existing menu first but don't trigger a hide timer yet
    _activeMenuEntry?.remove();
    _activeMenuEntry = null;
    _hideTimer?.cancel();

    if (!mounted) return;
    setState(() {
      _isAudioMenuVisible = type == 'audio';
      _isSubtitleMenuVisible = type == 'subtitle';
      _isSpeedMenuVisible = type == 'speed';
      _isPlaylistVisible = type == 'playlist';
    });

    final RenderBox? renderBox =
        key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final isSpeed = type == 'speed';

    _activeMenuEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Block interaction with other layers while menu is open
          Positioned.fill(
            child: GestureDetector(
              onTap: _hideMenu,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: isSpeed ? null : position.dx,
            right: isSpeed
                ? (MediaQuery.of(context).size.width -
                      position.dx -
                      renderBox.size.width)
                : null,
            top: position.dy - 12, // Gap above button
            child: FractionalTranslation(
              translation: const Offset(
                0,
                -1,
              ), // Move entire menu above the button
              child: Material(
                color: Colors.transparent,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_activeMenuEntry!);
  }

  Future<void> _takeScreenshot() async {
    // Show flash and toast immediately for instant feedback
    if (mounted) {
      setState(() {
        _showFlash = true;
        _showSnapshotToast = true;
      });

      // Subtle flash fade
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) setState(() => _showFlash = false);
      });

      // Notification timer
      _snapshotToastTimer?.cancel();
      _snapshotToastTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showSnapshotToast = false);
      });
    }

    try {
      // Capture the frame as soon as possible after visual trigger
      final bytes = await player.screenshot();
      if (bytes == null) return;

      final file = File(_currentItem.path);
      final snapshotsDir = Directory(p.join(file.parent.path, 'Snapshots'));

      if (!snapshotsDir.existsSync()) {
        snapshotsDir.createSync(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          '${p.basenameWithoutExtension(_currentItem.path)}_$timestamp.png';
      final screenshotFile = File(p.join(snapshotsDir.path, fileName));

      await screenshotFile.writeAsBytes(bytes);
      debugPrint('[VideoPlayer] Screenshot saved: ${screenshotFile.path}');
    } catch (e) {
      debugPrint('[VideoPlayer] Error taking screenshot: $e');
    }
  }

  void _toggleControls({bool isKeyboard = false}) {
    setState(() {
      _isControlsVisible = !_isControlsVisible;
      if (_isControlsVisible) {
        _startHideTimer();
      }
    });
  }

  Future<void> _openInNewWindow() async {
    final position = player.state.position.inMilliseconds;

    // Pause immediately to avoid dual-playback audio overlap
    await player.pause();

    // Serialize current playlist if available to pass to standalone window
    String? playlistJson;
    try {
      final itemsAsync = ref.read(sortedDirectoryItemsProvider);
      final videos = itemsAsync.maybeWhen(
        data: (items) =>
            items.where((i) => i.type == FileItemType.video).toList(),
        orElse: () => <FileItem>[],
      );
      if (videos.isNotEmpty) {
        playlistJson = jsonEncode(videos.map((v) => v.toJson()).toList());
      }
    } catch (e) {
      debugPrint('[VideoPlayer] Error serializing playlist: $e');
    }

    final windowParams = WindowParams(
      viewerType: ViewerType.video,
      file: _currentItem,
      initParams: {
        'startPositionMs': position,
        'playbackRate': _playbackSpeed,
        'audioTrackId': player.state.track.audio.id,
        'subtitleTrackId': player.state.track.subtitle.id,
        if (playlistJson != null) 'playlistJson': playlistJson,
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
    player.setVolume(
      (player.state.volume + (isIncrease ? 5 : -5)).clamp(0, 200),
    );
    _showVolumeOverlay();

    _volumeTimer?.cancel();
    _volumeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      player.setVolume(
        (player.state.volume + (isIncrease ? 2 : -2)).clamp(0, 200),
      );
      _showVolumeOverlay();
    });
  }

  void _stopVolumeAdjustment() {
    _volumeTimer?.cancel();
    _volumeTimer = null;
    _activeVolumeKey = null;
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (_isClosing) return KeyEventResult.ignored;
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        if (event is KeyDownEvent) player.playOrPause();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (_activeSeekKey == null && event is KeyDownEvent) {
          _activeSeekKey = event.logicalKey;
          _startFastSeek(isForward: false);
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (_activeSeekKey == null && event is KeyDownEvent) {
          _activeSeekKey = event.logicalKey;
          _startFastSeek(isForward: true);
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        if (_activeVolumeKey == null && event is KeyDownEvent) {
          _activeVolumeKey = event.logicalKey;
          _startVolumeAdjustment(isIncrease: true);
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_activeVolumeKey == null && event is KeyDownEvent) {
          _activeVolumeKey = event.logicalKey;
          _startVolumeAdjustment(isIncrease: false);
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
        if (event is KeyDownEvent) _toggleMute();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyS) {
        if (event is KeyDownEvent) _takeScreenshot();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
        if (event is KeyDownEvent) {
          if (widget.isStandalone) {
            if (_isControlsVisible) {
              setState(() => _isControlsVisible = false);
              _hideMenu();
            }
            _toggleFullscreen();
          }
        }
        return event.logicalKey == LogicalKeyboardKey.keyF ? (widget.isStandalone ? KeyEventResult.handled : KeyEventResult.ignored) : KeyEventResult.ignored;
      } else if (event.logicalKey == LogicalKeyboardKey.keyW &&
          HardwareKeyboard.instance.isControlPressed) {
        if (event is KeyDownEvent && !widget.isStandalone) {
          ref.read(previewFileProvider.notifier).state = null;
        }
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (_activeSeekKey == event.logicalKey) {
          _stopFastSeek();
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        if (_activeVolumeKey == event.logicalKey) {
          _stopVolumeAdjustment();
        }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  void _startFastSeek({required bool isForward}) {
    _fastSeekTimer?.cancel();
    final seekSeconds =
        ref.read(settingsProvider).value?.doubleTapSeekSeconds ?? 10;

    // Initial seek
    _showSeekIndicator();
    player.seek(
      player.state.position +
          Duration(seconds: isForward ? seekSeconds : -seekSeconds),
    );

    _fastSeekTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      _showSeekIndicator();
      // Periodic seek is usually slightly faster or same as initial
      player.seek(
        player.state.position +
            Duration(seconds: isForward ? seekSeconds : -seekSeconds),
      );
    });
  }

  void _stopFastSeek() {
    _fastSeekTimer?.cancel();
    _fastSeekTimer = null;
    _activeSeekKey = null;
  }

  void _navigateMedia(bool forward) {
    if (widget.windowId != null) {
      // 1. Standalone Mode: Send reverse IPC to Main Window (Window 0)
      final payload = jsonEncode({
        'direction': forward ? 'next' : 'prev',
        'currentPath': _currentItem.path,
        'type': 'video',
        'targetWindowId': widget.windowId!,
      });
      WindowController.fromWindowId(
        widget.parentWindowId ?? '0',
      ).invokeMethod('request_navigation', payload);
    } else {
      // 2. Inline Mode: Local Riverpod state update
      final items = ref.read(directoryItemsProvider).value ?? [];
      if (items.isEmpty) return;

      final mediaItems = items
          .where((i) => i.type == FileItemType.video)
          .toList();
      if (mediaItems.isEmpty) return;

      final currentIndex = mediaItems.indexWhere(
        (i) => i.path == _currentItem.path,
      );
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
    ref.listen(previewHudVisibleProvider, (previous, next) {
      if (mounted) {
        setState(() => _isGlobalHudVisible = next);
      }
    });

    // In standalone mode, we ignore the global HUD visibility provider as the window
    // itself is the dedicated viewer. We only care about the internal control timer.
    final isVisible =
        _isControlsVisible &&
        (widget.windowId != null || widget.isStandalone || _isGlobalHudVisible);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onFocusChange: (hasFocus) {
        if (!hasFocus) {
          _stopFastSeek();
          _stopVolumeAdjustment();
        }
      },
      onKeyEvent: (node, event) => _handleKeyEvent(event),
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        onDoubleTapDown: (details) {
          _doubleTapPosition = details.localPosition;
        },
        onDoubleTap: () {
          if (widget.windowId == null && !widget.isStandalone) {
            _openInNewWindow();
            return;
          }

          if (_doubleTapPosition == null) return;
          final width =
              context.size?.width ?? MediaQuery.of(context).size.width;
          final isForward = _doubleTapPosition!.dx > width / 2;

          final seconds =
              ref.read(settingsProvider).value?.doubleTapSeekSeconds ?? 10;
          player.seek(
            player.state.position +
                Duration(seconds: isForward ? seconds : -seconds),
          );

          _showSeekIndicator();
          _onInteraction(); // Show HUD to indicate action
        },
        child: Listener(
          onPointerSignal: (signal) {
            if (signal is PointerScrollEvent && signal.scrollDelta.dy != 0) {
              final isIncrease = signal.scrollDelta.dy < 0;
              // Use a base step of 2% but scale slightly with delta for faster scrolling
              final step = (signal.scrollDelta.dy.abs() / 15).clamp(1.5, 6.0);
              player.setVolume(
                (player.state.volume + (isIncrease ? step : -step)).clamp(
                  0.0,
                  200.0,
                ),
              );
              _showVolumeOverlay();
            }
          },
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                // Interaction Trigger Zone (Full Viewport)
                Positioned.fill(
                  child: MouseRegion(
                    cursor: isVisible
                        ? MouseCursor.defer
                        : SystemMouseCursors.none,
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

                        // Bubble Loader during loading/buffering/seeking
                        // Using AnimatedOpacity to ensure the loader is already in the tree and animating
                        IgnorePointer(
                          child: Center(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 200),
                              opacity: (_isOpening || _isBuffering || _isSeekingToInitial) ? 1.0 : 0.0,
                              child: const RepaintBoundary(
                                child: BubbleLoader(size: 100),
                              ),
                            ),
                          ),
                        ),

                        // Snapshot Flash Effect (Subtle Fade)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 500),
                              opacity: _showFlash ? 0.3 : 0.0,
                              curve: Curves.easeOut,
                              child: Container(
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Snapshot Glass Toast (Higher Z-order)
                if (_showSnapshotToast)
                  Positioned(
                    bottom: 120,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _buildSnapshotToast(),
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
                        },
                      ),
                    ),
                  ),
                ),

                // Seek Indicator Overlay (Top Right)
                Positioned(
                  top: 100,
                  right: 64,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _isSeekIndicatorVisible ? 1.0 : 0.0,
                    child: StreamBuilder<Duration>(
                      stream: player.stream.position,
                      builder: (context, snapshot) {
                        final position = snapshot.data ?? player.state.position;
                        final duration = player.state.duration;
                        return Text(
                          '${_formatDuration(position)} / ${_formatDuration(duration)}',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 54,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                            shadows: [
                              Shadow(
                                offset: const Offset(2, 2),
                                blurRadius: 4.0,
                                color: Colors.black.withOpacity(0.8),
                              ),
                              Shadow(
                                offset: const Offset(-1, -1),
                                blurRadius: 2.0,
                                color: Colors.black.withOpacity(0.5),
                              ),
                            ],
                          ),
                        );
                      },
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
                        final res = (state.height ?? 0) > 0
                            ? '${state.height}p'
                            : 'Loading...';
                        final fpsString = _fps != null
                            ? ' • ${_fps!.toInt()} FPS'
                            : '';

                        return ViewerTopBar(
                          title: _currentItem.name,
                          metadata: '$res$fpsString',
                          isStandalone: widget.isStandalone,
                          onPopOut: _openInNewWindow,
                          onClose: () =>
                              ref.read(previewFileProvider.notifier).state =
                                  null,
                          extraActions: [
                            _buildTopBarButton(
                              icon: Icons.edit_outlined,
                              onPressed: () {
                                // TODO: Implement video editing
                              },
                              tooltip: 'Edit Video',
                            ),
                            const SizedBox(width: 8),
                            _buildTopBarButton(
                              icon: Icons.settings_rounded,
                              onPressed: () => SettingsDialog.show(
                                context,
                                initialTab: 1,
                                section: 'Video',
                              ),
                              tooltip: 'Video Settings',
                            ),
                            const SizedBox(width: 8),
                          ],
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
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
                                    ? position.inMilliseconds /
                                          duration.inMilliseconds
                                    : 0.0;

                                return Row(
                                  children: [
                                    Text(
                                      _formatDuration(position),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackShape:
                                              GradientRectSliderTrackShape(
                                                gradient:
                                                    AppTheme.primaryGradient,
                                              ),
                                          activeTrackColor: Colors.white,
                                          inactiveTrackColor: Colors.white
                                              .withOpacity(0.1),
                                          thumbShape:
                                              SliderComponentShape.noThumb,
                                          overlayShape:
                                              SliderComponentShape.noOverlay,
                                          trackHeight: 10.0,
                                        ),
                                        child: Slider(
                                          value: progress.clamp(0.0, 1.0),
                                          onChanged: (v) {
                                            _onInteraction();
                                            _showSeekIndicator();
                                            player.seek(
                                              Duration(
                                                milliseconds:
                                                    (v *
                                                            duration
                                                                .inMilliseconds)
                                                        .toInt(),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: () => setState(
                                        () => _showRemainingTime =
                                            !_showRemainingTime,
                                      ),
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
                                  key: _playlistKey,
                                  onPressed: () {
                                    _onInteraction();
                                    _showMenu(
                                      key: _playlistKey,
                                      type: 'playlist',
                                      child: PlaylistOverlay(
                                        currentPath: _currentItem.path,
                                        videos: widget.isStandalone
                                            ? _standalonePlaylist
                                            : null,
                                        onVideoSelected: (video) {
                                          _hideMenu();
                                          if (widget.isStandalone) {
                                            _loadMedia(video);
                                          } else {
                                            ref
                                                    .read(
                                                      previewFileProvider
                                                          .notifier,
                                                    )
                                                    .state =
                                                video;
                                          }
                                        },
                                      ),
                                    );
                                  },
                                  icon: Icon(
                                    Icons.playlist_play,
                                    color: _isPlaylistVisible
                                        ? AppColors.violet
                                        : Colors.white70,
                                    size: 24,
                                  ),
                                  tooltip: 'Playlist',
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  key: _subtitleKey,
                                  onPressed: () {
                                    _onInteraction();
                                    _showMenu(
                                      key: _subtitleKey,
                                      type: 'subtitle',
                                      child: StreamBuilder<dynamic>(
                                        stream: player.stream.track,
                                        builder: (context, snapshot) {
                                          final state =
                                              snapshot.data ??
                                              player.state.track;
                                          return TrackSelectorMenu(
                                            title: 'Subtitles',
                                            subtitleTracks:
                                                player.state.tracks.subtitle,
                                            selectedTrack: state.subtitle,
                                            onTrackSelected: (t) {
                                              player.setSubtitleTrack(
                                                t as SubtitleTrack,
                                              );
                                            },
                                            onLoadExternal: () async {
                                              final result =
                                                  await FilePicker.pickFiles(
                                                    type: FileType.custom,
                                                    allowedExtensions: [
                                                      'srt',
                                                      'vtt',
                                                      'ass',
                                                    ],
                                                  );
                                              if (result != null &&
                                                  result.files.single.path !=
                                                      null) {
                                                player.setSubtitleTrack(
                                                  SubtitleTrack.uri(
                                                    result.files.single.path!,
                                                  ),
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
                                    color: _isSubtitleMenuVisible
                                        ? AppColors.violet
                                        : Colors.white70,
                                    size: 20,
                                  ),
                                  tooltip: 'Subtitles',
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  key: _audioKey,
                                  onPressed: () {
                                    _onInteraction();
                                    _showMenu(
                                      key: _audioKey,
                                      type: 'audio',
                                      child: StreamBuilder<dynamic>(
                                        stream: player.stream.track,
                                        builder: (context, snapshot) {
                                          final state =
                                              snapshot.data ??
                                              player.state.track;
                                          return TrackSelectorMenu(
                                            title: 'Audio Tracks',
                                            audioTracks:
                                                player.state.tracks.audio,
                                            selectedTrack: state.audio,
                                            onTrackSelected: (t) {
                                              player.setAudioTrack(
                                                t as AudioTrack,
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    );
                                  },
                                  icon: Icon(
                                    Icons.audiotrack_rounded,
                                    color: _isAudioMenuVisible
                                        ? AppColors.violet
                                        : Colors.white70,
                                    size: 20,
                                  ),
                                  tooltip: 'Audio Tracks',
                                ),

                                const Spacer(),

                                // Center cluster
                                IconButton(
                                  onPressed: () => _navigateMedia(false),
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
                                  onPressed: () {
                                    final seconds = ref.read(settingsProvider).value?.doubleTapSeekSeconds ?? 10;
                                    player.seek(player.state.position - Duration(seconds: seconds));
                                    _onInteraction();
                                  },
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
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.white.withOpacity(
                                                0.2,
                                              ),
                                              blurRadius: 12,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          playing
                                              ? Icons.pause
                                              : Icons.play_arrow,
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
                                  onPressed: () {
                                    final seconds = ref.read(settingsProvider).value?.doubleTapSeekSeconds ?? 10;
                                    player.seek(player.state.position + Duration(seconds: seconds));
                                    _onInteraction();
                                  },
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  onPressed: () => _navigateMedia(true),
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
                                    TextButton(
                                      key: _speedKey,
                                      onPressed: () {
                                        _onInteraction();
                                        _showMenu(
                                          key: _speedKey,
                                          type: 'speed',
                                          child: PlaybackSpeedControl(
                                            currentSpeed: _playbackSpeed,
                                            onSpeedSelected: (speed) {
                                              setState(
                                                () => _playbackSpeed = speed,
                                              );
                                              player.setRate(speed);
                                            },
                                          ),
                                        );
                                      },
                                      child: Text(
                                        '${_playbackSpeed.toString().replaceAll(RegExp(r'\.0$'), '')}x',
                                        style: GoogleFonts.manrope(
                                          color: _isSpeedMenuVisible
                                              ? AppColors.violet
                                              : Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: _toggleMute,
                                      icon: Icon(
                                        _isMuted
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
                                              inactiveTrackColor: Colors.white
                                                  .withOpacity(0.2),
                                              thumbShape:
                                                  const RoundSliderThumbShape(
                                                    enabledThumbRadius: 3,
                                                  ),
                                              overlayShape:
                                                  const RoundSliderOverlayShape(
                                                    overlayRadius: 6,
                                                  ),
                                            ),
                                            child: Slider(
                                              value: volume.clamp(0.0, 200.0),
                                              min: 0,
                                              max: 200,
                                              onChanged: (v) =>
                                                  player.setVolume(v),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    IconButton(
                                      onPressed: _toggleFullscreen,
                                      icon: Icon(
                                        Icons.fullscreen_rounded,
                                        color: Colors.white70,
                                        size: 22,
                                      ),
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
      ),
    );
  }

  void _initStandalonePlaylist() async {
    try {
      final absolutePath = File(_currentItem.path).absolute.path;
      final parentDir = File(absolutePath).parent;
      debugPrint(
        '[VideoPlayer] Scanning standalone playlist: ${parentDir.path}',
      );

      if (!parentDir.existsSync()) {
        debugPrint('[VideoPlayer] Parent directory does not exist!');
        return;
      }

      final entities = await parentDir.list().toList();
      final videos = <FileItem>[];

      for (final entity in entities) {
        if (FileSystemEntity.isFileSync(entity.path)) {
          final name = p.basename(entity.path);
          if (classifyFileType(name) == FileItemType.video) {
            try {
              final stat = await entity.stat();
              videos.add(
                FileItem(
                  name: name,
                  path: entity.path,
                  type: FileItemType.video,
                  sizeBytes: stat.size,
                  modified: stat.modified,
                ),
              );
            } catch (e) {
              debugPrint('Error stating file ${entity.path}: $e');
            }
          }
        }
      }

      debugPrint('[VideoPlayer] Standalone playlist count: ${videos.length}');

      if (mounted) {
        setState(() {
          _standalonePlaylist = videos;
        });
      }
    } catch (e) {
      debugPrint('[VideoPlayer] Error in _initStandalonePlaylist: $e');
    }
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

  Widget _buildTopBarButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    bool active = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: active
            ? AppColors.violet.withOpacity(0.3)
            : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? AppColors.violet.withOpacity(0.5)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: active ? AppColors.violet : Colors.white,
          size: 20,
        ),
        onPressed: onPressed,
        tooltip: tooltip,
        splashRadius: 24,
      ),
    );
  }

  Widget _buildSeekButton({
    required bool isForward,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onLongPressStart: (_) {
        _onInteraction();
        _showSeekIndicator();
        _startFastSeek(isForward: isForward);
      },
      onLongPressEnd: (_) {
        _stopFastSeek();
      },
      onLongPressCancel: () {
        _stopFastSeek();
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
        tooltip: isForward ? 'Seek Forward' : 'Seek Backward',
      ),
    );
  }

  Widget _buildSnapshotToast() {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: _showSnapshotToast ? 1.0 : 0.0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.violet.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.camera_alt_rounded, 
                    color: AppColors.violet, 
                    size: 18
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Snapshot saved to Snapshots/',
                  style: GoogleFonts.outfit(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
