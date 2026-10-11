import 'package:equatable/equatable.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/cluster_key.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';

class Stage1Cluster extends Equatable {
  const Stage1Cluster({
    required this.key,
    required this.sourceCandidates,
    required this.destinationCandidates,
  });

  final ClusterKey key;
  final List<ComparisonCandidate> sourceCandidates;
  final List<ComparisonCandidate> destinationCandidates;

  @override
  List<Object?> get props => [key, sourceCandidates, destinationCandidates];
}

class ClusterPair extends Equatable {
  const ClusterPair(this.clusterA, this.clusterB);
  final Stage1Cluster clusterA;
  final Stage1Cluster clusterB;

  @override
  List<Object?> get props => [clusterA, clusterB];
}
