import 'dart:io';
import 'dart:isolate';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/directory_size_utils.dart';

void main() {
  group('formatBytes in directory_size_utils', () {
    test('formats bytes correctly', () {
      expect(formatBytes(0), '0 B');
      expect(formatBytes(-100), '0 B');
      expect(formatBytes(512), '512.00 B');
      expect(formatBytes(1024), '1.00 KB');
      expect(formatBytes((1024 * 1024 * 1.5).toInt()), '1.50 MB');
      expect(formatBytes(1024 * 1024 * 1024 * 3), '3.00 GB');
    });
  });

  group('calculateDirectorySizeIncremental', () {
    late Directory tempDir;
    late File file1;
    late File file2;
    late Directory subDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('dir_size_test_');
      file1 = File('${tempDir.path}/file1.txt')..writeAsStringSync('12345'); // 5 bytes
      file2 = File('${tempDir.path}/file2.txt')..writeAsStringSync('1234567890'); // 10 bytes
      subDir = Directory('${tempDir.path}/subdir')..createSync();
      File('${subDir.path}/file3.txt').writeAsStringSync('abc'); // 3 bytes
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('calculates size and reports correctly', () async {
      final receivePort = ReceivePort();
      final args = DirectorySizeArgs(
        paths: [tempDir.path],
        sendPort: receivePort.sendPort,
        updateFrequency: 1,
      );

      calculateDirectorySizeIncremental(args);

      final updates = <dynamic>[];
      await for (final update in receivePort) {
        updates.add(update);
        if (update is DirectorySizeUpdate && update.isFinished) {
          receivePort.close();
        }
      }

      expect(updates.isNotEmpty, isTrue);
      final finalUpdate = updates.last as DirectorySizeUpdate;
      expect(finalUpdate.isFinished, isTrue);
      expect(finalUpdate.filesCount, 3);
      expect(finalUpdate.foldersCount, 2); // tempDir and subdir
      expect(finalUpdate.size, 18);
    });

    test('handles files directly in paths list', () async {
      final receivePort = ReceivePort();
      final args = DirectorySizeArgs(
        paths: [file1.path, file2.path],
        sendPort: receivePort.sendPort,
        updateFrequency: 1,
      );

      calculateDirectorySizeIncremental(args);

      final updates = <dynamic>[];
      await for (final update in receivePort) {
        updates.add(update);
        if (update is DirectorySizeUpdate && update.isFinished) {
          receivePort.close();
        }
      }

      expect(updates.isNotEmpty, isTrue);
      final finalUpdate = updates.last as DirectorySizeUpdate;
      expect(finalUpdate.isFinished, isTrue);
      expect(finalUpdate.filesCount, 2);
      expect(finalUpdate.foldersCount, 0);
      expect(finalUpdate.size, 15);
    });
  });
}
