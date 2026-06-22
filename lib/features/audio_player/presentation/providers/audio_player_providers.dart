import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';

import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:audiotags/audiotags.dart';
import 'package:onyxcore/features/audio_player/domain/utils/audio_metadata_utils.dart';
import 'package:onyxcore/core/playlist/playlist_providers.dart';

final audioTagsOverridesProvider = StateProvider.family<Tag?, String>(
  (ref, path) => null,
);

final audioTagsProvider = FutureProvider.family<Tag?, String>((
  ref,
  path,
) async {
  final overrideTag = ref.watch(audioTagsOverridesProvider(path));
  if (overrideTag != null) {
    return overrideTag;
  }
  return await AudioMetadataUtils.readTags(path);
});

enum AudioViewMode { home, favorites }

/// Audio favorites — delegates to the shared [MediaFavoritesNotifier].
class AudioFavoritesNotifier extends MediaFavoritesNotifier {
  AudioFavoritesNotifier() : super('audio_favorites');
}

final audioFavoritesProvider =
    StateNotifierProvider<AudioFavoritesNotifier, Set<String>>((ref) {
      return AudioFavoritesNotifier();
    });

final audioViewModeProvider = StateProvider<AudioViewMode>(
  (ref) => AudioViewMode.home,
);
final audioPlaylistSidebarVisibleProvider = StateProvider<bool>((ref) => true);
final audioPlaylistSidebarWidthProvider = StateProvider<double?>((ref) => null);
final isAudioPlaylistSidebarDraggingProvider = StateProvider<bool>(
  (ref) => false,
);

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
final audioPathForwardHistoryProvider = StateProvider<List<String>>(
  (ref) => [],
);

final audioShowHiddenProvider = StateProvider<bool>((ref) {
  return ref.watch(settingsProvider).value?.showHiddenAudioFiles ?? false;
});

// Selection State for Audio Sidebar
final audioSelectionProvider = StateProvider<Set<String>>((ref) => {});
final audioSelectionAnchorProvider = StateProvider<int?>((ref) => null);

final audioQueueProvider = StateProvider<List<FileItem>>((ref) => []);
final audioPlayingQueueProvider = StateProvider<List<FileItem>>((ref) => []);
final activeTrackIndexProvider = StateProvider<int>((ref) => 0);
final audioIsReloadingProvider = StateProvider<bool>((ref) => false);

final audioAutoPlaySessionProvider = StateProvider.autoDispose<bool>((ref) {
  return ref.watch(settingsProvider).value?.audioAutoPlayNext ?? true;
});

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

// Sorting and Searching
final audioSortOptionProvider = StateProvider<SortOption?>((ref) => null);
final audioSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredAndSortedAudioQueueProvider = Provider<List<FileItem>>((ref) {
  return sortAndFilterQueue(
    queue: ref.watch(audioQueueProvider),
    searchQuery: ref.watch(audioSearchQueryProvider),
    sortOption: ref.watch(audioSortOptionProvider),
    isFavoritesMode:
        ref.watch(audioViewModeProvider) == AudioViewMode.favorites,
    favorites: ref.watch(audioFavoritesProvider),
  );
});

// ── Provider Config for PlaylistSidebarBase ──────────────────────────────────

/// Pre-built [PlaylistProviderConfig] for the audio playlist sidebar.
final audioPlaylistProviderConfig = PlaylistProviderConfig(
  currentPathProvider: audioCurrentPathProvider,
  rootPathProvider: audioRootPathProvider,
  pathHistoryProvider: audioPathHistoryProvider,
  pathForwardHistoryProvider: audioPathForwardHistoryProvider,
  showHiddenProvider: audioShowHiddenProvider,
  selectionProvider: audioSelectionProvider,
  selectionAnchorProvider: audioSelectionAnchorProvider,
  queueProvider: audioQueueProvider,
  isReloadingProvider: audioIsReloadingProvider,
  sortOptionProvider: audioSortOptionProvider,
  searchQueryProvider: audioSearchQueryProvider,
  filteredAndSortedQueueProvider: filteredAndSortedAudioQueueProvider,
  viewModeProvider: audioViewModeProvider,
  favoritesValue: AudioViewMode.favorites,
);

final audioIsEmptyProvider = StateProvider<bool>((ref) => false);
final audioRestartSignalProvider = StateProvider<int>((ref) => 0);
