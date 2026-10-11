import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/media_probe.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/strategies/audio_media_strategy.dart';
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
  });
}
