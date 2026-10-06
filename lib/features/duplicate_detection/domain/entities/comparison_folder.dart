import 'package:equatable/equatable.dart';

/// Immutable description of a folder participating in a comparison run.
///
/// Carries the resolved absolute path and the number of candidate files
/// discovered under that path.  It is intentionally lightweight: no file
/// listings are stored here to keep memory bounded.
class ComparisonFolder extends Equatable {
  const ComparisonFolder({
    required this.path,
    required this.candidateCount,
    this.recursive = true,
  });

  /// Absolute path to the folder on the local file system.
  final String path;

  /// Number of files that matched the active [ComparisonCategory] and were
  /// promoted to candidates.  Zero if discovery has not yet run.
  final int candidateCount;

  /// Whether sub-folders were (or will be) traversed during discovery.
  final bool recursive;

  ComparisonFolder copyWith({
    String? path,
    int? candidateCount,
    bool? recursive,
  }) {
    return ComparisonFolder(
      path: path ?? this.path,
      candidateCount: candidateCount ?? this.candidateCount,
      recursive: recursive ?? this.recursive,
    );
  }

  @override
  List<Object?> get props => [path, candidateCount, recursive];
}
