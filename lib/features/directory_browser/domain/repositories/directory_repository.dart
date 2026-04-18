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
  Future<void> createFolder(String parentPath, String name);

  /// Delete items at the given [paths].
  /// If [permanent] is true, deletes permanently. Otherwise moves to trash.
  Future<void> deleteItems(List<String> paths, {required bool permanent});

  /// Move the given [paths] to the system trash
  /// (~/.local/share/Trash/files).
  Future<void> moveToTrash(List<String> paths);

  /// Watch a directory for file system changes via inotify.
  Stream<FileChangeEvent> watchDirectory(String path);
}
