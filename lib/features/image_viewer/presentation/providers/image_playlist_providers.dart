import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/core/playlist/playlist_providers.dart';

enum ImageViewMode { home, favorites }

/// Image favorites — delegates to the shared [MediaFavoritesNotifier].
class ImageFavoritesNotifier extends MediaFavoritesNotifier {
  ImageFavoritesNotifier() : super('image_favorites');
}

final imageFavoritesProvider =
    StateNotifierProvider<ImageFavoritesNotifier, Set<String>>((ref) {
      return ImageFavoritesNotifier();
    });

final imageViewModeProvider = StateProvider<ImageViewMode>(
  (ref) => ImageViewMode.home,
);

final imageCurrentPathProvider = StateProvider<String>((ref) => '');
final imageRootPathProvider = StateProvider<String>((ref) => '');
final imagePathHistoryProvider = StateProvider<List<String>>((ref) => []);
final imagePathForwardHistoryProvider = StateProvider<List<String>>(
  (ref) => [],
);

final imageShowHiddenProvider = StateProvider<bool>((ref) {
  return ref.watch(settingsProvider).value?.showHiddenFiles ?? false;
});

// Selection State for Image Sidebar
final imageSelectionProvider = StateProvider<Set<String>>((ref) => {});
final imageSelectionAnchorProvider = StateProvider<int?>((ref) => null);

final imageQueueProvider = StateProvider<List<FileItem>>((ref) => []);
final imagePlayingQueueProvider = StateProvider<List<FileItem>>((ref) => []);
final activeImageIndexProvider = StateProvider<int>((ref) => 0);
final imageIsReloadingProvider = StateProvider<bool>((ref) => false);

// ── Image Playlist Sidebar Providers ─────────────────────────────────────────

/// Whether the image playlist side panel is visible.
final imagePlaylistSidebarVisibleProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Current width of the image playlist side panel (null = default 280px).
final imagePlaylistSidebarWidthProvider = StateProvider.autoDispose<double?>((ref) => null);

/// True while the user is dragging the sidebar resize handle.
final isImagePlaylistSidebarDraggingProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);

final currentImageProvider = Provider<FileItem?>((ref) {
  final queue = ref.watch(imagePlayingQueueProvider);
  final index = ref.watch(activeImageIndexProvider);
  if (index >= 0 && index < queue.length) {
    return queue[index];
  }
  return null;
});

// Sorting and Searching
final imageSortOptionProvider = StateProvider<SortOption?>((ref) => null);
final imageSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredAndSortedImageQueueProvider = Provider<List<FileItem>>((ref) {
  return sortAndFilterQueue(
    queue: ref.watch(imageQueueProvider),
    searchQuery: ref.watch(imageSearchQueryProvider),
    sortOption: ref.watch(imageSortOptionProvider),
    isFavoritesMode:
        ref.watch(imageViewModeProvider) == ImageViewMode.favorites,
    favorites: ref.watch(imageFavoritesProvider),
  );
});

// ── Provider Config for PlaylistSidebarBase ──────────────────────────────────

/// Pre-built [PlaylistProviderConfig] for the image playlist sidebar.
final imagePlaylistProviderConfig = PlaylistProviderConfig(
  currentPathProvider: imageCurrentPathProvider,
  rootPathProvider: imageRootPathProvider,
  pathHistoryProvider: imagePathHistoryProvider,
  pathForwardHistoryProvider: imagePathForwardHistoryProvider,
  showHiddenProvider: imageShowHiddenProvider,
  selectionProvider: imageSelectionProvider,
  selectionAnchorProvider: imageSelectionAnchorProvider,
  queueProvider: imageQueueProvider,
  isReloadingProvider: imageIsReloadingProvider,
  sortOptionProvider: imageSortOptionProvider,
  searchQueryProvider: imageSearchQueryProvider,
  filteredAndSortedQueueProvider: filteredAndSortedImageQueueProvider,
  viewModeProvider: imageViewModeProvider,
  favoritesValue: ImageViewMode.favorites,
);

final imageIsEmptyProvider = StateProvider<bool>((ref) => false);
final imageRestartSignalProvider = StateProvider<int>((ref) => 0);
