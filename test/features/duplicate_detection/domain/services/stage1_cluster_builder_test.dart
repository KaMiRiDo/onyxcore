import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/cluster_key.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage1_cluster_builder.dart';

void main() {
  group('Stage1ClusterBuilder', () {
    test('groups candidates by cluster key', () {
      final builder = Stage1ClusterBuilder();

      final candidate1 = ComparisonCandidate(
        file: FileItem(
          path: '1',
          name: '1',
          type: FileItemType.image,
          modified: DateTime.now(),
          sizeBytes: 1,
        ),
        isSource: true,
      );
      final candidate2 = ComparisonCandidate(
        file: FileItem(
          path: '2',
          name: '2',
          type: FileItemType.image,
          modified: DateTime.now(),
          sizeBytes: 1,
        ),
        isSource: false,
      );

      const key = ClusterKey(
        type: FileItemType.image,
        orientation: MediaOrientation.landscape,
      );

      builder
        ..add(candidate1, key)
        ..add(candidate2, key);

      final clusters = builder.build();
      expect(clusters.length, 1);
      expect(clusters.first.key, key);
      expect(clusters.first.sourceCandidates.length, 1);
      expect(clusters.first.destinationCandidates.length, 1);
    });
  });
}
