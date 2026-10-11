import 'package:onyxcore/features/duplicate_detection/domain/entities/cluster_key.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';

class ClusterCompatibility {
  static bool isCompatible(ClusterKey a, ClusterKey b) {
    if (a.type != b.type) return false;

    // Orientation
    if (a.orientation != b.orientation) {
      // Allow square vs landscape/portrait if aspect ratio is close to 1
      final aIsSquare = a.orientation == MediaOrientation.square;
      final bIsSquare = b.orientation == MediaOrientation.square;

      if (!aIsSquare && !bIsSquare) return false; // landscape vs portrait

      final otherKey = aIsSquare ? b : a;

      final otherAspect = _parseAspectIndex(otherKey.aspectRatioGroup);
      if (otherAspect == null || otherAspect > 1) {
        return false;
      }
    }

    // Aspect Ratio
    final aAspect = _parseAspectIndex(a.aspectRatioGroup);
    final bAspect = _parseAspectIndex(b.aspectRatioGroup);

    if (aAspect == null && bAspect == null) {
      // both null -> ok (audio)
    } else if (aAspect == null || bAspect == null) {
      return false; // mixed null -> incompatible
    } else if ((aAspect - bAspect).abs() > 1) {
      return false;
    }

    // Duration
    if (a.durationBucket == null && b.durationBucket == null) {
      // both null -> ok (image)
    } else if (a.durationBucket == null || b.durationBucket == null) {
      return false; // mixed null
    } else if ((a.durationBucket! - b.durationBucket!).abs() > 5) {
      return false;
    }

    return true;
  }

  static int? _parseAspectIndex(String? group) {
    if (group == null || !group.startsWith('ar')) return null;
    return int.tryParse(group.substring(2));
  }
}
