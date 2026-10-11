import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_cluster.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/cluster_compatibility.dart';

class ClusterPairGenerator {
  static List<ClusterPair> generatePairs(List<Stage1Cluster> clusters) {
    final pairs = <ClusterPair>[];

    for (var i = 0; i < clusters.length; i++) {
      final clusterA = clusters[i];

      // Self-pairing: only if cluster has BOTH sources and destinations.
      if (clusterA.sourceCandidates.isNotEmpty &&
          clusterA.destinationCandidates.isNotEmpty) {
        pairs.add(ClusterPair(clusterA, clusterA));
      }

      // Pair with subsequent compatible clusters
      for (var j = i + 1; j < clusters.length; j++) {
        final clusterB = clusters[j];

        // We only pair if at least one cluster provides sources and the other provides destinations
        final aProvidesSources = clusterA.sourceCandidates.isNotEmpty;
        final aProvidesDestinations = clusterA.destinationCandidates.isNotEmpty;
        final bProvidesSources = clusterB.sourceCandidates.isNotEmpty;
        final bProvidesDestinations = clusterB.destinationCandidates.isNotEmpty;

        final canProvidePairs =
            (aProvidesSources && bProvidesDestinations) ||
            (bProvidesSources && aProvidesDestinations);

        if (canProvidePairs &&
            ClusterCompatibility.isCompatible(clusterA.key, clusterB.key)) {
          pairs.add(ClusterPair(clusterA, clusterB));
        }
      }
    }

    return pairs;
  }
}
