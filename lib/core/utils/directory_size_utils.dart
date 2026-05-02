import 'dart:io';
import 'dart:math';
import 'dart:isolate';

/// Represents a progress update from the directory size calculation isolate.
class DirectorySizeUpdate {
  final int size;
  final int count;
  final bool isFinished;

  DirectorySizeUpdate({
    required this.size,
    required this.count,
    required this.isFinished,
  });
}

/// The arguments passed to the Isolate.
class DirectorySizeArgs {
  final List<String> paths;
  final SendPort sendPort;
  final int updateFrequency;

  DirectorySizeArgs({
    required this.paths,
    required this.sendPort,
    this.updateFrequency = 500,
  });
}

/// Top-level function designed to be run in an Isolate via Isolate.spawn()
/// Sends intermediate and final results through the provided SendPort.
void calculateDirectorySizeIncremental(DirectorySizeArgs args) {
  _processDirectoryAsync(args);
}

Future<void> _processDirectoryAsync(DirectorySizeArgs args) async {
  int totalSize = 0;
  int itemCount = 0;

  try {
    for (final path in args.paths) {
      if (FileSystemEntity.isFileSync(path)) {
        itemCount++;
        try {
          totalSize += File(path).lengthSync();
        } catch (_) {}
        
        if (itemCount % args.updateFrequency == 0) {
          args.sendPort.send(DirectorySizeUpdate(
            size: totalSize,
            count: itemCount,
            isFinished: false,
          ));
        }
      } else if (FileSystemEntity.isDirectorySync(path)) {
        await for (final entity in Directory(path).list(recursive: true, followLinks: false)) {
          itemCount++;
          if (entity is File) {
            try {
              totalSize += entity.lengthSync();
            } catch (_) {}
          }

          if (itemCount % args.updateFrequency == 0) {
            args.sendPort.send(DirectorySizeUpdate(
              size: totalSize,
              count: itemCount,
              isFinished: false,
            ));
          }
        }
      }
    }
  } catch (e) {
    print('Background sizing error (permissions): $e');
  }

  // Send final update
  args.sendPort.send(DirectorySizeUpdate(
    size: totalSize,
    count: itemCount,
    isFinished: true,
  ));
}

/// Helper method to format bytes into readable strings (KB, MB, GB)
String formatBytes(int bytes) {
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB", "TB"];
  int i = (log(bytes) / log(1024)).floor();
  if (i >= suffixes.length) i = suffixes.length - 1;
  return '${(bytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
}
