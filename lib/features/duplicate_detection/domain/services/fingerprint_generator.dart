import 'package:onyxcore/features/duplicate_detection/domain/entities/candidate_fingerprint.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';

/// Contract for Stage 2 fingerprint generation.
///
/// Implementations produce a 256-bit [CandidateFingerprint] for a given
/// [ComparisonCandidate].  The decoded media MUST be released immediately
/// after fingerprint generation so it is never held in memory.
///
/// Phase 1 defines the contract only.  No fingerprint algorithm is implemented.
abstract class FingerprintGenerator {
  /// Returns [true] if this generator can handle the given [candidate].
  bool supports(ComparisonCandidate candidate);

  /// Generates a 256-bit [CandidateFingerprint] for [candidate].
  ///
  /// Implementations MUST:
  /// - process only the bytes required to produce the fingerprint;
  /// - release any decoded media immediately after generation;
  /// - NOT store the fingerprint persistently.
  ///
  /// Throws [FingerprintGenerationException] on failure.
  Future<CandidateFingerprint> generate(ComparisonCandidate candidate);
}

/// Thrown when a [FingerprintGenerator] cannot produce a fingerprint.
class FingerprintGenerationException implements Exception {
  const FingerprintGenerationException(this.candidatePath, this.message);

  final String candidatePath;
  final String message;

  @override
  String toString() =>
      'FingerprintGenerationException($candidatePath): $message';
}
