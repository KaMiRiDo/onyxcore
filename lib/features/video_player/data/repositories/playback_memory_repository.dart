import 'package:hive/hive.dart';

class PlaybackMemoryRepository {
  static const String boxName = 'video_playback_memory';
  
  static Future<void> savePosition(String path, int positionMs) async {
    final box = await Hive.openBox(boxName);
    await box.put(path, positionMs);
  }

  static Future<int?> getPosition(String path) async {
    final box = await Hive.openBox(boxName);
    return box.get(path) as int?;
  }
}
