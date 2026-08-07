import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/core/database/app_database.dart';

class MockAppDatabase extends Mock implements AppDatabase {}

void main() {
  late ThumbnailCacheService cacheService;
  late MockAppDatabase mockDb;

  setUpAll(() {
    // Create dummy files for tests so lengthSync() > 0 logic passes
    File('/tmp/cache_normal.jpg')
      ..createSync()
      ..writeAsStringSync('dummy_data');
    File('/tmp/cache_large.jpg')
      ..createSync()
      ..writeAsStringSync('dummy_data');

    registerFallbackValue(
      ThumbnailCacheEntriesCompanion.insert(
        fileHash: 'dummy',
        filePath: 'dummy',
        mtime: 0,
        sizeBytes: 0,
        kind: 'dummy',
        status: 'dummy',
        generatedAt: 0,
      ),
    );
  });

  tearDownAll(() {
    final normalCache = File('/tmp/cache_normal.jpg');
    if (normalCache.existsSync()) normalCache.deleteSync();
    final largeCache = File('/tmp/cache_large.jpg');
    if (largeCache.existsSync()) largeCache.deleteSync();
  });

  setUp(() {
    mockDb = MockAppDatabase();
    cacheService = ThumbnailCacheService(mockDb);
  });

  group('ThumbnailCacheService', () {
    final mockEntry = ThumbnailCacheEntry(
      fileHash: AppDatabase.computeFileHash('/test.jpg'),
      filePath: '/test.jpg',
      mtime: 1000,
      sizeBytes: 2000,
      cacheFileNormal: '/tmp/cache_normal.jpg',
      cacheFileLarge: '/tmp/cache_large.jpg',
      kind: 'image',
      status: 'ready',
      generatedAt: 123456789,
    );

    test('load populates index from DB', () async {
      when(() => mockDb.getAllThumbnailEntries()).thenAnswer((_) async => [mockEntry]);

      await cacheService.load();

      // Check if loaded by doing a lookup
      final result = cacheService.lookup(
        filePath: '/test.jpg',
        mtime: 1000,
        sizeBytes: 2000,
      );
      expect(result, ThumbnailLookupResult.hit);
    });

    test('lookup handles miss when mtime changes', () async {
      when(() => mockDb.getAllThumbnailEntries()).thenAnswer((_) async => [mockEntry]);
      await cacheService.load();

      final result = cacheService.lookup(
        filePath: '/test.jpg',
        mtime: 1001, // Different mtime
        sizeBytes: 2000,
      );
      expect(result, ThumbnailLookupResult.miss);
    });

    test('lookup handles miss when size changes', () async {
      when(() => mockDb.getAllThumbnailEntries()).thenAnswer((_) async => [mockEntry]);
      await cacheService.load();

      final result = cacheService.lookup(
        filePath: '/test.jpg',
        mtime: 1000,
        sizeBytes: 2001, // Different size
      );
      expect(result, ThumbnailLookupResult.miss);
    });

    test('lookup handles failed status', () async {
      final failedEntry = ThumbnailCacheEntry(
        fileHash: AppDatabase.computeFileHash('/fail.jpg'),
        filePath: '/fail.jpg',
        mtime: 100,
        sizeBytes: 200,
        kind: 'video',
        status: 'failed',
        generatedAt: 123456789,
      );
      when(() => mockDb.getAllThumbnailEntries()).thenAnswer((_) async => [failedEntry]);
      await cacheService.load();

      final result = cacheService.lookup(
        filePath: '/fail.jpg',
        mtime: 100,
        sizeBytes: 200,
      );
      expect(result, ThumbnailLookupResult.failed);
    });

    test('lookup returns miss when cache files do not exist on disk', () async {
      final missingFileEntry = ThumbnailCacheEntry(
        fileHash: AppDatabase.computeFileHash('/missing_thumb.jpg'),
        filePath: '/missing_thumb.jpg',
        mtime: 1000,
        sizeBytes: 2000,
        cacheFileNormal: '/tmp/does_not_exist_normal.jpg',
        cacheFileLarge: '/tmp/does_not_exist_large.jpg',
        kind: 'image',
        status: 'ready',
        generatedAt: 123456789,
      );
      when(() => mockDb.getAllThumbnailEntries()).thenAnswer((_) async => [missingFileEntry]);
      await cacheService.load();

      final result = cacheService.lookup(
        filePath: '/missing_thumb.jpg',
        mtime: 1000,
        sizeBytes: 2000,
      );
      expect(result, ThumbnailLookupResult.miss);

      final path = cacheService.getCachedPath('/missing_thumb.jpg');
      expect(path, isNull);
    });

    test('lookup returns miss when cache file is 0 bytes (corrupt file)', () async {
      final zeroByteFile = File('/tmp/cache_zero_byte.jpg')..createSync();
      addTearDown(() {
        if (zeroByteFile.existsSync()) zeroByteFile.deleteSync();
      });

      final corruptEntry = ThumbnailCacheEntry(
        fileHash: AppDatabase.computeFileHash('/zero_byte.jpg'),
        filePath: '/zero_byte.jpg',
        mtime: 1000,
        sizeBytes: 2000,
        cacheFileNormal: '/tmp/cache_zero_byte.jpg',
        kind: 'image',
        status: 'ready',
        generatedAt: 123456789,
      );
      when(() => mockDb.getAllThumbnailEntries()).thenAnswer((_) async => [corruptEntry]);
      await cacheService.load();

      final result = cacheService.lookup(
        filePath: '/zero_byte.jpg',
        mtime: 1000,
        sizeBytes: 2000,
      );
      expect(result, ThumbnailLookupResult.miss);
      expect(cacheService.getCachedPath('/zero_byte.jpg'), isNull);
    });

    test('getCachedPath returns correct path', () async {
      when(() => mockDb.getAllThumbnailEntries()).thenAnswer((_) async => [mockEntry]);
      await cacheService.load();

      final normalPath = cacheService.getCachedPath('/test.jpg');
      final largePath = cacheService.getCachedPath('/test.jpg', size: ThumbnailSize.large);

      expect(normalPath, '/tmp/cache_normal.jpg');
      expect(largePath, '/tmp/cache_large.jpg');
    });

    test('lookupAsync returns correct result asynchronously', () async {
      when(() => mockDb.getAllThumbnailEntries()).thenAnswer((_) async => [mockEntry]);
      await cacheService.load();

      final result = await cacheService.lookupAsync(
        filePath: '/test.jpg',
        mtime: 1000,
        sizeBytes: 2000,
      );
      expect(result, ThumbnailLookupResult.hit);
    });

    test('getCachedPathAsync returns correct path asynchronously', () async {
      when(() => mockDb.getAllThumbnailEntries()).thenAnswer((_) async => [mockEntry]);
      await cacheService.load();

      final normalPath = await cacheService.getCachedPathAsync('/test.jpg');
      final largePath = await cacheService.getCachedPathAsync('/test.jpg', size: ThumbnailSize.large);

      expect(normalPath, '/tmp/cache_normal.jpg');
      expect(largePath, '/tmp/cache_large.jpg');
    });

    test('markFailed inserts failed entry to db and memory', () async {
      when(() => mockDb.markThumbnailFailed(
            fileHash: any(named: 'fileHash'),
            filePath: any(named: 'filePath'),
            mtime: any(named: 'mtime'),
            sizeBytes: any(named: 'sizeBytes'),
            kind: any(named: 'kind'),
          )).thenAnswer((_) async {});

      await cacheService.markFailed(
        filePath: '/fail.jpg',
        mtime: 100,
        sizeBytes: 200,
        kind: 'image',
      );

      final result = cacheService.lookup(
        filePath: '/fail.jpg',
        mtime: 100,
        sizeBytes: 200,
      );
      expect(result, ThumbnailLookupResult.failed);

      verify(() => mockDb.markThumbnailFailed(
            fileHash: AppDatabase.computeFileHash('/fail.jpg'),
            filePath: '/fail.jpg',
            mtime: 100,
            sizeBytes: 200,
            kind: 'image',
          )).called(1);
    });

    test('storeThumbnail upserts entry and copies file', () async {
      when(() => mockDb.upsertThumbnail(any())).thenAnswer((_) async {});

      // Use a real temp file with data so copy succeeds and lengthSync() > 0 passes
      final tempFile = File('/tmp/thumbnail_test_gen.jpg')
        ..createSync()
        ..writeAsStringSync('dummy_data');
      addTearDown(tempFile.deleteSync);

      await cacheService.storeThumbnail(
        filePath: '/new.jpg',
        mtime: 50,
        sizeBytes: 150,
        kind: 'image',
        thumbnailFile: tempFile,
      );

      final result = cacheService.lookup(
        filePath: '/new.jpg',
        mtime: 50,
        sizeBytes: 150,
      );
      expect(result, ThumbnailLookupResult.hit);

      verify(() => mockDb.upsertThumbnail(any())).called(1);

      // Verify the file was copied to cacheDir
      final cachePath = ThumbnailCacheService.computeCachePath('/new.jpg', ThumbnailSize.normal);
      final cacheFile = File(cachePath);
      expect(cacheFile.existsSync(), true);

      // Clean up cache file
      if (cacheFile.existsSync()) cacheFile.deleteSync();
    });

    test('removeEntries deletes files and db entries', () async {
      when(() => mockDb.getAllThumbnailEntries()).thenAnswer((_) async => [mockEntry]);
      when(() => mockDb.deleteThumbnailsForPaths(any())).thenAnswer((_) async {});

      await cacheService.load();

      // Create dummy cache files to test deletion
      final normalCache = File('/tmp/cache_normal.jpg')
        ..createSync()
        ..writeAsStringSync('dummy_data');
      final largeCache = File('/tmp/cache_large.jpg')
        ..createSync()
        ..writeAsStringSync('dummy_data');

      await cacheService.removeEntries(['/test.jpg']);

      expect(normalCache.existsSync(), false);
      expect(largeCache.existsSync(), false);

      final result = cacheService.lookup(
        filePath: '/test.jpg',
        mtime: 1000,
        sizeBytes: 2000,
      );
      expect(result, ThumbnailLookupResult.miss); // Since it was removed

      verify(() => mockDb.deleteThumbnailsForPaths(['/test.jpg'])).called(1);
    });

    test('removeEntriesForFolder deletes all entries for files inside folder and subfolders', () async {
      final entry1 = ThumbnailCacheEntry(
        fileHash: AppDatabase.computeFileHash('/my_folder/pic1.jpg'),
        filePath: '/my_folder/pic1.jpg',
        mtime: 1000,
        sizeBytes: 2000,
        cacheFileNormal: '/tmp/cache_normal_pic1.jpg',
        cacheFileLarge: '/tmp/cache_large_pic1.jpg',
        kind: 'image',
        status: 'ready',
        generatedAt: 123456789,
      );
      final entry2 = ThumbnailCacheEntry(
        fileHash: AppDatabase.computeFileHash('/my_folder/sub/pic2.jpg'),
        filePath: '/my_folder/sub/pic2.jpg',
        mtime: 1000,
        sizeBytes: 2000,
        cacheFileNormal: '/tmp/cache_normal_pic2.jpg',
        cacheFileLarge: '/tmp/cache_large_pic2.jpg',
        kind: 'image',
        status: 'ready',
        generatedAt: 123456789,
      );
      final entry3 = ThumbnailCacheEntry(
        fileHash: AppDatabase.computeFileHash('/other_folder/pic3.jpg'),
        filePath: '/other_folder/pic3.jpg',
        mtime: 1000,
        sizeBytes: 2000,
        cacheFileNormal: '/tmp/cache_normal_pic3.jpg',
        cacheFileLarge: '/tmp/cache_large_pic3.jpg',
        kind: 'image',
        status: 'ready',
        generatedAt: 123456789,
      );

      when(() => mockDb.getAllThumbnailEntries()).thenAnswer((_) async => [entry1, entry2, entry3]);
      when(() => mockDb.deleteThumbnailsForPaths(any())).thenAnswer((_) async {});

      await cacheService.load();

      final f1 = File('/tmp/cache_normal_pic1.jpg')..createSync()..writeAsStringSync('dummy');
      final f2 = File('/tmp/cache_normal_pic2.jpg')..createSync()..writeAsStringSync('dummy');
      final f3 = File('/tmp/cache_normal_pic3.jpg')..createSync()..writeAsStringSync('dummy');
      addTearDown(() {
        if (f1.existsSync()) f1.deleteSync();
        if (f2.existsSync()) f2.deleteSync();
        if (f3.existsSync()) f3.deleteSync();
      });

      await cacheService.removeEntriesForFolder('/my_folder');

      expect(f1.existsSync(), false);
      expect(f2.existsSync(), false);
      expect(f3.existsSync(), true);

      expect(cacheService.lookup(filePath: '/my_folder/pic1.jpg', mtime: 1000, sizeBytes: 2000), ThumbnailLookupResult.miss);
      expect(cacheService.lookup(filePath: '/my_folder/sub/pic2.jpg', mtime: 1000, sizeBytes: 2000), ThumbnailLookupResult.miss);
      expect(cacheService.lookup(filePath: '/other_folder/pic3.jpg', mtime: 1000, sizeBytes: 2000), ThumbnailLookupResult.hit);
    });
  });
}
