import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/cluster_key.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/media_type_strategy.dart';

class OtherMediaStrategy implements MediaTypeStrategy {
  @override
  bool supports(ComparisonCandidate candidate) {
    return candidate.file.type != FileItemType.image &&
        candidate.file.type != FileItemType.video &&
        candidate.file.type != FileItemType.audio &&
        candidate.file.type != FileItemType.folder;
  }

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
}
