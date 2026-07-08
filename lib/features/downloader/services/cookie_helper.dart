import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// Shared cookie extraction utility used by all download engines.
///
/// Supports Firefox-based browsers (Firefox, LibreWolf, Waterfox) since
/// Chromium-based browsers encrypt their cookies on Linux.
class CookieHelper {
  static String? _cachedCookies;
  static DateTime? _cookiesCachedAt;
  static const Duration _cookieTTL = Duration(minutes: 5);

  @visibleForTesting
  static String? mockHome;

  @visibleForTesting
  static void clearCache() {
    _cachedCookies = null;
    _cookiesCachedAt = null;
  }

  /// Extract cookies from the specified browser's SQLite database.
  ///
  /// If [domain] is provided, only cookies matching that domain pattern are
  /// extracted. Defaults to Instagram/Facebook domains for backwards
  /// compatibility.
  static Future<String?> extractCookies(
    String? browser, {
    String? domain,
  }) async {
    if (browser == null || browser == 'None' || browser.isEmpty) return null;

    // Only Firefox-based browsers are supported for direct SQLite extraction
    if (!browser.toLowerCase().contains('firefox') &&
        !browser.toLowerCase().contains('librewolf') &&
        !browser.toLowerCase().contains('waterfox')) {
      return null;
    }

    if (_cachedCookies != null &&
        _cookiesCachedAt != null &&
        DateTime.now().difference(_cookiesCachedAt!) < _cookieTTL) {
      return _cachedCookies;
    }

    // Invalidate stale cache
    _cachedCookies = null;
    _cookiesCachedAt = null;

    final home = mockHome ?? Platform.environment['HOME'] ?? '';
    final possiblePaths = [
      p.join(home, '.mozilla', 'firefox'),
      p.join(home, 'snap', 'firefox', 'common', '.mozilla', 'firefox'),
      p.join(home, '.var', 'app', 'org.mozilla.firefox', '.mozilla', 'firefox'),
      p.join(home, '.librewolf'),
      p.join(home, '.waterfox'),
    ];

    File? cookieDb;

    for (final base in possiblePaths) {
      final dir = Directory(base);
      if (dir.existsSync()) {
        final profiles = dir.listSync().whereType<Directory>();
        for (final profile in profiles) {
          final dbFile = File(p.join(profile.path, 'cookies.sqlite'));
          if (dbFile.existsSync()) {
            cookieDb = dbFile;
            break;
          }
        }
      }
      if (cookieDb != null) break;
    }

    if (cookieDb == null) return null;

    final tmpFile = File(
      p.join(
        Directory.systemTemp.path,
        'onyx_cookies_${DateTime.now().millisecondsSinceEpoch}.sqlite',
      ),
    );
    try {
      await cookieDb.copy(tmpFile.path);
      final db = sqlite3.open(tmpFile.path);

      // Use domain-specific filter if provided, otherwise default to Instagram/Facebook
      final domainFilter =
          domain ??
          "host LIKE '%instagram%' OR host LIKE '%cdninstagram%' OR host LIKE '%fbcdn%'";

      final rows = db.select(
        'SELECT name, value FROM moz_cookies WHERE $domainFilter',
      );

      final cookies = <String>[];
      for (final row in rows) {
        cookies.add('${row['name']}=${row['value']}');
      }

      db.dispose();
      await tmpFile.delete();

      _cachedCookies = cookies.join('; ');
      _cookiesCachedAt = DateTime.now();
      return _cachedCookies;
    } catch (e) {
      debugPrint('[CookieHelper] Cookie extraction failed: $e');
      if (tmpFile.existsSync()) {
        await tmpFile.delete();
      }
      return null;
    }
  }
}
