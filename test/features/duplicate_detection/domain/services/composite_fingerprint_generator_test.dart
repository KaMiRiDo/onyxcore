import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/strategies/image_media_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/strategies/other_media_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/composite_fingerprint_generator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/fingerprint_generator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/media_strategy_registry.dart';

void main() {
  group('CompositeFingerprintGenerator', () {
    late CompositeFingerprintGenerator composite;

    setUp(() {
      final registry = MediaStrategyRegistry([
        ImageMediaStrategy(),
        OtherMediaStrategy(),
      ]);
      composite = CompositeFingerprintGenerator(registry);
    });

    test('supports returns true for supported media types', () {
      final imgCandidate = ComparisonCandidate(
        file: FileItem(
          path: '/photo.png',
          name: 'photo.png',
          type: FileItemType.image,
          modified: DateTime(2024),
          sizeBytes: 100,
        ),
        isSource: true,
      );
      expect(composite.supports(imgCandidate), isTrue);
    });

    test('generate throws on unsupported media type', () async {
      final docCandidate = ComparisonCandidate(
        file: FileItem(
          path: '/doc.txt',
          name: 'doc.txt',
          type: FileItemType.document,
          modified: DateTime(2024),
          sizeBytes: 100,
        ),
        isSource: true,
      );
      expect(
        () => composite.generate(docCandidate),
        throwsA(isA<FingerprintGenerationException>()),
      );
    });
  });
}
