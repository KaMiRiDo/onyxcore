import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';

void main() {
  group('ComparisonCandidate', () {
    final tModified = DateTime(2024, 6, 15);

    final tCandidate = ComparisonCandidate(
      file: FileItem(
        path: '/source/photo.jpg',
        name: 'photo.jpg',
        type: FileItemType.image,
        sizeBytes: 2048,
        modified: tModified,
      ),
      isSource: true,
    );

    test('supports value equality via Equatable', () {
      final tCandidate2 = ComparisonCandidate(
        file: FileItem(
          path: '/source/photo.jpg',
          name: 'photo.jpg',
          type: FileItemType.image,
          sizeBytes: 2048,
          modified: tModified,
        ),
        isSource: true,
      );
      expect(tCandidate, equals(tCandidate2));
    });

    test('inequal when path differs', () {
      final other = tCandidate.copyWith(
        file: tCandidate.file.copyWith(path: '/other/photo.jpg'),
      );
      expect(tCandidate, isNot(equals(other)));
    });

    test('inequal when isSource differs', () {
      final destCandidate = tCandidate.copyWith(isSource: false);
      expect(tCandidate, isNot(equals(destCandidate)));
    });

    test('inequal when type differs', () {
      final other = tCandidate.copyWith(
        file: tCandidate.file.copyWith(type: FileItemType.video),
      );
      expect(tCandidate, isNot(equals(other)));
    });

    test('copyWith overrides individual fields', () {
      final newModified = DateTime(2025);
      final updated = tCandidate.copyWith(
        file: tCandidate.file.copyWith(
          path: '/dest/photo.jpg',
          name: 'photo_copy.jpg',
          type: FileItemType.video,
          sizeBytes: 4096,
          modified: newModified,
        ),
        isSource: false,
      );
      expect(updated.file.path, '/dest/photo.jpg');
      expect(updated.file.name, 'photo_copy.jpg');
      expect(updated.file.type, FileItemType.video);
      expect(updated.file.sizeBytes, 4096);
      expect(updated.file.modified, newModified);
      expect(updated.isSource, false);
    });

    test('copyWith retains original values when called with no arguments', () {
      final copy = tCandidate.copyWith();
      expect(copy, equals(tCandidate));
    });

    test('isSource correctly identifies source vs destination candidates', () {
      final srcCandidate = tCandidate.copyWith(isSource: true);
      final dstCandidate = tCandidate.copyWith(isSource: false);
      expect(srcCandidate.isSource, isTrue);
      expect(dstCandidate.isSource, isFalse);
    });

    test('can represent all supported FileItemTypes', () {
      final mediaTypes = [
        FileItemType.image,
        FileItemType.video,
        FileItemType.audio,
        FileItemType.other,
      ];
      for (final type in mediaTypes) {
        final candidate = tCandidate.copyWith(
          file: tCandidate.file.copyWith(type: type),
        );
        expect(candidate.file.type, type);
      }
    });
  });
}
