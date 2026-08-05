import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/playlist/playlist_providers.dart';
import 'package:onyxcore/core/playlist/playlist_sidebar_base.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/context_menu.dart';
import 'package:onyxcore/features/video_player/presentation/providers/video_playlist_providers.dart';

class VideoPlaylistSidebar extends PlaylistSidebarBase {
  const VideoPlaylistSidebar({
    super.key,
    super.onDelete,
    super.onMove,
    super.onReload,
    super.isNetworkStream = false,
    this.onVideoSelected,
  });

  final void Function(FileItem)? onVideoSelected;

  @override
  ConsumerState<VideoPlaylistSidebar> createState() =>
      _VideoPlaylistSidebarState();
}

class _VideoPlaylistSidebarState
    extends PlaylistSidebarBaseState<VideoPlaylistSidebar> {
  // ── Configuration ──────────────────────────────────────────────────────────

  @override
  PlaylistProviderConfig get config => videoPlaylistProviderConfig;

  @override
  FileItemType get targetMediaType => FileItemType.video;

  @override
  String get emptyStateText => 'No video files found';

  @override
  String get favoritesEmptyStateText => 'No favorite files in this folder';

  @override
  IconData get defaultMediaIcon => Icons.play_arrow_rounded;

  @override
  double get defaultMediaIconSize => 32;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      refreshQueue();
    });
  }

  @override
  void buildListeners() {
    ref.listen(videoCurrentPathProvider, (previous, next) {
      if (previous != next && next.isNotEmpty) {
        setupWatcher();
        refreshQueue();
      }
    });
  }

  // ── Context Menu ───────────────────────────────────────────────────────────

  @override
  List<ContextMenuItem> buildContextMenuItems(
    BuildContext context,
    FileItem item,
    List<String> selection,
  ) {
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
          ref.read(videoSelectionProvider.notifier).state = {};
        },
      ),
      ContextMenuItem.divider(),
      ContextMenuItem(
        title: selection.length > 1 ? 'Copy Items' : 'Copy Item',
        icon: Icons.content_copy_rounded,
        onTap: () {
          handleMoveOrCopy(context, selection, false);
          ref.read(videoSelectionProvider.notifier).state = {};
        },
      ),
      ContextMenuItem(
        title: selection.length > 1 ? 'Move Items' : 'Move Item',
        icon: Icons.drive_file_move_outline,
        onTap: () {
          handleMoveOrCopy(context, selection, true);
          ref.read(videoSelectionProvider.notifier).state = {};
        },
      ),
      ContextMenuItem(
        title: selection.length > 1 ? 'Rename Items' : 'Rename Item',
        icon: Icons.edit_rounded,
        shortcut: 'F2',
        onTap: () {
          handleRename(context, selection);
        },
      ),
    ];
  }

  // ── Double Tap (Select Video) ──────────────────────────────────────────────

  @override
  void onItemDoubleTap(FileItem item, int realIndex, List<FileItem> queue) {
    if (ref.read(videoIsEmptyProvider)) {
      ref.read(videoRestartSignalProvider.notifier).state++;
    }
    if (widget.onVideoSelected != null) {
      widget.onVideoSelected!(item);
    }
  }

  // ── Tile Customization ─────────────────────────────────────────────────────

  @override
  void watchActiveItemDependencies() {
    ref.watch(videoIsEmptyProvider);
    ref.watch(previewFileProvider);
  }

  @override
  String buildSubtitle(FileItem item) {
    if (item.type == FileItemType.folder) {
      return item.itemCount != null
          ? "${item.itemCount} Video File${item.itemCount == 1 ? '' : 's'}"
          : 'Folder';
    }

    var subtitle = 'Video File';
    if (item.sizeBytes != null && item.sizeBytes! > 0) {
      final sizeMB = (item.sizeBytes! / (1024 * 1024)).toStringAsFixed(1);
      subtitle += ' • $sizeMB MB';
    }
    return subtitle;
  }

  @override
  Widget? buildCoverArt(WidgetRef ref, FileItem item) => null;

  @override
  Widget? buildActiveIndicator(bool isPlaying) {
    return isPlaying
        ? const Icon(Icons.play_arrow, color: AppColors.violet, size: 16)
        : const Icon(Icons.pause_rounded, color: AppColors.magenta, size: 16);
  }

  @override
  bool isItemActive(WidgetRef ref, FileItem item) {
    if (ref.watch(videoIsEmptyProvider)) return false;
    final currentPlayingTrack = ref.watch(previewFileProvider);
    if (currentPlayingTrack == null) return false;

    if (item.type == FileItemType.folder) {
      return currentPlayingTrack.path.startsWith('${item.path}/');
    } else {
      return item.path == currentPlayingTrack.path;
    }
  }

  @override
  bool get isCurrentlyPlaying => false;

  // ── Bottom Nav ─────────────────────────────────────────────────────────────

  @override
  void onHomeNavTap() {
    ref.read(videoViewModeProvider.notifier).state = VideoViewMode.home;
  }

  @override
  void onFavoritesNavTap() {
    ref.read(videoViewModeProvider.notifier).state = VideoViewMode.favorites;
  }
}
