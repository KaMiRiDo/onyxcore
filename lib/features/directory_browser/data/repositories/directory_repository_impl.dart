import 'package:path/path.dart' as p;

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

    _invalidateParents(paths);
  }

  @override
  Future<void> moveToTrash(List<String> paths) async {
    await datasource.moveToTrash(paths);
    _invalidateParents(paths);
  }

  @override
  Future<void> trashItems(List<String> paths) async {
    await datasource.trashItems(paths);
    _invalidateParents(paths);
  }

  @override
  Future<void> copyItems(List<String> sources, String destination) async {
    await datasource.copyItems(sources, destination);
    cache.invalidate(destination);
  }

  @override
  Future<void> copyItemTo(String source, String destinationPath) async {
    await datasource.copyItemTo(source, destinationPath);
    cache.invalidateRecursive(destinationPath);
    cache.invalidate(p.dirname(destinationPath));
  }

  @override
  Future<void> moveItems(List<String> sources, String destination) async {
    await datasource.moveItems(sources, destination);
    cache.invalidate(destination);
    for (final source in sources) {
      cache.invalidateRecursive(source);
    }
    _invalidateParents(sources);
  }

  @override
  Future<void> moveItemTo(String source, String destinationPath) async {
    await datasource.moveItemTo(source, destinationPath);
    cache.invalidateRecursive(source);
    cache.invalidateRecursive(destinationPath);
    cache.invalidate(p.dirname(destinationPath));
  }

  @override
  Future<String> renameItem(String path, String newName) async {
    final newPath = await datasource.renameItem(path, newName);
    cache.invalidateRecursive(path);
    _invalidateParents([path]);
    return newPath;
  }

  @override
  Future<List<String>> bulkRename(List<String> paths, {String? prefix, String? baseName}) async {
    final newPaths = await datasource.bulkRename(paths, prefix: prefix, baseName: baseName);
    for (final path in paths) {
      cache.invalidateRecursive(path);
    }
    _invalidateParents(paths);
    return newPaths;
  }

  void _invalidateParents(List<String> paths) {
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

  @override
  void invalidateCache(String path, {bool recursive = false}) {
    if (recursive) {
      cache.invalidateRecursive(path);
    } else {
      cache.invalidate(path);
    }
  }
}
