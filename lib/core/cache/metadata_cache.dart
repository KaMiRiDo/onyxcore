import 'package:onyxcore/core/database/app_database.dart';

/// Persistent cache for file metadata (image aspect ratios, etc.)
///
/// Backed by the [MetadataCacheEntries] Drift table. Maintains an in-memory
/// copy for fast synchronous reads — the DB is the authoritative persistent
/// store.
class MetadataCache {
  MetadataCache(this._db);

  static const int maxCacheSize = 5000;

  final AppDatabase _db;
  Map<String, double> _aspectRatios = {};

  /// The in-memory aspect ratio cache, keyed by file path.
  Map<String, double> get aspectRatios => _aspectRatios;

  /// Load all cached aspect ratios from the database into memory.
  Future<void> load() async {
    // Perform LRU pruning before loading to keep memory in check.
    await _db.pruneMetadataCache(maxCacheSize);
    final rows = await _db.getAllMetadataCache();
    _aspectRatios = {for (final r in rows) r.filePath: r.aspectRatio};
  }

  /// Save a single aspect ratio to the cache.
  Future<void> saveRatio(String path, double ratio) async {
    _aspectRatios[path] = ratio;
    await _db.upsertMetadataCache(path, ratio);
  }

  /// Save multiple aspect ratios at once.
  Future<void> saveRatioBatch(Map<String, double> ratios) async {
    _aspectRatios.addAll(ratios);
    await Future.wait(
      ratios.entries.map((e) => _db.upsertMetadataCache(e.key, e.value)),
    );
    await _pruneIfNeeded();
  }

  Future<void> _pruneIfNeeded() async {
    if (_aspectRatios.length > maxCacheSize) {
      final removedPaths = await _db.pruneMetadataCache(maxCacheSize);
      for (final path in removedPaths) {
        _aspectRatios.remove(path);
      }
    }
  }

  /// Remove a single entry from the cache.
  Future<void> removeRatio(String path) async {
    if (_aspectRatios.containsKey(path)) {
      _aspectRatios.remove(path);
      await _db.deleteMetadataCache(path);
    }
  }

  /// Remove all entries whose paths start with [folderPath].
  Future<void> removeForFolder(String folderPath) async {
    _aspectRatios.removeWhere((k, _) => k.startsWith(folderPath));
    await _db.deleteMetadataCacheForFolder(folderPath);
  }

  /// Remove multiple specific entries by path.
  Future<void> removeBatch(List<String> paths) async {
    for (final path in paths) {
      _aspectRatios.remove(path);
    }
    await _db.deleteMetadataCacheBatch(paths);
  }
}
