import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Table definitions
// ─────────────────────────────────────────────────────────────────────────────

/// Generic key-value settings store.
/// Each AppSettings field is stored as one row.
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

/// Per-folder sort overrides (directory browser).
class FolderSortPreferences extends Table {
  TextColumn get folderPath => text()();
  TextColumn get sortKey => text()();

  @override
  Set<Column<Object>> get primaryKey => {folderPath};
}

/// Ordered list of directory browser sidebar pinned shortcuts.
class PinnedFolders extends Table {
  TextColumn get folderPath => text()();
  IntColumn get position => integer()();

  @override
  Set<Column<Object>> get primaryKey => {folderPath};
}

/// Sidebar media-item pins (path → timestamp). Different from PinnedFolders.
class PinnedItems extends Table {
  TextColumn get itemPath => text()();
  IntColumn get pinnedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {itemPath};
}

/// Image aspect ratio cache (one row per image file ever viewed).
class MetadataCacheEntries extends Table {
  @override
  String get tableName => 'metadata_cache';

  TextColumn get filePath => text()();
  RealColumn get aspectRatio => real()();
  IntColumn get cachedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {filePath};
}

/// Video playback resume positions.
class PlaybackMemoryEntries extends Table {
  @override
  String get tableName => 'playback_memory';

  TextColumn get filePath => text()();
  IntColumn get positionMs => integer()();
  IntColumn get updatedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {filePath};
}

/// Audio favorite track paths.
class AudioFavoriteEntries extends Table {
  @override
  String get tableName => 'audio_favorites';

  TextColumn get filePath => text()();
  IntColumn get favoritedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {filePath};
}

/// Video favorite track paths.
class VideoFavoriteEntries extends Table {
  @override
  String get tableName => 'video_favorites';

  TextColumn get filePath => text()();
  IntColumn get favoritedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {filePath};
}

/// Image favorite file paths.
class ImageFavoriteEntries extends Table {
  @override
  String get tableName => 'image_favorites';

  TextColumn get filePath => text()();
  IntColumn get favoritedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {filePath};
}

/// Custom emoji sets for the video marker editor.
class CustomEmojiSetEntries extends Table {
  @override
  String get tableName => 'custom_emoji_sets';

  TextColumn get id => text()();
  TextColumn get rawData => text()();
  TextColumn get definitions =>
      text()(); // JSON-encoded Map<String, String> (emoji→keyword)

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Custom icon sets for the video marker editor.
class CustomIconSetEntries extends Table {
  @override
  String get tableName => 'custom_icon_sets';

  TextColumn get id => text()();
  TextColumn get imageBytes => text()(); // base64-encoded PNG
  TextColumn get tags => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Recently used marker icons/emojis (trimmed to last ~20, ordered by usedAt).
class MarkerRecentEntries extends Table {
  @override
  String get tableName => 'marker_recents';

  TextColumn get value =>
      text()(); // emoji char or 'B64:...' custom icon reference
  IntColumn get usedAt => integer()();

  @override
  Set<Column<Object>> get primaryKey => {value};
}

/// Download history (replaces the old raw sqlite3 table).
class DownloadHistoryEntries extends Table {
  @override
  String get tableName => 'download_history';

  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get url => text()();
  TextColumn get destination => text()();
  TextColumn get downloadType => text()();
  TextColumn get statusName => text()();
  TextColumn get errorMessage => text().nullable()();
  IntColumn get createdAt => integer()(); // ms since epoch
  IntColumn get completedAt => integer().nullable()();
  TextColumn get logs => text().nullable()(); // JSON list<String>

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────────────────────
// Database class
// ─────────────────────────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [
    Settings,
    FolderSortPreferences,
    PinnedFolders,
    PinnedItems,
    MetadataCacheEntries,
    PlaybackMemoryEntries,
    AudioFavoriteEntries,
    VideoFavoriteEntries,
    ImageFavoriteEntries,
    CustomEmojiSetEntries,
    CustomIconSetEntries,
    MarkerRecentEntries,
    DownloadHistoryEntries,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  // ── Settings helpers ──────────────────────────────────────────────────────

  /// Read a single settings value by key. Returns null if not set.
  Future<String?> getSetting(String key) async {
    final row = await (select(settings)
          ..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  /// Upsert a single settings key/value pair.
  Future<void> setSetting(String key, String value) async {
    await into(settings).insertOnConflictUpdate(
      SettingsCompanion.insert(key: key, value: value),
    );
  }

  /// Delete a settings key (used for nullable settings that are cleared).
  Future<void> removeSetting(String key) async {
    await (delete(settings)..where((t) => t.key.equals(key))).go();
  }

  /// Watch all settings rows as a stream (for reactive SettingsNotifier).
  Stream<List<Setting>> watchAllSettings() {
    return select(settings).watch();
  }

  // ── MetadataCache helpers ─────────────────────────────────────────────────

  Future<List<MetadataCacheEntry>> getAllMetadataCache() {
    return select(metadataCacheEntries).get();
  }

  Future<void> upsertMetadataCache(String filePath, double ratio) async {
    await into(metadataCacheEntries).insertOnConflictUpdate(
      MetadataCacheEntriesCompanion.insert(
        filePath: filePath,
        aspectRatio: ratio,
        cachedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> deleteMetadataCache(String filePath) async {
    await (delete(metadataCacheEntries)
          ..where((t) => t.filePath.equals(filePath)))
        .go();
  }

  Future<void> deleteMetadataCacheForFolder(String folderPath) async {
    await (delete(metadataCacheEntries)
          ..where((t) => t.filePath.like('$folderPath%')))
        .go();
  }

  Future<void> deleteMetadataCacheBatch(List<String> paths) async {
    await (delete(metadataCacheEntries)
          ..where((t) => t.filePath.isIn(paths)))
        .go();
  }

  Future<List<String>> pruneMetadataCache(int maxCount) async {
    final rows = await (select(metadataCacheEntries)
          ..orderBy([(t) => OrderingTerm.desc(t.cachedAt)]))
        .get();
    if (rows.length > maxCount) {
      final toDelete = rows.skip(maxCount).map((r) => r.filePath).toList();
      await (delete(metadataCacheEntries)
            ..where((t) => t.filePath.isIn(toDelete)))
          .go();
      return toDelete;
    }
    return [];
  }
  // ── PlaybackMemory helpers ────────────────────────────────────────────────

  Future<int?> getPlaybackPosition(String filePath) async {
    final row = await (select(playbackMemoryEntries)
          ..where((t) => t.filePath.equals(filePath)))
        .getSingleOrNull();
    return row?.positionMs;
  }

  Future<void> savePlaybackPosition(String filePath, int positionMs) async {
    await into(playbackMemoryEntries).insertOnConflictUpdate(
      PlaybackMemoryEntriesCompanion.insert(
        filePath: filePath,
        positionMs: positionMs,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  // ── Favorites helpers (generic) ───────────────────────────────────────────

  Future<Set<String>> getAudioFavorites() async {
    final rows = await select(audioFavoriteEntries).get();
    return rows.map((r) => r.filePath).toSet();
  }

  Future<void> addAudioFavorite(String filePath) async {
    await into(audioFavoriteEntries).insertOnConflictUpdate(
      AudioFavoriteEntriesCompanion.insert(
        filePath: filePath,
        favoritedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> removeAudioFavorite(String filePath) async {
    await (delete(audioFavoriteEntries)
          ..where((t) => t.filePath.equals(filePath)))
        .go();
  }

  Future<Set<String>> getVideoFavorites() async {
    final rows = await select(videoFavoriteEntries).get();
    return rows.map((r) => r.filePath).toSet();
  }

  Future<void> addVideoFavorite(String filePath) async {
    await into(videoFavoriteEntries).insertOnConflictUpdate(
      VideoFavoriteEntriesCompanion.insert(
        filePath: filePath,
        favoritedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> removeVideoFavorite(String filePath) async {
    await (delete(videoFavoriteEntries)
          ..where((t) => t.filePath.equals(filePath)))
        .go();
  }

  Future<Set<String>> getImageFavorites() async {
    final rows = await select(imageFavoriteEntries).get();
    return rows.map((r) => r.filePath).toSet();
  }

  Future<void> addImageFavorite(String filePath) async {
    await into(imageFavoriteEntries).insertOnConflictUpdate(
      ImageFavoriteEntriesCompanion.insert(
        filePath: filePath,
        favoritedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> removeImageFavorite(String filePath) async {
    await (delete(imageFavoriteEntries)
          ..where((t) => t.filePath.equals(filePath)))
        .go();
  }

  // ── PinnedItems helpers ───────────────────────────────────────────────────

  Future<Map<String, int>> getAllPinnedItems() async {
    final rows = await select(pinnedItems).get();
    return {for (final r in rows) r.itemPath: r.pinnedAt};
  }

  Future<void> addPinnedItem(String path, int timestamp) async {
    await into(pinnedItems).insertOnConflictUpdate(
      PinnedItemsCompanion.insert(itemPath: path, pinnedAt: timestamp),
    );
  }

  Future<void> removePinnedItem(String path) async {
    await (delete(pinnedItems)..where((t) => t.itemPath.equals(path))).go();
  }

  // ── PinnedFolders helpers ─────────────────────────────────────────────────

  Future<List<String>> getOrderedPinnedFolders() async {
    final rows = await (select(pinnedFolders)
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    return rows.map((r) => r.folderPath).toList();
  }

  Future<void> savePinnedFolders(List<String> paths) async {
    await transaction(() async {
      await delete(pinnedFolders).go();
      for (var i = 0; i < paths.length; i++) {
        await into(pinnedFolders).insert(
          PinnedFoldersCompanion.insert(folderPath: paths[i], position: i),
        );
      }
    });
  }

  // ── FolderSortPreferences helpers ─────────────────────────────────────────

  Future<Map<String, String>> getAllFolderSorts() async {
    final rows = await select(folderSortPreferences).get();
    return {for (final r in rows) r.folderPath: r.sortKey};
  }

  Future<void> setFolderSort(String folderPath, String sortKey) async {
    await into(folderSortPreferences).insertOnConflictUpdate(
      FolderSortPreferencesCompanion.insert(
        folderPath: folderPath,
        sortKey: sortKey,
      ),
    );
  }

  // ── MarkerRecents helpers ─────────────────────────────────────────────────

  Future<List<String>> getMarkerRecents() async {
    final rows = await (select(markerRecentEntries)
          ..orderBy([(t) => OrderingTerm.desc(t.usedAt)]))
        .get();
    return rows.map((r) => r.value).toList();
  }

  Future<void> upsertMarkerRecent(String value) async {
    await into(markerRecentEntries).insertOnConflictUpdate(
      MarkerRecentEntriesCompanion.insert(
        value: value,
        usedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> pruneMarkerRecents(int maxCount) async {
    final rows = await (select(markerRecentEntries)
          ..orderBy([(t) => OrderingTerm.desc(t.usedAt)]))
        .get();
    if (rows.length > maxCount) {
      final toDelete = rows.skip(maxCount).map((r) => r.value).toList();
      await (delete(markerRecentEntries)
            ..where((t) => t.value.isIn(toDelete)))
          .go();
    }
  }

  Future<void> clearMarkerRecents() async {
    await delete(markerRecentEntries).go();
  }

  // ── CustomEmojiSets helpers ───────────────────────────────────────────────

  Future<List<CustomEmojiSetEntry>> getAllCustomEmojiSets() {
    return select(customEmojiSetEntries).get();
  }

  Future<void> upsertCustomEmojiSet(
    String id,
    String rawData,
    String definitions,
  ) async {
    await into(customEmojiSetEntries).insertOnConflictUpdate(
      CustomEmojiSetEntriesCompanion.insert(
        id: id,
        rawData: rawData,
        definitions: definitions,
      ),
    );
  }

  Future<void> deleteCustomEmojiSet(String id) async {
    await (delete(customEmojiSetEntries)..where((t) => t.id.equals(id))).go();
  }

  Future<void> replaceAllCustomEmojiSets(
    List<({String id, String rawData, String definitions})> sets,
  ) async {
    await transaction(() async {
      await delete(customEmojiSetEntries).go();
      for (final s in sets) {
        await into(customEmojiSetEntries).insert(
          CustomEmojiSetEntriesCompanion.insert(
            id: s.id,
            rawData: s.rawData,
            definitions: s.definitions,
          ),
        );
      }
    });
  }

  // ── CustomIconSets helpers ────────────────────────────────────────────────

  Future<List<CustomIconSetEntry>> getAllCustomIconSets() {
    return select(customIconSetEntries).get();
  }

  Future<void> upsertCustomIconSet(
    String id,
    String imageBytes,
    String tags,
  ) async {
    await into(customIconSetEntries).insertOnConflictUpdate(
      CustomIconSetEntriesCompanion.insert(
        id: id,
        imageBytes: imageBytes,
        tags: tags,
      ),
    );
  }

  Future<void> deleteCustomIconSet(String id) async {
    await (delete(customIconSetEntries)..where((t) => t.id.equals(id))).go();
  }

  Future<void> replaceAllCustomIconSets(
    List<({String id, String imageBytes, String tags})> icons,
  ) async {
    await transaction(() async {
      await delete(customIconSetEntries).go();
      for (final icon in icons) {
        await into(customIconSetEntries).insert(
          CustomIconSetEntriesCompanion.insert(
            id: icon.id,
            imageBytes: icon.imageBytes,
            tags: icon.tags,
          ),
        );
      }
    });
  }

  // ── DownloadHistory helpers ───────────────────────────────────────────────

  Future<List<DownloadHistoryEntry>> getDownloadHistoryPage({
    int limit = 50,
    int offset = 0,
  }) async {
    return (select(downloadHistoryEntries)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(limit, offset: offset))
        .get();
  }

  Future<int> getDownloadHistoryCount() async {
    final expr = downloadHistoryEntries.id.count();
    final query = selectOnly(downloadHistoryEntries)..addColumns([expr]);
    final result = await query.getSingle();
    return result.read(expr) ?? 0;
  }

  Future<DownloadHistoryEntry?> getDownloadHistoryEntry(String id) async {
    return (select(downloadHistoryEntries)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  Future<void> upsertDownloadHistoryEntry(
    DownloadHistoryEntriesCompanion entry,
  ) async {
    await into(downloadHistoryEntries).insertOnConflictUpdate(entry);
  }

  Future<void> deleteDownloadHistoryEntries(Set<String> ids) async {
    await (delete(downloadHistoryEntries)
          ..where((t) => t.id.isIn(ids.toList())))
        .go();
  }

  Future<void> clearAllDownloadHistory() async {
    await delete(downloadHistoryEntries).go();
  }

  Future<List<DownloadHistoryEntry>> getAllDownloadHistoryEntries() {
    return select(downloadHistoryEntries).get();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Connection factory
// ─────────────────────────────────────────────────────────────────────────────

QueryExecutor _openConnection() {
  // Use XDG data home: ~/.local/share/onyxcore/onyxcore.db
  final home = Platform.environment['HOME'] ?? '/tmp';
  final dbDir = Directory(p.join(home, '.local', 'share', 'onyxcore'));
  if (!dbDir.existsSync()) {
    dbDir.createSync(recursive: true);
  }
  final dbPath = p.join(dbDir.path, 'onyxcore.db');
  return driftDatabase(
    name: 'onyxcore',
    native: DriftNativeOptions(databasePath: () async => dbPath),
  );
}
