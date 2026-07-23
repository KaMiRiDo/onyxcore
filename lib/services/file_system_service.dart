import 'package:file/file.dart';
import 'package:file/local.dart';

/// Service that abstracts file system operations using the 'file' package.
/// This allows for easy swapping of the file system (e.g., MemoryFileSystem for tests).
class FileSystemService {

  FileSystemService([FileSystem? fileSystem])
    : _fileSystem = fileSystem ?? const LocalFileSystem();
  final FileSystem _fileSystem;

  FileSystem get fileSystem => _fileSystem;

  /// Returns a Directory object for the given path.
  Directory getDirectory(String path) => _fileSystem.directory(path);

  /// Returns a File object for the given path.
  File getFile(String path) => _fileSystem.file(path);

  /// Checks if a path exists and is a directory.
  Future<bool> isDirectory(String path) async =>
      _fileSystem.isDirectory(path);

  /// Checks if a path exists and is a file.
  Future<bool> isFile(String path) async => _fileSystem.isFile(path);

  /// Lists the contents of a directory.
  Future<List<FileSystemEntity>> listDirectory(
    String path, {
    bool recursive = false,
    bool followLinks = true,
  }) async {
    final dir = _fileSystem.directory(path);
    if (!await dir.exists()) {
      throw FileSystemException('Directory does not exist', path);
    }
    return dir.list(recursive: recursive, followLinks: followLinks).toList();
  }
}
