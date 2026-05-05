import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

/// The active Player instance, set by AudioPlayerView when it mounts.
/// This is NOT auto-created by Riverpod — it is set externally.
final audioPlayerProvider = StateProvider<Player?>((ref) => null);

final audioQueueProvider = StateProvider<List<FileItem>>((ref) => []);
final activeTrackIndexProvider = StateProvider<int>((ref) => 0);

final currentTrackProvider = Provider<FileItem?>((ref) {
  final queue = ref.watch(audioQueueProvider);
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
