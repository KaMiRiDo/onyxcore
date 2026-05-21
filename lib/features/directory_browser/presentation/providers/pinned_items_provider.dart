import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class PinnedItemsNotifier extends AsyncNotifier<Map<String, int>> {
  static const String boxName = 'pinned_items';

  @override
  Future<Map<String, int>> build() async {
    final box = await Hive.openBox(boxName);
    final map = <String, int>{};
    for (final key in box.keys) {
      final value = box.get(key);
      if (value is int) {
        map[key as String] = value;
      }
    }
    return map;
  }

  Future<void> pinItem(String path) async {
    final box = await Hive.openBox(boxName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await box.put(path, timestamp);

    final currentMap = state.value ?? {};
    final newMap = Map<String, int>.from(currentMap);
    newMap[path] = timestamp;
    state = AsyncValue.data(newMap);
  }

  Future<void> unpinItem(String path) async {
    final box = await Hive.openBox(boxName);
    await box.delete(path);

    final currentMap = state.value ?? {};
    final newMap = Map<String, int>.from(currentMap);
    newMap.remove(path);
    state = AsyncValue.data(newMap);
  }
}

final pinnedItemsProvider =
    AsyncNotifierProvider<PinnedItemsNotifier, Map<String, int>>(
  PinnedItemsNotifier.new,
);
