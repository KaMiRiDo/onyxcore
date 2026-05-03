import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:path/path.dart' as p;

import '../../../../core/utils/file_type_classifier.dart';
import '../../domain/entities/file_item.dart';

/// Data source for local file system operations.
class LocalFileDatasource {
  /// List contents of a directory.
  Future<List<FileItem>> listDirectory(String path) async {
    return Isolate.run(() => _listDirectorySync(path));
  }

  /// Create a new directory.
  Future<void> createDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Create a new folder in a parent directory.
  Future<void> createFolder(String parentPath, String name, {String? taskId}) async {
    final dir = Directory(p.join(parentPath, name));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Delete items (files or folders).
  Future<void> deleteItems(List<String> paths, {void Function(int processed, int total)? onProgress, String? taskId, void Function(String message)? onLog}) async {
    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      final type = FileSystemEntity.typeSync(path);
      if (type == FileSystemEntityType.directory) {
        await Directory(path).delete(recursive: true);
      } else if (type == FileSystemEntityType.file) {
        await File(path).delete();
      }
      onLog?.call('Deleted: $path');
      onProgress?.call(i + 1, paths.length);
    }
  }

  /// Delete items permanently.
  Future<void> deleteItemsPermanent(List<String> paths, {void Function(int processed, int total)? onProgress, String? taskId, void Function(String message)? onLog}) async {
    await deleteItems(paths, onProgress: onProgress, taskId: taskId, onLog: onLog);
  }

  /// Move items to system trash using 'gio trash'.
  Future<void> moveToTrash(List<String> paths, {void Function(int processed, int total)? onProgress, String? taskId, void Function(String message)? onLog}) async {
    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      try {
        await Process.run('gio', ['trash', path]);
        onLog?.call('Moved to Trash: $path');
      } catch (_) {
        // Fallback: delete permanently if gio fails
        await deleteItems([path], onLog: onLog);
      }
      onProgress?.call(i + 1, paths.length);
    }
  }

  /// Alias for moveToTrash.
  Future<void> trashItems(List<String> paths, {void Function(int processed, int total)? onProgress, String? taskId, void Function(String message)? onLog}) async {
    await moveToTrash(paths, onProgress: onProgress, taskId: taskId, onLog: onLog);
  }

  /// Copy items (files or folders).
  Future<void> copyItems(List<String> sources, String destination) async {
    for (final source in sources) {
      final name = p.basename(source);
      final destPath = p.join(destination, name);
      await copyItemTo(source, destPath);
    }
  }

  /// Copy single item from [source] to [absDest].
  Future<void> copyItemTo(String source, String absDest, {void Function(int bytesCopied)? onProgress, void Function()? onSyncing, String? taskId, void Function(SendPort port, Isolate? isolate)? onPort}) async {
    final absSource = p.canonicalize(source);
    final absDestination = p.canonicalize(absDest);
    if (absSource == absDestination) return;

    final sourceType = FileSystemEntity.typeSync(absSource);
    final isDir = sourceType == FileSystemEntityType.directory;
    final isSourceInsideDest = absSource.startsWith(absDestination + p.separator);
    
    String actualSource = absSource;
    Directory? tempDir;

    if (isSourceInsideDest) {
      tempDir = Directory.systemTemp.createTempSync('onyx_copy_tmp_');
      actualSource = p.join(tempDir.path, p.basename(absSource));
      if (isDir) {
        await _copyDirectory(Directory(absSource), Directory(actualSource));
      } else {
        await File(absSource).copy(actualSource);
      }
    }

    if (isDir) {
      await _copyDirectory(Directory(actualSource), Directory(absDestination), onProgress: onProgress, onSyncing: onSyncing, taskId: taskId, onPort: onPort);
    } else {
      await _copyFileWithProgress(File(actualSource), File(absDestination), onProgress, onSyncing, taskId: taskId, onPort: onPort);
    }

    if (tempDir != null) await tempDir.delete(recursive: true);
  }

  /// Fixed flush threshold: 8 MB.
  static const int _flushThreshold = 16 * 1024 * 1024;

  Future<void> _copyFileWithProgress(File source, File destination, void Function(int bytesCopied)? onProgress, void Function()? onSyncing, {String? taskId, void Function(SendPort port, Isolate? isolate)? onPort}) async {
    final receivePort = ReceivePort();
    final completer = Completer<void>();
    Isolate? isolate;
    
    receivePort.listen((message) {
      if (message is SendPort) {
        onPort?.call(message, isolate);
      } else if (message is Map) {
        final status = message['status'];
        switch (status) {
          case 'progress':
            onProgress?.call(message['bytesCopied']);
            break;
          case 'syncing':
            onSyncing?.call();
            break;
          case 'completed':
            completer.complete();
            break;
          case 'cancelled':
            completer.completeError('CANCELLED');
            break;
          case 'error':
            completer.completeError(message['error']);
            break;
        }
      }
    });

    try {
      isolate = await Isolate.spawn(_fileCopyIsolateEntry, {
        'sendPort': receivePort.sendPort,
        'source': source.path,
        'destination': destination.path,
        'taskId': taskId,
        'flushThreshold': _flushThreshold,
      });

      await completer.future;
    } catch (e) {
      if (destination.existsSync()) {
        try {
          destination.deleteSync();
        } catch (_) {}
      }
      rethrow;
    } finally {
      receivePort.close();
      isolate?.kill(priority: Isolate.immediate);
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination, {void Function(int bytesCopied)? onProgress, void Function()? onSyncing, String? taskId, void Function(SendPort port, Isolate? isolate)? onPort}) async {
    if (!destination.existsSync()) {
      destination.createSync(recursive: true);
    }

    await for (final entity in source.list()) {
      final name = p.basename(entity.path);
      final destPath = p.join(destination.path, name);

      if (entity is Directory) {
        await _copyDirectory(entity, Directory(destPath), onProgress: onProgress, onSyncing: onSyncing, taskId: taskId, onPort: onPort);
      } else if (entity is File) {
        await _copyFileWithProgress(entity, File(destPath), onProgress, onSyncing, taskId: taskId, onPort: onPort);
      }
    }
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
  Future<void> moveItemTo(String source, String destinationPath, {void Function(int bytesCopied)? onProgress, void Function()? onSyncing, String? taskId, void Function(SendPort port, Isolate? isolate)? onPort}) async {
    final absSource = p.canonicalize(source);
    final absDest = p.canonicalize(destinationPath);
    if (absSource == absDest) return;

    final sourceType = FileSystemEntity.typeSync(absSource);
    final isDir = sourceType == FileSystemEntityType.directory;
    final isSourceInsideDest = absSource.startsWith(absDest + p.separator);
    
    String actualSource = absSource;
    Directory? tempDir;

    if (isSourceInsideDest) {
      tempDir = Directory.systemTemp.createTempSync('onyx_move_tmp_');
      actualSource = p.join(tempDir.path, p.basename(absSource));
      if (isDir) {
        await Directory(absSource).rename(actualSource);
      } else {
        await File(absSource).rename(actualSource);
      }
    }

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
      if (isDir) {
        await _copyDirectory(Directory(actualSource), Directory(absDest), onProgress: onProgress, onSyncing: onSyncing, taskId: taskId, onPort: onPort);
        await Directory(actualSource).delete(recursive: true);
      } else {
        await _copyFileWithProgress(File(actualSource), File(absDest), onProgress, onSyncing, taskId: taskId, onPort: onPort);
        await File(actualSource).delete();
      }
    }

    if (tempDir != null) await tempDir.delete(recursive: true);
  }

  /// Rename single item. Returns the new path.
  Future<String> renameItem(String path, String newName, {String? taskId, void Function(String message)? onLog}) async {
    final parent = p.dirname(path);
    final newPath = p.join(parent, newName);
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.directory) {
      await Directory(path).rename(newPath);
    } else {
      await File(path).rename(newPath);
    }
    onLog?.call('Renamed: $path -> $newPath');
    return newPath;
  }

  /// Bulk rename logic. Returns the new paths.
  Future<List<String>> bulkRename(List<String> paths, {String? prefix, String? baseName, String? taskId, void Function(int processed, int total)? onProgress, void Function(String message)? onLog}) async {
    final newPaths = <String>[];
    for (int i = 0; i < paths.length; i++) {
      final path = paths[i];
      final dirname = p.dirname(path);
      final originalName = p.basename(path);
      final ext = p.extension(path);
      
      String newName;
      if (prefix != null) {
        newName = '$prefix$originalName';
      } else if (baseName != null) {
        newName = '${baseName}_${i + 1}$ext';
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
      onLog?.call('Renamed: $path -> $newPath');
      newPaths.add(newPath);
      onProgress?.call(i + 1, paths.length);
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

        final modeStr = stat.modeString();
        final hasWrite = modeStr.length >= 9 && (modeStr[1] == 'w' || modeStr[7] == 'w');

        if (entity is Directory) {
          folders.add(FileItem(
            path: entity.path,
            name: name,
            type: FileItemType.folder,
            modified: stat.modified,
            hasWritePermission: hasWrite,
          ));
        } else if (entity is File) {
          final type = classifyFileType(name);
          final isExec = modeStr.contains('x');

          files.add(FileItem(
            path: entity.path,
            name: name,
            type: type,
            modified: stat.modified,
            sizeBytes: stat.size,
            isExecutable: isExec,
            hasWritePermission: hasWrite,
          ));
        }
      }
    } catch (_) {
      return [];
    }

    folders.sort((a, b) => b.modified.compareTo(a.modified));
    files.sort((a, b) => b.modified.compareTo(a.modified));

    return [...folders, ...files];
  }
}

/// Top-level isolate entry point for file copying.
void _fileCopyIsolateEntry(Map<String, dynamic> params) async {
  final SendPort mainSendPort = params['sendPort'];
  final String sourcePath = params['source'];
  final String destPath = params['destination'];
  final String? taskId = params['taskId'];
  final int flushThreshold = params['flushThreshold'];

  final controlPort = ReceivePort();
  mainSendPort.send(controlPort.sendPort);

  bool isCancelled = false;
  controlPort.listen((message) {
    if (message is Map && message['command'] == 'cancel') {
      isCancelled = true;
    }
  });

  RandomAccessFile? sourceRaf;
  RandomAccessFile? destRaf;

  try {
    sourceRaf = await File(sourcePath).open(mode: FileMode.read);
    destRaf = await File(destPath).open(mode: FileMode.write);

    final buffer = Uint8List(1024 * 1024 * 8); // 8MB buffer
    int bytesCopied = 0;
    int bytesSinceLastFlush = 0;
    final stopwatch = Stopwatch()..start();

    int bytesRead;
    while ((bytesRead = await sourceRaf!.readInto(buffer)) > 0) {
      if (isCancelled) {
        await sourceRaf!.close();
        await destRaf!.close();
        sourceRaf = null;
        destRaf = null;
        
        final partialFile = File(destPath);
        if (await partialFile.exists()) {
          await partialFile.delete();
        }
        
        mainSendPort.send({'status': 'cancelled', 'taskId': taskId});
        return;
      }

      await destRaf!.writeFrom(buffer, 0, bytesRead);
      bytesCopied += bytesRead;
      bytesSinceLastFlush += bytesRead;

      if (stopwatch.elapsedMilliseconds > 200) {
        mainSendPort.send({
          'status': 'progress',
          'taskId': taskId,
          'bytesCopied': bytesCopied,
        });
        stopwatch.reset();
      }

      if (bytesSinceLastFlush >= flushThreshold) {
        await destRaf!.flush();
        bytesSinceLastFlush = 0;
      }
    }

    mainSendPort.send({
      'status': 'progress',
      'taskId': taskId,
      'bytesCopied': bytesCopied,
    });

    mainSendPort.send({'status': 'syncing', 'taskId': taskId});
    
    await destRaf!.flush();
    await destRaf!.close();
    await sourceRaf!.close();
    sourceRaf = null;
    destRaf = null;

    mainSendPort.send({'status': 'completed', 'taskId': taskId});
  } catch (e) {
    mainSendPort.send({
      'status': 'error',
      'taskId': taskId,
      'error': e.toString(),
    });
  } finally {
    await sourceRaf?.close();
    await destRaf?.close();
    controlPort.close();
  }
}
