import 'package:equatable/equatable.dart';

/// Orientation bucket used in Stage 1 cluster-key construction.
///
/// Capturing orientation at Stage 1 prevents mismatched pairs from
/// ever being sent to the more expensive Stage 2 fingerprinting step.
enum MediaOrientation {
  /// Wider than tall (landscape videos / images).
  landscape,

  /// Taller than wide.
  portrait,

  /// Equal width and height (square images).
  square,

  /// Orientation is not applicable for this file type (e.g. audio).
  notApplicable,

  /// Orientation could not be determined.
  unknown,
}

/// Lightweight Stage 1 metadata record extracted from a [ComparisonCandidate].
///
/// All fields that cannot be determined for a given file type must be set to
/// [null].  [orientation] and [aspectRatioGroup] guide cluster-key creation
/// without storing exact pixel dimensions.
///
/// This entity is intentionally flat and media-library-free so it can be
/// constructed in a background isolate.
class Stage1Metadata extends Equatable {
  const Stage1Metadata({
    required this.candidatePath,
    required this.orientation,
    this.aspectRatioGroup,
    this.durationSeconds,
    this.extraAttributes = const {},
  });

  /// Path of the candidate this metadata belongs to.
  final String candidatePath;

  /// Detected orientation bucket.
  final MediaOrientation orientation;

  /// A coarse aspect-ratio descriptor (e.g. '16:9', '4:3', '1:1') used only
  /// for bucketing — not for exact pixel matching.  [null] when not applicable.
  final String? aspectRatioGroup;

  /// Duration in seconds for time-based media.  [null] for images or when
  /// the duration is not available.
  final double? durationSeconds;

  /// Type-specific attributes that a concrete Stage 1 extractor may populate
  /// (e.g., codec name, sample rate).  Kept as a plain [String] → [String] map
  /// so Stage 1 implementations remain isolate-safe.
  final Map<String, String> extraAttributes;

  @override
  List<Object?> get props => [
    candidatePath,
    orientation,
    aspectRatioGroup,
    durationSeconds,
    extraAttributes,
  ];
}
