import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/strategies/other_media_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/fingerprint_generator.dart';
import 'package:path/path.dart' as p;

void main() {
  group('OtherMediaStrategy', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('other_strategy_');
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

    test('supports other, document, archive, downloaderList', () {
      final strategy = OtherMediaStrategy();
      expect(
        strategy.supports(createCandidate('doc.txt', FileItemType.document)),
        isTrue,
      );
      expect(
        strategy.supports(createCandidate('arch.zip', FileItemType.archive)),
        isTrue,
      );
      expect(
        strategy.supports(createCandidate('foo.bin', FileItemType.other)),
        isTrue,
      );

      expect(
        strategy.supports(createCandidate('a.mp3', FileItemType.audio)),
        isFalse,
      );
    });

    test('extractMetadata returns empty metadata', () async {
      final strategy = OtherMediaStrategy();
      final candidate = createCandidate('doc.txt', FileItemType.document);

      final meta = await strategy.extractMetadata(candidate);

      expect(meta.orientation, MediaOrientation.notApplicable);
      expect(meta.aspectRatioGroup, isNull);
      expect(meta.durationSeconds, isNull);
    });

    group('Stage 2 Fingerprinting (Unsupported)', () {
      test('does not support candidate for fingerprinting', () {
        final strategy = OtherMediaStrategy();
        final candidate = createCandidate('doc.txt', FileItemType.document);

        // When queried as FingerprintGenerator, returns false
        expect(strategy.supportsFingerprinting(candidate), isFalse);
      });

      test(
        'throws FingerprintGenerationException if generate is invoked',
        () async {
          final strategy = OtherMediaStrategy();
          final candidate = createCandidate('doc.txt', FileItemType.document);

          expect(
            () => strategy.generate(candidate),
            throwsA(isA<FingerprintGenerationException>()),
          );
        },
      );
    });
  });
}
