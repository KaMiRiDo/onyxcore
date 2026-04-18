import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent cache for file metadata (image aspect ratios, etc.)
///
/// Wraps SharedPreferences with isolate-based serialization to avoid
/// blocking the main thread when serializing large cache maps.
class MetadataCache {
  MetadataCache(this._prefs);

  final SharedPreferences _prefs;
  Map<String, double> _aspectRatios = {};

  static const _cacheKey = 'imageAspectRatioCache';

  /// The in-memory aspect ratio cache, keyed by file path.
  Map<String, double> get aspectRatios => _aspectRatios;

  /// Load the cache from SharedPreferences.
  void load() {
    final raw = _prefs.getString(_cacheKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _aspectRatios = decoded.map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        );
      } catch (_) {
        _aspectRatios = {};
      }
    }
  }

  /// Save a single aspect ratio to the cache.
  Future<void> saveRatio(String path, double ratio) async {
    _aspectRatios[path] = ratio;
    await _persist();
  }

  /// Save multiple aspect ratios at once.
  Future<void> saveRatioBatch(Map<String, double> ratios) async {
    _aspectRatios.addAll(ratios);
    await _persist();
  }

  /// Remove a single entry from the cache.
  Future<void> removeRatio(String path) async {
    if (_aspectRatios.containsKey(path)) {
      _aspectRatios.remove(path);
      await _persist();
    }
  }

  /// Remove all entries whose paths start with [folderPath].
  Future<void> removeForFolder(String folderPath) async {
    final keysToRemove =
        _aspectRatios.keys.where((k) => k.startsWith(folderPath)).toList();
    if (keysToRemove.isEmpty) return;

    for (final key in keysToRemove) {
      _aspectRatios.remove(key);
    }
    await _persist();
  }

  /// Remove multiple specific entries by path.
  Future<void> removeBatch(List<String> paths) async {
    var changed = false;
    for (final path in paths) {
      if (_aspectRatios.containsKey(path)) {
        _aspectRatios.remove(path);
        changed = true;
      }
    }
    if (changed) await _persist();
  }

  Future<void> _persist() async {
    final encoded = await compute(_serializeMap, _aspectRatios);
    await _prefs.setString(_cacheKey, encoded);
  }

  static String _serializeMap(Map<String, double> cache) => jsonEncode(cache);
}
