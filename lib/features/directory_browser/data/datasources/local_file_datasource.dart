import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../../../../core/utils/file_type_classifier.dart';
import '../../domain/entities/file_item.dart';

/// Data source for local file system operations.
///
/// Runs directory listing in a separate isolate to avoid main-thread jank.
class LocalFileDatasource {
  /// List directory contents in an isolate, returning sorted [FileItem]s.
  Future<List<FileItem>> listDirectory(String path) async {
    return Isolate.run(() => _listDirectorySync(path));
  }

  /// Create a new folder.
  Future<void> createFolder(String parentPath, String name) async {
    await Directory(p.join(parentPath, name)).create();
  }

  /// Delete items permanently.
  Future<void> deleteItemsPermanent(List<String> paths) async {
    for (final path in paths) {
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.directory) {
        await Directory(path).delete(recursive: true);
      } else if (type != FileSystemEntityType.notFound) {
        await File(path).delete();
      }
    }
  }

  /// Move items to the system trash (~/.local/share/Trash/files).
  Future<void> moveToTrash(List<String> paths) async {
    final home = Platform.environment['HOME'] ?? '/';
    final trashDir = Directory(p.join(home, '.local/share/Trash/files'));
    if (!trashDir.existsSync()) {
      await trashDir.create(recursive: true);
    }

    for (final path in paths) {
      final entity = File(path);
      if (entity.existsSync()) {
        final baseName = p.basename(path);
        var newPath = p.join(trashDir.path, baseName);

        // Handle duplicate filenames in trash
        var counter = 1;
        while (File(newPath).existsSync() || Directory(newPath).existsSync()) {
          final ext = p.extension(baseName);
          final nameWithoutExt = p.basenameWithoutExtension(baseName);
          newPath = p.join(trashDir.path, '${nameWithoutExt}_$counter$ext');
          counter++;
        }

        entity.renameSync(newPath);
      }
    }
  }

  /// Use native 'gio trash' for standard Linux behavior.
  Future<void> trashItems(List<String> paths) async {
    for (final path in paths) {
      final result = await Process.run('gio', ['trash', path]);
      if (result.exitCode != 0) {
        throw Exception('gio trash failed for $path');
      }
    }
  }

  /// Copy files and folders.
  Future<void> copyItems(List<String> sources, String destination) async {
    for (final source in sources) {
      final name = p.basename(source);
      final destPath = p.join(destination, name);
      await copyItemTo(source, destPath);
    }
  }

  /// Copy a single item to a specific destination path.
  Future<void> copyItemTo(String source, String destinationPath) async {
    final absSource = p.canonicalize(source);
    final absDest = p.canonicalize(destinationPath);
    if (absSource == absDest) return;

    final sourceType = FileSystemEntity.typeSync(absSource);
    final isDir = sourceType == FileSystemEntityType.directory;
    final isSourceInsideDest = absSource.startsWith(absDest + p.separator);
    
    String actualSource = absSource;
    Directory? tempDir;

    // If source is inside dest, copying would be lost when dest is deleted.
    // Move to temp first.
    if (isSourceInsideDest) {
      tempDir = Directory.systemTemp.createTempSync('onyx_copy_tmp_');
      actualSource = p.join(tempDir.path, p.basename(absSource));
      if (isDir) {
        await _copyDirectory(Directory(absSource), Directory(actualSource));
      } else {
        await File(absSource).copy(actualSource);
      }
    }

    // For "Replace" to work, we must delete the existing destination if it exists
    final destType = FileSystemEntity.typeSync(absDest);
    if (destType != FileSystemEntityType.notFound) {
      if (destType == FileSystemEntityType.directory) {
        await Directory(absDest).delete(recursive: true);
      } else {
        await File(absDest).delete();
      }
    }

    if (isDir) {
      await _copyDirectory(Directory(actualSource), Directory(absDest));
    } else {
      await File(actualSource).copy(absDest);
    }

    if (tempDir != null) await tempDir.delete(recursive: true);
  }

  /// Move files and folders (Rename).
  Future<void> moveItems(List<String> sources, String destination) async {
    for (final source in sources) {
      final name = p.basename(source);
      final destPath = p.join(destination, name);
      await moveItemTo(source, destPath);
    }
  }

  /// Move a single item to a specific destination path.
  Future<void> moveItemTo(String source, String destinationPath) async {
    final absSource = p.canonicalize(source);
    final absDest = p.canonicalize(destinationPath);
    if (absSource == absDest) return;

    final sourceType = FileSystemEntity.typeSync(absSource);
    final isDir = sourceType == FileSystemEntityType.directory;
    final isSourceInsideDest = absSource.startsWith(absDest + p.separator);
    
    String actualSource = absSource;
    Directory? tempDir;

    // CRITICAL: If moving a child to replace its parent, isolation is mandatory.
    if (isSourceInsideDest) {
      tempDir = Directory.systemTemp.createTempSync('onyx_move_tmp_');
      actualSource = p.join(tempDir.path, p.basename(absSource));
      if (isDir) {
        await Directory(absSource).rename(actualSource);
      } else {
        await File(absSource).rename(actualSource);
      }
    }

    // For "Replace" to work, we must delete the existing destination if it exists
    final destType = FileSystemEntity.typeSync(absDest);
    if (destType != FileSystemEntityType.notFound) {
      if (destType == FileSystemEntityType.directory) {
        await Directory(absDest).delete(recursive: true);
      } else {
        await File(absDest).delete();
      }
    }

    try {
      if (isDir) {
        await Directory(actualSource).rename(absDest);
      } else {
        await File(actualSource).rename(absDest);
      }
    } catch (e) {
      // Fallback for cross-partition moves (Copy + Delete)
      if (isDir) {
        await _copyDirectory(Directory(actualSource), Directory(absDest));
        await Directory(actualSource).delete(recursive: true);
      } else {
        await File(actualSource).copy(absDest);
        await File(actualSource).delete();
      }
    }

    if (tempDir != null) await tempDir.delete(recursive: true);
  }

  /// Helper to copy directory recursively
  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final name = p.basename(entity.path);
      final destPath = p.join(destination.path, name);
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(destPath));
      } else if (entity is File) {
        await entity.copy(destPath);
      }
    }
  }

  /// Rename single item. Returns the new path.
  Future<String> renameItem(String path, String newName) async {
    final parent = p.dirname(path);
    final newPath = p.join(parent, newName);
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.directory) {
      await Directory(path).rename(newPath);
    } else {
      await File(path).rename(newPath);
    }
    return newPath;
  }

  /// Bulk rename logic. Returns the new paths.
  Future<List<String>> bulkRename(List<String> paths, {String? prefix, String? baseName}) async {
    final newPaths = <String>[];
    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      final dirname = p.dirname(path);
      final originalName = p.basename(path);
      final ext = p.extension(path);
      
      String newName;
      if (prefix != null) {
        newName = "$prefix$originalName";
      } else if (baseName != null) {
        newName = "$baseName\_${i + 1}$ext";
      } else {
        continue;
      }
      
      final newPath = p.join(dirname, newName);
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.directory) {
        await Directory(path).rename(newPath);
      } else {
        await File(path).rename(newPath);
      }
      newPaths.add(newPath);
    }
    return newPaths;
  }

  /// Synchronous directory listing (runs inside an isolate).
  static List<FileItem> _listDirectorySync(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) return [];

    final folders = <FileItem>[];
    final files = <FileItem>[];

    try {
      final entities = dir.listSync();

      for (final entity in entities) {
        final name = p.basename(entity.path);
        final stat = entity.statSync();

        if (entity is Directory) {
          folders.add(FileItem(
            path: entity.path,
            name: name,
            type: FileItemType.folder,
            modified: stat.modified,
          ));
        } else if (entity is File) {
          final type = classifyFileType(name);
          
          final isExec = stat.modeString().contains('x');

          files.add(FileItem(
            path: entity.path,
            name: name,
            type: type,
            modified: stat.modified,
            sizeBytes: stat.size,
            isExecutable: isExec,
          ));
        }
      }
    } catch (_) {
      return [];
    }

    // Sort: folders by date desc, then files by date desc
    folders.sort((a, b) => b.modified.compareTo(a.modified));
    files.sort((a, b) => b.modified.compareTo(a.modified));

    return [...folders, ...files];
  }
}
