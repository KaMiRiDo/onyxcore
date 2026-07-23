import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/playlist/playlist_sidebar_base.dart' show PlaylistSidebarBase;
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';

// ── Shared Favorites Notifier ────────────────────────────────────────────────

enum MediaType { audio, video, image }

/// Base class for Drift-backed media favorites notifiers.
///
/// Subclasses specify whether they manage audio, video or image favorites via
/// [_mediaType]. The Drift [AppDatabase] is accessed via the Riverpod ref
/// stored in [_ref].
abstract class MediaFavoritesNotifier extends StateNotifier<Set<String>> {

  MediaFavoritesNotifier(this._mediaType) : super({}) {
    // _ref is injected by the factory provider immediately after construction.
  }
  final MediaType _mediaType;
  Ref? _ref;

  void setRef(Ref ref) {
    _ref = ref;
    _init();
  }

  AppDatabase get _db => _ref!.read(databaseProvider);

  Future<void> _init() async {
    final Set<String> favs;
    switch (_mediaType) {
      case MediaType.audio:
        favs = await _db.getAudioFavorites();
      case MediaType.video:
        favs = await _db.getVideoFavorites();
      case MediaType.image:
        favs = await _db.getImageFavorites();
    }
    if (mounted) state = favs;
  }

  void toggleFavorite(String path) {
    if (state.contains(path)) {
      state = {...state}..remove(path);
      switch (_mediaType) {
        case MediaType.audio:
          _db.removeAudioFavorite(path);
        case MediaType.video:
          _db.removeVideoFavorite(path);
        case MediaType.image:
          _db.removeImageFavorite(path);
      }
    } else {
      state = {...state, path};
      switch (_mediaType) {
        case MediaType.audio:
          _db.addAudioFavorite(path);
        case MediaType.video:
          _db.addVideoFavorite(path);
        case MediaType.image:
          _db.addImageFavorite(path);
      }
    }
  }
}

// ── Shared Sort & Filter Utility ─────────────────────────────────────────────

/// Applies favorites filtering, search query, and sort option to a queue.
///
/// This is the shared implementation used by both
/// `filteredAndSortedAudioQueueProvider` and `filteredAndSortedVideoQueueProvider`.
List<FileItem> sortAndFilterQueue({
  required List<FileItem> queue,
  required String searchQuery,
  required SortOption? sortOption,
  required bool isFavoritesMode,
  required Set<String> favorites,
}) {
  // Filter
  var result = queue;
  if (isFavoritesMode) {
    result = result.where((item) => favorites.contains(item.path)).toList();
  }

  if (searchQuery.isNotEmpty) {
    final query = searchQuery.toLowerCase();
    result = result
        .where((item) => item.name.toLowerCase().contains(query))
        .toList();
  }

  // Sort
  if (sortOption != null) {
    result = List.from(result);
    result.sort((a, b) {
      if (sortOption != SortOption.filesFirst) {
        if (a.type == FileItemType.folder && b.type != FileItemType.folder) {
          return -1;
        }
        if (a.type != FileItemType.folder && b.type == FileItemType.folder) {
          return 1;
        }
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
          if (a.type == FileItemType.folder && b.type != FileItemType.folder) {
            return 1;
          }
          if (a.type != FileItemType.folder && b.type == FileItemType.folder) {
            return -1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });
  }

  return result;
}

// ── Provider Configuration Object ────────────────────────────────────────────

/// Configuration object that bundles all Riverpod provider references needed
/// by [PlaylistSidebarBase].
///
/// This avoids virtual dispatch overhead on every `ref.watch` call by using
/// a concrete data object instead of abstract getters.
class PlaylistProviderConfig {

  const PlaylistProviderConfig({
    required this.currentPathProvider,
    required this.rootPathProvider,
    required this.pathHistoryProvider,
    required this.pathForwardHistoryProvider,
    required this.showHiddenProvider,
    required this.selectionProvider,
    required this.selectionAnchorProvider,
    required this.queueProvider,
    required this.isReloadingProvider,
    required this.sortOptionProvider,
    required this.searchQueryProvider,
    required this.filteredAndSortedQueueProvider,
    required this.viewModeProvider,
    required this.favoritesValue,
  });
  final StateProvider<String> currentPathProvider;
  final StateProvider<String> rootPathProvider;
  final StateProvider<List<String>> pathHistoryProvider;
  final StateProvider<List<String>> pathForwardHistoryProvider;
  final StateProvider<bool> showHiddenProvider;
  final StateProvider<Set<String>> selectionProvider;
  final StateProvider<int?> selectionAnchorProvider;
  final StateProvider<List<FileItem>> queueProvider;
  final StateProvider<bool> isReloadingProvider;
  final StateProvider<SortOption?> sortOptionProvider;
  final StateProvider<String> searchQueryProvider;
  final Provider<List<FileItem>> filteredAndSortedQueueProvider;

  /// The view mode enum provider. This is dynamic because audio uses
  /// `AudioViewMode` and video uses `VideoViewMode`.
  final StateProvider<dynamic> viewModeProvider;

  /// The favorites mode enum value to compare against viewModeProvider.
  final dynamic favoritesValue;
}
