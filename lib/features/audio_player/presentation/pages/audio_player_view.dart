import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart' as p;
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
import 'package:onyxcore/features/directory_browser/presentation/widgets/dialogs.dart';
import 'package:onyxcore/features/directory_browser/domain/repositories/directory_repository.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import '../providers/audio_player_providers.dart';
import '../widgets/playlist_sidebar.dart';
import '../widgets/hero_audio_player.dart';
import 'package:onyxcore/features/settings/presentation/widgets/settings_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/rename_popover.dart';

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
      
      // Initialize the root path to the parent directory of the initial file
      final initialDir = p.dirname(widget.item.path);
      ref.read(audioRootPathProvider.notifier).state = initialDir;
      ref.read(audioCurrentPathProvider.notifier).state = initialDir;
      
      _focusNode.requestFocus();
      _initializePlayer();
    });
  }

  void _initializePlayer() async {
    debugPrint('[AudioPlayer] Initializing for: ${widget.item.path}');

    // Build the queue from directory items
    final itemsAsync = ref.read(directoryItemsProvider);
    final repo = ref.read(directoryRepositoryProvider);
    
    List<FileItem> audioFiles = [];
    if (itemsAsync.hasValue) {
      final items = itemsAsync.value!;
      for (final item in items) {
        if (item.type == FileItemType.audio) {
          audioFiles.add(item);
        } else if (item.type == FileItemType.folder) {
          try {
            final subItems = await repo.listDirectory(item.path);
            final hasAudio = subItems.any((sub) => sub.type == FileItemType.audio);
            if (hasAudio) {
              audioFiles.add(item);
            }
          } catch (_) {}
        }
      }
    } else {
      audioFiles = [widget.item];
    }

    final currentIndex = audioFiles.indexWhere((i) => i.path == widget.item.path);
    final startIndex = currentIndex != -1 ? currentIndex : 0;

    // Enable volume boosting up to 200%
    try {
      (_player.platform as dynamic).setProperty('volume-max', '200');
    } catch (e) {
      debugPrint('[AudioPlayer] Could not set volume-max: $e');
    }

    // Push state to providers AFTER the first frame (safe now)
    ref.read(audioQueueProvider.notifier).state = audioFiles;
    ref.read(activeTrackIndexProvider.notifier).state = startIndex;
    
    // Set initial isolated path
    final currentPath = ref.read(currentPathProvider);
    ref.read(audioCurrentPathProvider.notifier).state = currentPath;
    
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

  void _navigateHistoryBack(WidgetRef ref) {
    final history = ref.read(audioPathHistoryProvider);
    if (history.isEmpty) return;

    final newHistory = List<String>.from(history);
    final currentPath = ref.read(audioCurrentPathProvider);
    final prevPath = newHistory.removeLast();

    ref.read(audioPathForwardHistoryProvider.notifier).update((state) => [currentPath, ...state]);
    ref.read(audioPathHistoryProvider.notifier).state = newHistory;
    
    // Load the folder
    final repo = ref.read(directoryRepositoryProvider);
    repo.listDirectory(prevPath).then((items) {
      final audioFiles = items.where((i) => i.type == FileItemType.audio || i.type == FileItemType.folder).toList();
      ref.read(audioCurrentPathProvider.notifier).state = prevPath;
      ref.read(audioQueueProvider.notifier).state = audioFiles;
      ref.read(audioSelectionProvider.notifier).state = {};
      ref.read(audioSelectionAnchorProvider.notifier).state = null;
    });
  }

  void _navigateHistoryForward(WidgetRef ref) {
    final forwardHistory = ref.read(audioPathForwardHistoryProvider);
    if (forwardHistory.isEmpty) return;

    final newForward = List<String>.from(forwardHistory);
    final currentPath = ref.read(audioCurrentPathProvider);
    final nextPath = newForward.removeAt(0);

    ref.read(audioPathHistoryProvider.notifier).update((state) => [...state, currentPath]);
    ref.read(audioPathForwardHistoryProvider.notifier).state = newForward;

    final repo = ref.read(directoryRepositoryProvider);
    repo.listDirectory(nextPath).then((items) {
      final audioFiles = items.where((i) => i.type == FileItemType.audio || i.type == FileItemType.folder).toList();
      ref.read(audioCurrentPathProvider.notifier).state = nextPath;
      ref.read(audioQueueProvider.notifier).state = audioFiles;
      ref.read(audioSelectionProvider.notifier).state = {};
      ref.read(audioSelectionAnchorProvider.notifier).state = null;
    });
  }

  void _navigateUp(WidgetRef ref) {
    final currentPath = ref.read(audioCurrentPathProvider);
    if (currentPath.isEmpty || currentPath == '/') return;
    
    final parentPath = p.dirname(currentPath);
    ref.read(audioPathHistoryProvider.notifier).update((state) => [...state, currentPath]);
    ref.read(audioPathForwardHistoryProvider.notifier).state = [];
    
    final repo = ref.read(directoryRepositoryProvider);
    repo.listDirectory(parentPath).then((items) {
      final audioFiles = items.where((i) => i.type == FileItemType.audio || i.type == FileItemType.folder).toList();
      ref.read(audioCurrentPathProvider.notifier).state = parentPath;
      ref.read(audioQueueProvider.notifier).state = audioFiles;
      ref.read(audioSelectionProvider.notifier).state = {};
      ref.read(audioSelectionAnchorProvider.notifier).state = null;
    });
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

  Future<void> _handleDelete({required bool permanent}) async {
    final settings = ref.read(settingsProvider).value;
    final needConfirm = settings?.confirmDeleteAudio ?? true;
    final currentTrack = ref.read(currentTrackProvider);
    if (currentTrack == null) return;

    final confirm = needConfirm
        ? await showDialog<bool>(
            context: context,
            builder: (context) => ViewerDeleteDialog(
              fileName: currentTrack.name,
              permanent: permanent,
            ),
          )
        : true;

    if (confirm != true) return;

    _player.pause();

    final queue = ref.read(audioQueueProvider);
    final currentIndex = ref.read(activeTrackIndexProvider);
    final hasMultiple = queue.length > 1;

    int? nextIndex;
    if (hasMultiple) {
      nextIndex = currentIndex == queue.length - 1 ? currentIndex - 1 : currentIndex;
      ref.read(activeTrackIndexProvider.notifier).state = nextIndex;
      _player.jump(nextIndex);
    }

    final repo = ref.read(directoryRepositoryProvider);
    final path = currentTrack.path;

    final taskId = ref.read(taskProvider.notifier).addTask(
      title: permanent ? 'Deleting audio file permanently' : 'Moving audio file to Trash',
      subtitle: currentTrack.name,
      sourcePaths: [path],
      isLight: true,
    );

    try {
      if (widget.isStandalone) {
        final payload = jsonEncode({
          'path': path,
          'permanent': permanent,
          'taskId': taskId,
          'targetWindowId': widget.windowId!,
        });
        await WindowController.fromWindowId(widget.parentWindowId ?? '0').invokeMethod('delete_item', payload);
      } else {
        await repo.deleteItems(
          [path],
          permanent: permanent,
          taskId: taskId,
          onLog: (msg) => ref.read(taskProvider.notifier).addLog(taskId, msg),
        );
        ref.read(directoryItemsProvider.notifier).refresh();
      }
      ref.read(taskProvider.notifier).completeTask(taskId);
    } catch (e) {
      ref.read(taskProvider.notifier).failTask(taskId, e.toString());
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deletion failed: $e')));
    }

    if (hasMultiple) {
      final updatedQueue = queue.where((item) => item.path != path).toList();
      ref.read(audioQueueProvider.notifier).state = updatedQueue;
      
      final list = updatedQueue.map((item) => Media(item.path)).toList();
      await _player.open(Playlist(list, index: nextIndex!));
    } else {
      if (widget.isStandalone) {
        final c = await WindowController.fromCurrentEngine();
        await c.close();
      } else {
        ref.read(previewFileProvider.notifier).state = null;
        ref.read(mainFocusNodeProvider).requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack = ref.watch(currentTrackProvider);
    final settings = ref.watch(settingsProvider).value;
    final seekSeconds = settings?.audioSeekSeconds ?? 5;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;

        final isAlt = HardwareKeyboard.instance.isAltPressed;

        if (key == LogicalKeyboardKey.space) {
          _player.playOrPause();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft) {
          if (isAlt) {
            _navigateHistoryBack(ref);
          } else {
            _player.seek(_player.state.position - Duration(seconds: seekSeconds));
          }
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          if (isAlt) {
            _navigateHistoryForward(ref);
          } else {
            _player.seek(_player.state.position + Duration(seconds: seekSeconds));
          }
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp && isAlt) {
          _navigateUp(ref);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowUp) {
          _player.setVolume((_player.state.volume + 5).clamp(0, 200));
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown) {
          _player.setVolume((_player.state.volume - 5).clamp(0, 200));
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyM) {
          final currentVolume = _player.state.volume;
          _player.setVolume(currentVolume > 0 ? 0 : 100);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.delete) {
          final isShift = HardwareKeyboard.instance.isShiftPressed;
          _handleDelete(permanent: isShift);
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        behavior: HitTestBehavior.translucent,
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
                child: GestureDetector(
                  onDoubleTap: widget.isStandalone ? null : () {
                    final params = WindowParams(
                      viewerType: ViewerType.audio,
                      file: currentTrack ?? widget.item,
                    );
                    PersistentViewerManager.openMedia(params).then((_) {
                      ref.read(previewFileProvider.notifier).state = null;
                    });
                  },
                  behavior: HitTestBehavior.translucent,
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
                        extraActions: [
                          // Settings button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.settings_rounded, color: Colors.white, size: 20),
                              onPressed: () {
                                SettingsDialog.show(context, initialTab: 1, section: 'Audio');
                              },
                              tooltip: 'Audio Settings',
                              splashRadius: 24,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Edit / Rename button
                          if (currentTrack != null)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
                                onPressed: () {
                                  final existingNames = ref
                                      .read(directoryItemsProvider)
                                      .value
                                      ?.map((i) => i.name)
                                      .toList() ?? [];
                                  RenamePopover.show(
                                    context: context,
                                    position: Offset(
                                      MediaQuery.of(context).size.width / 2,
                                      80,
                                    ),
                                    paths: [currentTrack.path],
                                    existingNames: existingNames,
                                    onRename: (result) async {
                                      if (result is String) {
                                        final repo = ref.read(directoryRepositoryProvider);
                                        final taskId = ref.read(taskProvider.notifier).addTask(
                                          title: 'Renaming audio file',
                                          subtitle: result,
                                          sourcePaths: [currentTrack.path],
                                          isLight: true,
                                        );
                                        try {
                                          await repo.renameItem(
                                            currentTrack.path,
                                            result,
                                            taskId: taskId,
                                            onLog: (msg) => ref.read(taskProvider.notifier).addLog(taskId, msg),
                                          );
                                          ref.read(taskProvider.notifier).completeTask(taskId);
                                          ref.read(directoryItemsProvider.notifier).refresh();
                                        } catch (e) {
                                          ref.read(taskProvider.notifier).failTask(taskId, e.toString());
                                        }
                                      }
                                    },
                                    onClose: () => _focusNode.requestFocus(),
                                  );
                                },
                                tooltip: 'Rename',
                                splashRadius: 24,
                              ),
                            ),
                          const SizedBox(width: 8),
                        ],
                        onClose: () {
                          if (widget.isStandalone) {
                            WindowController.fromCurrentEngine().then((c) => c.close());
                          } else {
                            ref.read(previewFileProvider.notifier).state = null;
                          }
                        },
                        onPopOut: widget.isStandalone ? null : () {
                          final params = WindowParams(
                            viewerType: ViewerType.audio,
                            file: widget.item,
                          );
                          PersistentViewerManager.openMedia(params).then((_) {
                            ref.read(previewFileProvider.notifier).state = null;
                          });
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

