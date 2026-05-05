import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/widgets/viewer_top_bar.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/window_management/window_controller_extension.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import '../providers/audio_player_providers.dart';
import '../widgets/playlist_sidebar.dart';
import '../widgets/hero_audio_player.dart';

class AudioPlayerView extends ConsumerStatefulWidget {
  final FileItem item;
  final bool isStandalone;
  final String? windowId;
  final String? parentWindowId;

  const AudioPlayerView({
    required this.item,
    this.isStandalone = false,
    this.windowId,
    this.parentWindowId,
    super.key,
  });

  @override
  ConsumerState<AudioPlayerView> createState() => _AudioPlayerViewState();
}

class _AudioPlayerViewState extends ConsumerState<AudioPlayerView> {
  final FocusNode _focusNode = FocusNode();
  late final Player _player;
  StreamSubscription? _playlistSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _bufferingSub;
  bool _isOpening = false;
  bool _isBuffering = false;

  @override
  void initState() {
    super.initState();
    
    // Create the player locally (same pattern as VideoPreviewWidget)
    _player = Player();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      _initializePlayer();
    });
  }

  void _initializePlayer() {
    debugPrint('[AudioPlayer] Initializing for: ${widget.item.path}');

    // Build the queue from directory items
    final itemsAsync = ref.read(directoryItemsProvider);
    final audioFiles = itemsAsync.maybeWhen(
      data: (items) => items.where((i) => i.type == FileItemType.audio).toList(),
      orElse: () => [widget.item],
    );

    final currentIndex = audioFiles.indexWhere((i) => i.path == widget.item.path);
    final startIndex = currentIndex != -1 ? currentIndex : 0;

    // Push state to providers AFTER the first frame (safe now)
    ref.read(audioQueueProvider.notifier).state = audioFiles;
    ref.read(activeTrackIndexProvider.notifier).state = startIndex;
    
    // Register the player instance with Riverpod so child widgets can access it
    ref.read(audioPlayerProvider.notifier).state = _player;

    // Subscribe to errors
    _errorSub = _player.stream.error.listen((error) {
      debugPrint('[AudioPlayer] ENGINE ERROR: $error');
    });

    // Track changes
    _playlistSub = _player.stream.playlist.listen((playlist) {
      if (mounted) {
        ref.read(activeTrackIndexProvider.notifier).state = playlist.index;
      }
    });

    _bufferingSub = _player.stream.buffering.listen((buffering) {
      if (mounted && _isBuffering != buffering) {
        setState(() => _isBuffering = buffering);
      }
    });

    // Open and play
    final playlist = Playlist(
      audioFiles.map((f) => Media(f.path)).toList(),
      index: startIndex,
    );

    debugPrint('[AudioPlayer] Opening playlist with ${audioFiles.length} tracks, starting at $startIndex');
    setState(() => _isOpening = true);
    _player.open(playlist).then((_) {
      if (mounted) setState(() => _isOpening = false);
    });
    // player.open defaults to play: true, so playback starts immediately
  }

  @override
  void dispose() {
    _playlistSub?.cancel();
    _errorSub?.cancel();
    _bufferingSub?.cancel();
    _focusNode.dispose();
    
    // Clear the provider reference before disposing
    // Use a microtask to avoid modifying providers during dispose
    Future.microtask(() {
      try {
        ref.read(audioPlayerProvider.notifier).state = null;
      } catch (_) {}
    });
    
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack = ref.watch(currentTrackProvider);
    final settings = ref.watch(settingsProvider).value;
    final seekSeconds = settings?.audioSeekSeconds ?? 5;

    return FocusableActionDetector(
      focusNode: _focusNode,
      autofocus: true,
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.space): const _TogglePlayIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _SeekIntent(forward: false),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const _SeekIntent(forward: true),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const _VolumeIntent(increase: true),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const _VolumeIntent(increase: false),
        LogicalKeySet(LogicalKeyboardKey.keyM): const _ToggleMuteIntent(),
      },
      actions: {
        _TogglePlayIntent: CallbackAction<_TogglePlayIntent>(
          onInvoke: (_) => _player.playOrPause(),
        ),
        _SeekIntent: CallbackAction<_SeekIntent>(
          onInvoke: (intent) {
            final delta = intent.forward ? seekSeconds : -seekSeconds;
            _player.seek(_player.state.position + Duration(seconds: delta));
            return null;
          },
        ),
        _VolumeIntent: CallbackAction<_VolumeIntent>(
          onInvoke: (intent) {
            final delta = intent.increase ? 5 : -5;
            _player.setVolume((_player.state.volume + delta).clamp(0, 100));
            return null;
          },
        ),
        _ToggleMuteIntent: CallbackAction<_ToggleMuteIntent>(
          onInvoke: (_) {
            _player.setVolume(_player.state.volume > 0 ? 0 : 100);
            return null;
          },
        ),
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Row(
          children: [
            // Left Pane (25%)
            const Expanded(
              flex: 1,
              child: PlaylistSidebar(),
            ),
            
            // Right Pane (75%)
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  const HeroAudioPlayer(),
                  
                  // Top HUD (Hero Pane only)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: ViewerTopBar(
                      title: currentTrack?.name ?? widget.item.name,
                      metadata: "Audio Player",
                      isStandalone: widget.isStandalone,
                      onClose: () {
                        if (widget.isStandalone) {
                          WindowController.fromCurrentEngine().then((c) => c.close());
                        } else {
                          ref.read(previewFileProvider.notifier).state = null;
                        }
                      },
                      onPopOut: widget.isStandalone ? null : () async {
                        final params = WindowParams(
                          viewerType: ViewerType.audio,
                          file: widget.item,
                        );
                        await PersistentViewerManager.openMedia(params);
                        ref.read(previewFileProvider.notifier).state = null;
                      },
                    ),
                  ),
                  Positioned.fill(
                    child: Center(
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: (_isOpening || _isBuffering) ? 1.0 : 0.0,
                        child: const BubbleLoader(size: 80),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TogglePlayIntent extends Intent { const _TogglePlayIntent(); }
class _SeekIntent extends Intent { 
  final bool forward;
  const _SeekIntent({required this.forward}); 
}
class _VolumeIntent extends Intent { 
  final bool increase;
  const _VolumeIntent({required this.increase}); 
}
class _ToggleMuteIntent extends Intent { const _ToggleMuteIntent(); }
