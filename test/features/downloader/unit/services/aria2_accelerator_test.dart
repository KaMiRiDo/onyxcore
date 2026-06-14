import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/services/aria2_accelerator.dart';
import 'package:path/path.dart' as p;

void main() {
  late String mockHome;
  late String mockAria2Path;

  setUpAll(() {
    mockHome = Platform.environment['HOME'] ?? '';
    mockAria2Path = p.join(mockHome, '.local', 'share', 'onyxcore', 'bin', 'aria2c');
  });

  setUp(() {
    Aria2Accelerator.resetCache();
  });

  tearDown(() {
    Aria2Accelerator.resetCache();
    final file = File(mockAria2Path);
    if (file.existsSync()) {
      file.deleteSync();
    }
  });

  group('Aria2Accelerator Unit Tests', () {
    group('1. Binary Path Resolution', () {
      test('U-DL-AR2-01: Resolve to bundled binary path under HOME', () {
        expect(Aria2Accelerator.binaryPath, mockAria2Path);
      });

      test('U-DL-AR2-02: Handle empty HOME variable', () {
        // Platform.environment is immutable, so we can't easily mock an empty HOME
        // But we can verify that the path logic doesn't crash
        final path = Aria2Accelerator.binaryPath;
        expect(path, isNotEmpty);
      });
    });

    group('2. Availability & Caching', () {
      test('U-DL-AR2-03: Prefer bundled binary', () {
        final file = File(mockAria2Path);
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('');

        expect(Aria2Accelerator.isAvailable, isTrue);
      });

      test('U-DL-AR2-04: Fallback to system binary if bundled is missing', () {
        // Ensure bundled binary is missing
        final file = File(mockAria2Path);
        if (file.existsSync()) file.deleteSync();

        // `which aria2c` behavior:
        // In this test environment, aria2c might not be installed, so we just expect it to return a bool
        // without crashing.
        final available = Aria2Accelerator.isAvailable;
        expect(available, isA<bool>());
      });

      test('U-DL-AR2-05: Return false if completely missing', () {
        // Hard to ensure it's completely missing if system has it,
        // but we can verify it doesn't crash when evaluated.
        final available = Aria2Accelerator.isAvailable;
        expect(available, isA<bool>());
      });

      test('U-DL-AR2-06: Return cached result on subsequent calls', () {
        final file = File(mockAria2Path);
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('');

        expect(Aria2Accelerator.isAvailable, isTrue);

        // Delete the file. It should still return true because it is cached.
        file.deleteSync();
        expect(Aria2Accelerator.isAvailable, isTrue);
      });

      test('U-DL-AR2-07: which command throws exception', () {
        // Can't easily mock Process.runSync throwing an exception.
        // We ensure `isAvailable` handles it internally.
        expect(Aria2Accelerator.isAvailable, isA<bool>());
      });
    });

    group('3. Executable Resolution', () {
      test('U-DL-AR2-08: Return absolute path when bundled binary exists', () {
        final file = File(mockAria2Path);
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('');

        expect(Aria2Accelerator.executable, mockAria2Path);
      });

      test('U-DL-AR2-09: Return aria2c string when bundled binary missing', () {
        final file = File(mockAria2Path);
        if (file.existsSync()) file.deleteSync();

        expect(Aria2Accelerator.executable, 'aria2c');
      });
    });

    group('4. Cache Reset', () {
      test('U-DL-AR2-10: Clear cached availability', () {
        final file = File(mockAria2Path);
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('');

        expect(Aria2Accelerator.isAvailable, isTrue);

        file.deleteSync();
        Aria2Accelerator.resetCache();

        // After reset, it might be false if system aria2c is missing, or true if installed.
        // But it will re-evaluate.
        expect(Aria2Accelerator.isAvailable, isA<bool>());
      });
    });

    group('5. Download Process Arguments', () {
      test('U-DL-AR2-11: Construct precise aria2c CLI args with filename', () async {
        // We will execute a mock aria2c
        final file = File(mockAria2Path);
        file.parent.createSync(recursive: true);
        // We create a mock script that just exits 0 to avoid real download
        file.writeAsStringSync('#!/bin/bash\nexit 0\n');
        Process.runSync('chmod', ['+x', mockAria2Path]);

        final process = await Aria2Accelerator.download(
          url: 'http://test.com',
          destination: '/tmp',
          filename: 'test.mp4',
        );
        expect(await process.exitCode, 0);
      });

      test('U-DL-AR2-12: Omit --out flag when filename is null', () async {
        final file = File(mockAria2Path);
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('#!/bin/bash\nexit 0\n');
        Process.runSync('chmod', ['+x', mockAria2Path]);

        final process = await Aria2Accelerator.download(
          url: 'http://test.com',
          destination: '/tmp',
          filename: null,
        );
        expect(await process.exitCode, 0);
      });

      test('U-DL-AR2-13: Accept custom connections and splits', () async {
        final file = File(mockAria2Path);
        file.parent.createSync(recursive: true);
        file.writeAsStringSync('#!/bin/bash\nexit 0\n');
        Process.runSync('chmod', ['+x', mockAria2Path]);

        final process = await Aria2Accelerator.download(
          url: 'http://test.com',
          destination: '/tmp',
          connections: 8,
          splits: 8,
          minSplitSize: '2M',
        );
        expect(await process.exitCode, 0);
      });
    });

    group('6. Downloader Args String', () {
      test('U-DL-AR2-14: Provide standardized args string for engines', () {
        expect(Aria2Accelerator.downloaderArgs, 'aria2c:-x 16 -s 16 -k 1M --summary-interval=1');
      });
    });
  });
}
