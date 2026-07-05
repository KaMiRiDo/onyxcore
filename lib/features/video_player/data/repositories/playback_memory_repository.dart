import 'package:onyxcore/core/database/app_database.dart';

/// Drift-backed repository for persisting video playback resume positions.
///
/// Replaces the old Hive-based implementation. The [AppDatabase] instance
/// is passed in from the provider layer so there is no global state.
class PlaybackMemoryRepository {
  const PlaybackMemoryRepository(this._db);

  final AppDatabase _db;

  Future<void> savePosition(String path, int positionMs) =>
      _db.savePlaybackPosition(path, positionMs);

  Future<int?> getPosition(String path) => _db.getPlaybackPosition(path);
}
