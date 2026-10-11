import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/strategies/image_media_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/data/services/strategies/video_media_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/media_strategy_registry.dart';

void main() {
  group('MediaStrategyRegistry', () {
    test('returns first matching strategy', () {
      final registry = MediaStrategyRegistry([
        ImageMediaStrategy(),
        const VideoMediaStrategy(),
      ]);

      final imageCandidate = ComparisonCandidate(
        file: FileItem(
          path: '1.jpg',
          name: '1.jpg',
          type: FileItemType.image,
          modified: DateTime.now(),
          sizeBytes: 1,
        ),
        isSource: true,
      );

      final strategy = registry.getStrategy(imageCandidate);
      expect(strategy, isA<ImageMediaStrategy>());
    });

    test('throws StateError if no strategy matches', () {
      final registry = MediaStrategyRegistry([const VideoMediaStrategy()]);

      final imageCandidate = ComparisonCandidate(
        file: FileItem(
          path: '1.jpg',
          name: '1.jpg',
          type: FileItemType.image,
          modified: DateTime.now(),
          sizeBytes: 1,
        ),
        isSource: true,
      );

      expect(() => registry.getStrategy(imageCandidate), throwsStateError);
    });
  });
}
