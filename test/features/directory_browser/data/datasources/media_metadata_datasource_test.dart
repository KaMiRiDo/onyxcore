import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onyxcore/core/cache/metadata_cache.dart';
import 'package:onyxcore/features/directory_browser/data/datasources/media_metadata_datasource.dart';
import 'package:path/path.dart' as p;

void main() {
  late MetadataCache cache;
  late MediaMetadataDatasource datasource;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    cache = MetadataCache(prefs);
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
      await cache.saveRatio('/path/to/file.png', 2.0);
      final result = await datasource.extractAspectRatio('/path/to/file.png');
      expect(result, 2.0);
    });

    test('extractAspectRatio runs ffprobe and caches correct ratio on success (integration)', () async {
      final currentDir = Directory.current.path;
      final testImagePath = p.join(currentDir, 'test', 'features', 'directory_browser', 'data', 'datasources', 'test_1280x720.jpg');
      
      final result = await datasource.extractAspectRatio(testImagePath);

      expect(result, closeTo(1280 / 720, 0.001));
      expect(datasource.getCachedAspectRatio(testImagePath), closeTo(1280 / 720, 0.001));
    });

    test('extractAspectRatio returns 1.0 if process fails / file missing', () async {
      final result = await datasource.extractAspectRatio('/path/to/non_existent.mp4');

      expect(result, 1.0);
      expect(datasource.getCachedAspectRatio('/path/to/non_existent.mp4'), isNull);
    });
  });
}
