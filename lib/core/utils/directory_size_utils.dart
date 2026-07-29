import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:flutter/foundation.dart';

/// Represents a progress update from the directory size calculation isolate.
class DirectorySizeUpdate {

  DirectorySizeUpdate({
    required this.size,
    required this.filesCount,
    required this.foldersCount,
    required this.isFinished,
  });
  final int size;
  final int filesCount;
  final int foldersCount;
  final bool isFinished;
}

/// The arguments passed to the Isolate.
class DirectorySizeArgs {

  DirectorySizeArgs({
    required this.paths,
    required this.sendPort,
    this.updateFrequency = 500,
  });
  final List<String> paths;
  final SendPort sendPort;
  final int updateFrequency;
}

/// Top-level function designed to be run in an Isolate via Isolate.spawn()
/// Sends intermediate and final results through the provided SendPort.
void calculateDirectorySizeIncremental(DirectorySizeArgs args) {
  _processDirectoryAsync(args);
}

Future<void> _processDirectoryAsync(DirectorySizeArgs args) async {
  var totalSize = 0;
  var filesCount = 0;
  var foldersCount = 0;

  try {
    for (final path in args.paths) {
      if (FileSystemEntity.isFileSync(path)) {
        filesCount++;
        try {
          totalSize += File(path).lengthSync();
        } catch (_) {}
      } else if (FileSystemEntity.isDirectorySync(path)) {
        foldersCount++;
        await for (final entity in Directory(
          path,
        ).list(recursive: true, followLinks: false)) {
          if (entity is File) {
            filesCount++;
            try {
              totalSize += entity.lengthSync();
            } catch (_) {}
          } else if (entity is Directory) {
            foldersCount++;
          }

          if ((filesCount + foldersCount) % args.updateFrequency == 0) {
            args.sendPort.send(
              DirectorySizeUpdate(
                size: totalSize,
                filesCount: filesCount,
                foldersCount: foldersCount,
                isFinished: false,
              ),
            );
          }
        }
      }
    }
  } catch (e) {
    debugPrint('Background sizing error (permissions): $e');
  }

  // Send final update
  args.sendPort.send(
    DirectorySizeUpdate(
      size: totalSize,
      filesCount: filesCount,
      foldersCount: foldersCount,
      isFinished: true,
    ),
  );
}

/// Helper method to format bytes into readable strings (KB, MB, GB)
String formatBytes(int bytes) {
  if (bytes <= 0) return '0 B';
  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
  var i = (log(bytes) / log(1024)).floor();
  if (i >= suffixes.length) i = suffixes.length - 1;
  return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
}
