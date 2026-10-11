import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/cluster_key.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_cluster.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/cluster_pair_generator.dart';

void main() {
  group('ClusterPairGenerator', () {
    ComparisonCandidate candidate(String path, {required bool isSource}) {
      return ComparisonCandidate(
        file: FileItem(
          path: path,
          name: 'foo',
          type: FileItemType.image,
          modified: DateTime.now(),
          sizeBytes: 1,
        ),
        isSource: isSource,
      );
    }

    test(
      'generates pairs for compatible clusters containing source and dest candidates',
      () {
        final clusterA = Stage1Cluster(
          key: const ClusterKey(
            type: FileItemType.image,
            orientation: MediaOrientation.landscape,
          ),
          sourceCandidates: [candidate('s1', isSource: true)],
          destinationCandidates: [],
        );
        final clusterB = Stage1Cluster(
          key: const ClusterKey(
            type: FileItemType.image,
            orientation: MediaOrientation.landscape,
          ),
          sourceCandidates: [],
          destinationCandidates: [candidate('d1', isSource: false)],
        );

        final pairs = ClusterPairGenerator.generatePairs([clusterA, clusterB]);
        expect(pairs.length, 1);

        // We can pair a cluster with itself if it has both source and dest
        final clusterC = Stage1Cluster(
          key: const ClusterKey(
            type: FileItemType.image,
            orientation: MediaOrientation.landscape,
          ),
          sourceCandidates: [candidate('s2', isSource: true)],
          destinationCandidates: [candidate('d2', isSource: false)],
        );
        final pairsC = ClusterPairGenerator.generatePairs([clusterC]);
        expect(pairsC.length, 1);
      },
    );

    test('does not pair incompatible clusters', () {
      final clusterA = Stage1Cluster(
        key: const ClusterKey(
          type: FileItemType.image,
          orientation: MediaOrientation.landscape,
        ),
        sourceCandidates: [candidate('s1', isSource: true)],
        destinationCandidates: [],
      );
      final clusterB = Stage1Cluster(
        key: const ClusterKey(
          type: FileItemType.video,
          orientation: MediaOrientation.landscape,
        ),
        sourceCandidates: [],
        destinationCandidates: [candidate('d1', isSource: false)],
      );

      final pairs = ClusterPairGenerator.generatePairs([clusterA, clusterB]);
      expect(pairs, isEmpty);
    });
  });
}
