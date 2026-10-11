import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/data/datasources/media_metadata_datasource.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/cluster_key.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/media_type_strategy.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage1_extractor.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/stage1_normalizer.dart';

class ImageMediaStrategy implements MediaTypeStrategy {
  @override
  bool supports(ComparisonCandidate candidate) {
    return candidate.file.type == FileItemType.image;
  }

  @override
  Future<Stage1Metadata> extractMetadata(ComparisonCandidate candidate) async {
    try {
      final ratio = MediaMetadataDatasource.parseImageDimensions(
        candidate.file.path,
      );
      if (ratio != null) {
        return Stage1Metadata(
          candidatePath: candidate.file.path,
          orientation: Stage1Normalizer.normalizeOrientationRatio(ratio),
          aspectRatioGroup: Stage1Normalizer.normalizeAspectRatioFromRatio(
            ratio,
          ),
        );
      }
      return Stage1Metadata(
        candidatePath: candidate.file.path,
        orientation: MediaOrientation.unknown,
      );
    } catch (e) {
      throw Stage1ExtractionException(candidate.file.path, e.toString());
    }
  }

  @override
  ClusterKey buildClusterKey(
    ComparisonCandidate candidate,
    Stage1Metadata metadata,
  ) {
    return ClusterKey.fromMetadata(candidate.file.type, metadata);
  }
}
