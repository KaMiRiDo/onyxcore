import '../../../../core/cache/directory_cache.dart';
import '../../../../core/platform/directory_watcher.dart';
import '../../domain/entities/file_item.dart';
import '../../domain/repositories/directory_repository.dart';
import '../datasources/local_file_datasource.dart';

/// Concrete implementation of [DirectoryRepository].
///
/// Wraps [LocalFileDatasource] with caching via [DirectoryCache]
/// and file watching via [DirectoryWatcher].
class DirectoryRepositoryImpl implements DirectoryRepository {
  DirectoryRepositoryImpl({
    required this.datasource,
    required this.cache,
    required this.watcher,
  });

  final LocalFileDatasource datasource;
  final DirectoryCache<List<FileItem>> cache;
  final DirectoryWatcher watcher;

  @override
  Future<List<FileItem>> listDirectory(String path) async {
    // Check cache first
    final cached = cache.get(path);
    if (cached != null) return cached;

    // Load from filesystem (runs in isolate)
    final items = await datasource.listDirectory(path);

    // Cache the result
    cache.put(path, items);

    return items;
  }

  @override
  Future<void> createFolder(String parentPath, String name) async {
    await datasource.createFolder(parentPath, name);
    cache.invalidate(parentPath);
  }

  @override
  Future<void> deleteItems(
    List<String> paths, {
    required bool permanent,
  }) async {
    if (permanent) {
      await datasource.deleteItemsPermanent(paths);
    } else {
      await datasource.moveToTrash(paths);
    }

    // Invalidate cache for all affected parent directories
    final parents = paths.map((p) {
      final lastSlash = p.lastIndexOf('/');
      return lastSlash > 0 ? p.substring(0, lastSlash) : '/';
    }).toSet();

    for (final parent in parents) {
      cache.invalidate(parent);
    }
  }

  @override
  Future<void> moveToTrash(List<String> paths) async {
    await datasource.moveToTrash(paths);

    final parents = paths.map((p) {
      final lastSlash = p.lastIndexOf('/');
      return lastSlash > 0 ? p.substring(0, lastSlash) : '/';
    }).toSet();

    for (final parent in parents) {
      cache.invalidate(parent);
    }
  }

  @override
  Stream<FileChangeEvent> watchDirectory(String path) {
    watcher.watch(path);
    return watcher.events;
  }
}
