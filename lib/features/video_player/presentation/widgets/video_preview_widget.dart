// ignore_for_file: avoid_dynamic_calls, unawaited_futures, cascade_invocations, avoid_slow_async_io
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/playlist/media_queue_isolate.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
// import removed
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/utils/media_uri_helper.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/core/widgets/viewer_top_bar.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/dialogs.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/settings/presentation/widgets/settings_dialog.dart';
import 'package:onyxcore/features/video_player/data/repositories/playback_memory_repository.dart';
import 'package:onyxcore/features/video_player/domain/entities/video_marker.dart';
import 'package:onyxcore/features/video_player/presentation/controllers/hud_controller.dart';
import 'package:onyxcore/features/video_player/presentation/controllers/marker_controller.dart';
import 'package:onyxcore/features/video_player/presentation/controllers/seek_controller.dart';
import 'package:onyxcore/features/video_player/presentation/controllers/video_screenshot_controller.dart';
import 'package:onyxcore/features/video_player/presentation/handlers/gesture_handler.dart';
import 'package:onyxcore/features/video_player/presentation/handlers/keyboard_handler.dart';
import 'package:onyxcore/features/video_player/presentation/lifecycle/player_initializer.dart';
import 'package:onyxcore/features/video_player/presentation/overlays/empty_state.dart';
import 'package:onyxcore/features/video_player/presentation/overlays/error_state.dart';
import 'package:onyxcore/features/video_player/presentation/overlays/loading_overlay.dart';
import 'package:onyxcore/features/video_player/presentation/overlays/seek_indicator.dart';
import 'package:onyxcore/features/video_player/presentation/overlays/snapshot_overlay.dart';
import 'package:onyxcore/features/video_player/presentation/overlays/speed_indicator.dart';
import 'package:onyxcore/features/video_player/presentation/overlays/speed_overlay_wrapper.dart';
import 'package:onyxcore/features/video_player/presentation/overlays/video_bottom_controls.dart';
import 'package:onyxcore/features/video_player/presentation/overlays/volume_overlay_wrapper.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_playlist_providers.dart';

import 'package:onyxcore/features/video_player/presentation/services/subtitle_loader.dart';
import 'package:onyxcore/features/video_player/presentation/state/video_player_state.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/marker_editor_overlay.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/video_playlist_sidebar.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

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
  Timer? _snapshotToastTimer;
  List<FileItem> _standalonePlaylist = [];
  bool _isClosing = false;
  // ── Video Playlist Sidebar ──
  bool _isSidebarDragging = false;
  double _playbackSpeed = 1;
  double? _fps;
  Timer? _hideTimer;
  Timer? _fastSeekTimer;
  Timer? _volumeTimer;
  Timer? _volumeSaveDebouncer;
  Timer? _volumeOverlayTimer;
  Timer? _seekIndicatorTimer;
  LogicalKeyboardKey? _activeSeekKey;
  LogicalKeyboardKey? _activeVolumeKey;
  Timer? _virtualSeekCleanupTimer;
  StreamSubscription<dynamic>? _trackSubscription;
  StreamSubscription<dynamic>? _completedSubscription;
  StreamSubscription<dynamic>? _bufferingSubscription;
  StreamSubscription<dynamic>? _errorSubscription;
  StreamSubscription<dynamic>? _audioTrackInitSubscription;
  bool _isPlayerInitialized = false;
  bool _isPlayerDisposed = false;
  bool _isBuffering = false;

  VideoPlayerDisplayState _displayState = const VideoPlayerDisplayState(
    isOpening: false,
    isSeekingToInitial: false,
    isSmartBuffering: false,
    isSeekLoading: false,
    isControlsVisible: true,
    isMarkerEditorActive: false,
    isMarkerMenuVisible: false,
    isGlobalHudVisible: false,
    isFastSeeking: false,
    isScrubbing: false,
    hasError: false,
    errorMessage: '',
    fps: null,
    showRemainingTime: false,
    isMuted: false,
    isVolumeOverlayVisible: false,
    showSpeedOverlayVisible: false,
    isSeekIndicatorVisible: false,
    showFlash: false,
    showSnapshotToast: false,
    isEmpty: false,
    isNetworkStream: false,
    playbackSpeed: 1,
    isAudioMenuVisible: false,
    isSubtitleMenuVisible: false,
    isSpeedMenuVisible: false,
    scrollLockAxis: null,
    windowId: null,
    isStandalone: false,
  );

  @visibleForTesting
  void setErrorForTest() {
    setState(() {
      _displayState = _displayState.copyWith(
        hasError: true,
        errorMessage: 'Failed to play',
      );
    });
  }

  Timer? _seekLoaderTimer;
  StreamSubscription<dynamic>? _positionSubscription;
  Duration? _preSeekPosition;
  DateTime _lastSeekTime = DateTime.now();
  double _playerWidth = 0;
  double _playerHeight = 0; // ignore: unused_field
  Timer? _smartDelayTimer;

  bool _wasPlayingBeforeScrub = false;
  final GlobalKey _sliderKey = GlobalKey();
  final GlobalKey _playerKey = GlobalKey();

  // BUG-001: Hover preview state
  final ValueNotifier<double?> _hoverXNotifier = ValueNotifier<double?>(null);
  Timer? _hoverExitTimer;

  // BUG-001: Scrub throttle state
  Timer? _scrubThrottleTimer;
  Duration? _pendingScrubPosition;
  Duration? _virtualSeekPosition;

  // Seek Engine Gateway: Throttle + Debounce
  Timer? _engineSeekTimer;
  DateTime _lastEngineSeekTime = DateTime.fromMillisecondsSinceEpoch(0);
  final int _throttleMs = 400;
  final int _debounceMs = 250;
  int _cleanupRetryCount = 0;

  /// Unified position the UI should render (OSD, progress bar, slider).
  Duration get displayPosition {
    if (!_isPlayerInitialized) return Duration.zero;
    if (_displayState.isScrubbing && _virtualScrubPosition != null) {
      return _virtualScrubPosition!;
    }
    if (_displayState.isFastSeeking && _virtualSeekPosition != null) {
      return _virtualSeekPosition!;
    }
    return player.state.position;
  }

  StreamSubscription<dynamic>? _subtitleTrackInitSubscription;

  late final GlobalKey _audioKey;
  late final GlobalKey _subtitleKey;
  late final GlobalKey _speedKey;
  late final GlobalKey _resolutionKey;

  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _activeMenuEntry;

  bool get _isAnyMenuVisible =>
      _displayState.isAudioMenuVisible ||
      _displayState.isSubtitleMenuVisible ||
      _displayState.isSpeedMenuVisible ||
      _displayState.isMarkerMenuVisible;

  bool _isGlobalHudVisible = true;
  Offset? _doubleTapPosition;
  bool _sessionSkipConfirm = false;

  // EPX-006: Trackpad Gesture Engine state
  Duration? _virtualScrubPosition;
  double? _virtualVolume;
  double? _virtualSpeed;
  String? _scrollLockAxis; // 'h', 'volume', or 'speed'
  Timer? _scrollResetTimer;
  Timer? _scrollVolumeTimer;
  Timer? _scrollSpeedTimer;
  Timer? _speedOverlayTimer;

  DateTime? _lastKeyEventTime;

  // EPX-009: Marker System state

  // Marker editor state is now in VideoMarkerController
  VideoMarker? _editingMarker;
  Offset? _markerEditorAnchor;
  final bool _isHoveringMarker = false;

  final GlobalKey<MarkerEditorOverlayState> _markerEditorKey =
      GlobalKey<MarkerEditorOverlayState>();

  bool get _isNetworkStream => widget.initParams?['is_network_stream'] == true;
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier<bool>(false);
  StreamSubscription<dynamic>? _playingSubscription;

  bool _isSidebarDragOutOfBounds = false;
  double _sidebarDragStartWidth = 0;
  double _sidebarDragStartX = 0;

  late final PlaybackMemoryRepository _playbackRepo;

  List<MediaFormat> _availableFormats = [];
  String? _selectedFormatId;

  void _onWindowFocus() {
    if (mounted) _focusNode.requestFocus();
  }

  late final VideoGestureHandler _gestureHandler;
  late final VideoKeyboardHandler _keyboardHandler;
  late final VideoSeekController _seekController;
  late final VideoMarkerController _markerController;
  late final VideoHudController _hudController;
  late final VideoScreenshotController _screenshotController;

  @override
  void initState() {
    super.initState();
    _screenshotController = VideoScreenshotController(
      VideoScreenshotCallbacks(
        getMounted: () => mounted,
        setShowFlash: (v) => setState(
          () => _displayState = _displayState.copyWith(showFlash: v),
        ),
        setShowSnapshotToast: (v) => setState(
          () => _displayState = _displayState.copyWith(showSnapshotToast: v),
        ),
        getSnapshotToastTimer: () => _snapshotToastTimer,
        setSnapshotToastTimer: (v) => _snapshotToastTimer = v,
      ),
    );
    _hudController = VideoHudController(
      VideoHudCallbacks(
        getMounted: () => mounted,
        getIsClosing: () => _isClosing,
        getIsControlsVisible: () => _displayState.isControlsVisible,
        setIsControlsVisible: (v) => setState(
          () => _displayState = _displayState.copyWith(isControlsVisible: v),
        ),
        getIsScrubbing: () => _displayState.isScrubbing,
        getIsMarkerEditorActive: () => _displayState.isMarkerEditorActive,
        getIsHoveringMarker: () => _isHoveringMarker,
        getIsAnyMenuVisible: () => _isAnyMenuVisible,
        getIsAudioMenuVisible: () => _displayState.isAudioMenuVisible,
        setIsAudioMenuVisible: (v) => setState(
          () => _displayState = _displayState.copyWith(isAudioMenuVisible: v),
        ),
        getIsSubtitleMenuVisible: () => _displayState.isSubtitleMenuVisible,
        setIsSubtitleMenuVisible: (v) => setState(
          () =>
              _displayState = _displayState.copyWith(isSubtitleMenuVisible: v),
        ),
        getIsSpeedMenuVisible: () => _displayState.isSpeedMenuVisible,
        setIsSpeedMenuVisible: (v) => setState(
          () => _displayState = _displayState.copyWith(isSpeedMenuVisible: v),
        ),
        getIsVolumeOverlayVisible: () => _displayState.isVolumeOverlayVisible,
        setIsVolumeOverlayVisible: (v) => setState(
          () =>
              _displayState = _displayState.copyWith(isVolumeOverlayVisible: v),
        ),
        getIsSeekIndicatorVisible: () => _displayState.isSeekIndicatorVisible,
        setIsSeekIndicatorVisible: (v) => setState(
          () =>
              _displayState = _displayState.copyWith(isSeekIndicatorVisible: v),
        ),
        getShowSpeedOverlayVisible: () => _displayState.showSpeedOverlayVisible,
        setShowSpeedOverlayVisible: (v) => setState(
          () => _displayState = _displayState.copyWith(
            showSpeedOverlayVisible: v,
          ),
        ),
        getHideTimer: () => _hideTimer,
        setHideTimer: (v) => _hideTimer = v,
        getVolumeOverlayTimer: () => _volumeOverlayTimer,
        setVolumeOverlayTimer: (v) => _volumeOverlayTimer = v,
        getSpeedOverlayTimer: () => _speedOverlayTimer,
        setSpeedOverlayTimer: (v) => _speedOverlayTimer = v,
        getSeekIndicatorTimer: () => _seekIndicatorTimer,
        setSeekIndicatorTimer: (v) => _seekIndicatorTimer = v,
        getActiveMenuEntry: () => _activeMenuEntry,
        setActiveMenuEntry: (v) => _activeMenuEntry = v,
        getWindowId: () => widget.windowId,
        getRef: () => ref,
        setStateCallback: setState,
        getOverlayContext: () => context,
      ),
    );

    _seekController = VideoSeekController(
      VideoSeekCallbacks(
        getPlayer: () => player,
        getRef: () => ref,
        getMounted: () => mounted,
        getIsClosing: () => _isClosing,
        getIsFastSeeking: () => _displayState.isFastSeeking,
        setIsFastSeeking: (v) => setState(
          () => _displayState = _displayState.copyWith(isFastSeeking: v),
        ),
        getIsScrubbing: () => _displayState.isScrubbing,
        setIsScrubbing: (v) => setState(
          () => _displayState = _displayState.copyWith(isScrubbing: v),
        ),
        getVirtualSeekPosition: () => _virtualSeekPosition,
        setVirtualSeekPosition: (v) => _virtualSeekPosition = v,
        getVirtualScrubPosition: () => _virtualScrubPosition,
        setVirtualScrubPosition: (v) => _virtualScrubPosition = v,
        getPendingScrubPosition: () => _pendingScrubPosition,
        setPendingScrubPosition: (v) => _pendingScrubPosition = v,
        getWasPlayingBeforeScrub: () => _wasPlayingBeforeScrub,
        setWasPlayingBeforeScrub: (v) => _wasPlayingBeforeScrub = v,
        getIsSmartBuffering: () => _displayState.isSmartBuffering,
        setIsSmartBuffering: (v) => setState(
          () => _displayState = _displayState.copyWith(isSmartBuffering: v),
        ),
        getScrollLockAxis: () => _scrollLockAxis,
        getActiveSeekKey: () => _activeSeekKey,
        setActiveSeekKey: (v) => _activeSeekKey = v,
        getLastEngineSeekTime: () => _lastEngineSeekTime,
        setLastEngineSeekTime: (v) => _lastEngineSeekTime = v,
        getThrottleMs: () => _throttleMs,
        getDebounceMs: () => _debounceMs,
        getCleanupRetryCount: () => _cleanupRetryCount,
        setCleanupRetryCount: (v) => _cleanupRetryCount = v,
        getEngineSeekTimer: () => _engineSeekTimer,
        setEngineSeekTimer: (v) => _engineSeekTimer = v,
        getVirtualSeekCleanupTimer: () => _virtualSeekCleanupTimer,
        setVirtualSeekCleanupTimer: (v) => _virtualSeekCleanupTimer = v,
        getFastSeekTimer: () => _fastSeekTimer,
        setFastSeekTimer: (v) => _fastSeekTimer = v,
        getSeekLoaderTimer: () => _seekLoaderTimer,
        setSeekLoaderTimer: (v) => _seekLoaderTimer = v,
        setIsSeekLoading: (v) => setState(
          () => _displayState = _displayState.copyWith(isSeekLoading: v),
        ),
        setPreSeekPosition: (v) => _preSeekPosition = v,
        setLastSeekTime: (v) => _lastSeekTime = v,
        showSeekIndicator: _hudController.showSeekIndicator,
        onInteraction: _hudController.onInteraction,
        setStateCallback: setState,
      ),
    );

    _markerController = VideoMarkerController(
      VideoMarkerCallbacks(
        getPlayer: () => player,
        getRef: () => ref,
        getMounted: () => mounted,
        getIsMarkerEditorActive: () => _displayState.isMarkerEditorActive,
        setIsMarkerEditorActive: (v) => setState(
          () => _displayState = _displayState.copyWith(isMarkerEditorActive: v),
        ),
        getEditingMarker: () => _editingMarker,
        setEditingMarker: (v) => _editingMarker = v,
        getIsControlsVisible: () => _displayState.isControlsVisible,
        setIsControlsVisible: (v) => setState(
          () => _displayState = _displayState.copyWith(isControlsVisible: v),
        ),
        getMarkerEditorAnchor: () => _markerEditorAnchor,
        setMarkerEditorAnchor: (v) => _markerEditorAnchor = v,
        getSliderWidth: () => MediaQuery.of(context).size.width - 64,
        getContextSize: () => context.size ?? MediaQuery.of(context).size,
        getHideTimer: () => _hideTimer,
        getIsPlayingNotifier: () => _isPlayingNotifier,
        getFocusNode: () => _focusNode,
        getCurrentVideoPath: () => _currentItem.path,
        onInteraction: _hudController.onInteraction,
        setStateCallback: setState,
      ),
    );

    _gestureHandler = VideoGestureHandler(
      VideoGestureCallbacks(
        getPlayer: () => player,
        getRef: () => ref,
        getMounted: () => mounted,
        getIsClosing: () => _isClosing,
        getIsScrubbing: () => _displayState.isScrubbing,
        setIsScrubbing: (v) => setState(
          () => _displayState = _displayState.copyWith(isScrubbing: v),
        ),
        getIsFastSeeking: () => _displayState.isFastSeeking,
        setIsFastSeeking: (v) => setState(
          () => _displayState = _displayState.copyWith(isFastSeeking: v),
        ),
        getVirtualSeekPosition: () => _virtualSeekPosition,
        setVirtualSeekPosition: (v) => _virtualSeekPosition = v,
        getVirtualScrubPosition: () => _virtualScrubPosition,
        setVirtualScrubPosition: (v) => _virtualScrubPosition = v,
        getPendingScrubPosition: () => _pendingScrubPosition,
        setPendingScrubPosition: (v) => _pendingScrubPosition = v,
        getVirtualVolume: () => _virtualVolume,
        setVirtualVolume: (v) => _virtualVolume = v,
        getVirtualSpeed: () => _virtualSpeed,
        setVirtualSpeed: (v) => _virtualSpeed = v,
        getScrollLockAxis: () => _scrollLockAxis,
        setScrollLockAxis: (v) => _scrollLockAxis = v,
        getWasPlayingBeforeScrub: () => _wasPlayingBeforeScrub,
        setWasPlayingBeforeScrub: (v) => _wasPlayingBeforeScrub = v,
        getLastKeyEventTime: () => _lastKeyEventTime,
        getEngineSeekTimer: () => _engineSeekTimer,
        getVirtualSeekCleanupTimer: () => _virtualSeekCleanupTimer,
        setVirtualSeekCleanupTimer: (v) => _virtualSeekCleanupTimer = v,
        getFastSeekTimer: () => _fastSeekTimer,
        getScrollResetTimer: () => _scrollResetTimer,
        setScrollResetTimer: (v) => _scrollResetTimer = v,
        getScrollVolumeTimer: () => _scrollVolumeTimer,
        setScrollVolumeTimer: (v) => _scrollVolumeTimer = v,
        getScrollSpeedTimer: () => _scrollSpeedTimer,
        setScrollSpeedTimer: (v) => _scrollSpeedTimer = v,
        getScrubThrottleTimer: () => _scrubThrottleTimer,
        setScrubThrottleTimer: (v) => _scrubThrottleTimer = v,
        getContextSize: () => context.size ?? MediaQuery.of(context).size,
        showVolumeOverlay: _hudController.showVolumeOverlay,
        showSpeedOverlay: _hudController.showSpeedOverlay,
        showSeekIndicator: _hudController.showSeekIndicator,
        onInteraction: _hudController.onInteraction,
        cleanupVirtualSeeking: _seekController.cleanupVirtualSeeking,
        setStateCallback: setState,
      ),
    );

    _keyboardHandler = VideoKeyboardHandler(
      ref: ref,
      isStandalone: widget.isStandalone,
      windowId: widget.windowId,
      isClosing: () => _isClosing,
      isMarkerEditorActive: () => _displayState.isMarkerEditorActive,
      markerEditorKey: _markerEditorKey,
      callbacks: VideoKeyboardCallbacks(
        playOrPause: () => player.playOrPause(),
        startFastSeek: _seekController.startFastSeek,
        stopFastSeek: _seekController.stopFastSeek,
        startVolumeAdjust: _startVolumeAdjustment,
        stopVolumeAdjust: _stopVolumeAdjustment,
        toggleMute: _toggleMute,
        takeScreenshot: () => _screenshotController.takeScreenshot(
          player: player,
          videoPath: _currentItem.path,
          setStateCallback: setState,
        ),
        openMarkerEditor: _markerController.openMarkerEditor,
        closeMarkerEditor: _markerController.closeMarkerEditor,
        toggleFullscreen: _toggleFullscreen,
        navigateMedia: _navigateMedia,
        handleDelete: _handleDelete,
        closePreview: () {
          if (widget.isStandalone) {
            if (widget.windowId != null) {
              PersistentViewerManager.closeWindow(int.parse(widget.windowId!));
            }
          } else {
            ref.read(previewFileProvider.notifier).state = null;
          }
        },
        navigatePlaylistHistoryBack: _navigatePlaylistHistoryBack,
        navigatePlaylistHistoryForward: _navigatePlaylistHistoryForward,
        showHud: _hudController.onInteraction,
        hideMenu: _hudController.hideMenu,
        getIsControlsVisible: () => _displayState.isControlsVisible,
        setIsControlsVisible: (v) => setState(
          () => _displayState = _displayState.copyWith(isControlsVisible: v),
        ),
        requestFocus: _focusNode.requestFocus,
        getActiveSeekKey: () => _activeSeekKey,
        setActiveSeekKey: (k) => _activeSeekKey = k,
        getActiveVolumeKey: () => _activeVolumeKey,
        setActiveVolumeKey: (k) => _activeVolumeKey = k,
      ),
    );

    _resolutionKey = GlobalKey();
    _currentItem = widget.item;
    _playbackRepo = PlaybackMemoryRepository(ref.read(databaseProvider));
    if (widget.isStandalone && widget.windowId != null) {
      PersistentViewerManager.getFocusTrigger(
        int.parse(widget.windowId!),
      ).addListener(_onWindowFocus);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(videoIsEmptyProvider.notifier).state = false;
    });

    final settings = ref.read(settingsProvider).value;
    if (settings != null) {
      // showRemainingTime is now managed by VideoBottomControls
    }

    if (_isNetworkStream) {
      final formatsJson = widget.initParams?['formats'] as List?;
      if (formatsJson != null) {
        _availableFormats = formatsJson
            .map(
              (e) => MediaFormat.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
        _availableFormats = _availableFormats
            .where((f) => !f.isAudioOnly)
            .toList();

        final selectedFormatIdStr = widget.initParams?['selectedFormatId']
            ?.toString();

        // Ensure the selected format is prioritized during deduplication
        if (selectedFormatIdStr != null) {
          final selectedIndex = _availableFormats.indexWhere(
            (f) => f.formatId == selectedFormatIdStr,
          );
          if (selectedIndex > 0) {
            final selected = _availableFormats.removeAt(selectedIndex);
            _availableFormats.insert(0, selected);
          }
        }

        final uniqueRes = <String>{};
        _availableFormats.retainWhere((f) => uniqueRes.add(f.resolution));

        int parseRes(String r) {
          final lower = r.toLowerCase();
          if (lower.contains('4k') || lower.contains('2160')) return 2160;
          if (lower.contains('1440') || lower.contains('2k')) return 1440;
          if (lower.contains('1080')) return 1080;
          if (lower.contains('720')) return 720;
          if (lower.contains('480')) return 480;
          final parts = lower.split('x');
          if (parts.length == 2) return int.tryParse(parts[1]) ?? 0;
          return int.tryParse(lower.replaceAll(RegExp('[^0-9]'), '')) ?? 0;
        }

        _availableFormats.sort((a, b) {
          final hA = parseRes(a.resolution);
          final hB = parseRes(b.resolution);
          return hB.compareTo(hA);
        });
      }
      _selectedFormatId = widget.initParams?['selectedFormatId']?.toString();
    }

    // On Linux/GTK, newly spawned windows may take a moment to be mapped by the OS.
    // A delayed focus request ensures the widget grabs focus after the window is fully active.
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (mounted) {
        if (widget.isStandalone && widget.windowId != null) {
          await PersistentViewerManager.presentWindow(
            int.parse(widget.windowId!),
          );
        }
        if (mounted) _focusNode.requestFocus();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();

        final parentPath = p.dirname(widget.item.path);
        final currentRoot = ref.read(videoRootPathProvider);

        // Only update root if it's empty or we navigated outside of it.
        // This prevents the breadcrumb root from resetting when playing a video from a subfolder.
        if (currentRoot.isEmpty || !parentPath.startsWith(currentRoot)) {
          ref.read(videoRootPathProvider.notifier).state = parentPath;
          ref.read(videoPathHistoryProvider.notifier).state = [];
          ref.read(videoPathForwardHistoryProvider.notifier).state = [];
        }
        ref.read(videoCurrentPathProvider.notifier).state = parentPath;
        ref.read(videoSearchQueryProvider.notifier).state = '';
        ref.read(videoViewModeProvider.notifier).state = VideoViewMode.home;
        ref.read(videoSelectionProvider.notifier).state = {};
        ref.read(videoSelectionAnchorProvider.notifier).state = null;

        if (!widget.isStandalone && widget.windowId == null) {
          try {
            final parentSort = ref.read(sortSettingsProvider).option;
            ref.read(videoSortOptionProvider.notifier).state = parentSort;
          } catch (e) {
            debugPrint('Could not read sort settings: $e');
          }
        }
      }
    });
    _currentItem = widget.item;

    // Ensure the provider knows the current item for the sidebar highlighting
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isStandalone) {
        ref.read(previewFileProvider.notifier).state = widget.item;
      }
    });
    _playbackSpeed = widget.initialRate ?? 1.0;
    _isGlobalHudVisible = ref.read(previewHudVisibleProvider);

    if (widget.windowId != null || widget.isStandalone) {
      // In the new Multi-View architecture, we do NOT use window_manager for standalone windows
      // because window_manager only controls the primary application window.
      // Fullscreen and window management is handled natively via PersistentViewerManager.

      // Initialize playlist from passed arguments if available
      if (widget.initParams?.containsKey('playlistJson') ?? false) {
        try {
          final list =
              jsonDecode(widget.initParams!['playlistJson'] as String)
                  as List<dynamic>;
          final currentPath = widget.initParams?['playlistPath'] as String?;
          _standalonePlaylist = list
              .map((e) => FileItem.fromJson(e as Map<String, dynamic>))
              .toList();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(videoQueueProvider.notifier).state = _standalonePlaylist;
          });

          if (currentPath != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(videoCurrentPathProvider.notifier).state = currentPath;
              ref.read(videoRootPathProvider.notifier).state = currentPath;
            });
          }
        } catch (e) {
          debugPrint('[VideoPlayer] Error parsing standalone playlist: $e');
        }
      } else if (!_isNetworkStream) {
        // Only scan local filesystem for sibling videos.
        // Network streams don't have a local parent directory.
        _initStandalonePlaylist();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(videoIsEmptyProvider.notifier).state = false;
        ref.read(videoPlaylistSidebarVisibleProvider.notifier).state = false;
      }
      final initialPath = p.dirname(widget.item.path);
      if (ref.read(videoCurrentPathProvider).isEmpty) {
        ref.read(videoCurrentPathProvider.notifier).state = initialPath;
      }
      if (ref.read(videoRootPathProvider).isEmpty) {
        ref.read(videoRootPathProvider.notifier).state = initialPath;
      }
    });

    WidgetsBinding.instance.addObserver(this);

    _currentItem = widget.item;
    _audioKey = GlobalKey(debugLabel: 'video_audio_${widget.item.path}');
    _subtitleKey = GlobalKey(debugLabel: 'video_subtitle_${widget.item.path}');
    _speedKey = GlobalKey(debugLabel: 'video_speed_${widget.item.path}');
    _displayState = _displayState.copyWith(isOpening: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initPlayerAsync();
    });
  }

  Future<void> _initPlayerAsync() async {
    player = Player();

    await PlayerInitializer.configure(
      player: player,
      isNetworkStream: _isNetworkStream,
      initParams: widget.initParams,
      ref: ref,
    );

    // FIX: On devices where EGL/GPU is unavailable (e.g., certain Linux Mint
    // configurations), media_kit falls back to S/W rendering. The native layer
    // initialises with a 1×1 pixel texture by default, and when mpv's S/W renderer
    // immediately tries to crop a decoded frame to this 1×1 surface, the internal
    // assertion `x1 <= img->w && y1 <= img->h` in mp_image.c fails → core dump.
    //
    // Setting an initial width/height matching the physical screen resolution ensures
    // the render buffer is always large enough to hold any video frame on first render.
    // This is ONLY the starting size — NativeVideoController's videoParamsSubscription
    // calls SetSize with the real video dimensions the moment video-out-params arrive,
    // so the final render size always matches the video's native dimensions and the
    // aspect ratio is fully preserved.
    final display = PlatformDispatcher.instance.displays.isNotEmpty
        ? PlatformDispatcher.instance.displays.first
        : null;
    final safeWidth = (display?.size.width ?? 1920.0).round().clamp(1, 3840);
    final safeHeight = (display?.size.height ?? 1080.0).round().clamp(1, 2160);
    debugPrint(
      '[VideoPlayer] Initial render buffer size: ${safeWidth}x$safeHeight',
    );
    controller = VideoController(
      player,
      configuration: VideoControllerConfiguration(
        width: safeWidth,
        height: safeHeight,
      ),
    );

    // EPX-008: Hardware Decoder Resolution Listener
    _trackSubscription = player.stream.track.listen((track) {
      _fetchFps();

      // Query the actual driver settled on by the engine
      final settings = ref.read(settingsProvider).value;
      if (settings != null &&
          settings.selectedHwDec == 'auto' &&
          settings.cachedResolvedHwDec == null) {
        Future.delayed(const Duration(seconds: 1), () async {
          if (_isClosing || !mounted) return;
          try {
            final dynamic platform = player.platform;
            final currentHwDec =
                await platform.getProperty('hwdec-current') as String?;

            if (currentHwDec != null &&
                currentHwDec != 'no' &&
                currentHwDec.isNotEmpty) {
              debugPrint(
                '[VideoPlayer] Resolved hardware decoder: $currentHwDec. Saving to cache.',
              );
              await ref
                  .read(settingsProvider.notifier)
                  .setCachedResolvedHwDec(currentHwDec);
            }
          } catch (e) {
            debugPrint('[VideoPlayer] Error resolving current hwdec: $e');
          }
        });
      }
    });

    _playingSubscription = player.stream.playing.listen((playing) {
      _isPlayingNotifier.value = playing;
      if (!playing) {
        _savePlaybackPosition();
      }
    });

    player.stream.volume.listen((vol) {
      if (!mounted) return;

      _volumeSaveDebouncer?.cancel();
      _volumeSaveDebouncer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        final settings = ref.read(settingsProvider).value;
        if (settings != null && settings.videoPlayerVolume != vol) {
          ref
              .read(settingsProvider.notifier)
              .saveSettings(settings.copyWith(videoPlayerVolume: vol));
        }
      });
    });

    setState(() => _displayState = _displayState.copyWith(isOpening: true));

    // Ensure the loader is rendered and animating before engine-level open.
    // The double-frame delay (two addPostFrameCallback calls) ensures the Video
    // widget's LayoutBuilder has reported real non-trivial dimensions to the
    // native layer before mpv begins decoding. This closes the race window where
    // the S/W renderer could fire its first render callback while the texture is
    // still at its initial bootstrap size.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _isPlayerInitialized = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openMediaWithDelay();
      });
    });

    // Resume from initial position if provided
    if (widget.initialPosition != null) {
      debugPrint(
        '[VideoPlayer] Target initial position: ${widget.initialPosition}',
      );
      setState(
        () => _displayState = _displayState.copyWith(isSeekingToInitial: true),
      );

      // Wait for player to be truly ready for seeking.
      // catchError handles 'Bad state: No element' which occurs when the media
      // fails to load (e.g. corrupted file / missing moov atom) and the
      // duration stream closes without ever emitting a value > Duration.zero.
      // Without this guard the unhandled Dart exception cascades into GTK
      // assertion crashes on Linux.
      player.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .then((_) async {
            // Small stability delay to ensure engine-level media initialization
            await Future<void>.delayed(const Duration(milliseconds: 200));

            if (mounted) {
              debugPrint(
                '[VideoPlayer] Applying seek to ${widget.initialPosition}',
              );
              await player.seek(widget.initialPosition!);

              setState(() {
                _displayState = _displayState.copyWith(
                  isSeekingToInitial: false,
                );
                // Initially hide controls for a clean startup
                _displayState = _displayState.copyWith(
                  isControlsVisible: false,
                );
              });
            }
          })
          .catchError((Object e) {
            // Media failed to load — stream closed without a valid duration.
            // Reset seek state so the loader is dismissed; the error stream
            // listener will have already set _displayState.hasError = true.
            debugPrint(
              '[VideoPlayer] Seek setup failed (media load error): $e',
            );
            if (mounted) {
              setState(() {
                _displayState = _displayState.copyWith(
                  isSeekingToInitial: false,
                );
              });
            }
          });
    }

    _completedSubscription = player.stream.completed.listen((completed) {
      if (!completed || _isClosing || !mounted) return;
      final isAutoPlay = ref.read(videoAutoPlaySessionProvider);
      if (isAutoPlay) {
        _navigateMedia(true);
      } else {
        player.pause();
      }
    });

    _bufferingSubscription = player.stream.buffering.listen((buffering) {
      if (_isClosing || !mounted) return;

      if (buffering) {
        // Smart Delay: only show loader if buffering persists > 150ms
        // This applies universally to scrubbing, fast seeking, and normal playback
        _smartDelayTimer?.cancel();
        _smartDelayTimer = Timer(const Duration(milliseconds: 150), () {
          if (mounted && !_isClosing) {
            setState(
              () => _displayState = _displayState.copyWith(
                isSmartBuffering: true,
              ),
            );
          }
        });
      } else {
        _smartDelayTimer?.cancel();
        if (mounted) {
          setState(
            () =>
                _displayState = _displayState.copyWith(isSmartBuffering: false),
          );
        }
      }

      if (mounted && _isBuffering != buffering) {
        setState(() => _isBuffering = buffering);
      }
    });

    _errorSubscription = player.stream.error.listen((error) {
      debugPrint('[VideoPlayer] Engine Error: $error');
      if (mounted) {
        setState(() {
          _displayState = _displayState.copyWith(
            isOpening: false,
            isSeekingToInitial: false,
            hasError: true,
            errorMessage: error,
          );
          _isBuffering = false;
        });
      }
    });

    _positionSubscription = player.stream.position.listen((pos) {
      if (_isClosing || !mounted) return;
      if (_preSeekPosition != null) {
        final timeSinceSeek = DateTime.now()
            .difference(_lastSeekTime)
            .inMilliseconds;
        final posDiff = (pos.inMilliseconds - _preSeekPosition!.inMilliseconds)
            .abs();

        // If the position has changed significantly or if it has been longer than 500ms
        // (meaning the player likely resumed natively), consider the seek finished.
        if (posDiff > 100 || timeSinceSeek > 500) {
          _preSeekPosition = null;
          _seekLoaderTimer?.cancel();
          if (_displayState.isSeekLoading) {
            setState(
              () =>
                  _displayState = _displayState.copyWith(isSeekLoading: false),
            );
          }
        }
      }
    });

    _hudController.onInteraction();
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

  /// Opens the video media after a short delay.
  ///
  /// Safe to call since the AudioPlayerView now uses a global Player instance
  /// that doesn't need to be disposed, avoiding native deadlocks.
  Future<void> _openMediaWithDelay() async {
    if (!mounted || _isClosing) return;

    debugPrint('[VideoPlayer] _openMediaWithDelay: START');

    // No longer need to wait for audio player disposal because AudioPlayerView
    // now uses a global, reused Player instance that is never disposed.
    // Minimal delay just to let the frame render
    await Future<void>.delayed(const Duration(milliseconds: 16));
    if (!mounted || _isClosing) return;

    debugPrint('[VideoPlayer] Calling player.open() for: ${_currentItem.path}');
    try {
      await MediaUriHelper.ensureLocalProxy();
      var shouldPlay = true;
      if (ref.read(videoForcePauseNextProvider)) {
        shouldPlay = false;
        ref.read(videoForcePauseNextProvider.notifier).state = false;
      }
      await player.open(
        Media(MediaUriHelper.getSafeMediaUri(_currentItem.path)),
        play: shouldPlay,
      );
      debugPrint('[VideoPlayer] player.open() completed successfully');
      if (mounted) {
        setState(
          () => _displayState = _displayState.copyWith(isOpening: false),
        );
      }
    } catch (e) {
      debugPrint('[VideoPlayer] player.open() FAILED: $e');
      if (mounted) {
        setState(() {
          _displayState = _displayState.copyWith(isOpening: false);
          _isBuffering = false;
        });
      }
    }
  }

  Future<void> _loadMedia(FileItem item) async {
    if (_isClosing) return;

    // 1. Save current position
    await _savePlaybackPosition();

    // 2. Update state
    setState(() {
      _displayState = _displayState.copyWith(
        hasError: false,
        errorMessage: '',
        isEmpty: false,
      );
      _currentItem = item;
      _fps = null;
    });
    ref.read(previewFileProvider.notifier).state = item;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(videoIsEmptyProvider.notifier).state = false;
      }
    });

    // 3. Open new media
    setState(() => _displayState = _displayState.copyWith(isOpening: true));

    // Give the UI time to render the loader before engine init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 16), () async {
        if (mounted) {
          await MediaUriHelper.ensureLocalProxy();
          var shouldPlay = true;
          if (ref.read(videoForcePauseNextProvider)) {
            shouldPlay = false;
            ref.read(videoForcePauseNextProvider.notifier).state = false;
          }
          await player.open(
            Media(MediaUriHelper.getSafeMediaUri(item.path)),
            play: shouldPlay,
          );
          if (mounted) {
            setState(
              () => _displayState = _displayState.copyWith(isOpening: false),
            );
          }

          // 4. Initialize new media (subs, memory) after open completes
          _initMedia();
        }
      });
    });

    _hudController.onInteraction();
  }

  Future<void> _initMedia() async {
    final currentPath = _currentItem.path;

    // 1. External Subtitles
    SubtitleLoader.autoLoadExternalSubtitles(
      player: player,
      videoPath: _currentItem.path,
    );

    // 2. Playback Memory
    final settings = ref.read(settingsProvider).value;
    if (settings?.resumePlayback ?? true) {
      int? savedPos;
      savedPos = await _playbackRepo.getPosition(currentPath);
      debugPrint(
        '[VideoPlayer] getPosition for $currentPath returned: $savedPos',
      );

      if (savedPos != null && savedPos > 0 && widget.initialPosition == null) {
        debugPrint('[VideoPlayer] Resuming from saved position: $savedPos');
        try {
          if (player.state.duration == Duration.zero) {
            await player.stream.duration
                .firstWhere((d) => d > Duration.zero)
                .timeout(const Duration(seconds: 5));
          }

          // Small stability delay to ensure engine-level media initialization
          if (player.state.duration == Duration.zero) {
            await player.stream.duration
                .firstWhere((d) => d > Duration.zero)
                .timeout(const Duration(seconds: 5));
          }
          await Future<void>.delayed(const Duration(milliseconds: 200));

          if (mounted && _currentItem.path == currentPath) {
            debugPrint('[VideoPlayer] Seeking to $savedPos');
            await player.seek(Duration(milliseconds: savedPos));
          }
        } catch (e) {
          debugPrint('[VideoPlayer] Seek setup failed/timed out: $e');
        }
      }
    }
  }

  Future<void> _onResolutionChanged(MediaFormat format) async {
    if (_isClosing || !mounted) return;
    if (_selectedFormatId == format.formatId) return;

    final currentPosition = player.state.position;

    setState(() {
      _selectedFormatId = format.formatId;
      _isBuffering = true;
    });

    try {
      if (_isNetworkStream) {
        final platform = player.platform as dynamic;
        platform.setProperty(
          'ytdl-format',
          '${format.formatId}+bestaudio/best',
        );
        await player.open(
          Media(MediaUriHelper.getSafeMediaUri(_currentItem.path)),
        );
      } else {
        final streamUrl = format.url ?? format.formatString;
        if (streamUrl.isEmpty) {
          debugPrint(
            '[VideoPlayer] Resolution switch aborted: no stream URL available',
          );
          return;
        }
        await player.open(Media(streamUrl));
      }

      // Wait for player to be ready — use timeout to avoid hanging indefinitely
      // if the format can't be opened (e.g. 'Failed to recognize file format')
      final duration = await player.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(const Duration(seconds: 10), onTimeout: () => Duration.zero);
      if (duration > Duration.zero && mounted && !_isClosing) {
        _seekController.requestEngineSeek(currentPosition);
      }
    } catch (e) {
      debugPrint('[VideoPlayer] Error switching resolution: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isBuffering = false;
        });
      }
    }
  }

  Future<void> _savePlaybackPosition({bool force = false}) async {
    // Capture state synchronously before any async operations or disposal
    if (!force && (_isClosing || !mounted)) return;
    final position = player.state.position.inMilliseconds;
    final duration = player.state.duration.inMilliseconds;
    final path = _currentItem.path;

    // Do not save if duration is 0 (player not fully loaded)
    if (duration == 0) return;

    // Don't save if near the end (95%)
    final targetPosition = (position < (duration * 0.95)) ? position : 0;

    debugPrint(
      '[VideoPlayer] _savePlaybackPosition called for: $path, position: $position, duration: $duration, target: $targetPosition',
    );

    if (widget.isStandalone) {
      await _playbackRepo.savePosition(path, targetPosition);
      debugPrint('[VideoPlayer] _savePlaybackPosition saved standalone');
    } else {
      await _playbackRepo.savePosition(path, targetPosition);
      debugPrint('[VideoPlayer] _savePlaybackPosition saved normal');
    }
  }

  bool _isStandaloneFullscreen = false; // It starts maximized, not fullscreen

  Future<void> _toggleFullscreen() async {
    if (widget.isStandalone && widget.windowId != null) {
      final willBeFullScreen = !_isStandaloneFullscreen;
      _isStandaloneFullscreen = willBeFullScreen;
      await PersistentViewerManager.setFullScreen(
        int.parse(widget.windowId!),
        willBeFullScreen,
      );
      if (willBeFullScreen) {
        setState(() {
          _displayState = _displayState.copyWith(isControlsVisible: false);
          _hideTimer?.cancel();
        });
      } else {
        setState(() {
          _displayState = _displayState.copyWith(isControlsVisible: true);
          _hudController.onInteraction();
        });
      }
      return;
    }

    final isFullScreen = await windowManager.isFullScreen();
    final willBeFullScreen = !isFullScreen;

    await windowManager.setFullScreen(willBeFullScreen);
    if (willBeFullScreen) {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
      setState(() {
        _displayState = _displayState.copyWith(isControlsVisible: false);
        _hideTimer?.cancel();
      });
    } else {
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      // Reveal controls when exiting fullscreen (returning to system UI)
      setState(() {
        _displayState = _displayState.copyWith(isControlsVisible: true);
        _hudController.onInteraction();
      });
      _hudController.onInteraction();
    }
    // Linux/GTK window transitions can cause temporary focus loss.
    // We wait for the window state to settle before forcing focus back.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(VideoPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldFormatId = oldWidget.initParams?['selectedFormatId']?.toString();
    final newFormatId = widget.initParams?['selectedFormatId']?.toString();

    final pathChanged = oldWidget.item.path != widget.item.path;
    final formatChanged = oldFormatId != newFormatId;

    if (pathChanged || formatChanged) {
      if (_isNetworkStream) {
        _clearNetworkCache();
        if (formatChanged && newFormatId != null) {
          _selectedFormatId = newFormatId;
          final platform = player.platform as dynamic;
          platform.setProperty('ytdl-format', '$newFormatId+bestaudio/best');
        }
      }
      _loadMedia(widget.item);
    }
  }

  @override
  Future<void> onWindowClose() async {
    if (_isClosing || !widget.isStandalone) return;

    // Mark as closing immediately so all MPV stream callbacks bail out
    _isClosing = true;

    // Save position before any teardown
    await _savePlaybackPosition();

    // Stop the MPV pipeline fully so its render thread stops firing into the FlView.
    // We then await its disposal so it has time to gracefully detach from the GTK
    // OpenGL context *before* the window is actually destroyed.
    try {
      player.stop();
      await player.dispose();
      _isPlayerDisposed = true;
    } catch (e) {
      debugPrint('[VideoPlayer] Error stopping player on window close: $e');
    }

    // Now delegate to PersistentViewerManager which will:
    // 1. Remove the view from the widget tree (unmount Flutter widgets)
    // 2. Wait 150ms for the engine to fully release its EGL/GL context
    // 3. Destroy the native GTK window
    if (widget.windowId != null) {
      await PersistentViewerManager.closeWindow(int.parse(widget.windowId!));
    }
  }

  Future<void> _clearNetworkCache() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final cacheDir = Directory(p.join(tempDir.path, 'onyx_stream_cache'));
      if (cacheDir.existsSync()) {
        final contents = cacheDir.listSync();
        for (final file in contents) {
          try {
            file.deleteSync(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    // 1. Mark as closing immediately to block incoming callbacks/state updates
    _isClosing = true;

    if (_isNetworkStream) {
      _clearNetworkCache();
    }

    // 2. Unregister from all global observers
    WidgetsBinding.instance.removeObserver(this);
    if (widget.isStandalone) {
      windowManager.removeListener(this);
    }

    // 3. Stop all timers and animations
    _hideTimer?.cancel();
    _fastSeekTimer?.cancel();
    _volumeTimer?.cancel();
    _volumeSaveDebouncer?.cancel();
    _volumeOverlayTimer?.cancel();
    _seekIndicatorTimer?.cancel();
    _snapshotToastTimer?.cancel();
    _smartDelayTimer?.cancel();
    _hoverExitTimer?.cancel();
    _scrubThrottleTimer?.cancel();
    _scrollResetTimer?.cancel();
    _scrollVolumeTimer?.cancel();
    _scrollSpeedTimer?.cancel();
    _speedOverlayTimer?.cancel();
    _virtualSeekCleanupTimer?.cancel();
    _engineSeekTimer?.cancel();

    // 4. Cancel all stream subscriptions
    _trackSubscription?.cancel();
    _completedSubscription?.cancel();
    _bufferingSubscription?.cancel();
    _positionSubscription?.cancel();
    _seekLoaderTimer?.cancel();
    _errorSubscription?.cancel();
    _playingSubscription?.cancel();
    _audioTrackInitSubscription?.cancel();
    _subtitleTrackInitSubscription?.cancel();

    // 5. Save position using a non-awaited call (we captured state if needed)
    _savePlaybackPosition(force: true);

    // 6. Dispose UI controllers
    _isPlayingNotifier.dispose();
    _hoverXNotifier.dispose();
    _focusNode.dispose();
    if (widget.isStandalone && widget.windowId != null) {
      PersistentViewerManager.getFocusTrigger(
        int.parse(widget.windowId!),
      ).removeListener(_onWindowFocus);
    }
    try {
      final emptyNotifier = ref.read(videoIsEmptyProvider.notifier);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        emptyNotifier.state = false;
      });
    } catch (_) {}
    _activeMenuEntry?.remove();
    _activeMenuEntry = null;

    // 7. Final engine teardown
    // We pause before disposing to ensure the native pipeline is idle
    try {
      if (!_isPlayerDisposed) {
        player.pause();
        player.dispose();
        _isPlayerDisposed = true;
      }
    } catch (e) {
      debugPrint('[VideoPlayer] Error during engine disposal: $e');
    }

    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (_activeMenuEntry != null) {
      _hudController.hideMenu();
    }
  }

  Future<void> _fetchFps() async {
    try {
      if (_isClosing || !mounted) return;
      // Small delay to allow mpv to parse container metadata
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (_isClosing || !mounted) return;

      var fps = player.state.track.video.fps;

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
      // Close preview first so UI feels responsive
      ref.read(previewFileProvider.notifier).state = null;
      // Use the singleton manager to handle persistent window logic
      await PersistentViewerManager.openMedia(windowParams);
    } catch (e) {
      debugPrint('Error opening persistent viewer: $e');
      await player.play(); // Rescue playback on failure
    }
  }

  void _toggleMute() {
    setState(() {
      _displayState = _displayState.copyWith(isMuted: !_displayState.isMuted);
      player.setVolume(_displayState.isMuted ? 0 : 100);
    });
  }

  void _startVolumeAdjustment({required bool isIncrease}) {
    player.setVolume(
      (player.state.volume + (isIncrease ? 5 : -5)).clamp(0, 200),
    );
    _hudController.showVolumeOverlay();

    _volumeTimer?.cancel();
    _volumeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      player.setVolume(
        (player.state.volume + (isIncrease ? 2 : -2)).clamp(0, 200),
      );
      _hudController.showVolumeOverlay();
    });
  }

  void _stopVolumeAdjustment() {
    _volumeTimer?.cancel();
    _volumeTimer = null;
    _activeVolumeKey = null;
  }

  void _navigateMedia(bool forward) {
    if (widget.isStandalone) {
      // 1. Standalone Mode: Use _standalonePlaylist
      var mediaItems = _standalonePlaylist;
      if (mediaItems.isEmpty) {
        mediaItems = ref.read(videoQueueProvider);
      }

      if (mediaItems.isEmpty) return;

      final currentIndex = mediaItems.indexWhere(
        (i) => i.path == _currentItem.path,
      );

      if (currentIndex == -1 || mediaItems.length == 1) {
        player.pause();
        setState(() => _displayState = _displayState.copyWith(isEmpty: true));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(videoIsEmptyProvider.notifier).state = true;
        });
        return;
      }

      int nextIndex;
      if (forward) {
        if (currentIndex == mediaItems.length - 1) {
          player.pause();
          setState(() => _displayState = _displayState.copyWith(isEmpty: true));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(videoIsEmptyProvider.notifier).state = true;
          });
          return;
        }
        nextIndex = currentIndex + 1;
      } else {
        if (currentIndex == 0) {
          player.pause();
          setState(() => _displayState = _displayState.copyWith(isEmpty: true));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(videoIsEmptyProvider.notifier).state = true;
          });
          return;
        }
        nextIndex = currentIndex - 1;
      }

      _loadMedia(mediaItems[nextIndex]);
    } else {
      // 2. Inline Mode: Local Riverpod state update
      var mediaItems = ref
          .read(filteredAndSortedVideoQueueProvider)
          .where((i) => i.type == FileItemType.video)
          .toList();
      if (mediaItems.isEmpty) {
        final items = ref.read(sortedDirectoryItemsProvider).value ?? [];
        mediaItems = items.where((i) => i.type == FileItemType.video).toList();
      }

      if (mediaItems.isEmpty) return;

      final currentIndex = mediaItems.indexWhere(
        (i) => i.path == _currentItem.path,
      );
      if (currentIndex == -1 || mediaItems.length == 1) {
        player.pause();
        setState(() => _displayState = _displayState.copyWith(isEmpty: true));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(videoIsEmptyProvider.notifier).state = true;
        });
        return;
      }

      int nextIndex;
      if (forward) {
        if (currentIndex == mediaItems.length - 1) {
          player.pause();
          setState(() => _displayState = _displayState.copyWith(isEmpty: true));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(videoIsEmptyProvider.notifier).state = true;
          });
          return;
        }
        nextIndex = currentIndex + 1;
      } else {
        if (currentIndex == 0) {
          player.pause();
          setState(() => _displayState = _displayState.copyWith(isEmpty: true));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(videoIsEmptyProvider.notifier).state = true;
          });
          return;
        }
        nextIndex = currentIndex - 1;
      }

      ref.read(previewFileProvider.notifier).state = mediaItems[nextIndex];
    }
  }

  Future<void> _handleItemsMoved(List<String> paths) async {
    if (paths.contains(_currentItem.path)) {
      await player.pause();
      _navigateMedia(true);
    }
  }

  Future<void> _handleDelete({
    required bool permanent,
    List<String>? paths,
    bool isMove = false,
  }) async {
    player.pause();

    final settings = ref.read(settingsProvider).value;
    var shouldConfirm = permanent || (settings?.confirmDeleteVideo ?? true);

    if (_sessionSkipConfirm) {
      shouldConfirm = false;
    }

    if (shouldConfirm) {
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) {
          if (permanent) {
            var size = 0;
            final targetList = paths ?? [widget.item.path];
            for (final p in targetList) {
              try {
                size += File(p).lengthSync();
              } catch (_) {}
            }
            return PermanentDeleteDialog(
              filesCount: targetList.length,
              foldersCount: 0,
              totalSize: StringUtils.formatBytes(size),
              onDontAskAgainChanged: (val) {
                _sessionSkipConfirm = val;
              },
            );
          } else {
            return ViewerDeleteDialog(
              fileName: paths?.length == 1
                  ? p.basename(paths!.first)
                  : widget.item.name,
              permanent: permanent,
              onDontAskAgainChanged: (val) {
                _sessionSkipConfirm = val;
              },
            );
          }
        },
      );
      if (shouldDelete != true) return;

      // Allow the delete dialog's closing animation to finish smoothly
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }

    final targetPaths = paths ?? [widget.item.path];

    if (!isMove) {
      final repo = ref.read(directoryRepositoryProvider);
      final taskId = ref
          .read(taskProvider.notifier)
          .addTask(
            title: permanent
                ? 'Deleting video permanently'
                : 'Moving video to Trash',
            subtitle: targetPaths.length == 1
                ? p.basename(targetPaths.first)
                : '${targetPaths.length} items',
            sourcePaths: targetPaths,
            isLight: true,
          );

      try {
        await repo.deleteItems(
          targetPaths,
          permanent: permanent,
          taskId: taskId,
          onLog: (msg) => ref.read(taskProvider.notifier).addLog(taskId, msg),
        );
        ref.read(taskProvider.notifier).completeTask(taskId);
      } catch (e) {
        ref.read(taskProvider.notifier).failTask(taskId, e.toString());
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Deletion failed: $e')));
        }
      }
    }

    if (!widget.isStandalone) {
      ref.read(directoryItemsProvider.notifier).refresh();
      if (targetPaths.contains(_currentItem.path)) {
        final isAutoPlay = ref.read(videoAutoPlaySessionProvider);
        if (!isAutoPlay) {
          ref.read(videoForcePauseNextProvider.notifier).state = true;
        }
        _navigateMedia(true);
      }
    } else {
      // Standalone logic for closing if current item is deleted
      if (targetPaths.contains(_currentItem.path)) {
        final isAutoPlay = ref.read(videoAutoPlaySessionProvider);
        if (!isAutoPlay) {
          ref.read(videoForcePauseNextProvider.notifier).state = true;
        }
        _navigateMedia(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(videoRestartSignalProvider, (previous, next) {
      if (_displayState.isEmpty) {
        setState(() => _displayState = _displayState.copyWith(isEmpty: false));
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(videoIsEmptyProvider.notifier).state = false;
        });
        _loadMedia(_currentItem);
      }
    });

    ref.listen(previewHudVisibleProvider, (previous, next) {
      if (mounted) {
        setState(
          () =>
              _displayState = _displayState.copyWith(isGlobalHudVisible: next),
        );
      }
    });

    if (!_isPlayerInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: BubbleLoader(size: 40)),
      );
    }

    // In standalone mode, we ignore the global HUD visibility provider as the window
    // itself is the dedicated viewer. We only care about the internal control timer.
    // Hide the main HUD (timeline, play button, etc.) during active trackpad gestures
    // to provide a cleaner view while adjusting volume/speed/scrubbing.
    final isVisible =
        (_displayState.isControlsVisible ||
            _displayState.isMarkerEditorActive ||
            _displayState.isMarkerMenuVisible) &&
        _scrollLockAxis == null &&
        (widget.windowId != null || widget.isStandalone || _isGlobalHudVisible);

    return PopScope(
      canPop: widget.windowId != null || widget.isStandalone,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Specifically block back navigation in preview mode
      },
      child: Consumer(
        builder: (context, sidebarRef, _) {
          final isSidebarOpen = sidebarRef.watch(
            videoPlaylistSidebarVisibleProvider,
          );

          final screenWidth = MediaQuery.of(context).size.width;
          const minWidth = 240.0;
          final maxWidth = screenWidth * 0.40;
          final savedWidth = sidebarRef.watch(
            videoPlaylistSidebarWidthProvider,
          );
          var panelWidth = savedWidth ?? (screenWidth * 0.25);
          panelWidth = panelWidth.clamp(minWidth, maxWidth);

          final sidebarWidth = isSidebarOpen ? panelWidth : 0.0;

          return MouseRegion(
            cursor: (_isSidebarDragging && !_isSidebarDragOutOfBounds)
                ? SystemMouseCursors.resizeLeftRight
                : MouseCursor.defer,
            child: Row(
              children: [
                // ── Sidebar Panel ───────────────────────────────────────
                SizedBox(
                  width: sidebarWidth,
                  child: isSidebarOpen
                      ? VideoPlaylistSidebar(
                          onVideoSelected: (video) {
                            if (widget.isStandalone) {
                              _loadMedia(video);
                            } else {
                              ref.read(previewFileProvider.notifier).state =
                                  video;
                            }
                          },
                          onDelete: (paths) =>
                              _handleDelete(permanent: false, paths: paths),
                          onMove: _handleItemsMoved,
                          onReload: () => ref
                              .read(directoryItemsProvider.notifier)
                              .refresh(),
                        )
                      : const SizedBox.shrink(),
                ),
                // ── Resize Handle ───────────────────────────────────────
                if (isSidebarOpen)
                  MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (details) {
                        setState(() {
                          _isSidebarDragging = true;
                          _isSidebarDragOutOfBounds = false;
                          _sidebarDragStartWidth = panelWidth;
                          _sidebarDragStartX = details.globalPosition.dx;
                        });
                      },
                      onPanUpdate: (details) {
                        final dx =
                            details.globalPosition.dx - _sidebarDragStartX;
                        final intendedWidth = _sidebarDragStartWidth + dx;
                        setState(() {
                          _isSidebarDragOutOfBounds =
                              intendedWidth < minWidth ||
                              intendedWidth > maxWidth;
                        });
                        final newWidth = intendedWidth.clamp(
                          minWidth,
                          maxWidth,
                        );
                        ref
                                .read(
                                  videoPlaylistSidebarWidthProvider.notifier,
                                )
                                .state =
                            newWidth;
                      },
                      onPanEnd: (_) {
                        setState(() {
                          _isSidebarDragging = false;
                          _isSidebarDragOutOfBounds = false;
                        });
                      },
                      child: Container(
                        width: 6,
                        color: _isSidebarDragging
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.transparent,
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                // ── Video Player ─────────────────────────────────────
                Expanded(
                  child: Focus(
                    focusNode: _focusNode,
                    autofocus: true,
                    onFocusChange: (hasFocus) {
                      if (!hasFocus) {
                        _seekController.stopFastSeek();
                        _stopVolumeAdjustment();
                      }
                    },
                    onKeyEvent: (node, event) => _keyboardHandler.handle(event),
                    child: Listener(
                      onPointerSignal: (event) {
                        if (_displayState.isMarkerEditorActive) {
                          final box =
                              _markerEditorKey.currentContext
                                      ?.findRenderObject()
                                  as RenderBox?;
                          if (box != null) {
                            final local = box.globalToLocal(event.position);
                            if (box.paintBounds.contains(local)) return;
                          }
                          _markerEditorKey.currentState?.shake();
                          return;
                        }
                        _gestureHandler.handlePointerScroll(event);
                      },
                      onPointerPanZoomUpdate: (event) {
                        if (_displayState.isMarkerEditorActive) {
                          final box =
                              _markerEditorKey.currentContext
                                      ?.findRenderObject()
                                  as RenderBox?;
                          if (box != null) {
                            final local = box.globalToLocal(event.position);
                            if (box.paintBounds.contains(local)) return;
                          }
                          _markerEditorKey.currentState?.shake();
                          return;
                        }
                        _gestureHandler.handlePointerPanZoomUpdate(event);
                      },
                      onPointerPanZoomEnd: (event) {
                        if (_displayState.isMarkerEditorActive) return;
                        _gestureHandler.handlePointerPanZoomEnd(event);
                      },
                      behavior: HitTestBehavior.translucent,
                      child: GestureDetector(
                        onTap: () {
                          _focusNode.requestFocus();
                          _hudController.onInteraction();
                        },
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
                              context.size?.width ??
                              MediaQuery.of(context).size.width;
                          final isForward = _doubleTapPosition!.dx > width / 2;

                          _seekController.performStepSeek(isForward: isForward);
                        },
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth == 0 ||
                                constraints.maxHeight == 0) {
                              return const SizedBox();
                            }
                            _playerWidth = constraints.maxWidth;
                            _playerHeight = constraints.maxHeight;

                            return ColoredBox(
                              key: _playerKey,
                              color: Colors.black,
                              child: Stack(
                                children: [
                                  // Interaction Trigger Zone (Full Viewport)
                                  Positioned.fill(
                                    child: MouseRegion(
                                      cursor: isVisible
                                          ? MouseCursor.defer
                                          : SystemMouseCursors.none,
                                      onEnter: (_) =>
                                          _hudController.onInteraction(),
                                      onHover: (_) =>
                                          _hudController.onInteraction(),
                                      child: Stack(
                                        children: [
                                          // Video Player (isolated render pipeline)
                                          if (_displayState.isEmpty)
                                            Positioned.fill(
                                              child: VideoEmptyState(
                                                isStandalone:
                                                    widget.isStandalone,
                                                onClose: () {
                                                  if (widget.isStandalone &&
                                                      widget.windowId != null) {
                                                    PersistentViewerManager.closeWindow(
                                                      int.parse(
                                                        widget.windowId!,
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                            )
                                          else if (_displayState.hasError)
                                            Positioned.fill(
                                              child: VideoErrorState(
                                                errorMessage:
                                                    _displayState.errorMessage,
                                                isStandalone:
                                                    widget.isStandalone,
                                                onClose: () {
                                                  if (widget.isStandalone) {
                                                    if (widget.windowId !=
                                                        null) {
                                                      PersistentViewerManager.closeWindow(
                                                        int.parse(
                                                          widget.windowId!,
                                                        ),
                                                      );
                                                    }
                                                  } else {
                                                    ref
                                                        .read(
                                                          videoViewModeProvider
                                                              .notifier,
                                                        )
                                                        .state = VideoViewMode
                                                        .home;
                                                  }
                                                },
                                              ),
                                            )
                                          else if (_isPlayerInitialized)
                                            RepaintBoundary(
                                              child: Center(
                                                child: Video(
                                                  controller: controller,
                                                  controls: (state) =>
                                                      const SizedBox.shrink(),
                                                ),
                                              ),
                                            ),

                                          // Unified BubbleLoader
                                          VideoLoadingOverlay(
                                            isVisible:
                                                !_displayState.hasError &&
                                                (_displayState.isOpening ||
                                                _displayState
                                                    .isSeekingToInitial ||
                                                _displayState
                                                    .isSmartBuffering ||
                                                _displayState.isSeekLoading),
                                          ),

                                          // Snapshot Flash Effect
                                          Positioned.fill(
                                            child: SnapshotFlash(
                                              isVisible:
                                                  _displayState.showFlash,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),

                                  // Snapshot Glass Toast
                                  Positioned(
                                    bottom: 120,
                                    left: 0,
                                    right: 0,
                                    child: SnapshotToast(
                                      isVisible:
                                          _displayState.showSnapshotToast,
                                    ),
                                  ),

                                  // Volume Overlay (Right side)
                                  Positioned(
                                    right: 32,
                                    top: 0,
                                    bottom: 0,
                                    child: VolumeOverlayWrapper(
                                      isVisible:
                                          _displayState.isVolumeOverlayVisible,
                                      volumeStream: player.stream.volume,
                                      currentVolume: player.state.volume,
                                      onVolumeChanged: (v) =>
                                          player.setVolume(v),
                                    ),
                                  ),

                                  // Speed Overlay (Left side)
                                  Positioned(
                                    left: 32,
                                    top: 0,
                                    bottom: 0,
                                    child: SpeedOverlayWrapper(
                                      isVisible:
                                          _displayState.showSpeedOverlayVisible,
                                      rateStream: player.stream.rate,
                                      currentRate: player.state.rate,
                                      onSpeedChanged: (r) => player.setRate(r),
                                    ),
                                  ),

                                  // Persistent Speed Indicator Text (Bottom Left)
                                  Positioned(
                                    bottom: 24,
                                    left: 24,
                                    child: SpeedIndicator(
                                      rateStream: player.stream.rate,
                                      currentRate: player.state.rate,
                                    ),
                                  ),

                                  // Seek Indicator Overlay (Top Right)
                                  Positioned(
                                    top: 100,
                                    right: 64,
                                    child: SeekIndicator(
                                      isVisible:
                                          _displayState.isSeekIndicatorVisible,
                                      displayPosition: displayPosition,
                                      totalDuration: player.state.duration,
                                    ),
                                  ),

                                  // Top HUD (Standardized)
                                  if (!_displayState.isEmpty)
                                    Positioned(
                                      top: 0,
                                    left: 0,
                                    right: 0,
                                    child: AnimatedOpacity(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
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

                                          var q = ref
                                              .watch(
                                                filteredAndSortedVideoQueueProvider,
                                              )
                                              .where(
                                                (i) =>
                                                    i.type ==
                                                    FileItemType.video,
                                              )
                                              .toList();
                                          if (q.isEmpty) {
                                            final items =
                                                ref
                                                    .watch(
                                                      sortedDirectoryItemsProvider,
                                                    )
                                                    .value ??
                                                [];
                                            q = items
                                                .where(
                                                  (i) =>
                                                      i.type ==
                                                      FileItemType.video,
                                                )
                                                .toList();
                                          }
                                          final index = q.indexWhere(
                                            (i) => i.path == _currentItem.path,
                                          );
                                          final indexString = index != -1
                                              ? ' • ${index + 1} / ${q.length}'
                                              : '';

                                          return ViewerTopBar(
                                            title: _displayState.isEmpty ? '' : _currentItem.name,
                                            metadata: _displayState.isEmpty
                                                ? ''
                                                : '$res$fpsString$indexString',
                                            isStandalone: widget.isStandalone,
                                            onPopOut: _openInNewWindow,
                                            onClose: () =>
                                                ref
                                                        .read(
                                                          previewFileProvider
                                                              .notifier,
                                                        )
                                                        .state =
                                                    null,
                                            extraActions: [
                                              if (!_displayState.isEmpty) ...[
                                                if (!_isNetworkStream)
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
                                                onPressed: () =>
                                                    SettingsDialog.show(
                                                      context,
                                                      initialTab: 1,
                                                      section: 'Video',
                                                    ),
                                                tooltip: 'Video Settings',
                                              ),
                                              const SizedBox(width: 8),
                                              ],
                                            ],
                                          );
                                        },
                                      ),
                                    ),
                                  ),

                                  // Custom Bottom Controls
                                  VideoBottomControls(
                                    displayState: _displayState.copyWith(
                                      isGlobalHudVisible: _isGlobalHudVisible,
                                      fps: _fps,
                                      showRemainingTime: false,
                                      isNetworkStream: _isNetworkStream,
                                      playbackSpeed: _playbackSpeed,
                                      scrollLockAxis: _scrollLockAxis,
                                      windowId: widget.windowId,
                                      isStandalone: widget.isStandalone,
                                    ),
                                    player: player,
                                    currentItem: _currentItem,
                                    displayPosition: displayPosition,
                                    availableFormats: _availableFormats,
                                    selectedFormatId: _selectedFormatId,
                                    onResolutionChanged: _onResolutionChanged,
                                    onInteraction: _hudController.onInteraction,
                                    onShowSeekIndicator:
                                        _hudController.showSeekIndicator,
                                    onToggleMute: _toggleMute,
                                    onToggleFullscreen: _toggleFullscreen,
                                    onNavigateMedia: _navigateMedia,
                                    onShowMenu: _hudController.showMenu,
                                    onOpenMarkerEditor: (m) => _markerController
                                        .openMarkerEditor(marker: m),
                                    audioKey: _audioKey,
                                    subtitleKey: _subtitleKey,
                                    speedKey: _speedKey,
                                    resolutionKey: _resolutionKey,
                                    onMarkerMenuVisibilityChanged: (v) {
                                      if (mounted) {
                                        setState(
                                          () => _displayState = _displayState
                                              .copyWith(isMarkerMenuVisible: v),
                                        );
                                        _hudController.onInteraction();
                                      }
                                    },
                                    onStepSeek: _seekController.performStepSeek,
                                    onStartFastSeek:
                                        _seekController.startFastSeek,
                                    onStopFastSeek:
                                        _seekController.stopFastSeek,
                                    playingNotifier: _isPlayingNotifier,
                                    playbackSpeed: _playbackSpeed,
                                  ),

                                  // EPX-009: Marker Editor Overlay with full-screen click-outside dismissal
                                  if (_displayState.isMarkerEditorActive &&
                                      _markerEditorAnchor != null)
                                    Builder(
                                      builder: (context) {
                                        // We need to calculate the slider's position relative to the player's root stack
                                        final playerBox =
                                            _playerKey.currentContext
                                                    ?.findRenderObject()
                                                as RenderBox?;
                                        final sliderBox =
                                            _sliderKey.currentContext
                                                    ?.findRenderObject()
                                                as RenderBox?;

                                        double sliderX = 0;
                                        if (playerBox != null &&
                                            sliderBox != null) {
                                          sliderX = sliderBox
                                              .localToGlobal(
                                                Offset.zero,
                                                ancestor: playerBox,
                                              )
                                              .dx;
                                        }

                                        final anchorX =
                                            sliderX + _markerEditorAnchor!.dx;
                                        final idealLeft = anchorX - 210;
                                        final clampedLeft = idealLeft.clamp(
                                          16.0,
                                          _playerWidth - 420 - 16.0,
                                        );
                                        final notchOffset =
                                            anchorX - clampedLeft;

                                        return Positioned.fill(
                                          child: GestureDetector(
                                            onTap: () => _markerController
                                                .closeMarkerEditor(
                                                  resume: true,
                                                ),
                                            behavior: HitTestBehavior.opaque,
                                            onScaleUpdate: (_) =>
                                                _markerEditorKey.currentState
                                                    ?.shake(),
                                            onDoubleTap: () {},
                                            child: Stack(
                                              children: [
                                                Positioned(
                                                  left: clampedLeft,
                                                  bottom:
                                                      104, // Aligned with the track top
                                                  child: MarkerEditorOverlay(
                                                    key: _markerEditorKey,
                                                    initialContent:
                                                        _editingMarker?.content,
                                                    initialIcon:
                                                        _editingMarker?.icon,
                                                    timestamp:
                                                        _editingMarker
                                                            ?.timestamp ??
                                                        player.state.position,
                                                    notchOffset: notchOffset,
                                                    onSave: _markerController
                                                        .saveMarker,
                                                    onCancel: () =>
                                                        _markerController
                                                            .closeMarkerEditor(
                                                              resume: true,
                                                            ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _initStandalonePlaylist() async {
    try {
      final videos = <FileItem>[];

      if (widget.initParams != null && widget.initParams!['playlistPaths'] != null) {
        final paths = List<String>.from(widget.initParams!['playlistPaths'] as Iterable);
        for (final path in paths) {
          final file = File(path);
          if (file.existsSync()) {
            final name = p.basename(path);
            try {
              final stat = await file.stat();
              videos.add(
                FileItem(
                  name: name,
                  path: path,
                  type: FileItemType.video,
                  sizeBytes: stat.size,
                  modified: stat.modified,
                ),
              );
            } catch (e) {
              debugPrint('Error stating file $path: $e');
            }
          }
        }
      } else {
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
        
        videos.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      }

      debugPrint('[VideoPlayer] Standalone playlist count: ${videos.length}');

      if (mounted) {
        setState(() {
          _standalonePlaylist = videos;
        });
        ref.read(videoQueueProvider.notifier).state = _standalonePlaylist;
      }
    } catch (e) {
      debugPrint('[VideoPlayer] Error in _initStandalonePlaylist: $e');
    }
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
            ? AppColors.violet.withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active
              ? AppColors.violet.withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.05),
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

  void _navigatePlaylistHistoryBack(WidgetRef ref) {
    final history = ref.read(videoPathHistoryProvider);
    if (history.isNotEmpty) {
      final newPath = history.last;
      final currentPath = ref.read(videoCurrentPathProvider);

      ref.read(videoPathHistoryProvider.notifier).state = history.sublist(
        0,
        history.length - 1,
      );
      ref
          .read(videoPathForwardHistoryProvider.notifier)
          .update((state) => [...state, currentPath]);

      _openPlaylistFolder(ref, newPath);
    }
  }

  void _navigatePlaylistHistoryForward(WidgetRef ref) {
    final forwardHistory = ref.read(videoPathForwardHistoryProvider);
    if (forwardHistory.isNotEmpty) {
      final newPath = forwardHistory.last;
      final currentPath = ref.read(videoCurrentPathProvider);

      ref.read(videoPathForwardHistoryProvider.notifier).state = forwardHistory
          .sublist(0, forwardHistory.length - 1);
      ref
          .read(videoPathHistoryProvider.notifier)
          .update((state) => [...state, currentPath]);

      _openPlaylistFolder(ref, newPath);
    }
  }

  Future<void> _openPlaylistFolder(WidgetRef ref, String path) async {
    final repo = ref.read(directoryRepositoryProvider);
    final showHidden = ref.read(videoShowHiddenProvider);
    try {
      final items = await repo.listDirectory(path);
      final mediaFiles = await compute(processMediaQueueIsolate, {
        'items': items.map((e) => e.toJson()).toList(),
        'showHidden': showHidden,
        'targetType': FileItemType.video.index,
      });
      ref.read(videoCurrentPathProvider.notifier).state = path;
      ref.read(videoQueueProvider.notifier).state = mediaFiles;
      ref.read(videoSelectionProvider.notifier).state = {};
      ref.read(videoSelectionAnchorProvider.notifier).state = null;
    } catch (e) {
      debugPrint('Error opening folder: $e');
    }
  }
}
