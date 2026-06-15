import 'dart:isolate';
import '../../../../core/platform/directory_watcher.dart';
import '../entities/file_item.dart';

/// Abstract interface for directory operations.
///
/// Data layer implements this. Domain and presentation layers depend only
/// on this interface, enabling easy testing and swapping of implementations.
abstract class DirectoryRepository {
  /// List the contents of a directory, returning sorted [FileItem]s.
  /// Folders come first (by date desc), then files (by date desc).
  Future<List<FileItem>> listDirectory(String path);

  /// Create a new folder with [name] inside [parentPath].
  Future<void> createFolder(String parentPath, String name, {String? taskId});

  /// Create a new file with [name] inside [parentPath].
  Future<void> createFile(String parentPath, String name, {String? taskId});

  /// Delete items at the given [paths].
  /// If [permanent] is true, deletes permanently. Otherwise moves to trash.
  Future<void> deleteItems(
    List<String> paths, {
    required bool permanent,
    String? taskId,
    void Function(int processed, int total)? onProgress,
    void Function(String message)? onLog,
  });

  Future<void> moveToTrash(
    List<String> paths, {
    String? taskId,
    void Function(int processed, int total)? onProgress,
    void Function(String message)? onLog,
  });

  /// Restore items from the system trash to their original locations.
  Future<void> restoreFromTrash(
    List<String> paths, {
    String? taskId,
    void Function(int processed, int total)? onProgress,
    void Function(String message)? onLog,
  });

  /// Copy items from [sources] to [destination] folder.
  Future<void> copyItems(List<String> sources, String destination);

  /// Copy a single item from [source] to the exact [destinationPath].
  Future<void> copyItemTo(
    String source,
    String destinationPath, {
    void Function(int bytesCopied)? onProgress,
    void Function()? onSyncing,
    String? taskId,
    void Function(SendPort port, Isolate? isolate)? onPort,
  });

  /// Move items from [sources] to [destination] folder (Cut & Paste).
  Future<void> moveItems(List<String> sources, String destination);

  /// Move a single item from [source] to the exact [destinationPath].
  Future<void> moveItemTo(
    String source,
    String destinationPath, {
    void Function(int bytesCopied)? onProgress,
    void Function()? onSyncing,
    String? taskId,
    void Function(SendPort port, Isolate? isolate)? onPort,
  });

  /// Rename a single item. Returns the new path.
  Future<String> renameItem(
    String path,
    String newName, {
    String? taskId,
    void Function(String message)? onLog,
  });

  /// Rename multiple items using prefix or numbering. Returns the new paths.
  Future<List<String>> bulkRename(
    List<String> paths, {
    String? prefix,
    String? baseName,
    String? taskId,
    void Function(String message)? onLog,
  });

  /// Specialized Linux trash operation using 'gio'.
  Future<void> trashItems(
    List<String> paths, {
    String? taskId,
    void Function(int processed, int total)? onProgress,
    void Function(String message)? onLog,
  });

  /// Watch a directory for file system changes via inotify.
  Stream<FileChangeEvent> watchDirectory(String path);

  /// Manually invalidate cache for a path.
  void invalidateCache(String path, {bool recursive = false});
}
