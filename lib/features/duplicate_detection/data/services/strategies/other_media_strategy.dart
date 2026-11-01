import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/candidate_fingerprint.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/cluster_key.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/fingerprint_generator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/media_type_strategy.dart';

class OtherMediaStrategy implements MediaTypeStrategy, FingerprintGenerator {
  @override
  bool supports(ComparisonCandidate candidate) {
    return candidate.file.type != FileItemType.image &&
        candidate.file.type != FileItemType.video &&
        candidate.file.type != FileItemType.audio &&
        candidate.file.type != FileItemType.folder;
  }

  /// Other files do not have a supported content fingerprinting algorithm.
  bool supportsFingerprinting(ComparisonCandidate candidate) => false;

  @override
  Future<Stage1Metadata> extractMetadata(ComparisonCandidate candidate) async {
    return Stage1Metadata(
      candidatePath: candidate.file.path,
      orientation: MediaOrientation.notApplicable,
    );
  }

  @override
  ClusterKey buildClusterKey(
    ComparisonCandidate candidate,
    Stage1Metadata metadata,
  ) {
    return ClusterKey.fromMetadata(candidate.file.type, metadata);
  }

  @override
  Future<CandidateFingerprint> generate(ComparisonCandidate candidate) {
    throw FingerprintGenerationException(
      candidate.file.path,
      'Duplicate fingerprinting is unsupported for file type ${candidate.file.type.name}',
    );
  }
}
