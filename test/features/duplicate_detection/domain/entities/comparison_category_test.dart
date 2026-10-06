import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_category.dart';

void main() {
  group('ComparisonCategory', () {
    test('has exactly five values', () {
      expect(ComparisonCategory.values.length, 5);
    });

    test('contains all expected variants', () {
      expect(
        ComparisonCategory.values,
        containsAll([
          ComparisonCategory.all,
          ComparisonCategory.images,
          ComparisonCategory.videos,
          ComparisonCategory.audio,
          ComparisonCategory.other,
        ]),
      );
    });

    test('values are distinct', () {
      final unique = ComparisonCategory.values.toSet();
      expect(unique.length, ComparisonCategory.values.length);
    });

    test('can be compared by identity', () {
      expect(ComparisonCategory.images, ComparisonCategory.images);
      expect(ComparisonCategory.images, isNot(ComparisonCategory.videos));
    });
  });
}
