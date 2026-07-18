import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:onyxcore/core/playlist/media_queue_isolate.dart';
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
import 'package:onyxcore/features/video_player/presentation/widgets/video_speed_overlay.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/track_selector_menu.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/playback_speed_control.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/video_playlist_sidebar.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_playlist_providers.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/hover_preview.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/video_player/data/repositories/playback_memory_repository.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:onyxcore/features/video_player/domain/entities/video_marker.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_markers_provider.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/marker_editor_overlay.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/timeline_marker.dart';
import 'package:onyxcore/features/file_picker/presentation/widgets/custom_file_picker_dialog.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/features/settings/presentation/widgets/settings_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/core/utils/media_uri_helper.dart';
import 'package:onyxcore/core/widgets/viewer_top_bar.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
import 'package:window_manager/window_manager.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
// import removed
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/dialogs.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';

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
  bool _isAudioMenuVisible = false;
  // ── Video Playlist Sidebar ──
  bool _isSidebarDragging = false;
  bool _isSubtitleMenuVisible = false;
  bool _isSpeedMenuVisible = false;
  double _playbackSpeed = 1.0;
  double? _fps;
  Timer? _hideTimer;
  Timer? _fastSeekTimer;
  Timer? _volumeTimer;
  Timer? _volumeSaveDebouncer;
  Timer? _volumeOverlayTimer;
  Timer? _seekIndicatorTimer;
  LogicalKeyboardKey? _activeSeekKey;
  LogicalKeyboardKey? _activeVolumeKey;
  bool _isSeekIndicatorVisible = false;
  bool _isOpening = false;
  bool _isBuffering = false;
  Timer? _virtualSeekCleanupTimer;
  StreamSubscription<dynamic>? _trackSubscription;
  StreamSubscription<dynamic>? _completedSubscription;
  StreamSubscription<dynamic>? _bufferingSubscription;
  StreamSubscription<dynamic>? _errorSubscription;
  bool _showFlash = false;
  bool _showSnapshotToast = false;
  Timer? _snapshotToastTimer;
  StreamSubscription<dynamic>? _audioTrackInitSubscription;

  // BUG-001: Sliding Window seek state
  bool _isFastSeeking = false;
  bool _isPlayerInitialized = false;
  bool _isPlayerDisposed = false;

  bool _isSmartBuffering = false;
  bool _isSeekLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _seekLoaderTimer;
  Duration? _preSeekPosition;
  DateTime _lastSeekTime = DateTime.now();
  StreamSubscription<dynamic>? _positionSubscription;
  double _playerWidth = 0;
  double _playerHeight = 0; // ignore: unused_field
  Timer? _smartDelayTimer;
  bool _isScrubbing = false;
  bool _wasPlayingBeforeScrub = false;
  final GlobalKey _sliderKey = GlobalKey();
  final GlobalKey _playerKey = GlobalKey();

  // BUG-001: Hover preview state
  final ValueNotifier<double?> _hoverXNotifier = ValueNotifier<double?>(null);
  double _sliderWidth = 0;
  bool _isSliderHovered = false;
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
    if (_isScrubbing && _virtualScrubPosition != null) {
      return _virtualScrubPosition!;
    }
    if (_isFastSeeking && _virtualSeekPosition != null) {
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
      _isAudioMenuVisible ||
      _isSubtitleMenuVisible ||
      _isSpeedMenuVisible ||
      _isMarkerMenuVisible;

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
  bool _showSpeedOverlayVisible = false;
  DateTime? _lastKeyEventTime;

  // EPX-009: Marker System state
  bool _isMarkerEditorActive = false;
  VideoMarker? _editingMarker;
  Offset? _markerEditorAnchor;
  bool _isHoveringMarker = false;
  bool _isMarkerMenuVisible = false;
  final GlobalKey<MarkerEditorOverlayState> _markerEditorKey =
      GlobalKey<MarkerEditorOverlayState>();
  final LayerLink _sliderLink = LayerLink();

  bool get _isNetworkStream => widget.initParams?['is_network_stream'] == true;
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier<bool>(false);
  StreamSubscription<dynamic>? _playingSubscription;

  bool _isSidebarDragOutOfBounds = false;
  double _sidebarDragStartWidth = 0.0;
  double _sidebarDragStartX = 0.0;
  bool _isEmpty = false;
  late final PlaybackMemoryRepository _playbackRepo;

  List<MediaFormat> _availableFormats = [];
  String? _selectedFormatId;

  void _onWindowFocus() {
    if (mounted) _focusNode.requestFocus();
  }

  @override
  void initState() {
    super.initState();
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
      _showRemainingTime = settings.videoShowRemainingTime;
    }

    if (_isNetworkStream) {
      final formatsJson = widget.initParams?['formats'] as List?;
      if (formatsJson != null) {
        _availableFormats = formatsJson
            .map((e) => MediaFormat.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        _availableFormats = _availableFormats
            .where((f) => !f.isAudioOnly)
            .toList();

        final selectedFormatIdStr = widget.initParams?['selectedFormatId']?.toString();
        
        // Ensure the selected format is prioritized during deduplication
        if (selectedFormatIdStr != null) {
          final selectedIndex = _availableFormats.indexWhere((f) => f.formatId == selectedFormatIdStr);
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
          return int.tryParse(lower.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
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
            debugPrint("Could not read sort settings: $e");
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
      if (widget.initParams?.containsKey('playlistJson') == true) {
        try {
          final List<dynamic> list =
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
    _isOpening = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initPlayerAsync();
    });
  }

  Future<void> _initPlayerAsync() async {
    player = Player();

    // BUG-001: Sliding Window buffer configuration
    if (player.platform != null) {
      final dynamic platform = player.platform;

      if (_isNetworkStream) {
        final selectedFormatId = widget.initParams?['selectedFormatId'] as String?;
        if (selectedFormatId != null) {
          platform.setProperty('ytdl-format', '$selectedFormatId+bestaudio/best');
        } else {
          platform.setProperty('ytdl-format', 'bestvideo+bestaudio/best');
        }
        
        final audioUrl = widget.initParams?['audioUrl'] as String?;
        if (audioUrl != null && audioUrl.isNotEmpty) {
          platform.setProperty('audio-file', audioUrl);
        }

        final ytDlpPath = p.join(
          Platform.environment['HOME'] ?? '',
          '.local',
          'share',
          'onyxcore',
          'yt-dlp-venv',
          'bin',
          'yt-dlp',
        );
        if (File(ytDlpPath).existsSync()) {
          platform.setProperty('script-opts', 'ytdl_hook-ytdl_path=$ytDlpPath');
        }

        // Setup cache directory
        try {
          final tempDir = await getTemporaryDirectory();
          final cacheDir = Directory(p.join(tempDir.path, 'onyx_stream_cache'));
          if (!cacheDir.existsSync()) {
            cacheDir.createSync(recursive: true);
          }
          platform.setProperty('cache-dir', cacheDir.path);
          platform.setProperty('cache-on-disk', 'yes');
        } catch (e) {
          debugPrint('Failed to set up stream cache directory: $e');
        }

        // Network Streaming Buffer Configuration
        platform.setProperty(
          'demuxer-readahead-secs',
          '120',
        ); // 2 minutes read-ahead
        platform.setProperty(
          'demuxer-max-bytes',
          '524288000',
        ); // 500 MB forward buffer
        platform.setProperty(
          'demuxer-max-back-bytes',
          '134217728',
        ); // 128 MB backward
        platform.setProperty('buffer-size', '134217728'); // 128 MB internal
        platform.setProperty('cache', 'yes');
        platform.setProperty('cache-secs', '120');
        platform.setProperty('cache-pause', 'yes'); // Pause to build cache
        platform.setProperty(
          'cache-pause-wait',
          '2',
        ); // Wait for 2 secs buffer before unpausing
      } else {
        // Local File Sliding Window Buffer Configuration
        // 400MiB forward + 200MiB backward for zero-latency arrow-key seeks
        platform.setProperty('demuxer-readahead-secs', '60');
        platform.setProperty(
          'demuxer-max-bytes',
          '419430400',
        ); // 400 MiB forward
        platform.setProperty(
          'demuxer-max-back-bytes',
          '209715200',
        ); // 200 MiB backward
        platform.setProperty('buffer-size', '134217728'); // 128MB internal
        platform.setProperty('cache', 'yes');
        platform.setProperty('cache-secs', '60');
        platform.setProperty('cache-pause', 'no');
      }

      platform.setProperty('hr-seek', 'yes'); // Exact seeking
      platform.setProperty('hr-seek-framedrop', 'yes');
      platform.setProperty('vd-lavc-fast', 'yes');

      // FIX: Prevent mp_image_crop assertion crash on systems where EGL is
      // invalid and media_kit falls back to S/W rendering. In that code path,
      // mpv's direct-rendering mode tries to crop a decoded frame onto a
      // not-yet-resized texture surface (1×1 or small default), causing:
      //   Assertion `x1 <= img->w && y1 <= img->h' failed.
      // Disabling direct rendering (`vd-lavc-dr=no`) forces mpv to copy
      // decoded frames into a properly sized buffer instead of rendering
      // directly onto the texture. Also disable early GL flushes to avoid
      // premature buffer commits during resize transitions.
      platform.setProperty('vd-lavc-dr', 'no');
      platform.setProperty('opengl-early-flush', 'no');

      // EPX-008: Hardware Decoder Auto-Cache Logic
      final settings = ref.read(settingsProvider).value;
      if (settings != null) {
        if (settings.selectedHwDec == 'auto') {
          if (settings.cachedResolvedHwDec != null) {
            debugPrint(
              '[VideoPlayer] Using cached hardware decoder: ${settings.cachedResolvedHwDec}',
            );
            platform.setProperty('hwdec', settings.cachedResolvedHwDec!);
          } else {
            debugPrint('[VideoPlayer] No cached decoder, using fallback chain');
            platform.setProperty('hwdec', 'vaapi,nvdec,vdpau,auto-safe');
          }
        } else {
          debugPrint(
            '[VideoPlayer] Using manually selected hardware decoder: ${settings.selectedHwDec}',
          );
          platform.setProperty('hwdec', settings.selectedHwDec);
        }
      } else {
        platform.setProperty('hwdec', 'auto-safe');
      }

      // Volume persistence
      if (settings != null) {
        player.setVolume(settings.videoPlayerVolume);
      }
    }

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
    final int safeWidth = (display?.size.width ?? 1920.0).round().clamp(
      1,
      3840,
    );
    final int safeHeight = (display?.size.height ?? 1080.0).round().clamp(
      1,
      2160,
    );
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
            final String? currentHwDec =
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

    _isOpening = true;

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
      setState(() => _isSeekingToInitial = true);

      // Wait for player to be truly ready for seeking.
      // catchError handles "Bad state: No element" which occurs when the media
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
                _isSeekingToInitial = false;
                // Initially hide controls for a clean startup
                _isControlsVisible = false;
              });
            }
          })
          .catchError((Object e) {
            // Media failed to load — stream closed without a valid duration.
            // Reset seek state so the loader is dismissed; the error stream
            // listener will have already set _hasError = true.
            debugPrint('[VideoPlayer] Seek setup failed (media load error): $e');
            if (mounted) {
              setState(() {
                _isSeekingToInitial = false;
              });
            }
          });
    }

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
      if (_isClosing || !mounted) return;

      if (buffering) {
        // Smart Delay: only show loader if buffering persists > 150ms
        // This applies universally to scrubbing, fast seeking, and normal playback
        _smartDelayTimer?.cancel();
        _smartDelayTimer = Timer(const Duration(milliseconds: 150), () {
          if (mounted && !_isClosing) {
            setState(() => _isSmartBuffering = true);
          }
        });
      } else {
        _smartDelayTimer?.cancel();
        if (mounted) setState(() => _isSmartBuffering = false);
      }

      if (mounted && _isBuffering != buffering) {
        setState(() => _isBuffering = buffering);
      }
    });

    _positionSubscription = player.stream.position.listen((pos) {
      if (_isClosing || !mounted) return;
      if (_preSeekPosition != null) {
        final timeSinceSeek = DateTime.now().difference(_lastSeekTime).inMilliseconds;
        final posDiff = (pos.inMilliseconds - _preSeekPosition!.inMilliseconds).abs();
        
        // If the position has changed significantly or if it has been longer than 500ms
        // (meaning the player likely resumed natively), consider the seek finished.
        if (posDiff > 100 || timeSinceSeek > 500) {
          _preSeekPosition = null;
          _seekLoaderTimer?.cancel();
          if (_isSeekLoading) {
            setState(() => _isSeekLoading = false);
          }
        }
      }
    });

    _errorSubscription = player.stream.error.listen((error) {
      debugPrint('[VideoPlayer] Engine Error: $error');
      if (mounted) {
        setState(() {
          _isOpening = false;
          _isBuffering = false;
          _isSeekingToInitial = false;
          _hasError = true;
          _errorMessage = error.toString();
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
      bool shouldPlay = true;
      if (ref.read(videoForcePauseNextProvider)) {
        shouldPlay = false;
        ref.read(videoForcePauseNextProvider.notifier).state = false;
      }
      await player.open(
        Media(MediaUriHelper.getSafeMediaUri(_currentItem.path)),
        play: shouldPlay,
      );
      debugPrint('[VideoPlayer] player.open() completed successfully');
      if (mounted) setState(() => _isOpening = false);
    } catch (e) {
      debugPrint('[VideoPlayer] player.open() FAILED: $e');
      if (mounted) {
        setState(() {
          _isOpening = false;
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
      _currentItem = item;
      _fps = null;
      _isEmpty = false;
    });
    ref.read(previewFileProvider.notifier).state = item;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(videoIsEmptyProvider.notifier).state = false;
      }
    });

    // 3. Open new media
    setState(() => _isOpening = true);

    // Give the UI time to render the loader before engine init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 16), () async {
        if (mounted) {
          await MediaUriHelper.ensureLocalProxy();
          bool shouldPlay = true;
          if (ref.read(videoForcePauseNextProvider)) {
            shouldPlay = false;
            ref.read(videoForcePauseNextProvider.notifier).state = false;
          }
          await player.open(
            Media(MediaUriHelper.getSafeMediaUri(item.path)),
            play: shouldPlay,
          );
          if (mounted) setState(() => _isOpening = false);

          // 4. Initialize new media (subs, memory) after open completes
          _initMedia();
        }
      });
    });

    _onInteraction();
  }

  Future<void> _initMedia() async {
    final currentPath = _currentItem.path;

    // 1. External Subtitles
    _loadExternalSubtitles();

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
        platform.setProperty('ytdl-format', '${format.formatId}+bestaudio/best');
        await player.open(
          Media(MediaUriHelper.getSafeMediaUri(_currentItem.path)),
          play: true,
        );
      } else {
        final streamUrl = format.url ?? format.formatString;
        if (streamUrl.isEmpty) {
          debugPrint('[VideoPlayer] Resolution switch aborted: no stream URL available');
          return;
        }
        await player.open(Media(streamUrl), play: true);
      }

      // Wait for player to be ready — use timeout to avoid hanging indefinitely
      // if the format can't be opened (e.g. "Failed to recognize file format")
      final duration = await player.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(const Duration(seconds: 10), onTimeout: () => Duration.zero);
      if (duration > Duration.zero && mounted && !_isClosing) {
        _performSeek(currentPosition);
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
          _isControlsVisible = false;
          _hideTimer?.cancel();
        });
      } else {
        setState(() {
          _isControlsVisible = true;
          _startHideTimer();
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
        _isControlsVisible = false;
        _hideTimer?.cancel();
      });
    } else {
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
      // Reveal controls when exiting fullscreen (returning to system UI)
      setState(() {
        _isControlsVisible = true;
        _startHideTimer();
      });
      _onInteraction();
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
  void onWindowClose() async {
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
        for (var file in contents) {
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
      _hideMenu();
    }
  }

  Future<void> _fetchFps() async {
    try {
      if (_isClosing || !mounted) return;
      // Small delay to allow mpv to parse container metadata
      await Future<void>.delayed(const Duration(milliseconds: 500));
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
    if (_isAnyMenuVisible || _isMarkerEditorActive || _isHoveringMarker) return;
    _hideTimer = Timer(const Duration(seconds: 2), () {
      if (mounted &&
          _isControlsVisible &&
          !_isScrubbing &&
          !_isMarkerEditorActive &&
          !_isHoveringMarker &&
          !_isAnyMenuVisible) {
        setState(() => _isControlsVisible = false);
      }
    });
  }

  void _showVolumeOverlay() {
    _volumeOverlayTimer?.cancel();
    if (mounted && !_isVolumeOverlayVisible) {
      setState(() => _isVolumeOverlayVisible = true);
    }
    _volumeOverlayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isVolumeOverlayVisible = false);
      }
    });
  }

  void _showSpeedOverlay() {
    _speedOverlayTimer?.cancel();
    if (mounted && !_showSpeedOverlayVisible) {
      setState(() => _showSpeedOverlayVisible = true);
    }
    _speedOverlayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showSpeedOverlayVisible = false);
      }
    });
  }

  void _showSeekIndicator() {
    _seekIndicatorTimer?.cancel();
    if (mounted && !_isSeekIndicatorVisible) {
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

    // If marker editor or any menu is active, we don't start the hide timer
    if (_isMarkerEditorActive || _isAnyMenuVisible || _isHoveringMarker) return;

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
              child: Material(color: Colors.transparent, child: child),
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


  void _openMarkerEditor({VideoMarker? marker}) {
    _hideTimer?.cancel();
    player.pause();

    final position = marker?.timestamp ?? player.state.position;
    final duration = player.state.duration;

    setState(() {
      _isMarkerEditorActive = true;
      _isControlsVisible = true; // Lock HUD
      _editingMarker = marker;

      // Calculate anchor position on timeline
      if (duration > Duration.zero) {
        final fraction = position.inMilliseconds / duration.inMilliseconds;
        // The slider starts at 32px padding.
        // We calculate the absolute screen X for the notch.
        final effectiveWidth = _sliderWidth > 0
            ? _sliderWidth
            : (MediaQuery.of(context).size.width - 64);
        _markerEditorAnchor = Offset(fraction * effectiveWidth, 0);
      } else {
        _markerEditorAnchor = Offset(
          (MediaQuery.of(context).size.width - 64) / 2,
          0,
        );
      }
    });
    ref.read(isMarkerEditorActiveProvider.notifier).state = true;
  }

  void _saveMarker(String content, String icon) async {
    if (_editingMarker != null) {
      await ref
          .read(markerActionsProvider)
          .updateMarker(
            _currentItem.path,
            _editingMarker!.copyWith(content: content, icon: icon),
          );
    } else {
      await ref
          .read(markerActionsProvider)
          .addMarker(
            _currentItem.path,
            player.state.position,
            content,
            icon: icon,
          );
    }

    _closeMarkerEditor(resume: true);
  }

  void _closeMarkerEditor({bool resume = false}) {
    if (resume) {
      player.play();
      _isPlayingNotifier.value = true;
    }

    setState(() {
      _isMarkerEditorActive = false;
      _editingMarker = null;
      _markerEditorAnchor = null;
      // Force HUD to stay visible for 3 seconds after closing
      // to show updated progress/play state
      _onInteraction();
    });
    ref.read(isMarkerEditorActiveProvider.notifier).state = false;

    // EPX-009: Restore focus to the player to ensure shortcuts work immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
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
    _lastKeyEventTime = DateTime.now();

    // EPX-009: Handle Space and other keys during marker editor
    if (_isMarkerEditorActive) {
      // Allow standard OS shortcuts (Ctrl+C, Ctrl+V, Ctrl+A, etc.) to pass through
      final isControlPressed =
          HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      if (isControlPressed) return KeyEventResult.ignored;

      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          _closeMarkerEditor(resume: true);
          return KeyEventResult.handled;
        }

        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          final editor = _markerEditorKey.currentState;
          if (editor != null && editor.isTagFieldFocused) {
            editor.save();
            return KeyEventResult.handled;
          }
          return KeyEventResult
              .ignored; // Let the custom set editor handle its own Enter
        }

        // Block all shortcuts from triggering player actions while editor is open
        // This includes Space (play/pause), arrows, M, F, T, etc.
        // We let them through to the TextField by returning ignored ONLY for non-shortcut keys
        // or keys that the TextField needs (like Space, Backspace).

        // If it's a key that normally triggers a player action, we return handled to consume it
        // but we DON'T trigger the shake if it's a key the user might be typing (like a letter).
        // Actually, we should only shake for keys that are definitely NOT text input.

        // Arrows should be ignored here so the TextField can use them to move the caret.
        // We no longer shake the container for arrow keys when the editor is active.

        // Specifically block Space and Backspace from triggering player actions,
        // but return ignored so the TextField (child) can handle them for text entry.
        if (event.logicalKey == LogicalKeyboardKey.space ||
            event.logicalKey == LogicalKeyboardKey.backspace) {
          return KeyEventResult.ignored;
        }

        // For other potential shortcut keys (F, M, T, etc.), we also return ignored
        // to allow the TextField to process them as text input.
        // Bubbling to parent widgets (like PreviewContainer) is now handled
        // via focus checking in those widgets.
        return KeyEventResult.ignored;
      }
      return KeyEventResult.ignored;
    }

    // BUG-FIX: Block Backspace and Alt+Arrows navigation in preview mode
    final isAltPressed = HardwareKeyboard.instance.isAltPressed;
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.backspace ||
          (isAltPressed &&
              (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                  event.logicalKey == LogicalKeyboardKey.arrowRight))) {
        if (widget.windowId == null && !widget.isStandalone) {
          final isSidebarOpen = ref.read(videoPlaylistSidebarVisibleProvider);
          if (isSidebarOpen && isAltPressed) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              _navigatePlaylistHistoryBack(ref);
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              _navigatePlaylistHistoryForward(ref);
            }
          }
          return KeyEventResult.handled; // Consume to prevent navigation
        }
      }
    }

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
          // In all modes, 'F' should at least hide the HUD controls
          if (_isControlsVisible) {
            setState(() => _isControlsVisible = false);
            _hideMenu();
          } else {
            // Optional: Toggle it back on if it was already hidden?
            // User only asked to hide, but toggle is more standard.
            setState(() => _isControlsVisible = true);
          }

          if (widget.isStandalone) {
            _toggleFullscreen();
          } else {
            // In preview mode, ensure we keep focus after the HUD state change
            _focusNode.requestFocus();
          }
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyP &&
          HardwareKeyboard.instance.isControlPressed &&
          HardwareKeyboard.instance.isShiftPressed) {
        if (event is KeyDownEvent) {
          final isOpen = ref.read(videoPlaylistSidebarVisibleProvider);
          ref.read(videoPlaylistSidebarVisibleProvider.notifier).state =
              !isOpen;
        }
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyT) {
        if (event is KeyDownEvent) _openMarkerEditor();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.delete) {
        if (event is KeyDownEvent) {
          final shift = HardwareKeyboard.instance.isShiftPressed;
          _handleDelete(permanent: shift);
        }
        return KeyEventResult.handled;
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

  // ── Seek Engine Gateway (Throttle + Debounce) ─────────────────────

  void _requestEngineSeek(Duration targetPosition) {
    // Clear any lingering scrub state so displayPosition uses the seek target
    _isScrubbing = false;
    _virtualScrubPosition = null;
    _pendingScrubPosition = null;

    // 1. Instantly update the UI's source of truth
    setState(() {
      _virtualSeekPosition = targetPosition;
    });

    // 2. Prevent play/seek fighting during rapid inputs
    if (player.state.playing && !_isFastSeeking) {
      _wasPlayingBeforeScrub = true;
      player.pause();
    }

    final now = DateTime.now();
    final timeSinceLastSeek = now
        .difference(_lastEngineSeekTime)
        .inMilliseconds;

    // Cancel any pending debounced seek
    _engineSeekTimer?.cancel();

    if (timeSinceLastSeek > _throttleMs) {
      // THROTTLE: Give the user a visual frame update right now.
      _dispatchToEngine(targetPosition);
    } else {
      // DEBOUNCE: Protect the engine from starvation. Wait for clicks to settle.
      _engineSeekTimer = Timer(Duration(milliseconds: _debounceMs), () {
        if (_virtualSeekPosition != null && mounted) {
          _dispatchToEngine(_virtualSeekPosition!);
        }
      });
    }
  }

  void _performSeek(Duration target) {
    _preSeekPosition = player.state.position;
    _lastSeekTime = DateTime.now();
    _seekLoaderTimer?.cancel();
    _seekLoaderTimer = Timer(const Duration(milliseconds: 150), () {
      if (mounted && !_isClosing) {
        setState(() => _isSeekLoading = true);
      }
    });

    player.seek(target);
  }

  void _dispatchToEngine(Duration target) {
    _lastEngineSeekTime = DateTime.now();
    _performSeek(target);
    _scheduleVirtualStateCleanup();
  }

  void _scheduleVirtualStateCleanup() {
    // CRITICAL: Kill ghost timers to prevent snapbacks
    _virtualSeekCleanupTimer?.cancel();
    _cleanupRetryCount = 0; // Reset on fresh schedule

    // Wait 1200ms for mpv to lock onto the keyframe and update its stream
    _virtualSeekCleanupTimer = Timer(const Duration(milliseconds: 1200), () {
      if (_engineSeekTimer?.isActive ?? false) {
        // Safety net: Prevent infinite reschedule loop
        if (++_cleanupRetryCount < 5) {
          _scheduleVirtualStateCleanup();
          return;
        }
        // If we hit 5 retries, fall through and force cleanup anyway
      }

      if (!mounted) return;

      setState(() {
        _virtualSeekPosition = null;
        _isFastSeeking = false;
      });

      if (_wasPlayingBeforeScrub) {
        player.play();
        _wasPlayingBeforeScrub = false;
      }
    });
  }

  // ── Seek Triggers ────────────────────────────────────────────────

  void _startFastSeek({required bool isForward}) {
    setState(() {
      _isFastSeeking = true;
    });

    _performStepSeek(isForward: isForward);

    _fastSeekTimer?.cancel();
    _fastSeekTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      _performStepSeek(isForward: isForward);
    });
  }

  void _performStepSeek({required bool isForward}) {
    // STRICT HANDOFF GUARD: If we have a valid scrub position, it means we just
    // finished scrubbing. We MUST invalidate any dormant fast-seek state.
    if (_virtualScrubPosition != null) {
      _isFastSeeking = false;
      _virtualSeekPosition = null;
    }

    final currentBase =
        (_isFastSeeking ? _virtualSeekPosition : null) ??
        _virtualScrubPosition ??
        player.state.position;
    final seekSeconds =
        ref.read(settingsProvider).value?.doubleTapSeekSeconds ?? 10;
    final step = Duration(seconds: seekSeconds);

    Duration target = isForward ? currentBase + step : currentBase - step;

    // Clamp to valid range
    if (target < Duration.zero) target = Duration.zero;
    final dur = player.state.duration;
    if (dur > Duration.zero && target > dur) target = dur;

    setState(() {
      _isFastSeeking = true;
      // Clear scrub position now that we have safely used it as the base
      _virtualScrubPosition = null;
      _isScrubbing = false;
    });

    _showSeekIndicator();
    _onInteraction();
    _requestEngineSeek(target);
  }

  void _stopFastSeek() {
    _fastSeekTimer?.cancel();
    _fastSeekTimer = null;
    _activeSeekKey = null;

    // Force the debouncer to fire immediately on key release
    if (_engineSeekTimer?.isActive ?? false) {
      _engineSeekTimer?.cancel();
      if (_virtualSeekPosition != null) {
        _dispatchToEngine(_virtualSeekPosition!);
      }
    }
  }

  // ── Shared Utilities ─────────────────────────────────────────────

  void _cleanupVirtualSeeking() {
    if (!mounted) return;

    // If a trackpad gesture is still active (fingers on pad),
    // don't clear the virtual position yet.
    if (_scrollLockAxis != null) return;

    setState(() {
      _isFastSeeking = false;
      _virtualSeekPosition = null;
      _isScrubbing = false;
      _virtualScrubPosition = null;
      _pendingScrubPosition = null;
      _isSmartBuffering = false;
    });

    if (_wasPlayingBeforeScrub) {
      player.play();
      _wasPlayingBeforeScrub = false;
    }
  }

  void _handlePointerScroll(PointerSignalEvent signal) {
    if (signal is PointerScrollEvent) {
      _processTrackpadGesture(
        signal.scrollDelta.dx,
        signal.scrollDelta.dy,
        signal.localPosition,
        isDiscrete: true,
      );
    }
  }

  void _handlePointerPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    _processTrackpadGesture(
      event.panDelta.dx,
      event.panDelta.dy,
      event.localPosition,
      isDiscrete: false,
    );
  }

  void _handlePointerPanZoomEnd(PointerPanZoomEndEvent event) {
    _resetTrackpadGesture();
  }

  void _processTrackpadGesture(
    double dx,
    double dy,
    Offset localPosition, {
    required bool isDiscrete,
  }) {
    if (_scrollLockAxis == null) {
      final settings = ref.read(settingsProvider).value;
      final speedControlOption =
          settings?.trackpadSpeedControl ?? SpeedControlOption.off;
      final screenWidth =
          context.size?.width ?? MediaQuery.of(context).size.width;

      if (dx.abs() > dy.abs() && dx.abs() > 0.5) {
        // Explicitly kill all step-seek state before initializing scrub
        _virtualSeekPosition = null;
        _isFastSeeking = false;
        _engineSeekTimer?.cancel();
        _virtualSeekCleanupTimer?.cancel();
        _fastSeekTimer?.cancel();

        _scrollLockAxis = 'h';
        _isScrubbing = true;
        _virtualScrubPosition ??= player.state.position;
        _wasPlayingBeforeScrub = player.state.playing;
        player.pause();
      } else if (dy.abs() > dx.abs() && dy.abs() > 0.5) {
        if (speedControlOption != SpeedControlOption.off &&
            localPosition.dx < screenWidth / 2) {
          _scrollLockAxis = 'speed';
          _virtualSpeed = player.state.rate;
        } else {
          _scrollLockAxis = 'v';
          _virtualVolume = player.state.volume;
        }
      } else {
        return;
      }
    }

    _scrollResetTimer?.cancel();
    if (isDiscrete) {
      // For discrete scrolls (mouse wheel), we must use a timer because there's no "End" signal.
      _scrollResetTimer = Timer(const Duration(milliseconds: 1000), () {
        _resetTrackpadGesture();
      });
    }
    // For continuous pan-zoom (trackpad), we strictly wait for the "End" event from the OS.
    // This allows the user to hold their finger stationary without resetting.

    if (_scrollLockAxis == 'h') {
      _handleScrubScroll(dx);
    } else if (_scrollLockAxis == 'v') {
      _handleVolumeScroll(dy);
    } else if (_scrollLockAxis == 'speed') {
      _handleSpeedScroll(dy);
    }
  }

  void _resetTrackpadGesture() {
    if (!mounted) return;

    // EPX-006: Ultra-tight 50ms window for blip rejection.
    // If a reset is blocked by a recent keypress, we schedule a retry in 50ms
    // to ensure the speed eventually returns to 1.0x if this was a real release.
    if (_lastKeyEventTime != null &&
        DateTime.now().difference(_lastKeyEventTime!).inMilliseconds < 50) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) _resetTrackpadGesture();
      });
      return;
    }

    // Trigger the actual player speed change immediately BEFORE the setState
    // to minimize perceived latency from the Flutter build/re-layout cycle.
    if (_scrollLockAxis == 'speed') {
      final settings = ref.read(settingsProvider).value;
      final option = settings?.trackpadSpeedControl ?? SpeedControlOption.off;
      if (option == SpeedControlOption.releaseToNormal) {
        player.setRate(1.0);
      }
    }

    setState(() {
      if (_scrollLockAxis == 'speed') {
        final settings = ref.read(settingsProvider).value;
        final option = settings?.trackpadSpeedControl ?? SpeedControlOption.off;
        if (option == SpeedControlOption.releaseToNormal) {
          _virtualSpeed = 1.0;
          _showSpeedOverlay();
        }
      }

      _scrollLockAxis = null;
      _virtualVolume = null;
      _virtualSpeed = null;

      if (_wasPlayingBeforeScrub) {
        player.play();
        _wasPlayingBeforeScrub = false;
      }

      // Start the cleanup timer now that the physical gesture has ended.
      _virtualSeekCleanupTimer?.cancel();
      _virtualSeekCleanupTimer = Timer(const Duration(seconds: 1), () {
        _cleanupVirtualSeeking();
      });
    });
  }

  void _handleScrubScroll(double dx) {
    // Determine target based on virtual position rather than actual player position
    // which may lag behind rapid gesture updates.
    final duration = player.state.duration;
    if (duration > Duration.zero && _virtualScrubPosition != null) {
      // 200ms per unit of dx is the sensitivity
      int newMs = _virtualScrubPosition!.inMilliseconds + (dx * 200).toInt();
      newMs = newMs.clamp(0, duration.inMilliseconds);
      setState(() {
        _virtualScrubPosition = Duration(milliseconds: newMs);
        _pendingScrubPosition = _virtualScrubPosition;
      });

      _showSeekIndicator();
      _onInteraction();

      // Reset cleanup timer to keep virtual position alive during gesture
      _virtualSeekCleanupTimer?.cancel();
      _virtualSeekCleanupTimer = Timer(const Duration(seconds: 1), () {
        _cleanupVirtualSeeking();
      });

      if (_scrubThrottleTimer?.isActive != true) {
        player.seek(_pendingScrubPosition!);
        _scrubThrottleTimer = Timer(const Duration(milliseconds: 100), () {
          if (_pendingScrubPosition != null && mounted && _isScrubbing) {
            player.seek(_pendingScrubPosition!);
          }
        });
      }
    }
  }

  void _handleVolumeScroll(double dy) {
    // Invert the dy value so that "scrolling up" (negative dy) increases volume.
    final isIncrease = dy < 0;
    // Apply a direct sensitivity multiplier based on pixels moved
    final step = dy.abs() * 0.05;

    // Clamp resulting volume between 0.0 and 200.0.
    _virtualVolume ??= player.state.volume;
    _virtualVolume = (_virtualVolume! + (isIncrease ? step : -step)).clamp(
      0.0,
      200.0,
    );

    _showVolumeOverlay();
    _onInteraction();

    if (_scrollVolumeTimer?.isActive != true) {
      if (_virtualVolume != null) {
        player.setVolume(_virtualVolume!);
      }
      _scrollVolumeTimer = Timer(const Duration(milliseconds: 30), () {
        if (_isClosing || !mounted) return;
        if (_virtualVolume != null) {
          player.setVolume(_virtualVolume!);
        }
      });
    }
  }

  void _handleSpeedScroll(double dy) {
    // Invert the dy value so that "scrolling up" (negative dy) increases speed.
    final isIncrease = dy < 0;
    // Multiplier for speed: we want fine control. A full swipe should change speed by maybe 1.0x.
    // 0.005 means 200 pixels = 1.0x speed change.
    final step = dy.abs() * 0.005;

    // Clamp resulting speed between 0.25 and 4.0.
    _virtualSpeed ??= player.state.rate;
    _virtualSpeed = (_virtualSpeed! + (isIncrease ? step : -step)).clamp(
      0.25,
      4.0,
    );

    _showSpeedOverlay();
    _onInteraction();

    if (_scrollSpeedTimer?.isActive != true) {
      if (_virtualSpeed != null) {
        player.setRate(_virtualSpeed!);
      }
      _scrollSpeedTimer = Timer(const Duration(milliseconds: 30), () {
        if (_isClosing || !mounted) return;
        if (_virtualSpeed != null) {
          player.setRate(_virtualSpeed!);
        }
      });
    }
  }

  void _navigateMedia(bool forward) {
    if (widget.isStandalone) {
      // Handled natively via shared isolate state or just fallback to inline logic
    } else {
      // 2. Inline Mode: Local Riverpod state update
      List<FileItem> mediaItems = ref
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
        setState(() => _isEmpty = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(videoIsEmptyProvider.notifier).state = true;
        });
        return;
      }

      int nextIndex;
      if (forward) {
        if (currentIndex == mediaItems.length - 1) {
          player.pause();
          setState(() => _isEmpty = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(videoIsEmptyProvider.notifier).state = true;
          });
          return;
        }
        nextIndex = currentIndex + 1;
      } else {
        if (currentIndex == 0) {
          player.pause();
          setState(() => _isEmpty = true);
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

  void _handleItemsMoved(List<String> paths) async {
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
    bool shouldConfirm = permanent || (settings?.confirmDeleteVideo ?? true);

    if (_sessionSkipConfirm) {
      shouldConfirm = false;
    }

    if (shouldConfirm) {
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) {
          if (permanent) {
            int size = 0;
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
      if (_isEmpty) {
        setState(() => _isEmpty = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(videoIsEmptyProvider.notifier).state = false;
        });
        _loadMedia(_currentItem);
      }
    });

    ref.listen(previewHudVisibleProvider, (previous, next) {
      if (mounted) {
        setState(() => _isGlobalHudVisible = next);
      }
    });

    if (!_isPlayerInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(child: BubbleLoader(size: 40)),
      );
    }

    // In standalone mode, we ignore the global HUD visibility provider as the window
    // itself is the dedicated viewer. We only care about the internal control timer.
    // Hide the main HUD (timeline, play button, etc.) during active trackpad gestures
    // to provide a cleaner view while adjusting volume/speed/scrubbing.
    final isVisible =
        (_isControlsVisible || _isMarkerEditorActive || _isMarkerMenuVisible) &&
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
          final minWidth = 240.0;
          final maxWidth = screenWidth * 0.40;
          double? savedWidth = sidebarRef.watch(
            videoPlaylistSidebarWidthProvider,
          );
          double panelWidth = savedWidth ?? (screenWidth * 0.25);
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
                isSidebarOpen
                    ? MouseRegion(
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
                            double intendedWidth = _sidebarDragStartWidth + dx;
                            setState(() {
                              _isSidebarDragOutOfBounds =
                                  intendedWidth < minWidth ||
                                  intendedWidth > maxWidth;
                            });
                            double newWidth = intendedWidth.clamp(
                              minWidth,
                              maxWidth,
                            );
                            ref
                                    .read(
                                      videoPlaylistSidebarWidthProvider
                                          .notifier,
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
                                ? Colors.white.withOpacity(0.1)
                                : Colors.transparent,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                // ── Video Player ─────────────────────────────────────
                Expanded(
                  child: Focus(
                    focusNode: _focusNode,
                    autofocus: true,
                    onFocusChange: (hasFocus) {
                      if (!hasFocus) {
                        _stopFastSeek();
                        _stopVolumeAdjustment();
                      }
                    },
                    onKeyEvent: (node, event) => _handleKeyEvent(event),
                    child: Listener(
                      onPointerSignal: (event) {
                        if (_isMarkerEditorActive) {
                          final RenderBox? box =
                              _markerEditorKey.currentContext
                                      ?.findRenderObject()
                                  as RenderBox?;
                          if (box != null) {
                            final Offset local = box.globalToLocal(
                              event.position,
                            );
                            if (box.paintBounds.contains(local)) return;
                          }
                          _markerEditorKey.currentState?.shake();
                          return;
                        }
                        _handlePointerScroll(event);
                      },
                      onPointerPanZoomUpdate: (event) {
                        if (_isMarkerEditorActive) {
                          final RenderBox? box =
                              _markerEditorKey.currentContext
                                      ?.findRenderObject()
                                  as RenderBox?;
                          if (box != null) {
                            final Offset local = box.globalToLocal(
                              event.position,
                            );
                            if (box.paintBounds.contains(local)) return;
                          }
                          _markerEditorKey.currentState?.shake();
                          return;
                        }
                        _handlePointerPanZoomUpdate(event);
                      },
                      onPointerPanZoomEnd: (event) {
                        if (_isMarkerEditorActive) return;
                        _handlePointerPanZoomEnd(event);
                      },
                      behavior: HitTestBehavior.translucent,
                      child: GestureDetector(
                        onTap: () {
                          _focusNode.requestFocus();
                          _onInteraction();
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

                          _performStepSeek(isForward: isForward);
                        },
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            _playerWidth = constraints.maxWidth;
                            _playerHeight = constraints.maxHeight;

                            return Container(
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
                                      onEnter: (_) => _onInteraction(),
                                      onHover: (_) => _onInteraction(),
                                      child: Stack(
                                        children: [
                                          // Video Player (isolated render pipeline)
                                          if (_isEmpty)
                                            Positioned.fill(
                                              child: _buildEmptyState(),
                                            )
                                          else if (_hasError)
                                            Positioned.fill(
                                              child: _buildErrorState(),
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
                                          // Shown instantly on open/initial seek, and universally after 150ms delay
                                          IgnorePointer(
                                            child: Center(
                                              child: AnimatedOpacity(
                                                duration: const Duration(
                                                  milliseconds: 300,
                                                ),
                                                opacity: (_isOpening ||
                                                        _isSeekingToInitial ||
                                                        _isSmartBuffering ||
                                                        _isSeekLoading)
                                                    ? 1.0
                                                    : 0.0,
                                                child: const RepaintBoundary(
                                                  child: BubbleLoader(
                                                    size: 100,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),

                                          // Snapshot Flash Effect (Subtle Fade)
                                          Positioned.fill(
                                            child: IgnorePointer(
                                              child: AnimatedOpacity(
                                                duration: const Duration(
                                                  milliseconds: 500,
                                                ),
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
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        opacity: _isVolumeOverlayVisible
                                            ? 1.0
                                            : 0.0,
                                        child: StreamBuilder<double>(
                                          stream: player.stream.volume,
                                          builder: (context, snapshot) {
                                            final vol =
                                                snapshot.data ??
                                                player.state.volume;
                                            return VideoVolumeOverlay(
                                              volume: vol,
                                              onVolumeChanged: (v) =>
                                                  player.setVolume(v),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Speed Overlay (Left side)
                                  Positioned(
                                    left: 32,
                                    top: 0,
                                    bottom: 0,
                                    child: Center(
                                      child: AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        opacity: _showSpeedOverlayVisible
                                            ? 1.0
                                            : 0.0,
                                        child: StreamBuilder<double>(
                                          stream: player.stream.rate,
                                          builder: (context, snapshot) {
                                            final rate =
                                                snapshot.data ??
                                                player.state.rate;
                                            return VideoSpeedOverlay(
                                              speed: rate,
                                              onSpeedChanged: (r) =>
                                                  player.setRate(r),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Persistent Speed Indicator Text (Bottom Left)
                                  Positioned(
                                    bottom: 24,
                                    left: 24,
                                    child: StreamBuilder<double>(
                                      stream: player.stream.rate,
                                      builder: (context, snapshot) {
                                        final rate =
                                            snapshot.data ?? player.state.rate;
                                        if ((rate - 1.0).abs() < 0.01)
                                          return const SizedBox.shrink();
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(
                                              0.6,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Colors.white.withOpacity(
                                                0.1,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.speed,
                                                color: AppColors.violet,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '${rate.toStringAsFixed(2)}x',
                                                style: GoogleFonts.manrope(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),

                                  // Seek Indicator Overlay (Top Right)
                                  Positioned(
                                    top: 100,
                                    right: 64,
                                    child: AnimatedOpacity(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      opacity: _isSeekIndicatorVisible
                                          ? 1.0
                                          : 0.0,
                                      child: StreamBuilder<Duration>(
                                        stream: player.stream.position,
                                        builder: (context, snapshot) {
                                          final position = displayPosition;
                                          final duration =
                                              player.state.duration;
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
                                                  color: Colors.black
                                                      .withOpacity(0.8),
                                                ),
                                                Shadow(
                                                  offset: const Offset(-1, -1),
                                                  blurRadius: 2.0,
                                                  color: Colors.black
                                                      .withOpacity(0.5),
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
                                            title: _currentItem.name,
                                            metadata:
                                                '$res$fpsString$indexString',
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
                                              if (!_isEmpty) ...[
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
                                  if (!_isEmpty)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      child: AnimatedOpacity(
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
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
                                                  stream:
                                                      player.stream.position,
                                                  builder: (context, snapshot) {
                                                    final position =
                                                        displayPosition;
                                                    final duration =
                                                        player.state.duration;
                                                    final remaining =
                                                        duration - position;
                                                    final progress =
                                                        duration.inMilliseconds >
                                                            0
                                                        ? position.inMilliseconds /
                                                              duration
                                                                  .inMilliseconds
                                                        : 0.0;

                                                    return Row(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .end,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                bottom: 17,
                                                              ),
                                                          child: Text(
                                                            _formatDuration(
                                                              position,
                                                            ),
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .white,
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 16,
                                                        ),
                                                        Expanded(
                                                          child: LayoutBuilder(
                                                            builder:
                                                                (
                                                                  context,
                                                                  constraints,
                                                                ) {
                                                                  _sliderWidth =
                                                                      constraints
                                                                          .maxWidth;
                                                                  return MouseRegion(
                                                                    onEnter: (_) {
                                                                      _hoverExitTimer
                                                                          ?.cancel();
                                                                      if (mounted &&
                                                                          !_isSliderHovered) {
                                                                        setState(
                                                                          () => _isSliderHovered =
                                                                              true,
                                                                        );
                                                                      }
                                                                    },
                                                                    onExit: (_) {
                                                                      _hoverExitTimer
                                                                          ?.cancel();
                                                                      _hoverExitTimer = Timer(
                                                                        const Duration(
                                                                          milliseconds:
                                                                              300,
                                                                        ),
                                                                        () {
                                                                          if (mounted) {
                                                                            setState(
                                                                              () => _isSliderHovered = false,
                                                                            );
                                                                            _hoverXNotifier.value =
                                                                                null;
                                                                          }
                                                                        },
                                                                      );
                                                                    },
                                                                    onHover: (event) {
                                                                      // Strictly show preview only when hovering over the progress bar (bottom area)
                                                                      // The track is at bottom: 20-30 of the 100px container (dy: 70-80)
                                                                      final dy = event
                                                                          .localPosition
                                                                          .dy;
                                                                      if (dy >=
                                                                              65 &&
                                                                          dy <=
                                                                              95 &&
                                                                          !_isHoveringMarker) {
                                                                        _hoverXNotifier
                                                                            .value = event
                                                                            .localPosition
                                                                            .dx;
                                                                      } else {
                                                                        _hoverXNotifier.value =
                                                                            null;
                                                                      }
                                                                    },
                                                                    child: CompositedTransformTarget(
                                                                      link:
                                                                          _sliderLink,
                                                                      key:
                                                                          _sliderKey,
                                                                      child: SizedBox(
                                                                        height:
                                                                            100, // Increased height for radial marker menu
                                                                        child: Stack(
                                                                          clipBehavior:
                                                                              Clip.none,
                                                                          alignment:
                                                                              Alignment.bottomCenter,
                                                                          children: [
                                                                            Positioned(
                                                                              left: 0,
                                                                              right: 0,
                                                                              bottom: 20, // Move slider up slightly
                                                                              child:
                                                                                  StreamBuilder<
                                                                                    Duration
                                                                                  >(
                                                                                    stream: player.stream.buffer,
                                                                                    builder:
                                                                                        (
                                                                                          context,
                                                                                          bufferSnapshot,
                                                                                        ) {
                                                                                          final bufferDuration =
                                                                                              bufferSnapshot.data ??
                                                                                              player.state.buffer;
                                                                                          final bufferProgress =
                                                                                              duration.inMilliseconds >
                                                                                                  0
                                                                                              ? bufferDuration.inMilliseconds /
                                                                                                    duration.inMilliseconds
                                                                                              : 0.0;
                                                                                          return SliderTheme(
                                                                                            data:
                                                                                                SliderTheme.of(
                                                                                                  context,
                                                                                                ).copyWith(
                                                                                                  trackShape: GradientRectSliderTrackShape(
                                                                                                    gradient: AppTheme.primaryGradient,
                                                                                                    bufferProgress: bufferProgress.clamp(
                                                                                                      0.0,
                                                                                                      1.0,
                                                                                                    ),
                                                                                                  ),
                                                                                                  activeTrackColor: Colors.white,
                                                                                                  inactiveTrackColor: Colors.white.withOpacity(
                                                                                                    0.1,
                                                                                                  ),
                                                                                                  thumbShape: SliderComponentShape.noThumb,
                                                                                                  overlayShape: SliderComponentShape.noOverlay,
                                                                                                  trackHeight: 10.0,
                                                                                                ),
                                                                                            child: Slider(
                                                                                              value: progress.clamp(
                                                                                                0.0,
                                                                                                1.0,
                                                                                              ),
                                                                                              onChangeStart:
                                                                                                  (
                                                                                                    _,
                                                                                                  ) {
                                                                                                    setState(
                                                                                                      () {
                                                                                                        // 1. Explicitly kill all step-seek state
                                                                                                        _virtualSeekPosition = null;
                                                                                                        _isFastSeeking = false;

                                                                                                        // 2. Kill all pending timers
                                                                                                        _engineSeekTimer?.cancel();
                                                                                                        _virtualSeekCleanupTimer?.cancel();
                                                                                                        _fastSeekTimer?.cancel();

                                                                                                        // 3. Initialize scrub state
                                                                                                        _isScrubbing = true;
                                                                                                        _wasPlayingBeforeScrub = player.state.playing;
                                                                                                      },
                                                                                                    );
                                                                                                    player.pause();
                                                                                                  },
                                                                                              onChanged:
                                                                                                  (
                                                                                                    v,
                                                                                                  ) {
                                                                                                    _onInteraction();
                                                                                                    _showSeekIndicator();
                                                                                                    final targetMs =
                                                                                                        (v *
                                                                                                                duration.inMilliseconds)
                                                                                                            .toInt();
                                                                                                    setState(
                                                                                                      () {
                                                                                                        _virtualScrubPosition = Duration(
                                                                                                          milliseconds: targetMs,
                                                                                                        );
                                                                                                        _pendingScrubPosition = _virtualScrubPosition;
                                                                                                      },
                                                                                                    );
                                                                                                    if (_scrubThrottleTimer?.isActive !=
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
                                                                                              onChangeEnd:
                                                                                                  (
                                                                                                    v,
                                                                                                  ) {
                                                                                                    _scrubThrottleTimer?.cancel();
                                                                                                    _smartDelayTimer?.cancel();

                                                                                                    // Final seek
                                                                                                    _performSeek(
                                                                                                      Duration(
                                                                                                        milliseconds:
                                                                                                            (v *
                                                                                                                    duration.inMilliseconds)
                                                                                                                .toInt(),
                                                                                                      ),
                                                                                                    );

                                                                                                    if (_wasPlayingBeforeScrub) {
                                                                                                      player.play();
                                                                                                      _wasPlayingBeforeScrub = false;
                                                                                                    }

                                                                                                    // Reset cleanup timer
                                                                                                    _virtualSeekCleanupTimer?.cancel();
                                                                                                    _virtualSeekCleanupTimer = Timer(
                                                                                                      const Duration(
                                                                                                        seconds: 1,
                                                                                                      ),
                                                                                                      () {
                                                                                                        _cleanupVirtualSeeking();
                                                                                                      },
                                                                                                    );
                                                                                                  },
                                                                                            ),
                                                                                          );
                                                                                        },
                                                                                  ),
                                                                            ),

                                                                            // EPX-009: Timeline Markers
                                                                            if (ref
                                                                                    .watch(
                                                                                      settingsProvider,
                                                                                    )
                                                                                    .value
                                                                                    ?.showMarkersOnTimeline ??
                                                                                true)
                                                                              ...ref
                                                                                  .watch(
                                                                                    videoMarkersProvider(
                                                                                      _currentItem.path,
                                                                                    ),
                                                                                  )
                                                                                  .maybeWhen(
                                                                                    data:
                                                                                        (
                                                                                          markers,
                                                                                        ) => markers.map(
                                                                                          (
                                                                                            m,
                                                                                          ) => TimelineMarker(
                                                                                            marker: m,
                                                                                            totalDuration: duration,
                                                                                            sliderWidth: _sliderWidth,
                                                                                            videoPath: _currentItem.path,
                                                                                            hoverXNotifier: _hoverXNotifier,
                                                                                            isMarkerEditorActive: _isMarkerEditorActive,
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
                                                                                              player.seek(
                                                                                                m.timestamp,
                                                                                              );
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
                                                                                            onEdit: () => _openMarkerEditor(
                                                                                              marker: m,
                                                                                            ),
                                                                                            onHoverChanged:
                                                                                                (
                                                                                                  hovering,
                                                                                                ) {
                                                                                                  if (mounted) {
                                                                                                    setState(
                                                                                                      () => _isHoveringMarker = hovering,
                                                                                                    );
                                                                                                    if (hovering) {
                                                                                                      _hideTimer?.cancel();
                                                                                                    } else {
                                                                                                      _onInteraction();
                                                                                                    }
                                                                                                  }
                                                                                                },
                                                                                            onMenuVisibilityChanged:
                                                                                                (
                                                                                                  visible,
                                                                                                ) {
                                                                                                  if (mounted) {
                                                                                                    setState(
                                                                                                      () => _isMarkerMenuVisible = visible,
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
                                                                                    mediaPath: _currentItem.path,
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
                                                        const SizedBox(
                                                          width: 16,
                                                        ),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                                bottom: 17,
                                                              ),
                                                          child: GestureDetector(
                                                            onTap: () {
                                                              setState(() {
                                                                _showRemainingTime = !_showRemainingTime;
                                                              });
                                                              final currentSettings = ref.read(settingsProvider).value;
                                                              if (currentSettings != null) {
                                                                ref.read(settingsProvider.notifier).saveSettings(
                                                                  currentSettings.copyWith(videoShowRemainingTime: _showRemainingTime),
                                                                );
                                                              }
                                                            },
                                                            child: Text(
                                                              _showRemainingTime
                                                                  ? '-${_formatDuration(remaining)}'
                                                                  : _formatDuration(
                                                                      duration,
                                                                    ),
                                                              style: const TextStyle(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
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
                                                    // Left: Playlist & Subtitles
                                                    Consumer(
                                                      builder: (context, sidebarRef, _) {
                                                        final isOpen =
                                                            sidebarRef.watch(
                                                              videoPlaylistSidebarVisibleProvider,
                                                            );
                                                        return IconButton(
                                                          icon: const Icon(
                                                            Icons.playlist_play,
                                                            size: 24,
                                                          ),
                                                          color:
                                                              _isNetworkStream
                                                              ? Colors.white30
                                                              : (isOpen
                                                                    ? AppColors
                                                                          .magenta
                                                                    : Colors
                                                                          .white),
                                                          onPressed:
                                                              _isNetworkStream
                                                              ? null
                                                              : () {
                                                                  sidebarRef
                                                                          .read(
                                                                            videoPlaylistSidebarVisibleProvider.notifier,
                                                                          )
                                                                          .state =
                                                                      !isOpen;
                                                                },
                                                          tooltip: 'Playlist',
                                                        );
                                                      },
                                                    ),
                                                    const SizedBox(width: 4),
                                                    if (!_isNetworkStream)
                                                      Consumer(
                                                        builder: (context, ref, _) {
                                                          final isFavorite = ref
                                                              .watch(
                                                                videoFavoritesProvider,
                                                              )
                                                              .contains(
                                                                _currentItem
                                                                    .path,
                                                              );
                                                          return IconButton(
                                                            icon: Icon(
                                                              isFavorite
                                                                  ? Icons
                                                                        .favorite_rounded
                                                                  : Icons
                                                                        .favorite_border_rounded,
                                                              size: 22,
                                                            ),
                                                            color: isFavorite
                                                                ? AppColors
                                                                      .magenta
                                                                : Colors
                                                                      .white70,
                                                            onPressed: () {
                                                              ref
                                                                  .read(
                                                                    videoFavoritesProvider
                                                                        .notifier,
                                                                  )
                                                                  .toggleFavorite(
                                                                    _currentItem
                                                                        .path,
                                                                  );
                                                            },
                                                            tooltip: isFavorite
                                                                ? 'Remove from Favorites'
                                                                : 'Add to Favorites',
                                                          );
                                                        },
                                                      ),
                                                    if (!_isNetworkStream)
                                                      const SizedBox(width: 4),
                                                    if (!_isNetworkStream)
                                                      Consumer(
                                                        builder: (context, ref, _) {
                                                          final isAutoPlay = ref
                                                              .watch(
                                                                videoAutoPlaySessionProvider,
                                                              );
                                                          return IconButton(
                                                            icon: Icon(
                                                              isAutoPlay
                                                                  ? Icons
                                                                        .autorenew_rounded
                                                                  : Icons
                                                                        .sync_disabled_rounded,
                                                              size: 22,
                                                            ),
                                                            color: isAutoPlay
                                                                ? AppColors
                                                                      .magenta
                                                                : Colors
                                                                      .white70,
                                                            onPressed: () {
                                                              ref
                                                                      .read(
                                                                        videoAutoPlaySessionProvider
                                                                            .notifier,
                                                                      )
                                                                      .state =
                                                                  !isAutoPlay;
                                                            },
                                                            tooltip: isAutoPlay
                                                                ? 'Autoplay Next: ON'
                                                                : 'Autoplay Next: OFF',
                                                          );
                                                        },
                                                      ),
                                                    if (!_isNetworkStream)
                                                      const SizedBox(width: 4),
                                                    IconButton(
                                                      key: _subtitleKey,
                                                      onPressed: () {
                                                        _onInteraction();
                                                        _showMenu(
                                                          key: _subtitleKey,
                                                          type: 'subtitle',
                                                          child: StreamBuilder<dynamic>(
                                                            stream: player
                                                                .stream
                                                                .track,
                                                            builder: (context, snapshot) {
                                                              final state =
                                                                  snapshot
                                                                      .data ??
                                                                  player
                                                                      .state
                                                                      .track;
                                                              return TrackSelectorMenu(
                                                                title:
                                                                    'Subtitles',
                                                                subtitleTracks:
                                                                    player
                                                                        .state
                                                                        .tracks
                                                                        .subtitle,
                                                                selectedTrack:
                                                                    state
                                                                        .subtitle,
                                                                onTrackSelected: (t) {
                                                                  player.setSubtitleTrack(
                                                                    t
                                                                        as SubtitleTrack,
                                                                  );
                                                                },
                                                                onLoadExternal: () async {
                                                                  final result =
                                                                      await CustomFilePickerDialog.show(
                                                                        context,
                                                                        title:
                                                                            'SELECT SUBTITLE',
                                                                        allowedExtensions: [
                                                                          'srt',
                                                                          'vtt',
                                                                          'ass',
                                                                        ],
                                                                      );
                                                                  if (result !=
                                                                          null &&
                                                                      result
                                                                          .isNotEmpty) {
                                                                    player.setSubtitleTrack(
                                                                      SubtitleTrack.uri(
                                                                        result
                                                                            .first,
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
                                                        Icons
                                                            .subtitles_outlined,
                                                        color:
                                                            _isSubtitleMenuVisible
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
                                                            stream: player
                                                                .stream
                                                                .track,
                                                            builder: (context, snapshot) {
                                                              final state =
                                                                  snapshot
                                                                      .data ??
                                                                  player
                                                                      .state
                                                                      .track;
                                                              return TrackSelectorMenu(
                                                                title:
                                                                    'Audio Tracks',
                                                                audioTracks:
                                                                    player
                                                                        .state
                                                                        .tracks
                                                                        .audio,
                                                                selectedTrack:
                                                                    state.audio,
                                                                onTrackSelected: (t) {
                                                                  player.setAudioTrack(
                                                                    t
                                                                        as AudioTrack,
                                                                  );
                                                                },
                                                              );
                                                            },
                                                          ),
                                                        );
                                                      },
                                                      icon: Icon(
                                                        Icons
                                                            .audiotrack_rounded,
                                                        color:
                                                            _isAudioMenuVisible
                                                            ? AppColors.violet
                                                            : Colors.white70,
                                                        size: 20,
                                                      ),
                                                      tooltip: 'Audio Tracks',
                                                    ),

                                                    const Spacer(),

                                                    // Center cluster
                                                    IconButton(
                                                      onPressed: () =>
                                                          _navigateMedia(false),
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
                                                      onPressed: () =>
                                                          _performStepSeek(
                                                            isForward: false,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    ValueListenableBuilder<
                                                      bool
                                                    >(
                                                      valueListenable:
                                                          _isPlayingNotifier,
                                                      builder: (context, playing, _) {
                                                        return GestureDetector(
                                                          onTap: () {
                                                            _onInteraction();
                                                            player
                                                                .playOrPause();
                                                          },
                                                          child: Container(
                                                            width: 48,
                                                            height: 48,
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  Colors.white,
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              boxShadow: [
                                                                BoxShadow(
                                                                  color: Colors
                                                                      .white
                                                                      .withOpacity(
                                                                        0.2,
                                                                      ),
                                                                  blurRadius:
                                                                      12,
                                                                  spreadRadius:
                                                                      2,
                                                                ),
                                                              ],
                                                            ),
                                                            child: Icon(
                                                              playing
                                                                  ? Icons.pause
                                                                  : Icons
                                                                        .play_arrow,
                                                              color:
                                                                  Colors.black,
                                                              size: 28,
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                    const SizedBox(width: 16),
                                                    _buildSeekButton(
                                                      isForward: true,
                                                      onPressed: () =>
                                                          _performStepSeek(
                                                            isForward: true,
                                                          ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    IconButton(
                                                      onPressed: () =>
                                                          _navigateMedia(true),
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
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        if (_isNetworkStream &&
                                                            _availableFormats
                                                                .isNotEmpty) ...[
                                                          PopupMenuButton<
                                                            MediaFormat
                                                          >(
                                                            key: _resolutionKey,
                                                            initialValue: _availableFormats.firstWhere(
                                                              (f) =>
                                                                  f.formatId ==
                                                                  _selectedFormatId,
                                                              orElse: () =>
                                                                  _availableFormats
                                                                      .first,
                                                            ),
                                                            onSelected:
                                                                _onResolutionChanged,
                                                            tooltip:
                                                                'Video Resolution',
                                                            color: const Color(
                                                              0xFF2A2A35,
                                                            ),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    12,
                                                                  ),
                                                              side: BorderSide(
                                                                color: Colors
                                                                    .white
                                                                    .withValues(
                                                                      alpha:
                                                                          0.1,
                                                                    ),
                                                              ),
                                                            ),
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  -10,
                                                                ),
                                                            itemBuilder: (context) {
                                                              return _availableFormats.map((
                                                                f,
                                                              ) {
                                                                final isSelected =
                                                                    f.formatId ==
                                                                    _selectedFormatId;
                                                                return PopupMenuItem<
                                                                  MediaFormat
                                                                >(
                                                                  value: f,
                                                                  height: 38,
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            12,
                                                                      ),
                                                                  child: Row(
                                                                    children: [
                                                                      Icon(
                                                                        isSelected
                                                                            ? Icons.check
                                                                            : Icons.circle,
                                                                        color:
                                                                            isSelected
                                                                            ? AppColors.violet
                                                                            : Colors.transparent,
                                                                        size:
                                                                            16,
                                                                      ),
                                                                      const SizedBox(
                                                                        width:
                                                                            8,
                                                                      ),
                                                                      Text(
                                                                        f.resolution,
                                                                        style: GoogleFonts.manrope(
                                                                          fontSize:
                                                                              13,
                                                                          fontWeight:
                                                                              isSelected
                                                                              ? FontWeight.bold
                                                                              : FontWeight.w500,
                                                                          color:
                                                                              isSelected
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
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              children: [
                                                                Text(
                                                                  _availableFormats
                                                                      .firstWhere(
                                                                        (f) =>
                                                                            f.formatId ==
                                                                            _selectedFormatId,
                                                                        orElse: () =>
                                                                            _availableFormats.first,
                                                                      )
                                                                      .resolution,
                                                                  style: GoogleFonts.manrope(
                                                                    color: Colors
                                                                        .white70,
                                                                    fontSize:
                                                                        12,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .bold,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 2,
                                                                ),
                                                                const Icon(
                                                                  Icons
                                                                      .arrow_drop_down,
                                                                  color: Colors
                                                                      .white70,
                                                                  size: 16,
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 16,
                                                          ),
                                                        ],
                                                        TextButton(
                                                          key: _speedKey,
                                                          onPressed: () {
                                                            _onInteraction();
                                                            _showMenu(
                                                              key: _speedKey,
                                                              type: 'speed',
                                                              child: PlaybackSpeedControl(
                                                                currentSpeed:
                                                                    _playbackSpeed,
                                                                onSpeedSelected: (speed) {
                                                                  setState(
                                                                    () => _playbackSpeed =
                                                                        speed,
                                                                  );
                                                                  player
                                                                      .setRate(
                                                                        speed,
                                                                      );
                                                                },
                                                              ),
                                                            );
                                                          },
                                                          child: Text(
                                                            '${_playbackSpeed.toString().replaceAll(RegExp(r'\.0$'), '')}x',
                                                            style: GoogleFonts.manrope(
                                                              color:
                                                                  _isSpeedMenuVisible
                                                                  ? AppColors
                                                                        .violet
                                                                  : Colors
                                                                        .white70,
                                                              fontSize: 12,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                        IconButton(
                                                          onPressed:
                                                              _toggleMute,
                                                          icon: Icon(
                                                            _isMuted
                                                                ? Icons
                                                                      .volume_off
                                                                : Icons
                                                                      .volume_up,
                                                            color:
                                                                Colors.white70,
                                                            size: 24,
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          width: 80,
                                                          child: StreamBuilder<double>(
                                                            stream: player
                                                                .stream
                                                                .volume,
                                                            builder: (context, snapshot) {
                                                              final volume =
                                                                  snapshot
                                                                      .data ??
                                                                  100.0;
                                                              return SliderTheme(
                                                                data: SliderTheme.of(context).copyWith(
                                                                  trackHeight:
                                                                      2,
                                                                  activeTrackColor:
                                                                      volume >
                                                                          100
                                                                      ? Colors
                                                                            .orange
                                                                      : Colors
                                                                            .white,
                                                                  inactiveTrackColor:
                                                                      Colors
                                                                          .white
                                                                          .withOpacity(
                                                                            0.2,
                                                                          ),
                                                                  thumbShape:
                                                                      const RoundSliderThumbShape(
                                                                        enabledThumbRadius:
                                                                            3,
                                                                      ),
                                                                  overlayShape:
                                                                      const RoundSliderOverlayShape(
                                                                        overlayRadius:
                                                                            6,
                                                                      ),
                                                                ),
                                                                child: Slider(
                                                                  value: volume
                                                                      .clamp(
                                                                        0.0,
                                                                        200.0,
                                                                      ),
                                                                  min: 0,
                                                                  max: 200,
                                                                  onChanged:
                                                                      (
                                                                        v,
                                                                      ) => player
                                                                          .setVolume(
                                                                            v,
                                                                          ),
                                                                ),
                                                              );
                                                            },
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        IconButton(
                                                          onPressed:
                                                              _toggleFullscreen,
                                                          icon: Icon(
                                                            Icons
                                                                .fullscreen_rounded,
                                                            color:
                                                                Colors.white70,
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

                                  // EPX-009: Marker Editor Overlay with full-screen click-outside dismissal
                                  if (_isMarkerEditorActive &&
                                      _markerEditorAnchor != null)
                                    Builder(
                                      builder: (context) {
                                        // We need to calculate the slider's position relative to the player's root stack
                                        final RenderBox? playerBox =
                                            _playerKey.currentContext
                                                    ?.findRenderObject()
                                                as RenderBox?;
                                        final RenderBox? sliderBox =
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
                                            onTap: () => _closeMarkerEditor(
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
                                                    onSave: _saveMarker,
                                                    onCancel: () =>
                                                        _closeMarkerEditor(
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
        ref.read(videoQueueProvider.notifier).state = _standalonePlaylist;
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
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: AppColors.violet,
                    size: 18,
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

  Widget _buildErrorState() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: const Color(0xFF121212),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 64,
                    color: Colors.red.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to play media',
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 32,
          left: 32,
          child: IconButton(
            onPressed: () {
              if (widget.isStandalone) {
                // If it's a standalone window, close the window.
                if (widget.windowId != null) {
                  PersistentViewerManager.closeWindow(
                    int.parse(widget.windowId!),
                  );
                }
              } else {
                // Return to home view
                ref.read(videoViewModeProvider.notifier).state =
                    VideoViewMode.home;
              }
            },
            icon: Icon(
              widget.isStandalone
                  ? Icons.close_rounded
                  : Icons.arrow_back_rounded,
              color: Colors.white,
              size: 24,
            ),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              hoverColor: Colors.white.withOpacity(0.2),
              padding: const EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: const Color(0xFF121212),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_off_rounded,
                    size: 64,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No video files to play next.',
                    style: GoogleFonts.manrope(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 32,
          left: 32,
          child: Consumer(
            builder: (context, sidebarRef, _) {
              final isSidebarOpen = sidebarRef.watch(
                videoPlaylistSidebarVisibleProvider,
              );
              return Container(
                decoration: BoxDecoration(
                  color: isSidebarOpen
                      ? AppColors.magenta.withValues(alpha: 0.8)
                      : Colors.black.withValues(alpha: 0.4),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: IconButton(
                  icon: Icon(
                    Icons.playlist_play_rounded,
                    color: isSidebarOpen
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.9),
                  ),
                  onPressed: () {
                    sidebarRef
                            .read(videoPlaylistSidebarVisibleProvider.notifier)
                            .state =
                        !isSidebarOpen;
                  },
                  tooltip: 'Toggle Playlist',
                ),
              );
            },
          ),
        ),
      ],
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

  void _openPlaylistFolder(WidgetRef ref, String path) async {
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
      debugPrint("Error opening folder: $e");
    }
  }
}
