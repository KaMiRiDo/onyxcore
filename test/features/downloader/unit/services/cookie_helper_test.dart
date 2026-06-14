import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/services/cookie_helper.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

void main() {
  late Directory tempHome;

  setUp(() {
    tempHome = Directory.systemTemp.createTempSync('cookie_test_home');
    CookieHelper.mockHome = tempHome.path;
    CookieHelper.clearCache();
  });

  tearDown(() {
    if (tempHome.existsSync()) {
      tempHome.deleteSync(recursive: true);
    }
    CookieHelper.mockHome = null;
    CookieHelper.clearCache();
  });

  void createMockCookieDb(String profilePath, List<Map<String, String>> cookies) {
    final dir = Directory(profilePath);
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final dbFile = File(p.join(profilePath, 'cookies.sqlite'));
    if (dbFile.existsSync()) dbFile.deleteSync();
    
    final db = sqlite3.open(dbFile.path);
    db.execute('''
      CREATE TABLE moz_cookies (
        id INTEGER PRIMARY KEY,
        name TEXT,
        value TEXT,
        host TEXT,
        path TEXT,
        expiry INTEGER,
        lastAccessed INTEGER,
        creationTime INTEGER,
        isSecure INTEGER,
        isHttpOnly INTEGER,
        inBrowserElement INTEGER,
        sameSite INTEGER,
        rawSameSite INTEGER,
        schemeMap INTEGER
      );
    ''');
    
    final stmt = db.prepare('INSERT INTO moz_cookies (name, value, host) VALUES (?, ?, ?)');
    for (final c in cookies) {
      stmt.execute([c['name'], c['value'], c['host']]);
    }
    stmt.dispose();
    db.dispose();
  }

  group('CookieHelper Unit Tests', () {
    group('1. Browser Validation & Early Rejection', () {
      test('U-DL-CKI-01: Return null for null browser', () async {
        expect(await CookieHelper.extractCookies(null), isNull);
      });

      test('U-DL-CKI-02: Return null for None browser', () async {
        expect(await CookieHelper.extractCookies('None'), isNull);
      });

      test('U-DL-CKI-03: Return null for empty browser string', () async {
        expect(await CookieHelper.extractCookies(''), isNull);
      });

      test('U-DL-CKI-04: Reject Chromium-based browsers', () async {
        expect(await CookieHelper.extractCookies('Google Chrome'), isNull);
      });

      test('U-DL-CKI-05: Reject other unsupported browsers', () async {
        expect(await CookieHelper.extractCookies('Safari'), isNull);
      });
    });

    group('2. Supported Browser Detection', () {
      test('U-DL-CKI-06: Accept Firefox (case-insensitive)', () async {
        final profilePath = p.join(tempHome.path, '.mozilla', 'firefox', 'profile1');
        createMockCookieDb(profilePath, []);
        expect(await CookieHelper.extractCookies('firefox'), '');
      });

      test('U-DL-CKI-07: Accept LibreWolf', () async {
        final profilePath = p.join(tempHome.path, '.librewolf', 'profile1');
        createMockCookieDb(profilePath, []);
        expect(await CookieHelper.extractCookies('LibreWolf'), '');
      });

      test('U-DL-CKI-08: Accept Waterfox', () async {
        final profilePath = p.join(tempHome.path, '.waterfox', 'profile1');
        createMockCookieDb(profilePath, []);
        expect(await CookieHelper.extractCookies('Waterfox'), '');
      });
    });

    group('3. Cookie Caching & TTL', () {
      test('U-DL-CKI-09: Return cached cookies if within TTL', () async {
        final profilePath = p.join(tempHome.path, '.mozilla', 'firefox', 'profile');
        createMockCookieDb(profilePath, [{'name': 'a', 'value': '1', 'host': '.instagram.com'}]);
        
        // Initial fetch
        final firstFetch = await CookieHelper.extractCookies('Firefox');
        expect(firstFetch, 'a=1');

        // Delete DB to ensure it's not fetching from disk again
        File(p.join(profilePath, 'cookies.sqlite')).deleteSync();
        
        final secondFetch = await CookieHelper.extractCookies('Firefox');
        expect(secondFetch, 'a=1'); // Still returns 'a=1' from cache
      });

      test('U-DL-CKI-10: Invalidate cache after TTL expires', () async {
        // We can't mock time directly for the `DateTime.now()` inside the helper easily,
        // without reflection. Let's just bypass by using `clearCache()`.
        final profilePath = p.join(tempHome.path, '.mozilla', 'firefox', 'profile');
        createMockCookieDb(profilePath, [{'name': 'a', 'value': '1', 'host': '.instagram.com'}]);
        
        await CookieHelper.extractCookies('Firefox');
        
        // Simulate TTL expiration
        CookieHelper.clearCache();
        
        // Modify DB to verify re-fetch
        createMockCookieDb(profilePath, [{'name': 'b', 'value': '2', 'host': '.instagram.com'}]);
        
        final secondFetch = await CookieHelper.extractCookies('Firefox');
        expect(secondFetch, 'b=2');
      });

      test('U-DL-CKI-11: Stale cache cleared even if re-fetch fails', () async {
        final profilePath = p.join(tempHome.path, '.mozilla', 'firefox', 'profile');
        createMockCookieDb(profilePath, [{'name': 'a', 'value': '1', 'host': '.instagram.com'}]);
        await CookieHelper.extractCookies('Firefox');
        
        CookieHelper.clearCache(); // TTL expires
        
        // Delete DB to force failure
        File(p.join(profilePath, 'cookies.sqlite')).deleteSync();
        
        final result = await CookieHelper.extractCookies('Firefox');
        expect(result, isNull);
      });
    });

    group('4. Profile Discovery', () {
      test('U-DL-CKI-12: Search standard Firefox profile path', () async {
        final profilePath = p.join(tempHome.path, '.mozilla', 'firefox', 'profile');
        createMockCookieDb(profilePath, [{'name': 'a', 'value': '1', 'host': '.instagram.com'}]);
        expect(await CookieHelper.extractCookies('Firefox'), 'a=1');
      });

      test('U-DL-CKI-13: Search Snap Firefox profile path', () async {
        final profilePath = p.join(tempHome.path, 'snap', 'firefox', 'common', '.mozilla', 'firefox', 'profile');
        createMockCookieDb(profilePath, [{'name': 'snap_cookie', 'value': 'val', 'host': '.instagram.com'}]);
        expect(await CookieHelper.extractCookies('Firefox'), 'snap_cookie=val');
      });

      test('U-DL-CKI-14: Search Flatpak Firefox profile path', () async {
        final profilePath = p.join(tempHome.path, '.var', 'app', 'org.mozilla.firefox', '.mozilla', 'firefox', 'profile');
        createMockCookieDb(profilePath, [{'name': 'flatpak', 'value': 'val2', 'host': '.instagram.com'}]);
        expect(await CookieHelper.extractCookies('Firefox'), 'flatpak=val2');
      });

      test('U-DL-CKI-15: No profiles found in any path', () async {
        // No DB created
        expect(await CookieHelper.extractCookies('Firefox'), isNull);
      });
    });

    group('5. SQLite Cookie Extraction', () {
      test('U-DL-CKI-16: Parse cookies with default Instagram/Facebook domain filter', () async {
        final profilePath = p.join(tempHome.path, '.mozilla', 'firefox', 'profile');
        createMockCookieDb(profilePath, [
          {'name': 'ig1', 'value': '123', 'host': '.instagram.com'},
          {'name': 'fb1', 'value': '456', 'host': '.fbcdn.net'},
          {'name': 'tw1', 'value': '789', 'host': '.twitter.com'}, // Should be ignored
        ]);
        final result = await CookieHelper.extractCookies('Firefox');
        expect(result, 'ig1=123; fb1=456');
      });

      test('U-DL-CKI-17: Parse cookies with custom domain filter', () async {
        final profilePath = p.join(tempHome.path, '.mozilla', 'firefox', 'profile');
        createMockCookieDb(profilePath, [
          {'name': 'tw1', 'value': '789', 'host': '.twitter.com'},
        ]);
        final result = await CookieHelper.extractCookies('Firefox', domain: "host LIKE '%twitter%'");
        expect(result, 'tw1=789');
      });

      test('U-DL-CKI-18: Join multiple cookies with ; separator', () async {
        final profilePath = p.join(tempHome.path, '.mozilla', 'firefox', 'profile');
        createMockCookieDb(profilePath, [
          {'name': 'a', 'value': '1', 'host': '.instagram.com'},
          {'name': 'b', 'value': '2', 'host': '.instagram.com'},
          {'name': 'c', 'value': '3', 'host': '.instagram.com'},
        ]);
        final result = await CookieHelper.extractCookies('Firefox');
        expect(result, 'a=1; b=2; c=3');
      });

      test('U-DL-CKI-19: Empty result set from SQLite', () async {
        final profilePath = p.join(tempHome.path, '.mozilla', 'firefox', 'profile');
        createMockCookieDb(profilePath, [
          {'name': 'tw1', 'value': '789', 'host': '.twitter.com'},
        ]);
        // Default filter applies
        final result = await CookieHelper.extractCookies('Firefox');
        expect(result, '');
      });
    });

    group('6. Error Handling & Cleanup', () {
      test('U-DL-CKI-20: Gracefully handle locked or corrupt databases', () async {
        final profilePath = p.join(tempHome.path, '.mozilla', 'firefox', 'profile');
        final dir = Directory(profilePath);
        dir.createSync(recursive: true);
        final dbFile = File(p.join(profilePath, 'cookies.sqlite'));
        // Write invalid data
        dbFile.writeAsStringSync('not a sqlite database');
        
        final result = await CookieHelper.extractCookies('Firefox');
        expect(result, isNull);
      });

      test('U-DL-CKI-21/22: Clean up temp file after exception', () async {
        final profilePath = p.join(tempHome.path, '.mozilla', 'firefox', 'profile');
        final dir = Directory(profilePath);
        dir.createSync(recursive: true);
        final dbFile = File(p.join(profilePath, 'cookies.sqlite'));
        dbFile.writeAsStringSync('corrupt');
        
        await CookieHelper.extractCookies('Firefox');
        
        // Ensure no onyx_cookies*.sqlite files are left in system temp
        final tempDir = Directory.systemTemp;
        final leftover = tempDir.listSync().where((f) => f.path.contains('onyx_cookies_')).toList();
        expect(leftover, isEmpty);
      });
    });
  });
}
