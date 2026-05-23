import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/features/audio_player/domain/utils/audio_queue_isolate.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/dialogs/audio_tag_editor_dialog.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/dialogs/audio_properties_dialog.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
import 'package:onyxcore/core/utils/media_uri_helper.dart';
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
  static int _globalPlayerViewIdCounter = 0;
  int _myPlayerViewId = 0;

  final FocusNode _focusNode = FocusNode();
  late final Player _player;
  StreamSubscription? _playlistSub;
  StreamSubscription? _errorSub;
  StreamSubscription? _bufferingSub;
  StreamSubscription? _bitrateSub;
  bool _isOpening = false;
  bool _isBuffering = false;
  double? _bitrate;
  bool _sessionDontAskTrash = false;

  @override
  void initState() {
    super.initState();

    _globalPlayerViewIdCounter++;
    _myPlayerViewId = _globalPlayerViewIdCounter;

    // Use the global, reused Player instance to avoid native deadlocks
    _player = globalAudioPlayer;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Reset states for fresh open
      ref.read(audioSearchQueryProvider.notifier).state = '';
      ref.read(audioSelectionProvider.notifier).state = {};
      ref.read(audioSelectionAnchorProvider.notifier).state = null;
      ref.read(audioViewModeProvider.notifier).state = AudioViewMode.home;

      // Inherit sort order from gallery
      final gallerySort = ref.read(sortSettingsProvider).option;
      ref.read(audioSortOptionProvider.notifier).state = gallerySort;

      // Initialize the root path to the parent directory of the initial file
      final initialDir = p.dirname(widget.item.path);
      ref.read(audioRootPathProvider.notifier).state = initialDir;
      ref.read(audioCurrentPathProvider.notifier).state = initialDir;

      _focusNode.requestFocus();
      _initializePlayer();
    });
  }

  Future<List<FileItem>> _fetchAudioQueue(String path) async {
    final repo = ref.read(directoryRepositoryProvider);
    final showHidden = ref.read(audioShowHiddenProvider);
    
    final List<FileItem> items;
    try {
      items = await repo.listDirectory(path);
    } catch (_) {
      return [];
    }

    return await compute(processAudioQueueIsolate, {
      'items': items.map((e) => e.toJson()).toList(),
      'showHidden': showHidden,
    });
  }

  Future<void> _handleReload() async {
    if (ref.read(audioIsReloadingProvider)) return;
    ref.read(audioIsReloadingProvider.notifier).state = true;
    
    try {
      final currentDir = ref.read(audioCurrentPathProvider);
      
      // Invalidate the cache to ensure a true disk read
      final repo = ref.read(directoryRepositoryProvider);
      repo.invalidateCache(currentDir);
      
      // Artificial delay to ensure the UI loading effect is perceptible
      await Future.delayed(const Duration(milliseconds: 300));
      
      List<FileItem> audioFiles = await _fetchAudioQueue(currentDir);
      
      if (audioFiles.isEmpty) {
        audioFiles = [widget.item];
      }
      
      ref.read(audioQueueProvider.notifier).state = audioFiles;
      
      final currentPlayingQueue = ref.read(audioPlayingQueueProvider);
      if (currentPlayingQueue.isNotEmpty) {
        final currentPlayingDir = p.dirname(currentPlayingQueue.first.path);
        if (currentPlayingDir == currentDir) {
          ref.read(audioPlayingQueueProvider.notifier).state = audioFiles;
        }
      } else {
        ref.read(audioPlayingQueueProvider.notifier).state = audioFiles;
      }
    } finally {
      ref.read(audioIsReloadingProvider.notifier).state = false;
    }
  }

  void _initializePlayer() async {
    await MediaUriHelper.ensureLocalProxy();
    debugPrint('[AudioPlayer] Initializing for: ${widget.item.path}');

    final currentDir = ref.read(audioCurrentPathProvider);
    List<FileItem> audioFiles = await _fetchAudioQueue(currentDir);

    if (audioFiles.isEmpty) {
      audioFiles = [widget.item];
    }

    final currentIndex = audioFiles.indexWhere(
      (i) => i.path == widget.item.path,
    );
    final startIndex = currentIndex != -1 ? currentIndex : 0;

    // Enable volume boosting up to 200%
    try {
      (_player.platform as dynamic).setProperty('volume-max', '200');
    } catch (e) {
      debugPrint('[AudioPlayer] Could not set volume-max: $e');
    }

    // Push state to providers AFTER the first frame (safe now)
    ref.read(audioQueueProvider.notifier).state = audioFiles;
    ref.read(audioPlayingQueueProvider.notifier).state = audioFiles;
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

    _bitrateSub = _player.stream.audioBitrate.listen((bitrate) {
      if (mounted && _bitrate != bitrate) {
        setState(() => _bitrate = bitrate);
      }
    });

    // Open and play
    final playlist = Playlist(
      audioFiles.map((f) => Media(MediaUriHelper.getSafeMediaUri(f.path))).toList(),
      index: startIndex,
    );

    debugPrint(
      '[AudioPlayer] Opening playlist with ${audioFiles.length} tracks, starting at $startIndex',
    );
    setState(() => _isOpening = true);
    
    // Enforce sequential, non-looping playback through the sorted queue
    _player.setPlaylistMode(PlaylistMode.none);
    _player.setShuffle(false);
    
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

    ref
        .read(audioPathForwardHistoryProvider.notifier)
        .update((state) => [currentPath, ...state]);
    ref.read(audioPathHistoryProvider.notifier).state = newHistory;

    // Load the folder
    _fetchAudioQueue(prevPath).then((audioFiles) {
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

    ref
        .read(audioPathHistoryProvider.notifier)
        .update((state) => [...state, currentPath]);
    ref.read(audioPathForwardHistoryProvider.notifier).state = newForward;

    _fetchAudioQueue(nextPath).then((audioFiles) {
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
    ref
        .read(audioPathHistoryProvider.notifier)
        .update((state) => [...state, currentPath]);
    ref.read(audioPathForwardHistoryProvider.notifier).state = [];

    _fetchAudioQueue(parentPath).then((audioFiles) {
      ref.read(audioCurrentPathProvider.notifier).state = parentPath;
      ref.read(audioQueueProvider.notifier).state = audioFiles;
      ref.read(audioSelectionProvider.notifier).state = {};
      ref.read(audioSelectionAnchorProvider.notifier).state = null;
    });
  }

  @override
  void dispose() {
    // 1. Cancel all stream subscriptions first
    _playlistSub?.cancel();
    _errorSub?.cancel();
    _bufferingSub?.cancel();
    _bitrateSub?.cancel();
    _focusNode.dispose();

    // 2. Clear the provider reference.
    try {
      ref.read(audioPlayerProvider.notifier).state = null;
    } catch (_) {}

    //    global reused instance. This prevents native libmpv deadlocks.
    //    We use pause() instead of stop() or open(Media('')) because completely
    //    unloading the player breaks it for future Playlist loads on Linux due
    //    to a media_kit/libmpv native bug.
    //    We ONLY pause if we are the most recent view (prevents race conditions
    //    when switching between audio files).
    if (_myPlayerViewId == _globalPlayerViewIdCounter) {
      final playerToStop = _player;
      Future(() async {
        try {
          await playerToStop.pause();
          debugPrint('[AudioPlayer] Player paused (simulated unload)');
        } catch (e) {
          debugPrint('[AudioPlayer] Pause error: $e');
        }
      });
    }

    super.dispose();
  }

  Future<void> _handleDelete({required bool permanent, List<String>? paths}) async {
    final settings = ref.read(settingsProvider).value;
    final needConfirm = settings?.confirmDeleteAudio ?? true;
    
    List<String> targetPaths = paths ?? [];
    if (targetPaths.isEmpty) {
      final selection = ref.read(audioSelectionProvider);
      if (selection.isNotEmpty) {
        targetPaths = selection.toList();
      } else {
        final currentTrack = ref.read(currentTrackProvider);
        if (currentTrack == null) return;
        targetPaths = [currentTrack.path];
      }
    }

    bool shouldConfirm = needConfirm;
    if (!permanent && _sessionDontAskTrash) {
      shouldConfirm = false;
    }

    final confirm = shouldConfirm
        ? await showDialog<bool>(
            context: context,
            builder: (context) {
              if (permanent) {
                int size = 0;
                for (final p in targetPaths) {
                  try {
                    size += File(p).lengthSync();
                  } catch (_) {}
                }
                return PermanentDeleteDialog(
                  filesCount: targetPaths.length,
                  foldersCount: 0,
                  totalSize: StringUtils.formatBytes(size),
                );
              } else {
                return ViewerDeleteDialog(
                  fileName: targetPaths.length == 1 ? p.basename(targetPaths.first) : '${targetPaths.length} items',
                  permanent: permanent,
                  onDontAskAgainChanged: (val) {
                    _sessionDontAskTrash = val;
                  },
                );
              }
            },
          )
        : true;

    if (confirm != true) return;

    final currentTrack = ref.read(currentTrackProvider);
    final isPlayingTrackDeleted = currentTrack != null && targetPaths.contains(currentTrack.path);
    final queue = ref.read(audioPlayingQueueProvider);
    final currentIndex = ref.read(activeTrackIndexProvider);
    final hasMultiple = queue.length > 1;

    if (isPlayingTrackDeleted) {
      _player.pause();
    }

    final repo = ref.read(directoryRepositoryProvider);

    final taskId = ref
        .read(taskProvider.notifier)
        .addTask(
          title: permanent
              ? 'Deleting audio permanently'
              : 'Moving audio to Trash',
          subtitle: targetPaths.length == 1 ? p.basename(targetPaths.first) : '${targetPaths.length} items',
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
      
      // If we reach here, deletion succeeded
      // Clear selection to avoid stale references
        ref.read(audioSelectionProvider.notifier).state = {};
        
        // Always update both queues to reflect deletion instantly in the sidebar
        final currentQueue = ref.read(audioQueueProvider);
        final updatedQueue = currentQueue.where((item) => !targetPaths.contains(item.path)).toList();
        ref.read(audioQueueProvider.notifier).state = updatedQueue;

        final currentPlayingQueue = ref.read(audioPlayingQueueProvider);
        final updatedPlayingQueue = currentPlayingQueue.where((item) => !targetPaths.contains(item.path)).toList();
        ref.read(audioPlayingQueueProvider.notifier).state = updatedPlayingQueue;

        if (!widget.isStandalone) {
          ref.read(directoryItemsProvider.notifier).refresh();
        }

        if (isPlayingTrackDeleted) {
          if (updatedPlayingQueue.isNotEmpty) {
            // Safe index for the new queue
            int safeIndex = currentIndex >= updatedPlayingQueue.length ? updatedPlayingQueue.length - 1 : currentIndex;
            if (safeIndex < 0) safeIndex = 0;
            
            ref.read(activeTrackIndexProvider.notifier).state = safeIndex;

            await MediaUriHelper.ensureLocalProxy();
            final list = updatedPlayingQueue.map((item) => Media(MediaUriHelper.getSafeMediaUri(item.path))).toList();
            await _player.open(Playlist(list, index: safeIndex));
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
      ref.read(taskProvider.notifier).completeTask(taskId);
    } catch (e) {
      ref.read(taskProvider.notifier).failTask(taskId, e.toString());
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Deletion failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTrack = ref.watch(currentTrackProvider);
    final settings = ref.watch(settingsProvider).value;
    final seekSeconds = settings?.audioSeekSeconds ?? 5;

    String topBarMetadata = "Audio Player";
    if (currentTrack != null) {
      final queue = ref.watch(filteredAndSortedAudioQueueProvider);
      final total = queue.length;
      final index = queue.indexWhere((i) => i.path == currentTrack.path);
      final positionStr = index != -1 ? '${index + 1} / $total' : '';
      
      final sizeStr = currentTrack.sizeBytes != null 
          ? StringUtils.formatBytes(currentTrack.sizeBytes!) 
          : '';
      
      String bitrateStr = '';
      if (_bitrate != null && _bitrate! > 0) {
        bitrateStr = '${(_bitrate! / 1000).round()} kbps';
      }

      final parts = [sizeStr, bitrateStr, positionStr].where((s) => s.isNotEmpty);
      if (parts.isNotEmpty) {
        topBarMetadata = parts.join(' • ');
      }
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
          return KeyEventResult.ignored;
        }
        final key = event.logicalKey;

        final isAlt = HardwareKeyboard.instance.isAltPressed;
        final isCtrl = HardwareKeyboard.instance.isControlPressed;
        final isShift = HardwareKeyboard.instance.isShiftPressed;

        if ((key == LogicalKeyboardKey.period || key == LogicalKeyboardKey.greater || event.physicalKey == PhysicalKeyboardKey.period) && isCtrl && isShift) {
          if (FocusManager.instance.primaryFocus?.context?.widget is EditableText) {
            return KeyEventResult.ignored;
          }
          final current = ref.read(audioShowHiddenProvider);
          ref.read(audioShowHiddenProvider.notifier).state = !current;
          
          final currentPath = ref.read(audioCurrentPathProvider);
          final repo = ref.read(directoryRepositoryProvider);
          repo.listDirectory(currentPath).then((items) {
            compute(processAudioQueueIsolate, {
              'items': items.map((e) => e.toJson()).toList(),
              'showHidden': !current,
            }).then((files) {
              ref.read(audioQueueProvider.notifier).state = files;
              final currentPlayingQueue = ref.read(audioPlayingQueueProvider);
              if (currentPlayingQueue.isNotEmpty) {
                final currentPlayingDir = p.dirname(currentPlayingQueue.first.path);
                if (currentPlayingDir == currentPath) {
                  ref.read(audioPlayingQueueProvider.notifier).state = files;
                }
              } else {
                ref.read(audioPlayingQueueProvider.notifier).state = files;
              }
            });
          });
          
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.keyA && isCtrl) {
          if (FocusManager.instance.primaryFocus?.context?.widget is EditableText) {
            return KeyEventResult.ignored;
          }
          final queue = ref.read(filteredAndSortedAudioQueueProvider);
          if (queue.isNotEmpty) {
            final allPaths = queue.map((e) => e.path).toSet();
            ref.read(audioSelectionProvider.notifier).state = allPaths;
            ref.read(audioSelectionAnchorProvider.notifier).state = null;
          }
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyR && isCtrl) {
          if (FocusManager.instance.primaryFocus?.context?.widget is EditableText) {
            return KeyEventResult.ignored;
          }
          _handleReload();
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.space) {
          _player.playOrPause();
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowLeft) {
          if (isAlt) {
            _navigateHistoryBack(ref);
          } else {
            _player.seek(
              _player.state.position - Duration(seconds: seekSeconds),
            );
          }
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          if (isAlt) {
            _navigateHistoryForward(ref);
          } else {
            _player.seek(
              _player.state.position + Duration(seconds: seekSeconds),
            );
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
          // Ignore if user is typing in a text field
          if (FocusManager.instance.primaryFocus?.context?.widget
              is EditableText) {
            return KeyEventResult.ignored;
          }
          final currentVolume = _player.state.volume;
          _player.setVolume(currentVolume > 0 ? 0 : 100);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.f2) {
          final selection = ref.read(audioSelectionProvider);
          final current = ref.read(currentTrackProvider);
          final List<String> targetPaths = [];

          if (selection.isNotEmpty) {
            targetPaths.addAll(selection);
          } else if (current != null) {
            targetPaths.add(current.path);
          }

          if (targetPaths.isNotEmpty) {
            AudioTagEditorDialog.show(
              context, 
              targetPaths,
              onRename: (oldPath, newPath) {
                ref.read(directoryCacheProvider).invalidate(p.dirname(oldPath));
                final showHidden = ref.read(audioShowHiddenProvider);
                final isHidden = p.basename(newPath).startsWith('.');

                // Update queue
                final currentQueue = ref.read(audioQueueProvider);
                if (!showHidden && isHidden) {
                  final updatedQueue = currentQueue.where((item) => item.path != oldPath).toList();
                  ref.read(audioQueueProvider.notifier).state = updatedQueue;
                } else {
                  bool found = false;
                  final updatedQueue = currentQueue.map((item) {
                    if (item.path == oldPath) {
                      found = true;
                      return item.copyWith(
                        path: newPath,
                        name: p.basename(newPath),
                      );
                    }
                    return item;
                  }).toList();

                  if (!found && !isHidden) {
                    try {
                      final stat = File(newPath).statSync();
                      updatedQueue.add(FileItem(
                        path: newPath,
                        name: p.basename(newPath),
                        type: FileItemType.audio,
                        modified: stat.modified,
                        sizeBytes: stat.size,
                      ));
                    } catch (_) {}
                  }
                  ref.read(audioQueueProvider.notifier).state = updatedQueue;
                }

                // Update current track if it was playing
                final current = ref.read(currentTrackProvider);
                if (current?.path == oldPath) {
                  final playingQueue = ref.read(audioPlayingQueueProvider);
                  final updatedPlayingQueue = playingQueue.map((item) {
                    if (item.path == oldPath) {
                      return item.copyWith(
                        path: newPath,
                        name: p.basename(newPath),
                      );
                    }
                    return item;
                  }).toList();
                  ref.read(audioPlayingQueueProvider.notifier).state = updatedPlayingQueue;

                  // Update media_kit's playlist manually to prevent FileNotFoundException
                  final player = ref.read(audioPlayerProvider);
                  if (player != null) {
                    final playlist = player.state.playlist;
                    final currentMedias = List<Media>.from(playlist.medias);
                    bool replaced = false;
                    for (int i = 0; i < currentMedias.length; i++) {
                      if (currentMedias[i].uri == oldPath || currentMedias[i].uri == 'file://$oldPath' || currentMedias[i].uri == MediaUriHelper.getSafeMediaUri(oldPath)) {
                        currentMedias[i] = Media(MediaUriHelper.getSafeMediaUri(newPath));
                        replaced = true;
                      }
                    }
                    if (replaced) {
                      // Note: On Linux, a renamed file that is ALREADY playing will continue playing 
                      // because the FD is open, but if we seek or the next item is played, it needs the new path.
                      // media_kit doesn't allow replacing the playlist in-place without restarting playback,
                      // so we update the URI in our queue providers and let the UI handle the rest.
                    }
                  }
                }
                
                // Update selection
                final selection = ref.read(audioSelectionProvider);
                if (selection.contains(oldPath)) {
                  final newSelection = {...selection}..remove(oldPath);
                  if (showHidden || !isHidden) {
                    newSelection.add(newPath);
                  }
                  ref.read(audioSelectionProvider.notifier).state = newSelection;
                }
              },
            );
          }
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.delete) {
          final isShift = HardwareKeyboard.instance.isShiftPressed;
          _handleDelete(permanent: isShift);
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.enter && isAlt) {
          final selection = ref.read(audioSelectionProvider);
          if (selection.length == 1) {
            AudioPropertiesDialog.show(context, selection.first);
          } else if (selection.isEmpty) {
            final current = ref.read(currentTrackProvider);
            if (current != null) {
              AudioPropertiesDialog.show(context, current.path);
            }
          }
          return KeyEventResult.handled;
        }

        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: () {
          _focusNode.requestFocus();
          final selection = ref.read(audioSelectionProvider);
          if (selection.isNotEmpty) {
            ref.read(audioSelectionProvider.notifier).state = {};
            ref.read(audioSelectionAnchorProvider.notifier).state = null;
          }
        },
        behavior: HitTestBehavior.translucent,
        child: Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: Row(
            children: [
              // Left Pane (25%)
              Expanded(
                flex: 1,
                child: PlaylistSidebar(
                  onDelete: (paths) => _handleDelete(permanent: false, paths: paths),
                  onReload: _handleReload,
                ),
              ),

              // Right Pane (75%)
              Expanded(
                flex: 3,
                child: GestureDetector(
                  onDoubleTap: widget.isStandalone
                      ? null
                      : () {
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
                          metadata: topBarMetadata,
                          isStandalone: widget.isStandalone,
                          extraActions: [
                            // Settings button
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.settings_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () {
                                  SettingsDialog.show(
                                    context,
                                    initialTab: 1,
                                    section: 'Audio',
                                  );
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
                                  icon: const Icon(
                                    Icons.edit_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    final existingNames =
                                        ref
                                            .read(directoryItemsProvider)
                                            .value
                                            ?.map((i) => i.name)
                                            .toList() ??
                                        [];
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
                                          final repo = ref.read(
                                            directoryRepositoryProvider,
                                          );
                                          final taskId = ref
                                              .read(taskProvider.notifier)
                                              .addTask(
                                                title: 'Renaming audio file',
                                                subtitle: result,
                                                sourcePaths: [
                                                  currentTrack.path,
                                                ],
                                                isLight: true,
                                              );
                                          try {
                                            await repo.renameItem(
                                              currentTrack.path,
                                              result,
                                              taskId: taskId,
                                              onLog: (msg) => ref
                                                  .read(taskProvider.notifier)
                                                  .addLog(taskId, msg),
                                            );
                                            ref
                                                .read(taskProvider.notifier)
                                                .completeTask(taskId);
                                            ref
                                                .read(
                                                  directoryItemsProvider
                                                      .notifier,
                                                )
                                                .refresh();
                                          } catch (e) {
                                            ref
                                                .read(taskProvider.notifier)
                                                .failTask(taskId, e.toString());
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
                              WindowController.fromCurrentEngine().then(
                                (c) => c.close(),
                              );
                            } else {
                              ref.read(previewFileProvider.notifier).state =
                                  null;
                            }
                          },
                          onPopOut: widget.isStandalone
                              ? null
                              : () {
                                  final params = WindowParams(
                                    viewerType: ViewerType.audio,
                                    file: widget.item,
                                  );
                                  PersistentViewerManager.openMedia(
                                    params,
                                  ).then((_) {
                                    ref
                                            .read(previewFileProvider.notifier)
                                            .state =
                                        null;
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
