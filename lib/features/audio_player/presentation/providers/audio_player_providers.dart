import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

enum AudioViewMode { home, favorites }

class AudioFavoritesNotifier extends StateNotifier<Set<String>> {
  static const String _boxName = 'audio_favorites';
  Box? _box;

  AudioFavoritesNotifier() : super({}) {
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

final audioFavoritesProvider = StateNotifierProvider<AudioFavoritesNotifier, Set<String>>((ref) {
  return AudioFavoritesNotifier();
});

final audioViewModeProvider = StateProvider<AudioViewMode>((ref) => AudioViewMode.home);

/// The active Player instance, set by AudioPlayerView when it mounts.
/// This is NOT auto-created by Riverpod — it is set externally.
final audioPlayerProvider = StateProvider<Player?>((ref) => null);

/// A global, reused Player instance for all audio playback.
/// We reuse this instance instead of creating a new one for each AudioPlayerView.
/// This means we never have to call Player.dispose(), preventing native libmpv
/// deadlocks when switching rapidly between audio and video players.
final Player globalAudioPlayer = Player();

final audioCurrentPathProvider = StateProvider<String>((ref) => '');
final audioRootPathProvider = StateProvider<String>((ref) => '');
final audioPathHistoryProvider = StateProvider<List<String>>((ref) => []);
final audioPathForwardHistoryProvider = StateProvider<List<String>>((ref) => []);

// Selection State for Audio Sidebar
final audioSelectionProvider = StateProvider<Set<String>>((ref) => {});
final audioSelectionAnchorProvider = StateProvider<int?>((ref) => null);

final audioQueueProvider = StateProvider<List<FileItem>>((ref) => []);
final audioPlayingQueueProvider = StateProvider<List<FileItem>>((ref) => []);
final activeTrackIndexProvider = StateProvider<int>((ref) => 0);

final currentTrackProvider = Provider<FileItem?>((ref) {
  final queue = ref.watch(audioPlayingQueueProvider);
  final index = ref.watch(activeTrackIndexProvider);
  if (index >= 0 && index < queue.length) {
    return queue[index];
  }
  return null;
});

final audioPositionProvider = StreamProvider<Duration>((ref) {
  final player = ref.watch(audioPlayerProvider);
  if (player == null) return const Stream.empty();
  return player.stream.position;
});

final audioDurationProvider = StreamProvider<Duration>((ref) {
  final player = ref.watch(audioPlayerProvider);
  if (player == null) return const Stream.empty();
  return player.stream.duration;
});

final audioPlayingProvider = StreamProvider<bool>((ref) {
  final player = ref.watch(audioPlayerProvider);
  if (player == null) return const Stream.empty();
  return player.stream.playing;
});

final audioVolumeProvider = StreamProvider<double>((ref) {
  final player = ref.watch(audioPlayerProvider);
  if (player == null) return const Stream.empty();
  return player.stream.volume;
});

final audioShuffleProvider = StateProvider<bool>((ref) => false);
final audioRepeatProvider = StateProvider<PlaylistMode>((ref) => PlaylistMode.none);

// Sorting and Searching
final audioSortOptionProvider = StateProvider<SortOption?>((ref) => null);
final audioSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredAndSortedAudioQueueProvider = Provider<List<FileItem>>((ref) {
  final queue = ref.watch(audioQueueProvider);
  final query = ref.watch(audioSearchQueryProvider).toLowerCase();
  final sortOption = ref.watch(audioSortOptionProvider);
  final viewMode = ref.watch(audioViewModeProvider);
  final favorites = ref.watch(audioFavoritesProvider);

  // Filter
  var result = queue;
  if (viewMode == AudioViewMode.favorites) {
    result = result.where((item) => favorites.contains(item.path)).toList();
  }

  if (query.isNotEmpty) {
    result = result.where((item) => item.name.toLowerCase().contains(query)).toList();
  }

  // Sort
  if (sortOption != null) {
    result = List.from(result);
    result.sort((a, b) {
      if (a.type == FileItemType.folder && b.type != FileItemType.folder) return -1;
      if (a.type != FileItemType.folder && b.type == FileItemType.folder) return 1;

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
          if (a.type == FileItemType.folder && b.type != FileItemType.folder) return 1;
          if (a.type != FileItemType.folder && b.type == FileItemType.folder) return -1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      }
    });
  }

  return result;
});
