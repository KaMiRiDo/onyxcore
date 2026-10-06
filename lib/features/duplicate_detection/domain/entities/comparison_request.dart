import 'package:equatable/equatable.dart';

import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_category.dart';

/// Immutable configuration that fully describes a cross-folder comparison
/// request submitted by the user.
///
/// This entity is the single source of truth for the comparison parameters
/// and is passed through every stage of the processing pipeline without
/// modification.
class ComparisonRequest extends Equatable {
  const ComparisonRequest({
    required this.sourceFolder,
    required this.destinationFolder,
    required this.category,
    this.recursive = true,
  });

  /// Absolute path to the source folder.
  final String sourceFolder;

  /// Absolute path to the destination folder.
  final String destinationFolder;

  /// Which file-type category to consider during comparison.
  final ComparisonCategory category;

  /// Whether to recurse into sub-folders when discovering files.
  final bool recursive;

  ComparisonRequest copyWith({
    String? sourceFolder,
    String? destinationFolder,
    ComparisonCategory? category,
    bool? recursive,
  }) {
    return ComparisonRequest(
      sourceFolder: sourceFolder ?? this.sourceFolder,
      destinationFolder: destinationFolder ?? this.destinationFolder,
      category: category ?? this.category,
      recursive: recursive ?? this.recursive,
    );
  }

  @override
  List<Object?> get props => [
    sourceFolder,
    destinationFolder,
    category,
    recursive,
  ];
}
