import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/cluster_key.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';

void main() {
  group('ClusterKey', () {
    const tKey = ClusterKey(
      type: FileItemType.image,
      orientation: MediaOrientation.landscape,
      aspectRatioGroup: '16:9',
    );

    // ── value equality ──────────────────────────────────────────────────────

    test('equal keys have the same Equatable identity', () {
      const tKey2 = ClusterKey(
        type: FileItemType.image,
        orientation: MediaOrientation.landscape,
        aspectRatioGroup: '16:9',
      );
      expect(tKey, equals(tKey2));
    });

    test('inequal when type differs', () {
      const other = ClusterKey(
        type: FileItemType.video,
        orientation: MediaOrientation.landscape,
        aspectRatioGroup: '16:9',
      );
      expect(tKey, isNot(equals(other)));
    });

    test('inequal when orientation differs', () {
      const other = ClusterKey(
        type: FileItemType.image,
        orientation: MediaOrientation.portrait,
        aspectRatioGroup: '16:9',
      );
      expect(tKey, isNot(equals(other)));
    });

    test('inequal when aspectRatioGroup differs', () {
      const other = ClusterKey(
        type: FileItemType.image,
        orientation: MediaOrientation.landscape,
        aspectRatioGroup: '4:3',
      );
      expect(tKey, isNot(equals(other)));
    });

    // ── deterministic construction ──────────────────────────────────────────

    test(
      'fromMetadata produces deterministic equal keys for identical metadata',
      () {
        const meta1 = Stage1Metadata(
          candidatePath: '/source/photo.jpg',
          orientation: MediaOrientation.landscape,
          aspectRatioGroup: '16:9',
        );
        const meta2 = Stage1Metadata(
          candidatePath: '/dest/photo.jpg',
          orientation: MediaOrientation.landscape,
          aspectRatioGroup: '16:9',
        );

        final key1 = ClusterKey.fromMetadata(FileItemType.image, meta1);
        final key2 = ClusterKey.fromMetadata(FileItemType.image, meta2);

        expect(key1, equals(key2));
      },
    );

    test('fromMetadata produces different keys for different orientations', () {
      const meta1 = Stage1Metadata(
        candidatePath: '/photo1.jpg',
        orientation: MediaOrientation.landscape,
      );
      const meta2 = Stage1Metadata(
        candidatePath: '/photo2.jpg',
        orientation: MediaOrientation.portrait,
      );

      final key1 = ClusterKey.fromMetadata(FileItemType.image, meta1);
      final key2 = ClusterKey.fromMetadata(FileItemType.image, meta2);

      expect(key1, isNot(equals(key2)));
    });

    // ── duration bucketing ──────────────────────────────────────────────────

    test('duration is bucketed to nearest 5-second interval', () {
      final meta12 = Stage1Metadata(
        candidatePath: '/clip1.mp4',
        orientation: MediaOrientation.landscape,
        durationSeconds: 12,
      );
      final meta13 = Stage1Metadata(
        candidatePath: '/clip2.mp4',
        orientation: MediaOrientation.landscape,
        durationSeconds: 13,
      );
      // Both 12s and 13s should round to the same 10s bucket (nearest 5 is 10).
      // 12/5=2.4 → round(2.4)=2 → 10; 13/5=2.6 → round(2.6)=3 → 15
      // So 12→10, 13→15; they should be in different buckets.
      final key12 = ClusterKey.fromMetadata(FileItemType.video, meta12);
      final key13 = ClusterKey.fromMetadata(FileItemType.video, meta13);
      // 12 rounds to 10, 13 rounds to 15 — different buckets
      expect(key12.durationBucket, 10);
      expect(key13.durationBucket, 15);
    });

    test(
      'similar durations within same 5-second bucket are grouped together',
      () {
        // 10s and 12s both round to the 10s bucket
        final meta10 = Stage1Metadata(
          candidatePath: '/clip_a.mp4',
          orientation: MediaOrientation.landscape,
          durationSeconds: 10,
        );
        final meta11 = Stage1Metadata(
          candidatePath: '/clip_b.mp4',
          orientation: MediaOrientation.landscape,
          durationSeconds: 11,
        );
        // 10/5=2.0 → round=2 → bucket=10
        // 11/5=2.2 → round=2 → bucket=10
        final key10 = ClusterKey.fromMetadata(FileItemType.video, meta10);
        final key11 = ClusterKey.fromMetadata(FileItemType.video, meta11);
        expect(key10, equals(key11));
      },
    );

    test('null duration produces null durationBucket', () {
      const meta = Stage1Metadata(
        candidatePath: '/photo.png',
        orientation: MediaOrientation.square,
      );
      final key = ClusterKey.fromMetadata(FileItemType.image, meta);
      expect(key.durationBucket, isNull);
    });

    // ── usability as Map/Set key ────────────────────────────────────────────

    test('equal ClusterKeys hash to the same value', () {
      const k1 = ClusterKey(
        type: FileItemType.image,
        orientation: MediaOrientation.landscape,
        aspectRatioGroup: '16:9',
      );
      const k2 = ClusterKey(
        type: FileItemType.image,
        orientation: MediaOrientation.landscape,
        aspectRatioGroup: '16:9',
      );
      expect(k1.hashCode, k2.hashCode);
    });

    test('can be used as a Map key', () {
      const key = ClusterKey(
        type: FileItemType.image,
        orientation: MediaOrientation.landscape,
      );
      final map = <ClusterKey, List<String>>{};
      map[key] = ['a', 'b'];
      expect(map[key], ['a', 'b']);
    });
  });
}
