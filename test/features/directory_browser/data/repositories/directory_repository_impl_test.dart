import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/cache/directory_cache.dart';
import 'package:onyxcore/core/platform/directory_watcher.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/data/datasources/local_file_datasource.dart';
import 'package:onyxcore/features/directory_browser/data/repositories/directory_repository_impl.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

class MockLocalFileDatasource extends Mock implements LocalFileDatasource {}
class MockDirectoryCache extends Mock implements DirectoryCache<List<FileItem>> {}
class MockDirectoryWatcher extends Mock implements DirectoryWatcher {}

void main() {
  late MockLocalFileDatasource mockDatasource;
  late MockDirectoryCache mockCache;
  late MockDirectoryWatcher mockWatcher;
  late DirectoryRepositoryImpl repository;

  const tPath = '/path/to/folder';
  final tItem = FileItem(
    path: '/path/to/folder/f1.txt',
    name: 'f1.txt',
    type: FileItemType.document,
    modified: DateTime(2023),
  );
  final tItems = [tItem];

  setUp(() {
    mockDatasource = MockLocalFileDatasource();
    mockCache = MockDirectoryCache();
    mockWatcher = MockDirectoryWatcher();

    repository = DirectoryRepositoryImpl(
      datasource: mockDatasource,
      cache: mockCache,
      watcher: mockWatcher,
    );
  });

  group('DirectoryRepositoryImpl', () {
    test('listDirectory returns from cache if available', () async {
      when(() => mockCache.get(tPath)).thenReturn(tItems);

      final result = await repository.listDirectory(tPath);

      expect(result, tItems);
      verify(() => mockCache.get(tPath)).called(1);
      verifyNever(() => mockDatasource.listDirectory(any()));
    });

    test('listDirectory fetches from datasource and updates cache if cache is miss', () async {
      when(() => mockCache.get(tPath)).thenReturn(null);
      when(() => mockDatasource.listDirectory(tPath)).thenAnswer((_) async => tItems);
      when(() => mockCache.put(tPath, tItems)).thenReturn(null);

      final result = await repository.listDirectory(tPath);

      expect(result, tItems);
      verify(() => mockCache.get(tPath)).called(1);
      verify(() => mockDatasource.listDirectory(tPath)).called(1);
      verify(() => mockCache.put(tPath, tItems)).called(1);
    });

    test('createFolder delegates to datasource and invalidates cache', () async {
      when(() => mockDatasource.createFolder(tPath, 'new_folder')).thenAnswer((_) async {});
      when(() => mockCache.invalidate(tPath)).thenReturn(null);

      await repository.createFolder(tPath, 'new_folder');

      verify(() => mockDatasource.createFolder(tPath, 'new_folder')).called(1);
      verify(() => mockCache.invalidate(tPath)).called(1);
    });

    test('createFile delegates to datasource and invalidates cache', () async {
      when(() => mockDatasource.createFile(tPath, 'new_file.txt')).thenAnswer((_) async {});
      when(() => mockCache.invalidate(tPath)).thenReturn(null);

      await repository.createFile(tPath, 'new_file.txt');

      verify(() => mockDatasource.createFile(tPath, 'new_file.txt')).called(1);
      verify(() => mockCache.invalidate(tPath)).called(1);
    });

    test('deleteItems permanent true calls deleteItemsPermanent and invalidates parent', () async {
      final paths = ['/path/to/folder/f1.txt'];
      when(() => mockDatasource.deleteItemsPermanent(paths)).thenAnswer((_) async {});
      when(() => mockCache.invalidate('/path/to/folder')).thenReturn(null);

      await repository.deleteItems(paths, permanent: true);

      verify(() => mockDatasource.deleteItemsPermanent(paths)).called(1);
      verify(() => mockCache.invalidate('/path/to/folder')).called(1);
    });

    test('deleteItems permanent false calls moveToTrash and invalidates parent', () async {
      final paths = ['/path/to/folder/f1.txt'];
      when(() => mockDatasource.moveToTrash(paths)).thenAnswer((_) async {});
      when(() => mockCache.invalidate('/path/to/folder')).thenReturn(null);

      await repository.deleteItems(paths, permanent: false);

      verify(() => mockDatasource.moveToTrash(paths)).called(1);
      verify(() => mockCache.invalidate('/path/to/folder')).called(1);
    });

    test('moveToTrash delegates and invalidates parent', () async {
      final paths = ['/path/to/folder/f1.txt'];
      when(() => mockDatasource.moveToTrash(paths)).thenAnswer((_) async {});
      when(() => mockCache.invalidate('/path/to/folder')).thenReturn(null);

      await repository.moveToTrash(paths);

      verify(() => mockDatasource.moveToTrash(paths)).called(1);
      verify(() => mockCache.invalidate('/path/to/folder')).called(1);
    });

    test('restoreFromTrash delegates and invalidates parent', () async {
      final paths = ['/path/to/folder/f1.txt'];
      when(() => mockDatasource.restoreFromTrash(paths)).thenAnswer((_) async {});
      when(() => mockCache.invalidate('/path/to/folder')).thenReturn(null);

      await repository.restoreFromTrash(paths);

      verify(() => mockDatasource.restoreFromTrash(paths)).called(1);
      verify(() => mockCache.invalidate('/path/to/folder')).called(1);
    });

    test('trashItems delegates and invalidates parent', () async {
      final paths = ['/path/to/folder/f1.txt'];
      when(() => mockDatasource.trashItems(paths)).thenAnswer((_) async {});
      when(() => mockCache.invalidate('/path/to/folder')).thenReturn(null);

      await repository.trashItems(paths);

      verify(() => mockDatasource.trashItems(paths)).called(1);
      verify(() => mockCache.invalidate('/path/to/folder')).called(1);
    });

    test('copyItems delegates and invalidates destination', () async {
      final sources = ['/src/f1.txt'];
      const dest = '/dest';
      when(() => mockDatasource.copyItems(sources, dest)).thenAnswer((_) async {});
      when(() => mockCache.invalidate(dest)).thenReturn(null);

      await repository.copyItems(sources, dest);

      verify(() => mockDatasource.copyItems(sources, dest)).called(1);
      verify(() => mockCache.invalidate(dest)).called(1);
    });

    test('copyItemTo delegates and invalidates correctly', () async {
      const src = '/src/f1.txt';
      const dest = '/dest/f1.txt';
      when(() => mockDatasource.copyItemTo(src, dest)).thenAnswer((_) async {});
      when(() => mockCache.invalidateRecursive(dest)).thenReturn(null);
      when(() => mockCache.invalidate('/dest')).thenReturn(null);

      await repository.copyItemTo(src, dest);

      verify(() => mockDatasource.copyItemTo(src, dest)).called(1);
      verify(() => mockCache.invalidateRecursive(dest)).called(1);
      verify(() => mockCache.invalidate('/dest')).called(1);
    });

    test('moveItems delegates and invalidates correctly', () async {
      final sources = ['/src/f1.txt'];
      const dest = '/dest';
      when(() => mockDatasource.moveItems(sources, dest)).thenAnswer((_) async {});
      when(() => mockCache.invalidate(dest)).thenReturn(null);
      when(() => mockCache.invalidateRecursive('/src/f1.txt')).thenReturn(null);
      when(() => mockCache.invalidate('/src')).thenReturn(null);

      await repository.moveItems(sources, dest);

      verify(() => mockDatasource.moveItems(sources, dest)).called(1);
      verify(() => mockCache.invalidate(dest)).called(1);
      verify(() => mockCache.invalidateRecursive('/src/f1.txt')).called(1);
      verify(() => mockCache.invalidate('/src')).called(1);
    });

    test('moveItemTo delegates and invalidates correctly', () async {
      const src = '/src/f1.txt';
      const dest = '/dest/f1.txt';
      when(() => mockDatasource.moveItemTo(src, dest)).thenAnswer((_) async {});
      when(() => mockCache.invalidateRecursive(src)).thenReturn(null);
      when(() => mockCache.invalidateRecursive(dest)).thenReturn(null);
      when(() => mockCache.invalidate('/src')).thenReturn(null);
      when(() => mockCache.invalidate('/dest')).thenReturn(null);

      await repository.moveItemTo(src, dest);

      verify(() => mockDatasource.moveItemTo(src, dest)).called(1);
      verify(() => mockCache.invalidateRecursive(src)).called(1);
      verify(() => mockCache.invalidateRecursive(dest)).called(1);
      verify(() => mockCache.invalidate('/src')).called(1);
      verify(() => mockCache.invalidate('/dest')).called(1);
    });

    test('renameItem delegates and invalidates correctly', () async {
      const path = '/src/f1.txt';
      const newPath = '/src/f2.txt';
      when(() => mockDatasource.renameItem(path, 'f2.txt')).thenAnswer((_) async => newPath);
      when(() => mockCache.invalidateRecursive(path)).thenReturn(null);
      when(() => mockCache.invalidate('/src')).thenReturn(null);

      final result = await repository.renameItem(path, 'f2.txt');

      expect(result, newPath);
      verify(() => mockDatasource.renameItem(path, 'f2.txt')).called(1);
      verify(() => mockCache.invalidateRecursive(path)).called(1);
      verify(() => mockCache.invalidate('/src')).called(1);
    });

    test('bulkRename delegates and invalidates correctly', () async {
      final paths = ['/src/f1.txt', '/src/f2.txt'];
      final newPaths = ['/src/pre_f1.txt', '/src/pre_f2.txt'];
      when(() => mockDatasource.bulkRename(paths, prefix: 'pre_')).thenAnswer((_) async => newPaths);
      when(() => mockCache.invalidateRecursive(any())).thenReturn(null);
      when(() => mockCache.invalidate('/src')).thenReturn(null);

      final result = await repository.bulkRename(paths, prefix: 'pre_');

      expect(result, newPaths);
      verify(() => mockDatasource.bulkRename(paths, prefix: 'pre_')).called(1);
      verify(() => mockCache.invalidateRecursive('/src/f1.txt')).called(1);
      verify(() => mockCache.invalidateRecursive('/src/f2.txt')).called(1);
      verify(() => mockCache.invalidate('/src')).called(1);
    });

    test('watchDirectory delegates to watcher', () {
      final events = Stream<FileChangeEvent>.empty();
      when(() => mockWatcher.watch(tPath)).thenReturn(null);
      when(() => mockWatcher.events).thenAnswer((_) => events);

      final result = repository.watchDirectory(tPath);

      expect(result, events);
      verify(() => mockWatcher.watch(tPath)).called(1);
    });

    test('invalidateCache works non-recursively', () {
      when(() => mockCache.invalidate(tPath)).thenReturn(null);

      repository.invalidateCache(tPath);

      verify(() => mockCache.invalidate(tPath)).called(1);
    });

    test('invalidateCache works recursively', () {
      when(() => mockCache.invalidateRecursive(tPath)).thenReturn(null);

      repository.invalidateCache(tPath, recursive: true);

      verify(() => mockCache.invalidateRecursive(tPath)).called(1);
    });
    
    test('parent invalidation logic handles root edge cases', () async {
      // test when path is /f1.txt, parent should be /
      final paths = ['/f1.txt'];
      when(() => mockDatasource.moveToTrash(paths)).thenAnswer((_) async {});
      when(() => mockCache.invalidate('/')).thenReturn(null);

      await repository.deleteItems(paths, permanent: false);

      verify(() => mockCache.invalidate('/')).called(1);
    });
  });
}
