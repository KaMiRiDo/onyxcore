import 'package:equatable/equatable.dart';

/// A single source → destination match pair.
///
/// Immutable: the matched pair is determined by Stage 2 fingerprint comparison
/// and is never mutated after creation.
class MatchedPair extends Equatable {
  const MatchedPair({
    required this.sourcePath,
    required this.destinationPath,
    required this.similarityScore,
  });

  /// Absolute path of the source candidate file.
  final String sourcePath;

  /// Absolute path of the destination candidate file that was matched.
  final String destinationPath;

  /// Similarity score in the range [0.0, 1.0] where 1.0 is an exact match.
  ///
  /// The precise meaning of the score is determined by the Stage 2
  /// fingerprinting/comparison implementation.
  final double similarityScore;

  @override
  List<Object?> get props => [sourcePath, destinationPath, similarityScore];
}

/// Duplicate matches found for a single source file.
///
/// Supports the one-to-many relationship: one source file can match multiple
/// destination files (e.g., the same image present in several destination
/// sub-folders).
class DuplicateMatch extends Equatable {
  const DuplicateMatch({
    required this.sourcePath,
    required this.destinationMatches,
  });

  /// Absolute path of the source candidate file.
  final String sourcePath;

  /// All destination files that matched [sourcePath], sorted by
  /// [MatchedPair.similarityScore] descending (best match first).
  final List<MatchedPair> destinationMatches;

  /// Convenience getter: the number of destination files that matched.
  int get matchCount => destinationMatches.length;

  /// [true] when this source file has at least one destination match.
  bool get hasMatches => destinationMatches.isNotEmpty;

  @override
  List<Object?> get props => [sourcePath, destinationMatches];
}

/// The aggregated result of a completed comparison run.
///
/// Contains all [DuplicateMatch] entries found across the source folder.
/// Supports:
/// - one source file → one destination match;
/// - one source file → multiple destination matches;
/// - multiple source files → destination matches.
class ComparisonResult extends Equatable {
  const ComparisonResult({
    required this.requestId,
    required this.matches,
    required this.totalSourceCandidates,
    required this.totalDestinationCandidates,
    required this.completedAt,
  });

  /// Opaque identifier linking this result to its originating
  /// [ComparisonRequest].
  final String requestId;

  /// All source files that have at least one destination match.
  final List<DuplicateMatch> matches;

  /// Total number of source candidates that were evaluated.
  final int totalSourceCandidates;

  /// Total number of destination candidates that were evaluated.
  final int totalDestinationCandidates;

  /// Timestamp when the comparison run completed.
  final DateTime completedAt;

  /// Convenience getter: total number of source files with at least one match.
  int get matchedSourceCount => matches.length;

  /// Convenience getter: [true] when no matches were found.
  bool get isEmpty => matches.isEmpty;

  @override
  List<Object?> get props => [
    requestId,
    matches,
    totalSourceCandidates,
    totalDestinationCandidates,
    completedAt,
  ];
}
