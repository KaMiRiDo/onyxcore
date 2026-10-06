import 'package:equatable/equatable.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

/// A file that has passed the category filter and is being considered for
/// duplicate matching.
///
/// Wraps the [FileItem] with duplicate-detection specific flags like [isSource].
class ComparisonCandidate extends Equatable {
  const ComparisonCandidate({required this.file, required this.isSource});

  /// The underlying file item representing the candidate.
  final FileItem file;

  /// [true] when this candidate came from the source folder;
  /// [false] when it came from the destination folder.
  final bool isSource;

  ComparisonCandidate copyWith({FileItem? file, bool? isSource}) {
    return ComparisonCandidate(
      file: file ?? this.file,
      isSource: isSource ?? this.isSource,
    );
  }

  @override
  List<Object?> get props => [file, isSource];
}
