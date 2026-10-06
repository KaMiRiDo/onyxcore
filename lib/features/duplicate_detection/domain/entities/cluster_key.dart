import 'package:equatable/equatable.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';

/// An opaque bucket key derived from a file's Stage 1 metadata.
///
/// Files with the same [ClusterKey] are placed in the same cluster and
/// considered potential duplicates.  Only candidates within the same cluster
/// are passed to Stage 2 fingerprinting, making the overall pipeline O(cluster)
/// rather than O(A × B).
///
/// Equality is value-based: two [ClusterKey]s are equal when every field is
/// equal — making [Set] and [Map] usage safe.
class ClusterKey extends Equatable {
  const ClusterKey({
    required this.type,
    required this.orientation,
    this.aspectRatioGroup,
    this.durationBucket,
  });

  /// Constructs a [ClusterKey] from a [Stage1Metadata] record.
  factory ClusterKey.fromMetadata(FileItemType type, Stage1Metadata meta) {
    return ClusterKey(
      type: type,
      orientation: meta.orientation,
      aspectRatioGroup: meta.aspectRatioGroup,
      durationBucket: _bucketDuration(meta.durationSeconds),
    );
  }

  /// File type — forms the top-level cluster separation.
  final FileItemType type;

  /// Orientation bucket derived from the Stage 1 metadata.
  final MediaOrientation orientation;

  /// Coarse aspect-ratio descriptor (e.g., '16:9').  [null] for audio or when
  /// not applicable.
  final String? aspectRatioGroup;

  /// Coarse duration bucket in seconds, rounded to the nearest 5 s.  [null]
  /// for image files and when duration is not applicable.
  final int? durationBucket;

  /// Rounds [durationSeconds] to the nearest 5-second bucket so that minor
  /// encoding-length differences do not create spurious separate clusters.
  static int? _bucketDuration(double? durationSeconds) {
    if (durationSeconds == null) return null;
    const bucketSize = 5;
    return ((durationSeconds / bucketSize).round()) * bucketSize;
  }

  @override
  List<Object?> get props => [
    type,
    orientation,
    aspectRatioGroup,
    durationBucket,
  ];
}
