import 'package:equatable/equatable.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';

/// Configuration for duplicate-detection similarity thresholds.
class ComparisonThresholdConfig extends Equatable {
  const ComparisonThresholdConfig({
    this.imageThreshold = 0.92,
    this.videoThreshold = 0.90,
    this.audioThreshold = 0.90,
    this.exactMatchOnly = false,
  }) : assert(
         imageThreshold >= 0 && imageThreshold <= 1,
         'imageThreshold must be between 0.0 and 1.0',
       ),
       assert(
         videoThreshold >= 0 && videoThreshold <= 1,
         'videoThreshold must be between 0.0 and 1.0',
       ),
       assert(
         audioThreshold >= 0 && audioThreshold <= 1,
         'audioThreshold must be between 0.0 and 1.0',
       );

  final double imageThreshold;
  final double videoThreshold;
  final double audioThreshold;
  final bool exactMatchOnly;

  double thresholdFor(FileItemType type) {
    if (exactMatchOnly) return 1;
    switch (type) {
      case FileItemType.image:
        return imageThreshold;
      case FileItemType.video:
        return videoThreshold;
      case FileItemType.audio:
        return audioThreshold;
      case FileItemType.archive:
      case FileItemType.document:
      case FileItemType.downloaderList:
      case FileItemType.folder:
      case FileItemType.other:
        return 1;
    }
  }

  ComparisonThresholdConfig copyWith({
    double? imageThreshold,
    double? videoThreshold,
    double? audioThreshold,
    bool? exactMatchOnly,
  }) {
    return ComparisonThresholdConfig(
      imageThreshold: imageThreshold ?? this.imageThreshold,
      videoThreshold: videoThreshold ?? this.videoThreshold,
      audioThreshold: audioThreshold ?? this.audioThreshold,
      exactMatchOnly: exactMatchOnly ?? this.exactMatchOnly,
    );
  }

  @override
  List<Object?> get props => [
    imageThreshold,
    videoThreshold,
    audioThreshold,
    exactMatchOnly,
  ];
}
