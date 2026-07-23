import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/core/playlist/media_queue_isolate.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/utils/media_uri_helper.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
// import removed
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/core/widgets/viewer_top_bar.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/audio_player/domain/utils/audio_queue_isolate.dart';
import 'package:onyxcore/features/audio_player/presentation/providers/audio_player_providers.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/dialogs/audio_properties_dialog.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/dialogs/audio_tag_editor_dialog.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/hero_audio_player.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/playlist_sidebar.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/dialogs.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/settings/presentation/widgets/settings_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

class AudioPlayerView extends ConsumerStatefulWidget {

  const AudioPlayerView({
    required this.item,
    this.isStandalone = false,
    this.windowId,
    this.parentWindowId,
    this.initParams,
    super.key,
  });
  final FileItem item;
  final bool isStandalone;
  final String? windowId;
  final String? parentWindowId;
  final Map<String, dynamic>? initParams;

  @override
  ConsumerState<AudioPlayerView> createState() => _AudioPlayerViewState();
}

class _AudioPlayerViewState extends ConsumerState<AudioPlayerView> {
  static int _globalPlayerViewIdCounter = 0;
  int _myPlayerViewId = 0;

  final FocusNode _focusNode = FocusNode();
  late final Player _player;
  StreamSubscription<dynamic>? _playlistSub;
  StreamSubscription<dynamic>? _completedSub;
  StreamSubscription<dynamic>? _errorSub;
  StreamSubscription<dynamic>? _bufferingSub;
  StreamSubscription<dynamic>? _bitrateSub;
  bool _isOpening = false;
  bool _isBuffering = false;
  double? _bitrate;
  bool _sessionSkipConfirm = false;
  bool _isEmpty = false;

  void _onWindowFocus() {
    if (mounted) _focusNode.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    if (widget.isStandalone && widget.windowId != null) {
      PersistentViewerManager.getFocusTrigger(int.parse(widget.windowId!)).addListener(_onWindowFocus);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioIsEmptyProvider.notifier).state = false;
    });

    _globalPlayerViewIdCounter++;
    _myPlayerViewId = _globalPlayerViewIdCounter;

    // Use the global, reused Player instance to avoid native deadlocks
    _player = globalAudioPlayer;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.mounted) return;

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

    // On Linux/GTK, newly spawned windows may take a moment to be mapped by the OS.
    // A delayed focus request ensures the widget grabs focus after the window is fully active.
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (mounted) {
        if (widget.isStandalone && widget.windowId != null) {
          await PersistentViewerManager.presentWindow(int.parse(widget.windowId!));
        }
        if (mounted) _focusNode.requestFocus();
      }
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

    return compute(processAudioQueueIsolate, {
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

      var audioFiles = await _fetchAudioQueue(currentDir);

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

  Future<void> _initializePlayer() async {
    await MediaUriHelper.ensureLocalProxy();
    debugPrint('[AudioPlayer] Initializing for: ${widget.item.path}');

    final currentDir = ref.read(audioCurrentPathProvider);
    var audioFiles = await _fetchAudioQueue(currentDir);

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

    final settings = ref.read(settingsProvider).value;
    if (settings != null) {
      _player.setVolume(settings.audioPlayerVolume);
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

    _completedSub = _player.stream.completed.listen((completed) {
      if (completed && mounted) {
        final autoPlay = ref.read(audioAutoPlaySessionProvider);
        if (!autoPlay) {
          _player.pause();
        }
      }
    });

    // Open and play
    final playlist = Playlist(
      audioFiles
          .map((f) => Media(MediaUriHelper.getSafeMediaUri(f.path)))
          .toList(),
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



  @override
  void dispose() {
    if (widget.isStandalone && widget.windowId != null) {
      PersistentViewerManager.getFocusTrigger(int.parse(widget.windowId!)).removeListener(_onWindowFocus);
    }
    _focusNode.dispose();
    // 1. Cancel all stream subscriptions first
    _playlistSub?.cancel();
    _completedSub?.cancel();
    _errorSub?.cancel();
    _bufferingSub?.cancel();
    _bitrateSub?.cancel();
    try {
      final emptyNotifier = ref.read(audioIsEmptyProvider.notifier);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        emptyNotifier.state = false;
      });
    } catch (_) {}

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

  Future<void> _handleDelete({
    required bool permanent,
    List<String>? paths,
  }) async {
    final settings = ref.read(settingsProvider).value;
    final needConfirm = settings?.confirmDeleteAudio ?? true;

    var targetPaths = paths ?? [];
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

    var shouldConfirm = needConfirm;
    if (_sessionSkipConfirm) {
      shouldConfirm = false;
    }

    final confirm = shouldConfirm
        ? await showDialog<bool>(
            context: context,
            builder: (context) {
              if (permanent) {
                var size = 0;
                for (final p in targetPaths) {
                  try {
                    size += File(p).lengthSync();
                  } catch (_) {}
                }
                return PermanentDeleteDialog(
                  filesCount: targetPaths.length,
                  foldersCount: 0,
                  totalSize: StringUtils.formatBytes(size),
                  onDontAskAgainChanged: (val) {
                    _sessionSkipConfirm = val;
                  },
                );
              } else {
                return ViewerDeleteDialog(
                  fileName: targetPaths.length == 1
                      ? p.basename(targetPaths.first)
                      : '${targetPaths.length} items',
                  permanent: permanent,
                  onDontAskAgainChanged: (val) {
                    _sessionSkipConfirm = val;
                  },
                );
              }
            },
          )
        : true;

    if (confirm != true) return;

    // Allow the delete dialog's closing animation to finish smoothly
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final currentTrack = ref.read(currentTrackProvider);
    final isPlayingTrackDeleted =
        currentTrack != null && targetPaths.contains(currentTrack.path);
    final currentIndex = ref.read(activeTrackIndexProvider);
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

      // If we reach here, deletion succeeded
      // Clear selection to avoid stale references
      ref.read(audioSelectionProvider.notifier).state = {};

      // Always update both queues to reflect deletion instantly in the sidebar
      final currentQueue = ref.read(audioQueueProvider);
      final updatedQueue = currentQueue
          .where((item) => !targetPaths.contains(item.path))
          .toList();
      ref.read(audioQueueProvider.notifier).state = updatedQueue;

      final currentPlayingQueue = ref.read(audioPlayingQueueProvider);
      final updatedPlayingQueue = currentPlayingQueue
          .where((item) => !targetPaths.contains(item.path))
          .toList();
      ref.read(audioPlayingQueueProvider.notifier).state = updatedPlayingQueue;

      if (!widget.isStandalone) {
        ref.read(directoryItemsProvider.notifier).refresh();
      }

      if (isPlayingTrackDeleted) {
        if (updatedPlayingQueue.isNotEmpty) {
          // Safe index for the new queue
          var safeIndex = currentIndex >= updatedPlayingQueue.length
              ? updatedPlayingQueue.length - 1
              : currentIndex;
          if (safeIndex < 0) safeIndex = 0;

          ref.read(activeTrackIndexProvider.notifier).state = safeIndex;

          await MediaUriHelper.ensureLocalProxy();
          final list = updatedPlayingQueue
              .map((item) => Media(MediaUriHelper.getSafeMediaUri(item.path)))
              .toList();
          
          final autoPlay = ref.read(audioAutoPlaySessionProvider);
          await _player.open(Playlist(list, index: safeIndex), play: autoPlay);
        } else {
          setState(() => _isEmpty = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.read(audioIsEmptyProvider.notifier).state = true;
          });
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

  Future<void> _handleItemsMoved(List<String> paths) async {
    // 1. Update global queues unconditionally so UI reflects the move
    final currentQueue = ref.read(audioQueueProvider);
    final updatedQueue = currentQueue
        .where((item) => !paths.contains(item.path))
        .toList();
    ref.read(audioQueueProvider.notifier).state = updatedQueue;

    final currentPlayingQueue = ref.read(audioPlayingQueueProvider);
    final currentIndex = ref.read(activeTrackIndexProvider);
    final isPlayingTrackMoved = currentIndex >= 0 &&
        currentIndex < currentPlayingQueue.length &&
        paths.contains(currentPlayingQueue[currentIndex].path);

    final updatedPlayingQueue = currentPlayingQueue
        .where((item) => !paths.contains(item.path))
        .toList();
    ref.read(audioPlayingQueueProvider.notifier).state = updatedPlayingQueue;

    if (!widget.isStandalone) {
      ref.read(directoryItemsProvider.notifier).refresh();
    }

    // 2. Handle player state if the currently playing track was moved
    if (isPlayingTrackMoved) {
      await _player.pause();
      
      if (updatedPlayingQueue.isNotEmpty) {
        var safeIndex = currentIndex >= updatedPlayingQueue.length
            ? updatedPlayingQueue.length - 1
            : currentIndex;
        if (safeIndex < 0) safeIndex = 0;

        ref.read(activeTrackIndexProvider.notifier).state = safeIndex;

        await MediaUriHelper.ensureLocalProxy();
        final list = updatedPlayingQueue
            .map((item) => Media(MediaUriHelper.getSafeMediaUri(item.path)))
            .toList();
        
        final autoPlay = ref.read(audioAutoPlaySessionProvider);
        await _player.open(Playlist(list, index: safeIndex), play: autoPlay);
        if (autoPlay) {
          await _player.play();
        }
      } else {
        _player.pause();
        setState(() => _isEmpty = true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(audioIsEmptyProvider.notifier).state = true;
        });
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(audioRestartSignalProvider, (previous, next) {
      if (_isEmpty) {
        setState(() => _isEmpty = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(audioIsEmptyProvider.notifier).state = false;
        });
        final currentPlayingQueue = ref.read(audioPlayingQueueProvider);
        final currentIndex = ref.read(activeTrackIndexProvider);
        if (currentPlayingQueue.isNotEmpty && currentIndex < currentPlayingQueue.length) {
          final playlist = Playlist(
            currentPlayingQueue.map((f) => Media(MediaUriHelper.getSafeMediaUri(f.path))).toList(),
            index: currentIndex,
          );
          _player.open(playlist);
        }
      }
    });

    final currentTrack = ref.watch(currentTrackProvider);
    final settings = ref.watch(settingsProvider).value;
    final seekSeconds = settings?.audioSeekSeconds ?? 5;

    final screenWidth = MediaQuery.of(context).size.width;
    const minWidth = 240.0;
    final maxWidth = screenWidth * 0.40;

    final savedWidth = ref.watch(audioPlaylistSidebarWidthProvider);
    var panelWidth = savedWidth ?? (screenWidth * 0.25);
    panelWidth = panelWidth.clamp(minWidth, maxWidth);

    var topBarMetadata = 'Audio Player';
    if (currentTrack != null) {
      final queue = ref.watch(filteredAndSortedAudioQueueProvider).where((i) => i.type == FileItemType.audio).toList();
      final total = queue.length;
      final index = queue.indexWhere((i) => i.path == currentTrack.path);
      final positionStr = index != -1 ? '${index + 1} / $total' : '';

      final sizeStr = currentTrack.sizeBytes != null
          ? StringUtils.formatBytes(currentTrack.sizeBytes!)
          : '';

      var bitrateStr = '';
      if (_bitrate != null && _bitrate! > 0) {
        bitrateStr = '${(_bitrate! / 1000).round()} kbps';
      }

      final parts = [
        sizeStr,
        bitrateStr,
        positionStr,
      ].where((s) => s.isNotEmpty);
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

        if ((key == LogicalKeyboardKey.keyP ||
                event.physicalKey == PhysicalKeyboardKey.keyP) &&
            isCtrl &&
            isShift) {
          if (FocusManager.instance.primaryFocus?.context?.widget
              is EditableText) {
            return KeyEventResult.ignored;
          }
          final isVisible = ref.read(audioPlaylistSidebarVisibleProvider);
          ref.read(audioPlaylistSidebarVisibleProvider.notifier).state =
              !isVisible;
          return KeyEventResult.handled;
        }

        if ((key == LogicalKeyboardKey.period ||
                key == LogicalKeyboardKey.greater ||
                event.physicalKey == PhysicalKeyboardKey.period) &&
            isCtrl &&
            isShift) {
          if (FocusManager.instance.primaryFocus?.context?.widget
              is EditableText) {
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
                final currentPlayingDir = p.dirname(
                  currentPlayingQueue.first.path,
                );
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
          if (FocusManager.instance.primaryFocus?.context?.widget
              is EditableText) {
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
          if (FocusManager.instance.primaryFocus?.context?.widget
              is EditableText) {
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
            final isSidebarOpen = ref.read(audioPlaylistSidebarVisibleProvider);
            if (isSidebarOpen) {
              _navigateHistoryBack(ref);
            }
          } else {
            _player.seek(
              _player.state.position - Duration(seconds: seekSeconds),
            );
          }
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowRight) {
          if (isAlt) {
            final isSidebarOpen = ref.read(audioPlaylistSidebarVisibleProvider);
            if (isSidebarOpen) {
              _navigateHistoryForward(ref);
            }
          } else {
            _player.seek(
              _player.state.position + Duration(seconds: seekSeconds),
            );
          }
          return KeyEventResult.handled;
        }

        if (key == LogicalKeyboardKey.arrowUp) {
          final newVol = (_player.state.volume + 5).clamp(0, 200).toDouble();
          _player.setVolume(newVol);
          ref.read(settingsProvider.notifier).saveSettings(
            ref.read(settingsProvider).value!.copyWith(audioPlayerVolume: newVol),
          );
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.arrowDown) {
          final newVol = (_player.state.volume - 5).clamp(0, 200).toDouble();
          _player.setVolume(newVol);
          ref.read(settingsProvider.notifier).saveSettings(
            ref.read(settingsProvider).value!.copyWith(audioPlayerVolume: newVol),
          );
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.keyM) {
          // Ignore if user is typing in a text field
          if (FocusManager.instance.primaryFocus?.context?.widget
              is EditableText) {
            return KeyEventResult.ignored;
          }
          final currentVolume = _player.state.volume;
          final newVol = currentVolume > 0 ? 0.0 : 100.0;
          _player.setVolume(newVol);
          ref.read(settingsProvider.notifier).saveSettings(
            ref.read(settingsProvider).value!.copyWith(audioPlayerVolume: newVol),
          );
          return KeyEventResult.handled;
        }
        if (key == LogicalKeyboardKey.f2) {
          final selection = ref.read(audioSelectionProvider);
          final current = ref.read(currentTrackProvider);
          final targetPaths = <String>[];

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
                  final updatedQueue = currentQueue
                      .where((item) => item.path != oldPath)
                      .toList();
                  ref.read(audioQueueProvider.notifier).state = updatedQueue;
                } else {
                  var found = false;
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
                      updatedQueue.add(
                        FileItem(
                          path: newPath,
                          name: p.basename(newPath),
                          type: FileItemType.audio,
                          modified: stat.modified,
                          sizeBytes: stat.size,
                        ),
                      );
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
                  ref.read(audioPlayingQueueProvider.notifier).state =
                      updatedPlayingQueue;

                  // Update media_kit's playlist manually to prevent FileNotFoundException
                  final player = ref.read(audioPlayerProvider);
                  if (player != null) {
                    final playlist = player.state.playlist;
                    final currentMedias = List<Media>.from(playlist.medias);
                    var replaced = false;
                    for (var i = 0; i < currentMedias.length; i++) {
                      if (currentMedias[i].uri == oldPath ||
                          currentMedias[i].uri == 'file://$oldPath' ||
                          currentMedias[i].uri ==
                              MediaUriHelper.getSafeMediaUri(oldPath)) {
                        currentMedias[i] = Media(
                          MediaUriHelper.getSafeMediaUri(newPath),
                        );
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
                  ref.read(audioSelectionProvider.notifier).state =
                      newSelection;
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
          if (!mounted || !context.mounted) return;
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
          body: MouseRegion(
            cursor: ref.watch(isAudioPlaylistSidebarDraggingProvider)
                ? SystemMouseCursors.resizeColumn
                : MouseCursor.defer,
            child: Row(
              children: [
                // Left Pane
                if (ref.watch(audioPlaylistSidebarVisibleProvider))
                  SizedBox(
                    width: panelWidth,
                    child: Stack(
                      children: [
                        PlaylistSidebar(
                          onDelete: (paths) =>
                              _handleDelete(permanent: false, paths: paths),
                          onMove: _handleItemsMoved,
                          onReload: _handleReload,
                        ),
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width: 8,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.resizeColumn,
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onPanStart: (_) {
                                if (!mounted || !context.mounted) return;
                                ref
                                        .read(
                                          isAudioPlaylistSidebarDraggingProvider
                                              .notifier,
                                        )
                                        .state =
                                    true;
                              },
                              onPanUpdate: (details) {
                                if (!mounted || !context.mounted) return;
                                var newWidth = details.globalPosition.dx;
                                newWidth = newWidth.clamp(minWidth, maxWidth);
                                ref
                                        .read(
                                          audioPlaylistSidebarWidthProvider
                                              .notifier,
                                        )
                                        .state =
                                    newWidth;
                              },
                              onPanEnd: (_) {
                                try {
                                  ref
                                          .read(
                                            isAudioPlaylistSidebarDraggingProvider
                                                .notifier,
                                          )
                                          .state =
                                      false;
                                } catch (_) {}
                              },
                              onPanCancel: () {
                                try {
                                  ref
                                          .read(
                                            isAudioPlaylistSidebarDraggingProvider
                                                .notifier,
                                          )
                                          .state =
                                      false;
                                } catch (_) {}
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Right Pane (Takes remaining space)
                Expanded(
                  child: _isEmpty
                      ? _buildEmptyState()
                      : GestureDetector(
                          onDoubleTap: widget.isStandalone
                              ? null
                              : () {
                                  final params = WindowParams(
                                    viewerType: ViewerType.audio,
                                    file: currentTrack ?? widget.item,
                                  );
                                  PersistentViewerManager.openMedia(params).then((_) {
                                    ref.read(previewFileProvider.notifier).state =
                                        null;
                                  });
                                },
                          behavior: HitTestBehavior.translucent,
                          child: Stack(
                            children: [
                        HeroAudioPlayer(
                          isAudioPlayOnly: widget.initParams?['is_audio_play_only'] == true,
                          onNextPressed: () {
                            final currentPlayingQueue =
                                ref.read(audioPlayingQueueProvider);
                            final currentIndex =
                                ref.read(activeTrackIndexProvider);
                            if (currentIndex >=
                                currentPlayingQueue.length - 1) {
                              _player.pause();
                              setState(() => _isEmpty = true);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                ref.read(audioIsEmptyProvider.notifier).state = true;
                              });
                            } else {
                              _player.next();
                            }
                          },
                          onPreviousPressed: () {
                            final currentIndex = ref.read(activeTrackIndexProvider);
                            if (currentIndex == 0) {
                              _player.pause();
                              setState(() => _isEmpty = true);
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                ref.read(audioIsEmptyProvider.notifier).state = true;
                              });
                            } else {
                              _player.previous();
                            }
                          },
                        ),

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
                                  color: Colors.white.withValues(alpha: 0.1),
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
                                    color: Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.edit_rounded,
                                      color: Colors.white.withValues(alpha: 0.3),
                                      size: 20,
                                    ),
                                    onPressed: null, // Placeholder — disabled
                                    tooltip: 'Edit (coming soon)',
                                    splashRadius: 24,
                                  ),
                                ),
                              const SizedBox(width: 8),
                            ],
                            onClose: () {
                              if (widget.isStandalone) {
                                windowManager.close();
                              } else {
                                ref.read(previewFileProvider.notifier).state =
                                    null;
                              }
                            },
                            onPopOut: widget.isStandalone
                                ? null
                                : () {
                                    ref
                                            .read(
                                              previewFileProvider.notifier,
                                            )
                                            .state =
                                        null;
                                    final params = WindowParams(
                                      viewerType: ViewerType.audio,
                                      file: currentTrack ?? widget.item,
                                    );
                                    PersistentViewerManager.openMedia(
                                      params,
                                    );
                                  },
                          ),
                        ),
                        Positioned.fill(
                          child: Center(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: (_isOpening || _isBuffering) ? 1.0 : 0.0,
                              child: const BubbleLoader(),
                            ),
                          ),
                        ),
                        // Sidebar Toggle Button at bottom left
                        if (widget.initParams?['is_audio_play_only'] != true)
                          Positioned(
                            bottom: 24,
                            left: 24,
                            child: IconButton(
                              icon: const Icon(
                                Icons.playlist_play,
                                size: 24,
                              ),
                              color: ref.watch(audioPlaylistSidebarVisibleProvider) ? AppColors.magenta : Colors.white,
                              onPressed: () {
                                final isVisible = ref.read(
                                  audioPlaylistSidebarVisibleProvider,
                                );
                                ref
                                    .read(audioPlaylistSidebarVisibleProvider.notifier)
                                    .state = !isVisible;
                              },
                              tooltip: 'Playlist',
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
      ),
    );
  }

  Widget _buildEmptyState() {
    return ColoredBox(
      color: const Color(0xFF121212),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.music_off_rounded,
              size: 64,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            const Text(
              'No audio files to play next.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateHistoryBack(WidgetRef ref) {
    final history = ref.read(audioPathHistoryProvider);
    if (history.isNotEmpty) {
      final newPath = history.last;
      final currentPath = ref.read(audioCurrentPathProvider);

      ref.read(audioPathHistoryProvider.notifier).state =
          history.sublist(0, history.length - 1);
      ref.read(audioPathForwardHistoryProvider.notifier).update(
            (state) => [...state, currentPath],
          );

      _openPlaylistFolder(ref, newPath);
    }
  }

  void _navigateHistoryForward(WidgetRef ref) {
    final forwardHistory = ref.read(audioPathForwardHistoryProvider);
    if (forwardHistory.isNotEmpty) {
      final newPath = forwardHistory.last;
      final currentPath = ref.read(audioCurrentPathProvider);

      ref.read(audioPathForwardHistoryProvider.notifier).state =
          forwardHistory.sublist(0, forwardHistory.length - 1);
      ref.read(audioPathHistoryProvider.notifier).update(
            (state) => [...state, currentPath],
          );

      _openPlaylistFolder(ref, newPath);
    }
  }

  Future<void> _openPlaylistFolder(WidgetRef ref, String path) async {
    final repo = ref.read(directoryRepositoryProvider);
    final showHidden = ref.read(audioShowHiddenProvider);
    try {
      final items = await repo.listDirectory(path);
      final mediaFiles = await compute(processMediaQueueIsolate, {
        'items': items.map((e) => e.toJson()).toList(),
        'showHidden': showHidden,
        'targetType': FileItemType.audio.index,
      });
      ref.read(audioCurrentPathProvider.notifier).state = path;
      ref.read(audioQueueProvider.notifier).state = mediaFiles;
      ref.read(audioSelectionProvider.notifier).state = {};
      ref.read(audioSelectionAnchorProvider.notifier).state = null;
    } catch (e) {
      debugPrint('Error opening folder: $e');
    }
  }
}
