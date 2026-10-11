import 'package:equatable/equatable.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_cluster.dart';

class Stage1Failure extends Equatable {
  const Stage1Failure(this.candidate, this.error);
  final ComparisonCandidate candidate;
  final String error;

  @override
  List<Object?> get props => [candidate, error];
}

class Stage1Result extends Equatable {
  const Stage1Result({required this.pairs, required this.failures});

  final List<ClusterPair> pairs;
  final List<Stage1Failure> failures;

  @override
  List<Object?> get props => [pairs, failures];
}
