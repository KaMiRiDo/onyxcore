import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../database/app_database.dart';

/// Size tier for cached thumbnails, matching freedesktop convention.
enum ThumbnailSize {
  /// 128px — used in grid views.
  normal(128),

  /// 256px — used for larger previews.
  large(256);

  const ThumbnailSize(this.pixels);
  final int pixels;
}

/// Result of a thumbnail cache lookup.
enum ThumbnailLookupResult {
  /// A valid cached thumbnail exists. Use [ThumbnailCacheService.getCachedPath].
  hit,

  /// The file was previously attempted and failed. Show fallback icon.
  failed,

  /// No valid cache entry exists. Queue for generation.
  miss,
}

/// Freedesktop-style global thumbnail cache service.
///
/// Provides a single global cache at `~/.cache/onyxcore/thumbnails/`
/// keyed by MD5 hash of each file's `file://` URI. Thumbnails are
/// invalidated when the source file's mtime or size changes.
///
/// This service is the single source of truth for thumbnail caching,
/// replacing the ad-hoc per-widget caching patterns.
class ThumbnailCacheService {
  ThumbnailCacheService(this._db);

  final AppDatabase _db;

  /// In-memory index for fast synchronous lookups.
  /// Maps fileHash → cache entry.
  final Map<String, ThumbnailCacheEntry> _index = {};

  final Completer<void> _initCompleter = Completer<void>();

  /// Whether the in-memory index has been loaded from DB.
  bool _loaded = false;

  /// Ensure the index is loaded from the database.
  Future<void> ensureLoaded() => _initCompleter.future;

  /// Base cache directory.
  static String get _cacheBase {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return '$home/.cache/onyxcore/thumbnails';
  }

  /// Get the cache directory for a given size tier.
  static String _cacheDirForSize(ThumbnailSize size) {
    return '$_cacheBase/${size.name}';
  }

  /// Ensure cache directories exist.
  static Future<void> ensureCacheDirs() async {
    for (final size in ThumbnailSize.values) {
      final dir = Directory(_cacheDirForSize(size));
      if (!dir.existsSync()) {
        await dir.create(recursive: true);
      }
    }
  }

  /// Load all thumbnail cache entries from DB into memory.
  /// Should be called once at startup.
  Future<void> load() async {
    if (_loaded) return;
    try {
      final entries = await _db.getAllThumbnailEntries();
      for (final entry in entries) {
        _index[entry.fileHash] = entry;
      }
      _loaded = true;
      _initCompleter.complete();
    } catch (e) {
      debugPrint('ThumbnailCacheService: Failed to load index: $e');
      if (!_initCompleter.isCompleted) _initCompleter.complete();
    }
  }

  /// Compute the cache file path for a given file and size.
  static String computeCachePath(String absolutePath, ThumbnailSize size) {
    final hash = AppDatabase.computeFileHash(absolutePath);
    return '${_cacheDirForSize(size)}/$hash.jpg';
  }

  /// Look up the thumbnail cache for a file.
  ///
  /// Returns [ThumbnailLookupResult.hit] if a valid cached thumbnail exists,
  /// [ThumbnailLookupResult.failed] if the file was previously attempted and
  /// failed, or [ThumbnailLookupResult.miss] if no valid entry exists.
  ///
  /// [mtime] and [sizeBytes] are the current file's stat values — used to
  /// validate that the cached entry is still fresh.
  ThumbnailLookupResult lookup({
    required String filePath,
    required int mtime,
    required int sizeBytes,
  }) {
    final hash = AppDatabase.computeFileHash(filePath);
    final entry = _index[hash];

    if (entry == null) return ThumbnailLookupResult.miss;

    // Check staleness: mtime or size changed → treat as miss
    if (entry.mtime != mtime || entry.sizeBytes != sizeBytes) {
      return ThumbnailLookupResult.miss;
    }

    if (entry.status == 'failed') return ThumbnailLookupResult.failed;
    if (entry.status == 'ready') {
      bool valid = false;
      if (entry.cacheFileNormal != null) {
        final f = File(entry.cacheFileNormal!);
        if (f.existsSync() && f.lengthSync() > 0) valid = true;
      }
      if (entry.cacheFileLarge != null) {
        final f = File(entry.cacheFileLarge!);
        if (f.existsSync() && f.lengthSync() > 0) valid = true;
      }
      if (valid) return ThumbnailLookupResult.hit;
    }

    // 'pending' or unknown status → miss
    return ThumbnailLookupResult.miss;
  }

  /// Get the cached thumbnail path for a file (synchronous, from memory).
  ///
  /// Returns the path for the requested [size], or falls back to any
  /// available size. Returns null if no cached thumbnail exists.
  String? getCachedPath(String filePath, {ThumbnailSize size = ThumbnailSize.normal}) {
    final hash = AppDatabase.computeFileHash(filePath);
    final entry = _index[hash];
    if (entry == null || entry.status != 'ready') return null;

    if (size == ThumbnailSize.normal) {
      final path = entry.cacheFileNormal ?? entry.cacheFileLarge;
      if (path != null) {
        final f = File(path);
        if (f.existsSync() && f.lengthSync() > 0) return path;
      }
      return null;
    } else {
      final path = entry.cacheFileLarge ?? entry.cacheFileNormal;
      if (path != null) {
        final f = File(path);
        if (f.existsSync() && f.lengthSync() > 0) return path;
      }
      return null;
    }
  }

  /// Store a successfully generated thumbnail in the cache.
  ///
  /// [thumbnailFile] is the generated thumbnail file on disk.
  /// This copies it to the canonical cache location and updates the DB + index.
  Future<void> storeThumbnail({
    required String filePath,
    required int mtime,
    required int sizeBytes,
    required String kind,
    required File thumbnailFile,
    ThumbnailSize size = ThumbnailSize.normal,
  }) async {
    final hash = AppDatabase.computeFileHash(filePath);
    final cachePath = '${_cacheDirForSize(size)}/$hash.jpg';

    try {
      // Ensure target directory exists
      await ensureCacheDirs();

      // Copy (or move) the thumbnail to the canonical cache location
      if (thumbnailFile.path != cachePath) {
        await thumbnailFile.copy(cachePath);
      }

      // Look up existing entry to preserve the other size tier's path
      final existing = _index[hash];

      final normalPath = size == ThumbnailSize.normal
          ? cachePath
          : existing?.cacheFileNormal;
      final largePath = size == ThumbnailSize.large
          ? cachePath
          : existing?.cacheFileLarge;

      final companion = ThumbnailCacheEntriesCompanion.insert(
        fileHash: hash,
        filePath: filePath,
        mtime: mtime,
        sizeBytes: sizeBytes,
        cacheFileNormal: Value(normalPath),
        cacheFileLarge: Value(largePath),
        kind: kind,
        status: 'ready',
        generatedAt: DateTime.now().millisecondsSinceEpoch,
      );

      await _db.upsertThumbnail(companion);

      // Update in-memory index
      _index[hash] = ThumbnailCacheEntry(
        fileHash: hash,
        filePath: filePath,
        mtime: mtime,
        sizeBytes: sizeBytes,
        cacheFileNormal: normalPath,
        cacheFileLarge: largePath,
        kind: kind,
        status: 'ready',
        generatedAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('ThumbnailCacheService: Failed to store thumbnail for $filePath: $e');
    }
  }

  /// Mark a file as failed to thumbnail (negative cache).
  ///
  /// The file won't be retried until its mtime/size changes.
  Future<void> markFailed({
    required String filePath,
    required int mtime,
    required int sizeBytes,
    required String kind,
  }) async {
    final hash = AppDatabase.computeFileHash(filePath);

    try {
      await _db.markThumbnailFailed(
        fileHash: hash,
        filePath: filePath,
        mtime: mtime,
        sizeBytes: sizeBytes,
        kind: kind,
      );

      _index[hash] = ThumbnailCacheEntry(
        fileHash: hash,
        filePath: filePath,
        mtime: mtime,
        sizeBytes: sizeBytes,
        cacheFileNormal: null,
        cacheFileLarge: null,
        kind: kind,
        status: 'failed',
        generatedAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('ThumbnailCacheService: Failed to mark failure for $filePath: $e');
    }
  }

  /// Remove cache entries for specific file paths (e.g., when files are deleted).
  Future<void> removeEntries(List<String> paths) async {
    for (final path in paths) {
      final hash = AppDatabase.computeFileHash(path);
      final entry = _index.remove(hash);

      // Delete cached files from disk
      if (entry != null) {
        if (entry.cacheFileNormal != null) {
          try {
            await File(entry.cacheFileNormal!).delete();
          } catch (_) {}
        }
        if (entry.cacheFileLarge != null) {
          try {
            await File(entry.cacheFileLarge!).delete();
          } catch (_) {}
        }
      }
    }

    try {
      await _db.deleteThumbnailsForPaths(paths);
    } catch (e) {
      debugPrint('ThumbnailCacheService: Failed to delete entries: $e');
    }
  }
}
