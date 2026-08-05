import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/playlist/playlist_providers.dart';
import 'package:onyxcore/core/playlist/playlist_sidebar_base.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/context_menu.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/media_thumbnail_preview.dart';
import 'package:onyxcore/features/image_viewer/presentation/providers/image_playlist_providers.dart';

class ImagePlaylistSidebar extends PlaylistSidebarBase {
  const ImagePlaylistSidebar({
    super.key,
    super.onDelete,
    super.onMove,
    super.onReload,
    super.isNetworkStream = false,
    this.onImageSelected,
  });

  final void Function(FileItem)? onImageSelected;

  @override
  ConsumerState<ImagePlaylistSidebar> createState() =>
      _ImagePlaylistSidebarState();
}

class _ImagePlaylistSidebarState
    extends PlaylistSidebarBaseState<ImagePlaylistSidebar> {
  // ── Configuration ──────────────────────────────────────────────────────────

  @override
  PlaylistProviderConfig get config => imagePlaylistProviderConfig;

  @override
  FileItemType get targetMediaType => FileItemType.image;

  @override
  String get emptyStateText => 'No image files found';

  @override
  String get favoritesEmptyStateText => 'No favorite files in this folder';

  @override
  IconData get defaultMediaIcon => Icons.image_outlined;

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
  void watchActiveItemDependencies() {
    ref
      ..watch(imageIsEmptyProvider)
      ..watch(previewFileProvider);
  }

  @override
  void buildListeners() {
    ref.listen(imageCurrentPathProvider, (previous, next) {
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
          ref.read(imageSelectionProvider.notifier).state = {};
        },
      ),
      ContextMenuItem.divider(),
      ContextMenuItem(
        title: selection.length > 1 ? 'Copy Items' : 'Copy Item',
        icon: Icons.content_copy_rounded,
        onTap: () {
          handleMoveOrCopy(context, selection, false);
          ref.read(imageSelectionProvider.notifier).state = {};
        },
      ),
      ContextMenuItem(
        title: selection.length > 1 ? 'Move Items' : 'Move Item',
        icon: Icons.drive_file_move_outline,
        onTap: () {
          handleMoveOrCopy(context, selection, true);
          ref.read(imageSelectionProvider.notifier).state = {};
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

  // ── Double Tap (Select Image) ──────────────────────────────────────────────

  @override
  void onItemDoubleTap(FileItem item, int realIndex, List<FileItem> queue) {
    if (ref.read(imageIsEmptyProvider)) {
      ref.read(imageIsEmptyProvider.notifier).state = false;
      ref.read(imageRestartSignalProvider.notifier).state++;
    }
    widget.onImageSelected?.call(item);
  }

  // ── Tile Customization ─────────────────────────────────────────────────────

  @override
  String buildSubtitle(FileItem item) {
    if (item.type == FileItemType.folder) {
      return item.itemCount != null
          ? "${item.itemCount} Image File${item.itemCount == 1 ? '' : 's'}"
          : 'Folder';
    }

    var subtitle = 'Image File';
    if (item.sizeBytes != null && item.sizeBytes! > 0) {
      final sizeMB = (item.sizeBytes! / (1024 * 1024)).toStringAsFixed(1);
      subtitle += ' • $sizeMB MB';
    }
    return subtitle;
  }

  @override
  Widget? buildCoverArt(WidgetRef ref, FileItem item) {
    if (item.type != FileItemType.image) return null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        width: defaultMediaIconSize,
        height: defaultMediaIconSize,
        child: MediaThumbnailPreview(item: item, zoom: 1),
      ),
    );
  }

  @override
  Widget? buildActiveIndicator(bool isPlaying) {
    return const Icon(
      Icons.remove_red_eye_rounded,
      color: AppColors.violet,
      size: 16,
    );
  }

  @override
  bool isItemActive(WidgetRef ref, FileItem item) {
    final isEmpty = ref.watch(imageIsEmptyProvider);
    final currentPreviewTrack = ref.watch(previewFileProvider);

    if (isEmpty) return false;
    if (currentPreviewTrack == null) return false;

    if (item.type == FileItemType.folder) {
      return currentPreviewTrack.path.startsWith('${item.path}/');
    } else {
      return item.path == currentPreviewTrack.path;
    }
  }

  @override
  bool get isCurrentlyPlaying => false;

  // ── Bottom Nav ─────────────────────────────────────────────────────────────

  @override
  void onHomeNavTap() {
    ref.read(imageViewModeProvider.notifier).state = ImageViewMode.home;
  }

  @override
  void onFavoritesNavTap() {
    ref.read(imageViewModeProvider.notifier).state = ImageViewMode.favorites;
  }
}
