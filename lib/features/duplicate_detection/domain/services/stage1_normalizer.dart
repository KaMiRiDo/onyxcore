import 'dart:math' as math;
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';

class Stage1Normalizer {
  static MediaOrientation normalizeOrientation(num width, num height) {
    if (width <= 0 || height <= 0 || width.isNaN || height.isNaN) {
      return MediaOrientation.unknown;
    }
    return normalizeOrientationRatio(width / height);
  }

  static MediaOrientation normalizeOrientationRatio(double ratio) {
    if (ratio <= 0 || ratio.isNaN) return MediaOrientation.unknown;
    if (ratio >= 0.98 && ratio <= 1.02) {
      return MediaOrientation.square;
    }
    if (ratio > 1.0) {
      return MediaOrientation.landscape;
    }
    return MediaOrientation.portrait;
  }

  static String? normalizeAspectRatio(num width, num height) {
    if (width <= 0 || height <= 0 || width.isNaN || height.isNaN) {
      return null;
    }
    return normalizeAspectRatioFromRatio(width / height);
  }

  static String? normalizeAspectRatioFromRatio(double ratio) {
    if (ratio <= 0 || ratio.isNaN) return null;
    final normalizedRatio = ratio < 1.0 ? 1.0 / ratio : ratio;
    final index = (math.log(normalizedRatio) / math.ln2 / 0.05).round();
    return 'ar$index';
  }
}
