import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/logger.dart' as app_logger;

base class TestIOOverrides extends IOOverrides {
  TestIOOverrides(this.tempDir);
  final Directory tempDir;

  @override
  File createFile(String path) {
    if (path.contains('device_log.txt')) {
      return super.createFile('${tempDir.path}/device_log.txt');
    }
    return super.createFile(path);
  }

  @override
  Directory createDirectory(String path) {
    if (path.contains('scratch')) {
      return super.createDirectory('${tempDir.path}/scratch');
    }
    return super.createDirectory(path);
  }
}

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('logger_test_');
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('log writes message to file', () {
    IOOverrides.runWithIOOverrides(() {
      app_logger.log('Hello World');

      final logFile = File('${tempDir.path}/device_log.txt');
      expect(logFile.existsSync(), isTrue);

      final content = logFile.readAsStringSync();
      expect(content, contains('Hello World'));
    }, TestIOOverrides(tempDir));
  });
}
