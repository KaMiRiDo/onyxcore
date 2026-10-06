import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/stage1_metadata.dart';

/// Contract for Stage 1 metadata extraction.
///
/// Each supported media type (images, videos, audio, other) provides its own
/// implementation of this interface so that type-specific logic stays isolated.
///
/// Phase 1 defines the contract only.  No extraction logic is implemented here.
abstract class Stage1Extractor {
  /// Returns [true] if this extractor can handle the given [candidate].
  bool supports(ComparisonCandidate candidate);

  /// Extracts lightweight Stage 1 metadata from [candidate].
  ///
  /// Must NOT load the full media file into memory.  Implementations should
  /// read only the header/metadata section of the file.
  ///
  /// Throws [Stage1ExtractionException] if metadata cannot be read.
  Future<Stage1Metadata> extract(ComparisonCandidate candidate);
}

/// Thrown when a [Stage1Extractor] cannot produce metadata for a candidate.
class Stage1ExtractionException implements Exception {
  const Stage1ExtractionException(this.candidatePath, this.message);

  final String candidatePath;
  final String message;

  @override
  String toString() => 'Stage1ExtractionException($candidatePath): $message';
}
