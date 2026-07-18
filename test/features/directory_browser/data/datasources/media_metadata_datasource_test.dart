import 'dart:io';

import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/cache/metadata_cache.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/features/directory_browser/data/datasources/media_metadata_datasource.dart';
import 'package:path/path.dart' as p;

void main() {
  late MetadataCache cache;
  late MediaMetadataDatasource datasource;

  late AppDatabase db;

  setUpAll(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDownAll(() async {
    await db.close();
  });

  setUp(() async {
    cache = MetadataCache(db);
    // Since load() is fire-and-forget in the app but we need it here:
    await cache.load();
    datasource = MediaMetadataDatasource(cache);
  });

  group('MediaMetadataDatasource', () {
    test('getCachedAspectRatio returns null if not cached', () {
      expect(datasource.getCachedAspectRatio('/path/to/file.png'), isNull);
    });

    test('getCachedAspectRatio returns value if cached', () async {
      await cache.saveRatio('/path/to/file.png', 1.777);
      expect(datasource.getCachedAspectRatio('/path/to/file.png'), 1.777);
    });

    test('extractAspectRatio returns cached value immediately without process run', () async {
      await cache.saveRatio('/path/to/file.png', 2);
      final result = await datasource.extractAspectRatio('/path/to/file.png');
      expect(result, 2.0);
    });



    test('extractAspectRatio returns 1.0 if process fails / file missing', () async {
      final result = await datasource.extractAspectRatio('/path/to/non_existent.mp4');

      expect(result, 1.0);
      expect(datasource.getCachedAspectRatio('/path/to/non_existent.mp4'), isNull);
    });

    test('extractAspectRatios returns batched results with fallbacks', () async {
      // These files don't exist, so ffprobe fails and it falls back to 1.0
      final result = await datasource.extractAspectRatios([
        '/path/to/file1.png',
        '/path/to/file2.mp4',
        '/path/to/missing.png',
      ]);

      expect(result.length, 3);
      expect(result['/path/to/file1.png'], 1.0);
      expect(result['/path/to/file2.mp4'], 1.0);
      expect(result['/path/to/missing.png'], 1.0);
    });
  });
}
