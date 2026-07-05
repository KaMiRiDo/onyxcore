import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';

/// Manages sidebar media-item pins (path → pinned_at timestamp).
///
/// This is distinct from [PinnedFolders] — those are directory browser
/// sidebar shortcuts. [PinnedItems] are generic media-item pins used in the
/// secondary pinned-items panel.
class PinnedItemsNotifier extends AsyncNotifier<Map<String, int>> {
  AppDatabase get _db => ref.read(databaseProvider);

  @override
  Future<Map<String, int>> build() async {
    return _db.getAllPinnedItems();
  }

  Future<void> pinItem(String path) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _db.addPinnedItem(path, timestamp);

    final currentMap = state.value ?? {};
    state = AsyncValue.data({...currentMap, path: timestamp});
  }

  Future<void> unpinItem(String path) async {
    await _db.removePinnedItem(path);

    final currentMap = state.value ?? {};
    final newMap = Map<String, int>.from(currentMap)..remove(path);
    state = AsyncValue.data(newMap);
  }
}

final pinnedItemsProvider =
    AsyncNotifierProvider<PinnedItemsNotifier, Map<String, int>>(
      PinnedItemsNotifier.new,
    );
