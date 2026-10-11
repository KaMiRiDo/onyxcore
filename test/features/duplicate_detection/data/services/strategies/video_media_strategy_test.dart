import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/media_probe.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/strategies/video_media_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';
import 'package:path/path.dart' as p;

class FakeMediaProbe extends MediaProbe {
  FakeMediaProbe(this.stdout, this.exitCode);
  final String stdout;
  final int exitCode;

  @override
  Future<ProcessResult> runFfprobe(List<String> args) async {
    return ProcessResult(0, exitCode, stdout, '');
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
  });
}
