import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/video_player/data/repositories/marker_repository.dart';
import 'package:onyxcore/features/video_player/domain/entities/video_marker.dart';
// ignore: implementation_imports
import 'package:uuid/uuid.dart';

// Use FutureProvider for loading markers.
// We will use ref.invalidate() to trigger reloads after mutations.
final videoMarkersProvider = FutureProvider.family<List<VideoMarker>, String>((
  ref,
  videoPath,
) async {
  return MarkerRepository.loadMarkers(videoPath);
});

// A separate provider for marker actions
final markerActionsProvider = Provider(MarkerActions.new);

class MarkerActions {
  MarkerActions(this.ref);
  final Ref ref;

  Future<void> addMarker(
    String videoPath,
    Duration timestamp,
    String content, {
    String icon = '📍',
  }) async {
    final currentMarkers = await MarkerRepository.loadMarkers(videoPath);

    final newMarker = VideoMarker(
      id: const Uuid().v4(),
      timestamp: timestamp,
      content: content,
      icon: icon,
    );

    final updatedMarkers = [...currentMarkers, newMarker]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    await MarkerRepository.saveMarkers(videoPath, updatedMarkers);
    ref.invalidate(videoMarkersProvider(videoPath));
  }

  Future<void> updateMarker(String videoPath, VideoMarker marker) async {
    final currentMarkers = await MarkerRepository.loadMarkers(videoPath);

    final updatedMarkers =
        currentMarkers.map((m) => m.id == marker.id ? marker : m).toList()
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    await MarkerRepository.saveMarkers(videoPath, updatedMarkers);
    ref.invalidate(videoMarkersProvider(videoPath));
  }

  Future<void> deleteMarker(String videoPath, String id) async {
    final currentMarkers = await MarkerRepository.loadMarkers(videoPath);

    final updatedMarkers = currentMarkers.where((m) => m.id != id).toList();

    await MarkerRepository.saveMarkers(videoPath, updatedMarkers);
    ref.invalidate(videoMarkersProvider(videoPath));
  }

  Future<void> deleteAllMarkers(String videoPath) async {
    await MarkerRepository.saveMarkers(videoPath, []);
    ref.invalidate(videoMarkersProvider(videoPath));
  }
}
