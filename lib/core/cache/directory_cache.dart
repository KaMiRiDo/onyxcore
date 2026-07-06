/// In-memory LRU cache for directory listings.
///
/// Provides instant re-loading of previously visited directories
/// while background verification ensures cache freshness.
/// Integrates with [DirectoryWatcher] to auto-invalidate on inotify events.
class DirectoryCache<T> {
  DirectoryCache({
    this.maxEntries = 50,
    this.ttl = const Duration(seconds: 60),
  });

  final int maxEntries;
  final Duration ttl;
  final Map<String, _CacheEntry<T>> _cache = {};

  /// Retrieve a cached value for [key], or null if expired/missing.
  T? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (DateTime.now().difference(entry.timestamp) > ttl) {
      _cache.remove(key);
      return null;
    }

    // Move to end (most recently used)
    _cache.remove(key);
    _cache[key] = entry;
    return entry.value;
  }

  /// Store a value in the cache.
  void put(String key, T value) {
    _cache.remove(key); // Remove first to re-insert at end
    if (_cache.length >= maxEntries) {
      _cache.remove(_cache.keys.first); // Evict LRU
    }
    _cache[key] = _CacheEntry(value: value, timestamp: DateTime.now());
  }

  /// Invalidate a specific cache entry.
  void invalidate(String key) => _cache.remove(key);

  /// Invalidate a key and all its descendants.
  void invalidateRecursive(String key) {
    _cache.removeWhere((k, _) => k == key || k.startsWith(key + '/'));
  }

  /// Invalidate all cache entries.
  void invalidateAll() => _cache.clear();

  /// Check if a key exists (and is not expired) in the cache.
  bool has(String key) => get(key) != null;
}

class _CacheEntry<T> {
  const _CacheEntry({required this.value, required this.timestamp});

  final T value;
  final DateTime timestamp;
}
