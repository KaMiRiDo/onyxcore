import 'package:onyxcore/features/duplicate_detection/domain/entities/cluster_key.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_cluster.dart';

class Stage1ClusterBuilder {
  final Map<ClusterKey, _MutableCluster> _clusters = {};

  void add(ComparisonCandidate candidate, ClusterKey key) {
    final cluster = _clusters.putIfAbsent(key, _MutableCluster.new);
    if (candidate.isSource) {
      cluster.sources.add(candidate);
    } else {
      cluster.destinations.add(candidate);
    }
  }

  List<Stage1Cluster> build() {
    return _clusters.entries.map((e) {
      return Stage1Cluster(
        key: e.key,
        sourceCandidates: List.unmodifiable(e.value.sources),
        destinationCandidates: List.unmodifiable(e.value.destinations),
      );
    }).toList();
  }
}

class _MutableCluster {
  final List<ComparisonCandidate> sources = [];
  final List<ComparisonCandidate> destinations = [];
}
