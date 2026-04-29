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
      
      final type = FileSystemEntity.typeSync(source);
      if (type == FileSystemEntityType.directory) {
        await _copyDirectory(Directory(source), Directory(destPath));
      } else if (type == FileSystemEntityType.file) {
        await File(source).copy(destPath);
      }
    }
  }

  /// Move files and folders (Rename).
  Future<void> moveItems(List<String> sources, String destination) async {
    for (final source in sources) {
      final name = p.basename(source);
      final destPath = p.join(destination, name);
      final type = FileSystemEntity.typeSync(source);
      if (type == FileSystemEntityType.directory) {
        await Directory(source).rename(destPath);
      } else if (type == FileSystemEntityType.file) {
        await File(source).rename(destPath);
      }
    }
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

  /// Rename single item.
  Future<void> renameItem(String path, String newName) async {
    final parent = p.dirname(path);
    final newPath = p.join(parent, newName);
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.directory) {
      await Directory(path).rename(newPath);
    } else {
      await File(path).rename(newPath);
    }
  }

  /// Bulk rename logic.
  Future<void> bulkRename(List<String> paths, {String? prefix, String? baseName}) async {
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
    }
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
