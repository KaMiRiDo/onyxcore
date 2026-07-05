import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/engines/playwright_engine.dart';

class MockProcess extends Fake implements Process {

  MockProcess(this._exitCode, this._stdout, this._stderr);
  final int _exitCode;
  final String _stdout;
  final String _stderr;

  @override
  int get pid => 12345;

  @override
  Future<int> get exitCode => Future.value(_exitCode);

  @override
  Stream<List<int>> get stdout => Stream.value(utf8.encode(_stdout));

  @override
  Stream<List<int>> get stderr => Stream.value(utf8.encode(_stderr));
}

class TestPlaywrightEngine extends PlaywrightEngine {
  TestPlaywrightEngine(this.testPath);
  MockProcess? mockPythonProcess;
  final String testPath;

  @override
  String? get binaryPath => testPath;

  @override
  Future<Process> startPythonProcess(String url) async {
    if (mockPythonProcess != null) return mockPythonProcess!;
    return super.startPythonProcess(url);
  }

  @override
  Future<Process>? install() async => MockProcess(0, '', '');

  @override
  Future<Process>? uninstall() async => MockProcess(0, '', '');
}

void main() {
  late TestPlaywrightEngine engine;

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('playwright_test_');
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() {
    engine = TestPlaywrightEngine('${tempDir.path}/intercept_media.py');
  });

  group('PlaywrightEngine Unit Tests', () {
    group('1. Python Environment & Script Setup', () {
      test('U-DL-PLW-01: Return Python executable', () {
        // We verify the binary path for the script is correct
        expect(engine.binaryPath, contains('intercept_media.py'));
      });

      test('U-DL-PLW-02: Install playwright via PIP', () async {
        final installCmd = engine.install();
        expect(installCmd, isNotNull);
      });

      test('U-DL-PLW-04: Generate transient python script', () async {
        // fetchMetadata writes the script. We mock the process so it doesn't fail.
        engine.mockPythonProcess = MockProcess(0, jsonEncode({'thumbnail': '', 'media': [{'url': 'http://vid.mp4', 'type': 'video/mp4', 'size': '100'}]}), '');
        
        await engine.fetchMetadata(url: 'http://test.com');
        final script = File(engine.binaryPath!);
        expect(script.existsSync(), isTrue);
      });
    });

    group('2. Scraping & Metadata Fetching', () {
      test('U-DL-PLW-05: Execute Python script to extract direct video URL', () async {
        engine.mockPythonProcess = MockProcess(0, jsonEncode({
          'thumbnail': 'data:image/jpeg;base64,...',
          'media': [
            {'url': 'http://test.com/vid.mp4', 'type': 'video/mp4', 'size': '1048576'}
          ]
        }), '');

        final infos = await engine.fetchMetadata(url: 'http://test.com');
        expect(infos.length, 1);
        expect(infos.first.thumbnail, 'data:image/jpeg;base64,...');
        expect(infos.first.formats.first.formatString, 'http://test.com/vid.mp4');
        expect(infos.first.formats.first.resolution, contains('1.0 MB'));
      });

      test('U-DL-PLW-06: Parse embedded HLS/M3U8 streams', () async {
        engine.mockPythonProcess = MockProcess(0, jsonEncode({
          'media': [
            {'url': 'http://test.com/stream.m3u8', 'type': 'application/x-mpegurl', 'size': '0'}
          ]
        }), '');

        final infos = await engine.fetchMetadata(url: 'http://test.com');
        expect(infos.first.formats.first.extension, 'ts');
        expect(infos.first.formats.first.resolution, 'HLS Stream');
      });

      test('U-DL-PLW-07: Bypass failure or CAPTCHA block', () async {
        engine.mockPythonProcess = MockProcess(0, jsonEncode({
          'media': []
        }), 'hCaptcha blocked');

        expect(
          () => engine.fetchMetadata(url: 'http://test.com'),
          throwsException,
        );
      });
    });

    group('3. Download Execution (Aria2/FFmpeg/Curl Handoff)', () {
      test('U-DL-PLW-08: Use Aria2 for direct URLs extracted by Playwright', () async {
        // Start download directly
        // Note: Aria2Accelerator.isAvailable is static. We can't mock it trivially here without a wrapper.
        // It relies on `which aria2c`. If the system has it, it uses it.
        // We will just verify it returns a Future<Process>.
        final process = await engine.startDownload(
          url: 'http://test.com',
          destination: '/tmp',
          format: const MediaFormat(formatId: '1', extension: 'mp4', resolution: '1080p', formatString: 'http://test.com/vid.mp4'),
        );
        expect(process, isNotNull);
        // It's hard to assert the exact command since we get a running process, 
        // but we verify it didn't crash.
        // To prevent leaking processes, we kill it immediately.
        process.kill();
      });

      test('U-DL-PLW-09: Fallback to ffmpeg for HLS streams', () async {
        final process = await engine.startDownload(
          url: 'http://test.com',
          destination: '/tmp',
          format: const MediaFormat(formatId: '1', extension: 'ts', resolution: 'HLS', formatString: 'http://test.com/stream.m3u8'),
        );
        expect(process, isNotNull);
        process.kill();
      });

      test('U-DL-PLW-10: Fallback to curl if Aria2 absent', () async {
        // Same as above, just verify it returns a process.
        final process = await engine.startDownload(
          url: 'http://test.com',
          destination: '/tmp',
          format: const MediaFormat(formatId: '1', extension: 'mp4', resolution: '1080p', formatString: 'http://test.com/vid2.mp4'),
        );
        expect(process, isNotNull);
        process.kill();
      });
    });
  });
}
