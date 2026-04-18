import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui' show ImageFilter;
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../settings/data/repositories/settings_repository_impl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VideoPlayerPage extends StatefulWidget {
  final String videoPath;
  final DateTime? createdDate;

  const VideoPlayerPage({Key? key, required this.videoPath, this.createdDate}) : super(key: key);

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  late SettingsRepositoryImpl _settingsRepo;
  List<File> _playlist = [];
  int _currentIndex = 0;
  late String _currentVideoPath;
  DateTime? _currentCreatedDate;
  bool _showFlash = false;
  bool _anyDeleted = false;

  bool _isPlaying = false;
  bool _isMuted = false;
  bool _isFullView = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;

  String _resolutionLabel = '';
  int _fps = 30;

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;

  double _volume = 1.0;
  double _brightness = 0.5;
  double _playbackSpeed = 1.0;

  bool _showVolumeIndicator = false;
  bool _showBrightnessIndicator = false;
  bool _showSeekIndicator = false;
  bool _showSpeedIndicator = false;
  int _seekDirection = 0;
  Timer? _indicatorTimer;

  bool _isDraggingSeek = false;
  Duration _dragSeekPosition = Duration.zero;
  double _dragStartX = 0;
  Duration _dragStartPosition = Duration.zero;

  bool _isSliderDragging = false;
  bool _wasPlayingBeforeSliderDrag = false;
  bool _wasPlayingBeforeDrag = false;

  Timer? _seekThrottleTimer;
  Duration? _pendingSeekPosition;

  bool _isTwoFingerGesture = false;
  double _speedGestureAccumulator = 0.0;

  bool _isCapturingSnapshot = false;
  final List<int> _snapshotQueue = [];

  bool _isVerticalDragging = false;
  bool _verticalDragIsLeftSide = false;

  Offset? _gestureStartFocalPoint;
  bool _gestureDirectionDecided = false;
  bool _gestureIsHorizontal = false;

  bool _isEditMode = false;
  List<Duration> _flaggedTimestamps = [];
  final ScrollController _timestampScrollController = ScrollController();
  bool _isProcessing = false;
  String _processingStatus = "";
  String _processingType = "";
  double _verticalDragAccumulator = 0.0;

  @override
  void initState() {
    super.initState();
    _initSettings();
    _currentVideoPath = widget.videoPath;
    _currentCreatedDate = widget.createdDate;
    
    _buildPlaylist();
    _initVideo(_currentVideoPath, _currentCreatedDate);
    _startHideTimer();
  }

  Future<void> _initSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _settingsRepo = SettingsRepositoryImpl(prefs);
    await _settingsRepo.load();
  }

  void _buildPlaylist() {
    final File currentFile = File(_currentVideoPath);
    final Directory dir = currentFile.parent;
    if (dir.existsSync()) {
      final List<FileSystemEntity> files = dir.listSync()
        ..retainWhere((e) => e.path.toLowerCase().endsWith('.mp4') || e.path.toLowerCase().endsWith('.mkv'))
        ..sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      _playlist = files.map((f) => File(f.path)).toList();
      _currentIndex = _playlist.indexWhere((f) => f.path == _currentVideoPath);
      if (_currentIndex == -1) _currentIndex = 0;
    }
  }

  Future<void> _loadNewVideo(String path, DateTime? date) async {
    setState(() => _initialized = false);
    _controller.removeListener(_onVideoTick);
    await _controller.dispose();
    
    _currentVideoPath = path;
    _currentCreatedDate = date;
    _currentIndex = _playlist.indexWhere((f) => f.path == path);
    
    await _initVideo(path, date);
  }

  Future<void> _initVideo(String path, DateTime? date) async {
    _controller = VideoPlayerController.file(File(path));
    await _controller.initialize();
    _controller.setLooping(false);
    _controller.addListener(_onVideoTick);

    final size = _controller.value.size;
    final height = size.height.toInt();
    final width = size.width.toInt();
    if (width >= 3840 || height >= 2160) {
      _resolutionLabel = '4K';
    } else if (width >= 1920 || height >= 1080) {
      _resolutionLabel = '1080p';
    } else if (width >= 1280 || height >= 720) {
      _resolutionLabel = '720p';
    } else if (width >= 854 || height >= 480) {
      _resolutionLabel = '480p';
    } else {
      _resolutionLabel = 'SD';
    }

    // Try to get FPS via FFprobe for Linux
    try {
      final result = await Process.run('bash', [
        '-c',
        'ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of default=noprint_wrappers=1:nokey=1 "$path"'
      ]);

      if (result.exitCode == 0) {
        final frameRate = result.stdout.toString().trim();
        if (frameRate.isNotEmpty) {
          if (frameRate.contains('/')) {
            final parts = frameRate.split('/');
            _fps = (double.parse(parts[0]) / double.parse(parts[1])).round();
          } else {
            _fps = double.parse(frameRate).round();
          }
        }
      }
    } catch (_) {
      _fps = 30;
    }

    setState(() {
      _initialized = true;
      _totalDuration = _controller.value.duration;
    });

    _controller.play();
  }

  void _onVideoTick() {
    if (!mounted) return;
    if (_isDraggingSeek || _isSliderDragging) return;

    final value = _controller.value;
    final newPos = value.position;
    final newDur = value.duration;
    final newPlaying = value.isPlaying;
    
    if (newPlaying != _isPlaying ||
        (newPos.inSeconds != _currentPosition.inSeconds) ||
        newDur != _totalDuration) {
      setState(() {
        _currentPosition = newPos;
        _totalDuration = newDur;
        _isPlaying = newPlaying;
      });
    }

    if (newPos >= newDur && newDur.inMilliseconds > 0 && !_isPlaying) {
      if (_settingsRepo.pinnedFolders.isNotEmpty && _currentIndex < _playlist.length - 1) {
        // Check autoPlayNext via settings
      }
    }
  }

  void _startHideTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _onScreenTapUp(TapUpDetails details) {
    if (_isFullView) {
      setState(() {
        _isFullView = false;
        _showControls = true;
      });
      _startHideTimer();
      return;
    }
    
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _togglePlayPause() {
    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }
    _startHideTimer();
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      _controller.setVolume(_isMuted ? 0.0 : _volume);
    });
    _startHideTimer();
  }

  void _toggleFullView() {
    setState(() {
      _isFullView = !_isFullView;
      if (_isFullView) _showControls = false;
    });
  }

  void _throttledSeekTo(Duration position) {
    final clamped = Duration(
      milliseconds: position.inMilliseconds.clamp(0, _totalDuration.inMilliseconds),
    );

    if (_seekThrottleTimer?.isActive ?? false) {
      _pendingSeekPosition = clamped;
      return;
    }

    _pendingSeekPosition = null;
    _controller.seekTo(clamped);

    _seekThrottleTimer = Timer(const Duration(milliseconds: 100), () {
      if (_pendingSeekPosition != null) {
        final next = _pendingSeekPosition!;
        _pendingSeekPosition = null;
        _throttledSeekTo(next);
      }
    });
  }

  void _flushThrottledSeek(Duration position) {
    _seekThrottleTimer?.cancel();
    _seekThrottleTimer = null;
    _pendingSeekPosition = null;
    _controller.seekTo(Duration(
      milliseconds: position.inMilliseconds.clamp(0, _totalDuration.inMilliseconds),
    ));
  }

  void _onDoubleTapLeft() {
    final seekSeconds = _settingsRepo.pinnedFolders.isNotEmpty ? 10 : 10; // Default seek seconds
    _controller.seekTo(_currentPosition - Duration(seconds: seekSeconds));
    _showSeekOverlay(-1);
  }

  void _onDoubleTapRight() {
    final seekSeconds = _settingsRepo.pinnedFolders.isNotEmpty ? 10 : 10; // Default seek seconds
    _controller.seekTo(_currentPosition + Duration(seconds: seekSeconds));
    _showSeekOverlay(1);
  }

  void _showSeekOverlay(int direction) {
    setState(() {
      _showSeekIndicator = true;
      _seekDirection = direction;
    });
    _indicatorTimer?.cancel();
    _indicatorTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _showSeekIndicator = false);
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartFocalPoint = details.focalPoint;
    _gestureDirectionDecided = false;
    _gestureIsHorizontal = false;

    if (details.pointerCount >= 2) {
      _isTwoFingerGesture = true;
      _speedGestureAccumulator = 0.0;
    } else {
      _isTwoFingerGesture = false;
      _isVerticalDragging = false;
      _isDraggingSeek = false;
      _verticalDragAccumulator = 0.0;
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount >= 2 || _isTwoFingerGesture) {
      _isTwoFingerGesture = true;
      _speedGestureAccumulator += -details.focalPointDelta.dy;
      final speedDelta = (_speedGestureAccumulator / 40.0).truncateToDouble() * 0.25;
      if (speedDelta != 0) {
        _playbackSpeed = (_playbackSpeed + speedDelta).clamp(0.25, 3.0);
        _playbackSpeed = ((_playbackSpeed * 4).roundToDouble()) / 4;
        _controller.setPlaybackSpeed(_playbackSpeed);
        _speedGestureAccumulator = _speedGestureAccumulator % 40.0;
        setState(() => _showSpeedIndicator = true);
      }
      return;
    }

    if (!_gestureDirectionDecided && _gestureStartFocalPoint != null) {
      final dx = (details.focalPoint.dx - _gestureStartFocalPoint!.dx).abs();
      final dy = (details.focalPoint.dy - _gestureStartFocalPoint!.dy).abs();
      if (dx > 10 || dy > 10) {
        _gestureDirectionDecided = true;
        _gestureIsHorizontal = dx > dy;

        if (_gestureIsHorizontal) {
          _wasPlayingBeforeDrag = _isPlaying;
          _isDraggingSeek = true;
          _dragStartX = _gestureStartFocalPoint!.dx;
          _dragStartPosition = _currentPosition;
          _dragSeekPosition = _currentPosition;
          _controller.pause();
        } else {
          _isVerticalDragging = true;
          final screenWidth = MediaQuery.of(context).size.width;
          _verticalDragIsLeftSide = _gestureStartFocalPoint!.dx < screenWidth / 2;
        }
      }
      return;
    }

    if (_isDraggingSeek) {
      final screenWidth = MediaQuery.of(context).size.width;
      final dx = details.focalPoint.dx - _dragStartX;
      final seekDelta = Duration(milliseconds: (dx / screenWidth * 60000).toInt());
      final newPos = _dragStartPosition + seekDelta;
      final clampedPos = Duration(
        milliseconds: newPos.inMilliseconds.clamp(0, _totalDuration.inMilliseconds),
      );
      setState(() {
        _dragSeekPosition = clampedPos;
        _currentPosition = clampedPos;
      });
      _throttledSeekTo(clampedPos);
    } else if (_isVerticalDragging) {
      final delta = -details.focalPointDelta.dy / 300.0;
      if (_verticalDragIsLeftSide) {
        _brightness = (_brightness + delta).clamp(0.0, 1.0);
        setState(() => _showBrightnessIndicator = true);
      } else {
        _volume = (_volume + delta).clamp(0.0, 1.0);
        _controller.setVolume(_isMuted ? 0.0 : _volume);
        setState(() => _showVolumeIndicator = true);
      }
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_isTwoFingerGesture) {
      _isTwoFingerGesture = false;
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() => _showSpeedIndicator = false);
      });
    }

    if (_isDraggingSeek) {
      _flushThrottledSeek(_dragSeekPosition);
      setState(() {
        _isDraggingSeek = false;
        _currentPosition = _dragSeekPosition;
      });
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!mounted) return;
        if (_wasPlayingBeforeDrag && _dragSeekPosition < _totalDuration) {
          _controller.play();
        }
      });
    }

    if (_isVerticalDragging) {
      setState(() {
        _isVerticalDragging = false;
        _showBrightnessIndicator = false;
        _showVolumeIndicator = false;
      });
    }

    _gestureStartFocalPoint = null;
    _gestureDirectionDecided = false;
  }

  // Using formatDuration from core/utils/formatters.dart (imported at top)
  String _formatDuration(Duration d) => formatDuration(d);

  Future<void> _handleDelete() async {
    final file = File(_currentVideoPath);
    if (!await file.exists()) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Video"),
        content: const Text("Are you sure you want to delete this video?\n\nThis action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      )
    );

    if (confirm == true) {
      await file.delete();
      _anyDeleted = true;
      if (_playlist.length > 1) {
        _playlist.removeWhere((f) => f.path == _currentVideoPath);
        if (_currentIndex >= _playlist.length) _currentIndex = _playlist.length - 1;
        final nextFile = _playlist[_currentIndex];
        await _loadNewVideo(nextFile.path, nextFile.statSync().modified);
      } else {
        Navigator.pop(context, _anyDeleted);
      }
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _indicatorTimer?.cancel();
    _seekThrottleTimer?.cancel();
    _controller.removeListener(_onVideoTick);
    _controller.dispose();
    _timestampScrollController.dispose();
    super.dispose();
  }

  void _onFlagTap() {
    setState(() {
      if (!_isEditMode) _isEditMode = true;
      _flaggedTimestamps.insert(0, _currentPosition);
    });
    _scrollToTop();
  }

  void _scrollToTop() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (_timestampScrollController.hasClients) {
        _timestampScrollController.animateTo(0.0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  List<Map<String, Duration>> _getSegments() {
    final List<Duration> sorted = List.from(_flaggedTimestamps)..sort();
    final List<Map<String, Duration>> segments = [];
    for (int i = 0; i < sorted.length; i += 2) {
      final start = sorted[i];
      final end = (i + 1 < sorted.length) ? sorted[i + 1] : _totalDuration;
      final duration = end - start;
      if (duration.inMilliseconds > 0) segments.add({'start': start, 'duration': duration});
    }
    return segments;
  }

  Future<void> _estimateAndProcess(String type) async {
    if (_controller.value.isPlaying) await _controller.pause();
    if (_flaggedTimestamps.isEmpty) return;

    setState(() {
      _processingType = type;
      _processingStatus = "Preparing...";
      _isProcessing = true;
    });

    _showConfirmationDialog(type, 0, 0); // Simplified for Linux
  }

  // Using formatDurationMs from core/utils/formatters.dart (imported at top)
  String _formatDurationMs(Duration d) => formatDurationMs(d);

  Future<void> _showConfirmationDialog(String type, double req, double avail) async {
    final segments = _getSegments();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF192229),
        title: Text(type == "trim" ? "CONFIRM TRIM" : "EXTRACT FRAMES", style: const TextStyle(color: Colors.white)),
        content: Text("Process ${segments.length} segments?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
          if (type == "trim") ...[
            TextButton(
              onPressed: () { Navigator.pop(ctx); _executeTrim(true); },
              child: const Text("REPLACE", style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton(
              onPressed: () { Navigator.pop(ctx); _executeTrim(false); },
              child: const Text("COPY"),
            ),
          ] else
            ElevatedButton(
              onPressed: () { Navigator.pop(ctx); _executeFrameExtraction(); },
              child: const Text("PROCESS"),
            ),
        ],
      )
    );
    if (!_isProcessing) setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildVideoLayer(),
          _buildGestureLayer(),
          if (_showControls && !_isFullView && !_isEditMode) _buildTopGradient(),
          if (_showControls && !_isFullView && !_isEditMode) _buildBottomGradient(),
          if (_showControls && !_isFullView && !_isEditMode) _buildTopBanner(),
          if (_showControls && !_isFullView && !_isEditMode) _buildResolutionBadge(),
          if (_showControls && !_isFullView && !_isEditMode) _buildDeleteButton(),
          if (_showControls && !_isFullView && !_isEditMode) _buildCombinedControlPanel(),
          if (_isEditMode) ...[_buildEditModeTopBar(), _buildTimestampList()],
          if (_showBrightnessIndicator) _buildVerticalIndicator(Icons.brightness_6, _brightness, 'Brightness', true),
          if (_showVolumeIndicator) _buildVerticalIndicator(Icons.volume_up, _volume, 'Volume', false),
          if (_showSeekIndicator) _buildSeekIndicatorOverlay(),
          if (_showSpeedIndicator) _buildSpeedIndicator(),
          if (_isDraggingSeek) _buildDragSeekIndicator(),
          _buildActionButtons(),
          if (_isEditMode && !_isProcessing) _buildEditModePauseButton(),
          if (_showFlash) _buildFlashOverlay(),
          if (_isProcessing) _buildProcessingOverlay(),
          if (_isEditMode && !_isProcessing) _buildEditModeProgressBar(),
        ],
      ),
    );
  }

  Widget _buildVideoLayer() => Center(child: AspectRatio(aspectRatio: _controller.value.aspectRatio, child: VideoPlayer(_controller)));

  Widget _buildGestureLayer() => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTapUp: _onScreenTapUp,
    onScaleStart: _onScaleStart,
    onScaleUpdate: _onScaleUpdate,
    onScaleEnd: _onScaleEnd,
    child: Stack(
      children: [
        Positioned.fill(child: Container(color: Colors.transparent)),
        Positioned(left: 0, top: 0, bottom: 0, width: MediaQuery.of(context).size.width / 3, child: GestureDetector(behavior: HitTestBehavior.translucent, onDoubleTap: _onDoubleTapLeft)),
        Positioned(right: 0, top: 0, bottom: 0, width: MediaQuery.of(context).size.width / 3, child: GestureDetector(behavior: HitTestBehavior.translucent, onDoubleTap: _onDoubleTapRight)),
      ],
    ),
  );

  Widget _buildTopGradient() => Positioned(top: 0, left: 0, right: 0, height: 180, child: IgnorePointer(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xCC000000), Color(0x80000000), Colors.transparent])))));
  Widget _buildBottomGradient() => Positioned(bottom: 0, left: 0, right: 0, height: 220, child: IgnorePointer(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xCC000000), Color(0x80000000), Colors.transparent])))));

  Widget _buildTopBanner() {
    final fileName = _currentVideoPath.split('/').last;
    return Positioned(
      top: 32, left: 16, right: 16,
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.pop(context, _anyDeleted), icon: const Icon(Icons.arrow_back, color: Colors.white)),
          Expanded(child: Text(fileName, style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildResolutionBadge() => Positioned(top: 80, left: 16, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(20)), child: Text('$_resolutionLabel • ${_fps} FPS', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold))));
  Widget _buildDeleteButton() => Positioned(top: 70, right: 16, child: IconButton(onPressed: _handleDelete, icon: const Icon(Icons.delete_outline, color: Colors.redAccent)));

  Widget _buildCombinedControlPanel() {
    final progress = _totalDuration.inMilliseconds > 0 ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds : 0.0;
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(color: Color(0xFF192229), borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(_formatDuration(_currentPosition), style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 13, fontWeight: FontWeight.bold)),
                Expanded(child: Slider(value: progress.clamp(0.0, 1.0), onChanged: (v) { final pos = Duration(milliseconds: (v * _totalDuration.inMilliseconds).toInt()); setState(() => _currentPosition = pos); _throttledSeekTo(pos); })),
                Text(_formatDuration(_totalDuration), style: const TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(onPressed: _toggleMute, icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white)),
                IconButton(onPressed: _currentIndex > 0 ? () => _loadNewVideo(_playlist[_currentIndex - 1].path, null) : null, icon: const Icon(Icons.fast_rewind, color: Colors.white)),
                GestureDetector(onTap: _togglePlayPause, child: Container(padding: const EdgeInsets.all(16), decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white10), child: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: const Color(0xFF00E5FF), size: 32))),
                IconButton(onPressed: _currentIndex < _playlist.length - 1 ? () => _loadNewVideo(_playlist[_currentIndex + 1].path, null) : null, icon: const Icon(Icons.fast_forward, color: Colors.white)),
                IconButton(onPressed: _toggleFullView, icon: const Icon(Icons.fullscreen, color: Colors.white)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditModeTopBar() => Positioned(top: 40, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
    ElevatedButton(onPressed: () => _estimateAndProcess("trim"), child: const Text("TRIM")),
    const SizedBox(width: 20),
    IconButton(onPressed: () => setState(() => _isEditMode = false), icon: const Icon(Icons.close, color: Colors.white, size: 32)),
    const SizedBox(width: 20),
    ElevatedButton(onPressed: () => _estimateAndProcess("frame"), child: const Text("FRAME")),
  ]));

  Widget _buildTimestampList() => Positioned(left: 20, bottom: 120, top: 150, child: SizedBox(width: 140, child: ListView.builder(itemCount: _flaggedTimestamps.length, controller: _timestampScrollController, itemBuilder: (context, index) {
    final ts = _flaggedTimestamps[index];
    final color = ((_flaggedTimestamps.length - 1 - index) % 2 == 0) ? const Color(0xFF00E5FF) : const Color(0xFFFFAB40);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withOpacity(0.5))), child: Text(_formatDuration(ts), style: TextStyle(color: color, fontWeight: FontWeight.bold))),
      if (index == 0) IconButton(onPressed: () => setState(() => _flaggedTimestamps.removeAt(index)), icon: const Icon(Icons.close, color: Colors.red, size: 16)),
    ]));
  })));

  Widget _buildActionButtons() {
    final flagColor = (_flaggedTimestamps.length % 2 == 0) ? const Color(0xFF00E5FF) : const Color(0xFFFFAB40);
    return Positioned(bottom: 40, left: 0, right: 0, child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      GestureDetector(onTap: _onFlagTap, child: Container(width: 60, height: 60, decoration: BoxDecoration(color: flagColor.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: flagColor, width: 2)), child: Icon(Icons.flag, color: flagColor))),
      const SizedBox(width: 30),
      GestureDetector(onTap: _onSnapshotTap, child: Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white10)), child: const Icon(Icons.camera_alt, color: Color(0xFF00E5FF)))),
    ]));
  }

  Widget _buildEditModePauseButton() => Positioned(bottom: 40, right: 30, child: IconButton(onPressed: _togglePlayPause, icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: const Color(0xFF00E5FF), size: 32)));

  Widget _buildEditModeProgressBar() => Positioned(bottom: 0, left: 0, right: 0, child: LinearProgressIndicator(value: _totalDuration.inMilliseconds > 0 ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds : 0, backgroundColor: Colors.white10, valueColor: const AlwaysStoppedAnimation(Color(0xFF00E5FF)), minHeight: 4));

  Widget _buildFlashOverlay() => Positioned.fill(child: IgnorePointer(child: Container(color: Colors.white54)));

  Widget _buildProcessingOverlay() => Container(color: Colors.black87, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text(_processingStatus, style: const TextStyle(color: Colors.white))])));

  Widget _buildVerticalIndicator(IconData icon, double val, String label, bool isLeft) => Positioned(top: 200, left: isLeft ? 40 : null, right: isLeft ? null : 40, child: Column(children: [Icon(icon, color: const Color(0xFF00E5FF)), const SizedBox(height: 10), Container(height: 100, width: 4, child: RotatedBox(quarterTurns: -1, child: LinearProgressIndicator(value: val))) ]));
  Widget _buildSeekIndicatorOverlay() => Center(child: Icon(_seekDirection < 0 ? Icons.fast_rewind : Icons.fast_forward, color: const Color(0xFF00E5FF), size: 80));
  Widget _buildSpeedIndicator() => Center(child: Text('${_playbackSpeed}x', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)));
  Widget _buildDragSeekIndicator() => Center(child: Text(_formatDuration(_dragSeekPosition), style: const TextStyle(color: Colors.white, fontSize: 50, fontWeight: FontWeight.bold)));

  void _onSnapshotTap() { _triggerFlash(); _snapshotQueue.add(_currentPosition.inMilliseconds); _processSnapshotQueue(); }
  void _triggerFlash() { setState(() => _showFlash = true); Future.delayed(const Duration(milliseconds: 100), () => setState(() => _showFlash = false)); }
  Future<void> _processSnapshotQueue() async { if (_isCapturingSnapshot) return; _isCapturingSnapshot = true; while (_snapshotQueue.isNotEmpty) { await _captureSnapshotAtMs(_snapshotQueue.removeAt(0)); } _isCapturingSnapshot = false; }
  Future<void> _captureSnapshotAtMs(int ms) async {
    final dir = Directory('${File(_currentVideoPath).parent.path}/Snapshots');
    if (!await dir.exists()) await dir.create(recursive: true);
    final out = '${dir.path}/snapshot_${DateTime.now().millisecondsSinceEpoch}.png';
    final cmd = 'ffmpeg -ss ${_formatDurationMs(Duration(milliseconds: ms))} -i "$_currentVideoPath" -vframes 1 "$out" -y';
    await Process.run('bash', ['-c', cmd]);
  }

  Future<void> _executeTrim(bool replace) async {
    setState(() => _processingStatus = "Trimming...");
    final segments = _getSegments();
    final out = '${File(_currentVideoPath).parent.path}/trimmed_${DateTime.now().millisecondsSinceEpoch}.mp4';
    // Simplified: just trim the first segment for demo or complex logic
    final s = segments.first;
    final cmd = 'ffmpeg -ss ${_formatDurationMs(s['start']!)} -i "$_currentVideoPath" -t ${_formatDurationMs(s['duration']!)} -c copy "$out" -y';
    await Process.run('bash', ['-c', cmd]);
    if (replace) { await File(_currentVideoPath).delete(); await File(out).rename(_currentVideoPath); }
    setState(() => _isProcessing = false);
    Navigator.pop(context, true);
  }

  Future<void> _executeFrameExtraction() async {
    setState(() => _processingStatus = "Extracting...");
    final dir = Directory('${File(_currentVideoPath).parent.path}/Frames_${DateTime.now().millisecondsSinceEpoch}');
    await dir.create(recursive: true);
    final cmd = 'ffmpeg -i "$_currentVideoPath" -r $_fps "${dir.path}/frame_%04d.png" -y';
    await Process.run('bash', ['-c', cmd]);
    setState(() => _isProcessing = false);
    Navigator.pop(context, dir.path);
  }
}
