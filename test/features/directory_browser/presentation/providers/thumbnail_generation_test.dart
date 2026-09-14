import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/thumbnail_session.dart';
import 'package:path/path.dart' as p;

void main() {
  late AppDatabase db;
  late ThumbnailCacheService cacheService;
  late ThumbnailSession session;
  late Directory tempCacheDir;

  setUpAll(() async {
    // Create a temporary cache directory for the tests
    tempCacheDir = Directory.systemTemp.createTempSync('thumbnail_test_cache_');

    // Initialize a test database in memory
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));

    // Provide a mocked ThumbnailCacheService that uses a real DB for integration testing
    cacheService = ThumbnailCacheService(db);
    await cacheService.load();
  });

  setUp(() {
    session = ThumbnailSession(
      folderPath: '/test/media',
      tabId: 'tab_1',
      cacheService: cacheService,
    );
  });

  tearDown(() {
    session.dispose();
  });

  tearDownAll(() async {
    await db.close();
    if (tempCacheDir.existsSync()) {
      tempCacheDir.deleteSync(recursive: true);
    }
  });

  test('generateMediaThumbnail creates thumbnails for all dummy formats successfully', () async {
    final mediaDir = Directory('test/resources/media');
    if (!mediaDir.existsSync()) {
      fail('Media resources directory not found. Tests must run from project root.');
    }

    final dummyFiles = mediaDir.listSync().whereType<File>().toList();
    expect(dummyFiles.isNotEmpty, isTrue, reason: 'No dummy files found in test/resources/media');

    for (final file in dummyFiles) {
      final ext = p.extension(file.path).toLowerCase();
      final isVideo = ext == '.mp4';

      final item = FileItem(
        path: file.path,
        name: p.basename(file.path),
        type: isVideo ? FileItemType.video : FileItemType.image,
        sizeBytes: file.lengthSync(),
        modified: file.lastModifiedSync(),
      );

      // Extend interest so the session treats this as a current job
      final candidate = ThumbnailCandidate.fromFileItem(item);
      session.updateViewportInterest(
        candidates: [candidate],
        visiblePaths: {item.path},
      );

      final outcome = await session.enqueueCandidate(candidate);

      expect(
        outcome,
        ThumbnailJobOutcome.success,
        reason: 'Failed to generate thumbnail for format: $ext',
      );

      // Verify a file was actually placed in the cache and has size > 0
      final expectedPath = ThumbnailCacheService.computeCachePath(file.path, ThumbnailSize.normal);
      final cacheFile = File(expectedPath);
      expect(cacheFile.existsSync(), isTrue, reason: 'Cache file missing for $ext at $expectedPath');
      expect(cacheFile.lengthSync() > 0, isTrue, reason: 'Cache file is empty for $ext');
    }
  });
}
