import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/media_probe.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/strategies/video_media_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/fingerprint_generator.dart';
import 'package:path/path.dart' as p;

class FakeMediaProbe extends MediaProbe {
  FakeMediaProbe(
    this.stdout,
    this.exitCode, {
    this.ffmpegOutputBytes,
    this.ffmpegExitCode = 0,
  });

  final String stdout;
  final int exitCode;
  final List<int>? ffmpegOutputBytes;
  final int ffmpegExitCode;
  final List<List<String>> ffmpegCalls = [];

  @override
  Future<ProcessResult> runFfprobe(List<String> args) async {
    return ProcessResult(0, exitCode, stdout, '');
  }

  @override
  Future<ProcessResult> runFfmpeg(
    List<String> args, {
    bool binaryOutput = true,
  }) async {
    ffmpegCalls.add(args);
    // 72 bytes = 9x8 raw grayscale frame
    final bytes = ffmpegOutputBytes ?? List.generate(72, (i) => (i * 7) % 256);
    return ProcessResult(0, ffmpegExitCode, bytes, '');
  }
}

void main() {
  group('VideoMediaStrategy', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('video_strategy_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    ComparisonCandidate createCandidate(String name, FileItemType type) {
      final file = File(p.join(tempDir.path, name))..createSync();
      return ComparisonCandidate(
        file: FileItem(
          path: file.path,
          name: name,
          type: type,
          modified: DateTime.now(),
          sizeBytes: 100,
        ),
        isSource: true,
      );
    }

    test('supports only videos', () {
      final strategy = VideoMediaStrategy(FakeMediaProbe('', 0));
      expect(
        strategy.supports(createCandidate('v.mp4', FileItemType.video)),
        isTrue,
      );
      expect(
        strategy.supports(createCandidate('a.jpg', FileItemType.image)),
        isFalse,
      );
    });

    test('extractMetadata parses ffprobe json', () async {
      const jsonOutput = '''
      {
        "streams": [{"width": 1920, "height": 1080}],
        "format": {"duration": "120.5"}
      }
      ''';
      final strategy = VideoMediaStrategy(FakeMediaProbe(jsonOutput, 0));
      final candidate = createCandidate('vid.mp4', FileItemType.video);

      final meta = await strategy.extractMetadata(candidate);

      expect(meta.orientation, MediaOrientation.landscape);
      expect(meta.aspectRatioGroup, isNotNull);
      expect(meta.durationSeconds, 120.5);
    });

    test(
      'extractMetadata throws Stage1ExtractionException on ffprobe error',
      () async {
        final strategy = VideoMediaStrategy(FakeMediaProbe('error', 1));
        final candidate = createCandidate('vid.mp4', FileItemType.video);

        expect(
          () => strategy.extractMetadata(candidate),
          throwsA(isA<Exception>()),
        );
      },
    );

    group('Stage 2 Video Fingerprint Generation', () {
      test('samples bounded 4 frames and produces 256-bit fingerprint', () async {
        const jsonOutput = '''
        {
          "format": {"duration": "100.0"}
        }
        ''';
        final probe = FakeMediaProbe(jsonOutput, 0);
        final strategy = VideoMediaStrategy(probe);
        final candidate = createCandidate('vid.mp4', FileItemType.video);

        final fp = await strategy.generate(candidate);

        expect(fp.bytes.length, 32);
        expect(fp.candidatePath, candidate.file.path);
        // Expect exactly 4 frame samples
        expect(probe.ffmpegCalls.length, 4);

        // Verify ffmpeg arguments used bounded fast seeking and small 9x8 raw frames
        for (final args in probe.ffmpegCalls) {
          expect(args, contains('-ss'));
          expect(args, contains('scale=9:8,format=gray'));
          expect(args, contains('rawvideo'));
        }
      });

      test(
        'deterministic: identical sampled frames produce identical fingerprint',
        () async {
          const jsonOutput = '{"format": {"duration": "60.0"}}';
          final probe = FakeMediaProbe(jsonOutput, 0);
          final strategy = VideoMediaStrategy(probe);
          final candidate = createCandidate('vid.mp4', FileItemType.video);

          final fp1 = await strategy.generate(candidate);
          final fp2 = await strategy.generate(candidate);

          expect(fp1.bytes, equals(fp2.bytes));
        },
      );

      test(
        'throws FingerprintGenerationException on ffmpeg execution failure',
        () async {
          const jsonOutput = '{"format": {"duration": "60.0"}}';
          final probe = FakeMediaProbe(jsonOutput, 0, ffmpegExitCode: 1);
          final strategy = VideoMediaStrategy(probe);
          final candidate = createCandidate('vid.mp4', FileItemType.video);

          expect(
            () => strategy.generate(candidate),
            throwsA(isA<FingerprintGenerationException>()),
          );
        },
      );
    });
  });
}
