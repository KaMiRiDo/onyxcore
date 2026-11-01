import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/media_probe.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/strategies/audio_media_strategy.dart';
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
    // 4000 bytes = 0.5s at 8000 Hz 8-bit PCM
    final bytes =
        ffmpegOutputBytes ?? List.generate(4000, (i) => (i * 3) % 256);
    return ProcessResult(0, ffmpegExitCode, bytes, '');
  }
}

void main() {
  group('AudioMediaStrategy', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('audio_strategy_');
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

    test('supports only audio', () {
      final strategy = AudioMediaStrategy(FakeMediaProbe('', 0));
      expect(
        strategy.supports(createCandidate('a.mp3', FileItemType.audio)),
        isTrue,
      );
      expect(
        strategy.supports(createCandidate('v.mp4', FileItemType.video)),
        isFalse,
      );
    });

    test('extractMetadata parses duration from format', () async {
      const jsonOutput = '''
      {
        "format": {"duration": "65.2"}
      }
      ''';
      final strategy = AudioMediaStrategy(FakeMediaProbe(jsonOutput, 0));
      final candidate = createCandidate('audio.mp3', FileItemType.audio);

      final meta = await strategy.extractMetadata(candidate);

      expect(meta.orientation, MediaOrientation.notApplicable);
      expect(meta.aspectRatioGroup, isNull);
      expect(meta.durationSeconds, 65.2);
    });

    group('Stage 2 Audio Fingerprint Generation', () {
      test(
        'samples bounded 4 segments without loading entire audio and produces 256-bit fingerprint',
        () async {
          const jsonOutput = '{"format": {"duration": "180.0"}}';
          final probe = FakeMediaProbe(jsonOutput, 0);
          final strategy = AudioMediaStrategy(probe);
          final candidate = createCandidate('audio.mp3', FileItemType.audio);

          final fp = await strategy.generate(candidate);

          expect(fp.bytes.length, 32);
          expect(fp.candidatePath, candidate.file.path);
          // Expect 4 bounded segment extractions
          expect(probe.ffmpegCalls.length, 4);

          // Verify ffmpeg arguments used downsampling to 8 kHz mono and fast seek
          for (final args in probe.ffmpegCalls) {
            expect(args, contains('-ss'));
            expect(args, contains('-ar'));
            expect(args, contains('8000'));
            expect(args, contains('-ac'));
            expect(args, contains('1'));
          }
        },
      );

      test(
        'deterministic: identical acoustic segments produce identical 256-bit bytes',
        () async {
          const jsonOutput = '{"format": {"duration": "120.0"}}';
          final probe = FakeMediaProbe(jsonOutput, 0);
          final strategy = AudioMediaStrategy(probe);
          final candidate = createCandidate('audio.mp3', FileItemType.audio);

          final fp1 = await strategy.generate(candidate);
          final fp2 = await strategy.generate(candidate);

          expect(fp1.bytes, equals(fp2.bytes));
        },
      );

      test(
        'throws FingerprintGenerationException on ffmpeg execution failure',
        () async {
          const jsonOutput = '{"format": {"duration": "120.0"}}';
          final probe = FakeMediaProbe(jsonOutput, 0, ffmpegExitCode: 1);
          final strategy = AudioMediaStrategy(probe);
          final candidate = createCandidate(
            'bad_audio.mp3',
            FileItemType.audio,
          );

          expect(
            () => strategy.generate(candidate),
            throwsA(isA<FingerprintGenerationException>()),
          );
        },
      );
    });
  });
}
