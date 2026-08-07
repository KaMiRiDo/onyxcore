import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/cache/directory_cache.dart';
import 'package:onyxcore/core/cache/metadata_cache.dart';
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/core/platform/directory_watcher.dart';
import 'package:onyxcore/features/directory_browser/data/datasources/local_file_datasource.dart';
import 'package:onyxcore/features/directory_browser/data/repositories/directory_repository_impl.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

class MockLocalFileDatasource extends Mock implements LocalFileDatasource {}
class MockDirectoryCache extends Mock implements DirectoryCache<List<FileItem>> {}
class MockDirectoryWatcher extends Mock implements DirectoryWatcher {}
class MockThumbnailCacheService extends Mock implements ThumbnailCacheService {}
class MockMetadataCache extends Mock implements MetadataCache {}

void main() {
  late MockLocalFileDatasource mockDatasource;
  late MockDirectoryCache mockCache;
  late MockDirectoryWatcher mockWatcher;
  late MockThumbnailCacheService mockThumbnailCacheService;
  late MockMetadataCache mockMetadataCache;
  late DirectoryRepositoryImpl repository;

  setUp(() {
    mockDatasource = MockLocalFileDatasource();
    mockCache = MockDirectoryCache();
    mockWatcher = MockDirectoryWatcher();
    mockThumbnailCacheService = MockThumbnailCacheService();
    mockMetadataCache = MockMetadataCache();

    when(() => mockThumbnailCacheService.removeEntries(any())).thenAnswer((_) async {});
    when(() => mockThumbnailCacheService.removeEntriesForFolder(any())).thenAnswer((_) async {});
    when(() => mockMetadataCache.removeBatch(any())).thenAnswer((_) async {});
    when(() => mockMetadataCache.removeForFolder(any())).thenAnswer((_) async {});

    repository = DirectoryRepositoryImpl(
      datasource: mockDatasource,
      cache: mockCache,
      watcher: mockWatcher,
      thumbnailCacheService: mockThumbnailCacheService,
      metadataCache: mockMetadataCache,
    );
  });

  group('Metadata and Thumbnail Invalidation on Destructive Operations', () {
    test('deleteItems (permanent) invalidates thumbnail and metadata cache for files and folders', () async {
      final paths = ['/path/to/img1.jpg', '/path/to/folderA'];
      when(() => mockDatasource.deleteItemsPermanent(paths)).thenAnswer((_) async {});
      when(() => mockCache.invalidate('/path/to')).thenReturn(null);

      await repository.deleteItems(paths, permanent: true);

      // Verify thumbnail cache invalidation
      verify(() => mockThumbnailCacheService.removeEntries(paths)).called(1);
      verify(() => mockThumbnailCacheService.removeEntriesForFolder('/path/to/img1.jpg')).called(1);
      verify(() => mockThumbnailCacheService.removeEntriesForFolder('/path/to/folderA')).called(1);

      // Verify metadata cache invalidation
      verify(() => mockMetadataCache.removeBatch(paths)).called(1);
      verify(() => mockMetadataCache.removeForFolder('/path/to/img1.jpg')).called(1);
      verify(() => mockMetadataCache.removeForFolder('/path/to/folderA')).called(1);
    });

    test('deleteItems (to trash) invalidates thumbnail and metadata cache', () async {
      final paths = ['/path/to/video.mp4'];
      when(() => mockDatasource.moveToTrash(paths)).thenAnswer((_) async {});
      when(() => mockCache.invalidate('/path/to')).thenReturn(null);

      await repository.deleteItems(paths, permanent: false);

      verify(() => mockThumbnailCacheService.removeEntries(paths)).called(1);
      verify(() => mockThumbnailCacheService.removeEntriesForFolder('/path/to/video.mp4')).called(1);
      verify(() => mockMetadataCache.removeBatch(paths)).called(1);
      verify(() => mockMetadataCache.removeForFolder('/path/to/video.mp4')).called(1);
    });

    test('moveToTrash invalidates both thumbnail and metadata cache', () async {
      final paths = ['/path/to/photo.png'];
      when(() => mockDatasource.moveToTrash(paths)).thenAnswer((_) async {});
      when(() => mockCache.invalidate('/path/to')).thenReturn(null);

      await repository.moveToTrash(paths);

      verify(() => mockThumbnailCacheService.removeEntries(paths)).called(1);
      verify(() => mockThumbnailCacheService.removeEntriesForFolder('/path/to/photo.png')).called(1);
      verify(() => mockMetadataCache.removeBatch(paths)).called(1);
      verify(() => mockMetadataCache.removeForFolder('/path/to/photo.png')).called(1);
    });

    test('restoreFromTrash invalidates both thumbnail and metadata cache', () async {
      final paths = ['/path/to/restored.jpg'];
      when(() => mockDatasource.restoreFromTrash(paths)).thenAnswer((_) async {});
      when(() => mockCache.invalidate('/path/to')).thenReturn(null);

      await repository.restoreFromTrash(paths);

      verify(() => mockThumbnailCacheService.removeEntries(paths)).called(1);
      verify(() => mockThumbnailCacheService.removeEntriesForFolder('/path/to/restored.jpg')).called(1);
      verify(() => mockMetadataCache.removeBatch(paths)).called(1);
      verify(() => mockMetadataCache.removeForFolder('/path/to/restored.jpg')).called(1);
    });

    test('trashItems invalidates both thumbnail and metadata cache', () async {
      final paths = ['/path/to/trashed.jpg'];
      when(() => mockDatasource.trashItems(paths)).thenAnswer((_) async {});
      when(() => mockCache.invalidate('/path/to')).thenReturn(null);

      await repository.trashItems(paths);

      verify(() => mockThumbnailCacheService.removeEntries(paths)).called(1);
      verify(() => mockThumbnailCacheService.removeEntriesForFolder('/path/to/trashed.jpg')).called(1);
      verify(() => mockMetadataCache.removeBatch(paths)).called(1);
      verify(() => mockMetadataCache.removeForFolder('/path/to/trashed.jpg')).called(1);
    });

    test('moveItems invalidates both thumbnail and metadata cache for source paths', () async {
      final sources = ['/src/a.png', '/src/subfolder'];
      const destination = '/dst';
      when(() => mockDatasource.moveItems(sources, destination)).thenAnswer((_) async {});
      when(() => mockCache.invalidate(destination)).thenReturn(null);
      when(() => mockCache.invalidateRecursive(any())).thenReturn(null);
      when(() => mockCache.invalidate('/src')).thenReturn(null);

      await repository.moveItems(sources, destination);

      verify(() => mockThumbnailCacheService.removeEntries(sources)).called(1);
      verify(() => mockThumbnailCacheService.removeEntriesForFolder('/src/a.png')).called(1);
      verify(() => mockThumbnailCacheService.removeEntriesForFolder('/src/subfolder')).called(1);
      verify(() => mockMetadataCache.removeBatch(sources)).called(1);
      verify(() => mockMetadataCache.removeForFolder('/src/a.png')).called(1);
      verify(() => mockMetadataCache.removeForFolder('/src/subfolder')).called(1);
    });

    test('moveItemTo invalidates both thumbnail and metadata cache for source path', () async {
      const source = '/src/img.jpg';
      const dest = '/dst/img.jpg';
      when(() => mockDatasource.moveItemTo(source, dest)).thenAnswer((_) async {});
      when(() => mockCache.invalidateRecursive(source)).thenReturn(null);
      when(() => mockCache.invalidateRecursive(dest)).thenReturn(null);
      when(() => mockCache.invalidate('/src')).thenReturn(null);
      when(() => mockCache.invalidate('/dst')).thenReturn(null);

      await repository.moveItemTo(source, dest);

      verify(() => mockThumbnailCacheService.removeEntries([source])).called(1);
      verify(() => mockThumbnailCacheService.removeEntriesForFolder(source)).called(1);
      verify(() => mockMetadataCache.removeBatch([source])).called(1);
      verify(() => mockMetadataCache.removeForFolder(source)).called(1);
    });

    test('renameItem invalidates both thumbnail and metadata cache for original path', () async {
      const oldPath = '/folder/old_name.png';
      const newPath = '/folder/new_name.png';
      when(() => mockDatasource.renameItem(oldPath, 'new_name.png')).thenAnswer((_) async => newPath);
      when(() => mockCache.invalidateRecursive(oldPath)).thenReturn(null);
      when(() => mockCache.invalidate('/folder')).thenReturn(null);

      final res = await repository.renameItem(oldPath, 'new_name.png');

      expect(res, newPath);
      verify(() => mockThumbnailCacheService.removeEntries([oldPath])).called(1);
      verify(() => mockThumbnailCacheService.removeEntriesForFolder(oldPath)).called(1);
      verify(() => mockMetadataCache.removeBatch([oldPath])).called(1);
      verify(() => mockMetadataCache.removeForFolder(oldPath)).called(1);
    });

    test('bulkRename invalidates both thumbnail and metadata cache for all old paths', () async {
      final paths = ['/folder/pic1.jpg', '/folder/pic2.jpg'];
      final newPaths = ['/folder/renamed_pic1.jpg', '/folder/renamed_pic2.jpg'];
      when(() => mockDatasource.bulkRename(paths, prefix: 'renamed_')).thenAnswer((_) async => newPaths);
      when(() => mockCache.invalidateRecursive(any())).thenReturn(null);
      when(() => mockCache.invalidate('/folder')).thenReturn(null);

      final res = await repository.bulkRename(paths, prefix: 'renamed_');

      expect(res, newPaths);
      verify(() => mockThumbnailCacheService.removeEntries(paths)).called(1);
      verify(() => mockThumbnailCacheService.removeEntriesForFolder('/folder/pic1.jpg')).called(1);
      verify(() => mockThumbnailCacheService.removeEntriesForFolder('/folder/pic2.jpg')).called(1);
      verify(() => mockMetadataCache.removeBatch(paths)).called(1);
      verify(() => mockMetadataCache.removeForFolder('/folder/pic1.jpg')).called(1);
      verify(() => mockMetadataCache.removeForFolder('/folder/pic2.jpg')).called(1);
    });

    test('handles null metadataCache and thumbnailCacheService gracefully without errors', () async {
      final repoWithoutCaches = DirectoryRepositoryImpl(
        datasource: mockDatasource,
        cache: mockCache,
        watcher: mockWatcher,
      );

      final paths = ['/path/to/file.txt'];
      when(() => mockDatasource.deleteItemsPermanent(paths)).thenAnswer((_) async {});
      when(() => mockCache.invalidate('/path/to')).thenReturn(null);

      // Should complete without throwing
      await expectLater(
        repoWithoutCaches.deleteItems(paths, permanent: true),
        completes,
      );
    });

    test('invalidation calls are idempotent and handle empty paths', () async {
      final paths = <String>[];
      when(() => mockDatasource.deleteItemsPermanent(paths)).thenAnswer((_) async {});

      await repository.deleteItems(paths, permanent: true);

      verifyNever(() => mockThumbnailCacheService.removeEntries(any()));
      verifyNever(() => mockMetadataCache.removeBatch(any()));
    });
  });
}
