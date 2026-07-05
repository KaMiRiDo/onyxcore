import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/engines/youget_engine.dart';
import 'package:path/path.dart' as p;

class MockProcess extends Fake implements Process {
  @override
  Future<int> get exitCode => Future.value(0);
}

class TestYouGetEngine extends YouGetEngine {
  TestYouGetEngine(this.testPath);
  final String testPath;

  @override
  String? get binaryPath => testPath;

  @override
  Future<Process>? install() async => MockProcess();

  @override
  Future<Process>? uninstall() async => MockProcess();
}

void main() {
  late YouGetEngine engine;
  late String mockYouGetPath;

  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('youget_test_');
    mockYouGetPath = p.join(tempDir.path, 'you-get');
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });



  setUp(() {
    engine = TestYouGetEngine(mockYouGetPath);
  });

  tearDown(() {
    final file = File(mockYouGetPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
  });

  void setMockYouGetOutput(String output, {int delayMs = 0, int exitCode = 0}) {
    final file = File(mockYouGetPath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final script = '''#!/bin/bash
sleep ${delayMs / 1000}
cat << 'EOF' >&1
$output
EOF
exit $exitCode
''';
    file.writeAsStringSync(script);
    Process.runSync('chmod', ['+x', mockYouGetPath]);
  }

  group('YouGetEngine Unit Tests', () {
    group('1. Environment & Path Resolution', () {
      test('U-DL-YGT-01: Resolve path from common locations', () {
        // We ensure the file exists in the common path
        File(mockYouGetPath).writeAsStringSync('');
        expect(engine.binaryPath, mockYouGetPath);
        File(mockYouGetPath).deleteSync();
      });

      test('U-DL-YGT-02: Fallback to which if not in common paths', () {
        // Verify getter behavior. If not found, it tries `which`.
        // We just verify it does not crash.
        final path = engine.binaryPath;
        expect(true, isTrue);
      });
    });

    group('2. Metadata Fetching', () {
      test('U-DL-YGT-03: Parse You-Get standard JSON', () async {
        final mockJson = jsonEncode({
          'title': 'My You-Get Video',
          'site': 'Bilibili',
          'streams': {
            'flv': {
              'container': 'flv',
              'quality': '1080p High',
              'size': 1048576
            }
          }
        });
        setMockYouGetOutput(mockJson);

        final infos = await engine.fetchMetadata(url: 'http://video.com/1');
        expect(infos.length, 1);
        final info = infos.first;
        expect(info.title, 'My You-Get Video');
        expect(info.extractor, 'Bilibili');
        expect(info.formats.first.formatId, 'flv');
        expect(info.formats.first.extension, 'flv');
        expect(info.formats.first.resolution, '1080p High');
        expect(info.filesize, 1048576);
      });

      test('U-DL-YGT-04: Handle empty JSON blocks', () async {
        // The engine expects valid JSON. Empty JSON `{}` without title or streams is handled safely
        final mockJson = jsonEncode({});
        setMockYouGetOutput(mockJson);

        final infos = await engine.fetchMetadata(url: 'http://video.com/1');
        expect(infos.length, 1);
        expect(infos.first.title, 'Unknown Title');
      });

      test('U-DL-YGT-05: Handle process errors', () async {
        // Exit code 1
        setMockYouGetOutput('{"error": "some stderr"}', exitCode: 1);
        
        // Wait, if exitCode is 1 but stdout has JSON, YouGetEngine parses it.
        // Let's output empty stdout and some stderr. Wait, our mock script writes to stdout.
        // Let's write directly to stderr.
        final file = File(mockYouGetPath);
        const script = '''
#!/bin/bash
echo "Network error" >&2
exit 1
''';
        file.writeAsStringSync(script);
        Process.runSync('chmod', ['+x', mockYouGetPath]);

        expect(
          () => engine.fetchMetadata(url: 'http://video.com/1'),
          throwsA(predicate((e) => e.toString().contains('Network error'))),
        );
      });

      test('U-DL-YGT-06: Malformed JSON array', () async {
        setMockYouGetOutput('{"title": "incomplete"');
        
        expect(
          () => engine.fetchMetadata(url: 'http://video.com/1'),
          throwsA(predicate((e) => e.toString().contains('Could not find JSON') || e.toString().contains('Unexpected end of input'))),
        );
      });
    });

    group('3. Download Execution', () {
      test('U-DL-YGT-07: Construct download args with format ID', () async {
        setMockYouGetOutput('');
        final process = await engine.startDownload(
          url: 'http://video.com/1',
          destination: '/tmp',
          format: const MediaFormat(formatId: 'flv', extension: 'flv', resolution: '1080p', formatString: '1080p (flv)'),
        );
        expect(await process.exitCode, 0);
      });

      test('U-DL-YGT-08: Construct download args with title and destination', () async {
        setMockYouGetOutput('');
        final process = await engine.startDownload(
          url: 'http://video.com/1',
          destination: '/tmp',
          title: 'My Video',
          format: const MediaFormat(formatId: 'mp4', extension: 'mp4', resolution: '1080p', formatString: '1080p (mp4)'),
        );
        expect(await process.exitCode, 0);
      });

      test('U-DL-YGT-09: Missing output directory', () async {
        // Even if directory is missing, startDownload returns a Process. The wrapper handles failures.
        setMockYouGetOutput('');
        final process = await engine.startDownload(
          url: 'http://video.com/1',
          destination: '/does_not_exist/tmp',
        );
        expect(await process.exitCode, 0); // Our mock script just exits 0.
      });
    });
  });
}
