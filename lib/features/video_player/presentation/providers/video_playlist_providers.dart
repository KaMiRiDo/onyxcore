import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/core/playlist/playlist_providers.dart';

enum VideoViewMode { home, favorites }

/// Video favorites — delegates to the shared [MediaFavoritesNotifier].
class VideoFavoritesNotifier extends MediaFavoritesNotifier {
  VideoFavoritesNotifier() : super(MediaType.video);
}

final videoFavoritesProvider =
    StateNotifierProvider<VideoFavoritesNotifier, Set<String>>((ref) {
      final notifier = VideoFavoritesNotifier()..setRef(ref);
      return notifier;
    });

final videoViewModeProvider = StateProvider<VideoViewMode>(
  (ref) => VideoViewMode.home,
);

final videoCurrentPathProvider = StateProvider<String>((ref) => '');
final videoRootPathProvider = StateProvider<String>((ref) => '');
final videoPathHistoryProvider = StateProvider<List<String>>((ref) => []);
final videoPathForwardHistoryProvider = StateProvider<List<String>>(
  (ref) => [],
);

final videoShowHiddenProvider = StateProvider<bool>((ref) {
  return ref.watch(settingsProvider).value?.showHiddenFiles ?? false;
});

// Selection State for Video Sidebar
final videoSelectionProvider = StateProvider<Set<String>>((ref) => {});
final videoSelectionAnchorProvider = StateProvider<int?>((ref) => null);

final videoQueueProvider = StateProvider<List<FileItem>>((ref) => []);
final videoPlayingQueueProvider = StateProvider<List<FileItem>>((ref) => []);
final activeVideoIndexProvider = StateProvider<int>((ref) => 0);
final videoIsReloadingProvider = StateProvider<bool>((ref) => false);

// ── Video Playlist Sidebar Providers ─────────────────────────────────────────

/// Whether the video playlist side panel is visible.
final videoPlaylistSidebarVisibleProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Current width of the video playlist side panel (null = default 280px).
final videoPlaylistSidebarWidthProvider = StateProvider.autoDispose<double?>((ref) => null);

/// True while the user is dragging the sidebar resize handle.
final isVideoPlaylistSidebarDraggingProvider = StateProvider.autoDispose<bool>(
  (ref) => false,
);
final videoAutoPlaySessionProvider = StateProvider.autoDispose<bool>((ref) {
  return ref.watch(settingsProvider).value?.autoPlayNext ?? true;
});

/// Set to true to prevent the video player from auto-playing on the next _loadMedia call.
final videoForcePauseNextProvider = StateProvider<bool>((ref) => false);

final currentVideoProvider = Provider<FileItem?>((ref) {
  final queue = ref.watch(videoPlayingQueueProvider);
  final index = ref.watch(activeVideoIndexProvider);
  if (index >= 0 && index < queue.length) {
    return queue[index];
  }
  return null;
});

// Sorting and Searching
final videoSortOptionProvider = StateProvider<SortOption?>((ref) => null);
final videoSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredAndSortedVideoQueueProvider = Provider<List<FileItem>>((ref) {
  return sortAndFilterQueue(
    queue: ref.watch(videoQueueProvider),
    searchQuery: ref.watch(videoSearchQueryProvider),
    sortOption: ref.watch(videoSortOptionProvider),
    isFavoritesMode:
        ref.watch(videoViewModeProvider) == VideoViewMode.favorites,
    favorites: ref.watch(videoFavoritesProvider),
  );
});

// ── Provider Config for PlaylistSidebarBase ──────────────────────────────────

/// Pre-built [PlaylistProviderConfig] for the video playlist sidebar.
final videoPlaylistProviderConfig = PlaylistProviderConfig(
  currentPathProvider: videoCurrentPathProvider,
  rootPathProvider: videoRootPathProvider,
  pathHistoryProvider: videoPathHistoryProvider,
  pathForwardHistoryProvider: videoPathForwardHistoryProvider,
  showHiddenProvider: videoShowHiddenProvider,
  selectionProvider: videoSelectionProvider,
  selectionAnchorProvider: videoSelectionAnchorProvider,
  queueProvider: videoQueueProvider,
  isReloadingProvider: videoIsReloadingProvider,
  sortOptionProvider: videoSortOptionProvider,
  searchQueryProvider: videoSearchQueryProvider,
  filteredAndSortedQueueProvider: filteredAndSortedVideoQueueProvider,
  viewModeProvider: videoViewModeProvider,
  favoritesValue: VideoViewMode.favorites,
);

final videoIsEmptyProvider = StateProvider<bool>((ref) => false);
final videoRestartSignalProvider = StateProvider<int>((ref) => 0);
