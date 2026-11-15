import 'package:equatable/equatable.dart';

/// The nature of a duplicate match found by Stage 2.
enum MatchType {
  /// Exact match: 100% identical 256-bit fingerprint.
  exact,

  /// Perceptual match: fingerprints meet or exceed the similarity threshold.
  perceptual,
}

/// Record of an individual candidate file failure during comparison.
class ComparisonFailure extends Equatable {
  const ComparisonFailure({required this.candidatePath, required this.error});

  /// Path to the candidate that encountered an error.
  final String candidatePath;

  /// Error description.
  final String error;

  @override
  String toString() => 'ComparisonFailure($candidatePath): $error';

  @override
  List<Object?> get props => [candidatePath, error];
}

/// A single source → destination match pair.
///
/// Immutable: the matched pair is determined by Stage 2 fingerprint comparison
/// and is never mutated after creation.
class MatchedPair extends Equatable {
  const MatchedPair({
    required this.sourcePath,
    required this.destinationPath,
    required this.similarityScore,
    this.matchType = MatchType.exact,
  });

  /// Absolute path of the source candidate file.
  final String sourcePath;

  /// Absolute path of the destination candidate file that was matched.
  final String destinationPath;

  /// Similarity score in the range [0.0, 1.0] where 1.0 is an exact match.
  final double similarityScore;

  /// Whether this match is exact or perceptual.
  final MatchType matchType;

  @override
  List<Object?> get props => [
    sourcePath,
    destinationPath,
    similarityScore,
    matchType,
  ];
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

  /// `true` when this source file has at least one destination match.
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
    this.failures = const [],
  });

  /// Opaque identifier linking this result to its originating
  /// comparison request.
  final String requestId;

  /// All source files that have at least one destination match.
  final List<DuplicateMatch> matches;

  /// Total number of source candidates that were evaluated.
  final int totalSourceCandidates;

  /// Total number of destination candidates that were evaluated.
  final int totalDestinationCandidates;

  /// Timestamp when the comparison run completed.
  final DateTime completedAt;

  /// Failures encountered during the comparison run.
  final List<ComparisonFailure> failures;

  /// Convenience getter: total number of source files with at least one match.
  int get matchedSourceCount => matches.length;

  /// Convenience getter: `true` when no matches were found.
  bool get isEmpty => matches.isEmpty;

  /// Returns a new [ComparisonResult] with the given [pathsToRemove] excluded.
  ///
  /// Any [DuplicateMatch] whose `sourcePath` is in [pathsToRemove] is dropped.
  /// Any destination match whose `destinationPath` is in [pathsToRemove] is dropped.
  /// If a [DuplicateMatch] is left with no destination matches, it is dropped.
  ComparisonResult removePaths(Set<String> pathsToRemove) {
    if (pathsToRemove.isEmpty || matches.isEmpty) {
      return this;
    }

    final updatedMatches = <DuplicateMatch>[];
    for (final match in matches) {
      if (pathsToRemove.contains(match.sourcePath)) {
        continue;
      }
      final remainingDests = match.destinationMatches
          .where((p) => !pathsToRemove.contains(p.destinationPath))
          .toList();
      if (remainingDests.isNotEmpty) {
        updatedMatches.add(
          DuplicateMatch(
            sourcePath: match.sourcePath,
            destinationMatches: remainingDests,
          ),
        );
      }
    }

    return ComparisonResult(
      requestId: requestId,
      matches: updatedMatches,
      totalSourceCandidates: totalSourceCandidates,
      totalDestinationCandidates: totalDestinationCandidates,
      completedAt: completedAt,
      failures: failures,
    );
  }

  @override
  List<Object?> get props => [
    requestId,
    matches,
    totalSourceCandidates,
    totalDestinationCandidates,
    completedAt,
    failures,
  ];
}
