import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

enum VideoViewMode { home, favorites }

class VideoFavoritesNotifier extends StateNotifier<Set<String>> {
  static const String _boxName = 'video_favorites';
  Box? _box;

  VideoFavoritesNotifier() : super({}) {
    _init();
  }

  Future<void> _init() async {
    _box = await Hive.openBox(_boxName);
    final favs = _box!.get('favorites', defaultValue: <String>[]);
    if (mounted) {
      state = (favs as List).cast<String>().toSet();
    }
  }

  void toggleFavorite(String path) {
    if (state.contains(path)) {
      state = {...state}..remove(path);
    } else {
      state = {...state, path};
    }
    _box?.put('favorites', state.toList());
  }
}

final videoFavoritesProvider =
    StateNotifierProvider<VideoFavoritesNotifier, Set<String>>((ref) {
      return VideoFavoritesNotifier();
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
  final queue = ref.watch(videoQueueProvider);
  final query = ref.watch(videoSearchQueryProvider).toLowerCase();
  final sortOption = ref.watch(videoSortOptionProvider);
  final viewMode = ref.watch(videoViewModeProvider);
  final favorites = ref.watch(videoFavoritesProvider);

  // Filter
  var result = queue;
  if (viewMode == VideoViewMode.favorites) {
    result = result.where((item) => favorites.contains(item.path)).toList();
  }

  if (query.isNotEmpty) {
    result = result
        .where((item) => item.name.toLowerCase().contains(query))
        .toList();
  }

  // Sort
  if (sortOption != null) {
    result = List.from(result);
    result.sort((a, b) {
      if (sortOption != SortOption.filesFirst) {
        if (a.type == FileItemType.folder && b.type != FileItemType.folder)
          return -1;
        if (a.type != FileItemType.folder && b.type == FileItemType.folder)
          return 1;
      }

      switch (sortOption) {
        case SortOption.aToZ:
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        case SortOption.zToA:
          return b.name.toLowerCase().compareTo(a.name.toLowerCase());
        case SortOption.lastModified:
          return b.modified.compareTo(a.modified);
        case SortOption.firstModified:
          return a.modified.compareTo(b.modified);
        case SortOption.sizeSmallToLarge:
          return (a.sizeBytes ?? 0).compareTo(b.sizeBytes ?? 0);
        case SortOption.sizeLargeToSmall:
          return (b.sizeBytes ?? 0).compareTo(a.sizeBytes ?? 0);
        case SortOption.filesFirst:
          if (a.type == FileItemType.folder && b.type != FileItemType.folder)
            return 1;
          if (a.type != FileItemType.folder && b.type == FileItemType.folder)
            return -1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });
  }

  return result;
});
