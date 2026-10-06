import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_category.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_request.dart';

void main() {
  group('ComparisonRequest', () {
    const tRequest = ComparisonRequest(
      sourceFolder: '/source',
      destinationFolder: '/destination',
      category: ComparisonCategory.images,
    );

    test('default recursive is true', () {
      expect(tRequest.recursive, isTrue);
    });

    test('supports value equality via Equatable', () {
      const tRequest2 = ComparisonRequest(
        sourceFolder: '/source',
        destinationFolder: '/destination',
        category: ComparisonCategory.images,
      );
      expect(tRequest, equals(tRequest2));
    });

    test('inequal when source differs', () {
      const other = ComparisonRequest(
        sourceFolder: '/other',
        destinationFolder: '/destination',
        category: ComparisonCategory.images,
      );
      expect(tRequest, isNot(equals(other)));
    });

    test('inequal when destination differs', () {
      const other = ComparisonRequest(
        sourceFolder: '/source',
        destinationFolder: '/other',
        category: ComparisonCategory.images,
      );
      expect(tRequest, isNot(equals(other)));
    });

    test('inequal when category differs', () {
      const other = ComparisonRequest(
        sourceFolder: '/source',
        destinationFolder: '/destination',
        category: ComparisonCategory.videos,
      );
      expect(tRequest, isNot(equals(other)));
    });

    test('inequal when recursive differs', () {
      const other = ComparisonRequest(
        sourceFolder: '/source',
        destinationFolder: '/destination',
        category: ComparisonCategory.images,
        recursive: false,
      );
      expect(tRequest, isNot(equals(other)));
    });

    test('copyWith overrides individual fields', () {
      final updated = tRequest.copyWith(category: ComparisonCategory.all);
      expect(updated.category, ComparisonCategory.all);
      expect(updated.sourceFolder, tRequest.sourceFolder);
      expect(updated.destinationFolder, tRequest.destinationFolder);
      expect(updated.recursive, tRequest.recursive);
    });

    test('copyWith retains original values when called with no arguments', () {
      final copy = tRequest.copyWith();
      expect(copy, equals(tRequest));
    });

    test('can use all ComparisonCategory values', () {
      for (final category in ComparisonCategory.values) {
        final req = tRequest.copyWith(category: category);
        expect(req.category, category);
      }
    });
  });
}
