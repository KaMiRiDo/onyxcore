import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_threshold_config.dart';

void main() {
  group('ComparisonThresholdConfig', () {
    test('default configuration has balanced thresholds', () {
      const config = ComparisonThresholdConfig();
      expect(config.imageThreshold, 0.92);
      expect(config.videoThreshold, 0.90);
      expect(config.audioThreshold, 0.90);
      expect(config.exactMatchOnly, isFalse);
    });

    test(
      'thresholdFor returns media-specific threshold when not exactMatchOnly',
      () {
        const config = ComparisonThresholdConfig(
          imageThreshold: 0.95,
          videoThreshold: 0.88,
          audioThreshold: 0.85,
        );
        expect(config.thresholdFor(FileItemType.image), 0.95);
        expect(config.thresholdFor(FileItemType.video), 0.88);
        expect(config.thresholdFor(FileItemType.audio), 0.85);
        expect(config.thresholdFor(FileItemType.other), 1.0);
      },
    );

    test(
      'thresholdFor returns 1.0 for all types when exactMatchOnly is true',
      () {
        const config = ComparisonThresholdConfig(
          imageThreshold: 0.80,
          videoThreshold: 0.70,
          audioThreshold: 0.60,
          exactMatchOnly: true,
        );
        expect(config.thresholdFor(FileItemType.image), 1.0);
        expect(config.thresholdFor(FileItemType.video), 1.0);
        expect(config.thresholdFor(FileItemType.audio), 1.0);
        expect(config.thresholdFor(FileItemType.other), 1.0);
      },
    );

    test('asserts when thresholds are outside [0.0, 1.0]', () {
      expect(
        () => ComparisonThresholdConfig(imageThreshold: 1.05),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ComparisonThresholdConfig(videoThreshold: -0.01),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => ComparisonThresholdConfig(audioThreshold: 2),
        throwsA(isA<AssertionError>()),
      );
    });

    test('copyWith updates individual thresholds', () {
      const config = ComparisonThresholdConfig();
      final updated = config.copyWith(
        imageThreshold: 0.99,
        exactMatchOnly: true,
      );
      expect(updated.imageThreshold, 0.99);
      expect(updated.videoThreshold, 0.90);
      expect(updated.exactMatchOnly, isTrue);
    });

    test('supports Equatable equality', () {
      const config1 = ComparisonThresholdConfig();
      const config2 = ComparisonThresholdConfig();
      expect(config1, equals(config2));

      final config3 = config1.copyWith(exactMatchOnly: true);
      expect(config1, isNot(equals(config3)));
    });
  });
}
