import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/cluster_key.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/cluster_compatibility.dart';

void main() {
  group('ClusterCompatibility', () {
    test('different types -> incompatible', () {
      final key1 = ClusterKey(
        type: FileItemType.image,
        orientation: MediaOrientation.landscape,
      );
      final key2 = ClusterKey(
        type: FileItemType.video,
        orientation: MediaOrientation.landscape,
      );
      expect(ClusterCompatibility.isCompatible(key1, key2), isFalse);
    });

    group('orientation compatibility', () {
      test('same orientation -> compatible', () {
        final key1 = ClusterKey(
          type: FileItemType.image,
          orientation: MediaOrientation.landscape,
          aspectRatioGroup: 'ar10',
        );
        final key2 = ClusterKey(
          type: FileItemType.image,
          orientation: MediaOrientation.landscape,
          aspectRatioGroup: 'ar10',
        );
        expect(ClusterCompatibility.isCompatible(key1, key2), isTrue);
      });
      test('landscape vs portrait -> incompatible', () {
        final key1 = ClusterKey(
          type: FileItemType.image,
          orientation: MediaOrientation.landscape,
          aspectRatioGroup: 'ar10',
        );
        final key2 = ClusterKey(
          type: FileItemType.image,
          orientation: MediaOrientation.portrait,
          aspectRatioGroup: 'ar10',
        );
        expect(ClusterCompatibility.isCompatible(key1, key2), isFalse);
      });
      test(
        'square vs landscape with low aspect index (<= 1) -> compatible',
        () {
          final key1 = ClusterKey(
            type: FileItemType.image,
            orientation: MediaOrientation.square,
            aspectRatioGroup: 'ar1',
          );
          final key2 = ClusterKey(
            type: FileItemType.image,
            orientation: MediaOrientation.landscape,
            aspectRatioGroup: 'ar0',
          );
          expect(ClusterCompatibility.isCompatible(key1, key2), isTrue);
        },
      );
      test(
        'square vs landscape with high aspect index (> 1) -> incompatible',
        () {
          final key1 = ClusterKey(
            type: FileItemType.image,
            orientation: MediaOrientation.square,
            aspectRatioGroup: 'ar0',
          );
          final key2 = ClusterKey(
            type: FileItemType.image,
            orientation: MediaOrientation.landscape,
            aspectRatioGroup: 'ar2',
          );
          expect(ClusterCompatibility.isCompatible(key1, key2), isFalse);
        },
      );
    });

    group('aspect ratio compatibility', () {
      test('aspect difference <= 1 -> compatible', () {
        final key1 = ClusterKey(
          type: FileItemType.image,
          orientation: MediaOrientation.landscape,
          aspectRatioGroup: 'ar10',
        );
        final key2 = ClusterKey(
          type: FileItemType.image,
          orientation: MediaOrientation.landscape,
          aspectRatioGroup: 'ar11',
        );
        expect(ClusterCompatibility.isCompatible(key1, key2), isTrue);
      });
      test('aspect difference > 1 -> incompatible', () {
        final key1 = ClusterKey(
          type: FileItemType.image,
          orientation: MediaOrientation.landscape,
          aspectRatioGroup: 'ar10',
        );
        final key2 = ClusterKey(
          type: FileItemType.image,
          orientation: MediaOrientation.landscape,
          aspectRatioGroup: 'ar12',
        );
        expect(ClusterCompatibility.isCompatible(key1, key2), isFalse);
      });
      test('null aspect ratios -> compatible', () {
        final key1 = ClusterKey(
          type: FileItemType.audio,
          orientation: MediaOrientation.notApplicable,
        );
        final key2 = ClusterKey(
          type: FileItemType.audio,
          orientation: MediaOrientation.notApplicable,
        );
        expect(ClusterCompatibility.isCompatible(key1, key2), isTrue);
      });
      test('mixed null/non-null aspect ratio -> incompatible', () {
        final key1 = ClusterKey(
          type: FileItemType.image,
          orientation: MediaOrientation.landscape,
          aspectRatioGroup: 'ar10',
        );
        final key2 = ClusterKey(
          type: FileItemType.image,
          orientation: MediaOrientation.landscape,
        );
        expect(ClusterCompatibility.isCompatible(key1, key2), isFalse);
      });
    });

    group('duration compatibility', () {
      test('duration difference <= 5 (adjacent buckets) -> compatible', () {
        final key1 = ClusterKey(
          type: FileItemType.video,
          orientation: MediaOrientation.landscape,
          aspectRatioGroup: 'ar10',
          durationBucket: 55,
        );
        final key2 = ClusterKey(
          type: FileItemType.video,
          orientation: MediaOrientation.landscape,
          aspectRatioGroup: 'ar10',
          durationBucket: 60,
        );
        expect(ClusterCompatibility.isCompatible(key1, key2), isTrue);
      });
      test('duration difference > 5 -> incompatible', () {
        final key1 = ClusterKey(
          type: FileItemType.video,
          orientation: MediaOrientation.landscape,
          aspectRatioGroup: 'ar10',
          durationBucket: 55,
        );
        final key2 = ClusterKey(
          type: FileItemType.video,
          orientation: MediaOrientation.landscape,
          aspectRatioGroup: 'ar10',
          durationBucket: 65,
        );
        expect(ClusterCompatibility.isCompatible(key1, key2), isFalse);
      });
    });
  });
}
