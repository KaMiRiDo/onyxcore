import 'dart:io';

import 'package:audiotags/audiotags.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/core/playlist/playlist_providers.dart';
import 'package:onyxcore/core/playlist/playlist_sidebar_base.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/utils/media_uri_helper.dart';
import 'package:onyxcore/features/audio_player/presentation/providers/audio_player_providers.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/dialogs/audio_properties_dialog.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/dialogs/audio_tag_editor_dialog.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/playing_eq_animation.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/context_menu.dart';
import 'package:path/path.dart' as p;

class PlaylistSidebar extends PlaylistSidebarBase {
  const PlaylistSidebar({super.key, super.onDelete, super.onMove, super.onReload});

  @override
  ConsumerState<PlaylistSidebar> createState() => _PlaylistSidebarState();
}

class _PlaylistSidebarState extends PlaylistSidebarBaseState<PlaylistSidebar> {
  // ── Configuration ──────────────────────────────────────────────────────────

  @override
  PlaylistProviderConfig get config => audioPlaylistProviderConfig;

  @override
  FileItemType get targetMediaType => FileItemType.audio;

  @override
  String get emptyStateText => 'No audio files found';

  @override
  String get favoritesEmptyStateText => 'No favorite files in this folder';

  @override
  IconData get defaultMediaIcon => Icons.music_note_rounded;

  // ── Reload ─────────────────────────────────────────────────────────────────

  @override
  void onReloadTap() {
    if (widget.onReload != null) {
      widget.onReload!();
    } else {
      refreshQueue();
    }
  }

  // ── Context Menu ───────────────────────────────────────────────────────────

  @override
  List<ContextMenuItem> buildContextMenuItems(
    BuildContext context,
    FileItem item,
    List<String> selection,
  ) {
    final isMultiple = selection.length > 1;

    return [
      ContextMenuItem(
        title: 'Move to Trash',
        icon: Icons.delete_outline_rounded,
        isDestructive: true,
        shortcut: 'Del',
        onTap: () {
          if (widget.onDelete != null) {
            widget.onDelete!(selection);
          } else {
            ref.read(directoryRepositoryProvider).moveToTrash(selection);
          }
          ref.read(audioSelectionProvider.notifier).state = {};
        },
      ),
      ContextMenuItem.divider(),
      ContextMenuItem(
        title: selection.length > 1 ? 'Copy Items' : 'Copy Item',
        icon: Icons.content_copy_rounded,
        onTap: () {
          handleMoveOrCopy(context, selection, false);
          ref.read(audioSelectionProvider.notifier).state = {};
        },
      ),
      ContextMenuItem(
        title: selection.length > 1 ? 'Move Items' : 'Move Item',
        icon: Icons.drive_file_move_outline,
        onTap: () {
          handleMoveOrCopy(context, selection, true);
          ref.read(audioSelectionProvider.notifier).state = {};
        },
      ),
      if (item.type == FileItemType.audio || isMultiple) ...[
        ContextMenuItem.divider(),
        ContextMenuItem(
          title: 'Edit Tags',
          icon: Icons.edit_note_rounded,
          shortcut: 'F2',
          onTap: () {
            AudioTagEditorDialog.show(
              context,
              selection,
              onRename: (oldPath, newPath) {
                ref
                    .read(directoryCacheProvider)
                    .invalidate(p.dirname(oldPath));
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
                  final updatedQueue = currentQueue.map((queueItem) {
                    if (queueItem.path == oldPath) {
                      found = true;
                      return queueItem.copyWith(
                        path: newPath,
                        name: p.basename(newPath),
                      );
                    }
                    return queueItem;
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
                }

                // Update selection
                final currentSelection = ref.read(audioSelectionProvider);
                if (currentSelection.contains(oldPath)) {
                  final newSelection = {...currentSelection}..remove(oldPath);
                  if (showHidden || !isHidden) {
                    newSelection.add(newPath);
                  }
                  ref.read(audioSelectionProvider.notifier).state =
                      newSelection;
                }
              },
            );
          },
        ),
        if (!isMultiple)
          ContextMenuItem(
            title: 'Properties',
            icon: Icons.info_outline_rounded,
            shortcut: 'Alt+Enter',
            onTap: () {
              AudioPropertiesDialog.show(context, item.path);
            },
          ),
      ],
    ];
  }

  // ── Double Tap (Play Audio) ────────────────────────────────────────────────

  @override
  void onItemDoubleTap(FileItem item, int realIndex, List<FileItem> queue) {
    if (ref.read(audioIsEmptyProvider)) {
      ref.read(audioRestartSignalProvider.notifier).state++;
    }
    final player = ref.read(audioPlayerProvider);
    final playingQueue = ref.read(audioPlayingQueueProvider);

    if (queue != playingQueue) {
      // Browsing a different folder than playing, so load new playlist
      ref.read(audioPlayingQueueProvider.notifier).state = queue;
      final playlist = Playlist(
        queue
            .map(
              (f) => Media(
                MediaUriHelper.getSafeMediaUri(f.path),
              ),
            )
            .toList(),
        index: realIndex,
      );
      ref.read(activeTrackIndexProvider.notifier).state = realIndex;
      player?.open(playlist);
    } else {
      ref.read(activeTrackIndexProvider.notifier).state = realIndex;
      player?.jump(realIndex);
    }
  }

  // ── Tile Customization ─────────────────────────────────────────────────────

  @override
  String buildSubtitle(FileItem item) {
    if (item.type == FileItemType.folder) {
      return item.itemCount != null
          ? "${item.itemCount} Audio File${item.itemCount == 1 ? '' : 's'}"
          : 'Folder';
    }

    // Read audio tags for subtitle
    String? artistText;
    String? albumText;
    Tag? tag;

    final overrideTag = ref.read(audioTagsOverridesProvider(item.path));
    if (overrideTag != null) {
      tag = overrideTag;
    } else {
      final tagAsync = ref.read(audioTagsProvider(item.path));
      if (tagAsync.hasValue && tagAsync.value != null) {
        tag = tagAsync.value;
      }
    }

    if (tag != null) {
      if (tag.trackArtist != null && tag.trackArtist!.isNotEmpty) {
        artistText = tag.trackArtist;
      }
      if (tag.album != null && tag.album!.isNotEmpty) {
        albumText = tag.album;
      }
    }

    String subtitle;
    if (artistText != null && albumText != null) {
      subtitle = '$artistText | $albumText';
    } else if (artistText != null) {
      subtitle = artistText;
    } else if (albumText != null) {
      subtitle = albumText;
    } else {
      subtitle = 'Audio File';
    }

    if (item.sizeBytes != null && item.sizeBytes! > 0) {
      final sizeMB = (item.sizeBytes! / (1024 * 1024)).toStringAsFixed(1);
      subtitle += ' • $sizeMB MB';
    }
    return subtitle;
  }

  @override
  Widget? buildCoverArt(WidgetRef ref, FileItem item) {
    if (item.type == FileItemType.folder) return null;

    Tag? tag;
    final overrideTag = ref.watch(audioTagsOverridesProvider(item.path));
    if (overrideTag != null) {
      tag = overrideTag;
    } else {
      final tagAsync = ref.watch(audioTagsProvider(item.path));
      if (tagAsync.hasValue && tagAsync.value != null) {
        tag = tagAsync.value;
      }
    }

    if (tag != null && tag.pictures.isNotEmpty) {
      final pic = tag.pictures.first;
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.memory(
            Uint8List.fromList(pic.bytes),
            fit: BoxFit.cover,
            cacheWidth: 100,
            cacheHeight: 100,
            gaplessPlayback: true,
          ),
          // Overlay icon on top of image
          _buildImageOverlayIcon(),
        ],
      );
    }
    return null;
  }

  Widget _buildImageOverlayIcon() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: Colors.black.withValues(alpha: 0.5),
        ),
        Center(
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [AppColors.magenta, AppColors.violet],
            ).createShader(bounds),
            child: const Icon(
              Icons.music_note_rounded,
              size: 24,
              color: Colors.white,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.15),
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.4),
              ],
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget? buildActiveIndicator(bool isPlaying) {
    return isPlaying
        ? const PlayingEqAnimation()
        : const Icon(
            Icons.pause_rounded,
            color: AppColors.magenta,
            size: 16,
          );
  }

  @override
  bool isItemActive(WidgetRef ref, FileItem item) {
    if (ref.watch(audioIsEmptyProvider)) return false;
    final currentPlayingTrack = ref.watch(currentTrackProvider);
    if (currentPlayingTrack == null) return false;

    if (item.type == FileItemType.folder) {
      // Check if the playing track is inside this folder (or any subfolder)
      return currentPlayingTrack.path.startsWith('${item.path}/');
    } else {
      // Check if this exact file is the playing track
      return item.path == currentPlayingTrack.path;
    }
  }

  @override
  bool get isCurrentlyPlaying =>
      ref.watch(audioPlayingProvider).value ?? false;

  // ── Bottom Nav ─────────────────────────────────────────────────────────────

  @override
  void onHomeNavTap() {
    ref.read(audioViewModeProvider.notifier).state = AudioViewMode.home;
  }

  @override
  void onFavoritesNavTap() {
    ref.read(audioViewModeProvider.notifier).state = AudioViewMode.favorites;
  }
}
