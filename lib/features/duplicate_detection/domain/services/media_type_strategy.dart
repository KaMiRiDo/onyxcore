import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/cluster_key.dart';

/// Contract for the type-specific strategy that handles both Stage 1 metadata
/// extraction and Stage 2 fingerprinting for one media category.
///
/// The strategy pattern allows each media type (image, video, audio, other) to
/// have a completely independent implementation while sharing a common
/// interface with the orchestrator.
///
/// Phase 1 defines the contract only.  Concrete implementations belong to
/// Phase 2 and later.
abstract class MediaTypeStrategy {
  /// Returns [true] when this strategy can process [candidate].
  bool supports(ComparisonCandidate candidate);

  /// Extracts Stage 1 metadata from [candidate].
  ///
  /// See [Stage1Extractor.extract] for memory-safety requirements.
  Future<Stage1Metadata> extractMetadata(ComparisonCandidate candidate);

  /// Derives the cluster key for [candidate] given its Stage 1 [metadata].
  ClusterKey buildClusterKey(
    ComparisonCandidate candidate,
    Stage1Metadata metadata,
  );
}
