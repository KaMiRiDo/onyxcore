import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_folder.dart';

void main() {
  group('ComparisonFolder', () {
    const tFolder = ComparisonFolder(path: '/media/photos', candidateCount: 42);

    test('default recursive is true', () {
      expect(tFolder.recursive, isTrue);
    });

    test('supports value equality via Equatable', () {
      const tFolder2 = ComparisonFolder(
        path: '/media/photos',
        candidateCount: 42,
      );
      expect(tFolder, equals(tFolder2));
    });

    test('inequal when candidateCount differs', () {
      const other = ComparisonFolder(path: '/media/photos', candidateCount: 0);
      expect(tFolder, isNot(equals(other)));
    });

    test('copyWith overrides path', () {
      final updated = tFolder.copyWith(path: '/new/path');
      expect(updated.path, '/new/path');
      expect(updated.candidateCount, tFolder.candidateCount);
    });

    test('copyWith retains original values when called with no arguments', () {
      final copy = tFolder.copyWith();
      expect(copy, equals(tFolder));
    });

    test('zero candidateCount is valid (before discovery)', () {
      const empty = ComparisonFolder(path: '/empty', candidateCount: 0);
      expect(empty.candidateCount, 0);
    });
  });
}
