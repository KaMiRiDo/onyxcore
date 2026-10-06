import 'package:onyxcore/features/duplicate_detection/domain/entities/candidate_fingerprint.dart';

/// Contract for Stage 2 in-memory fingerprint comparison.
///
/// Compares two [CandidateFingerprint]s and returns a similarity score.
/// All comparison happens in memory from the compact 256-bit fingerprint
/// bytes — no additional I/O or media decoding is required.
///
/// Phase 1 defines the contract only.  No comparison algorithm is implemented.
abstract interface class FingerprintComparator {
  /// Returns a similarity score in [0.0, 1.0] between [a] and [b].
  ///
  /// - 1.0 → identical fingerprints (exact match).
  /// - 0.0 → completely dissimilar fingerprints.
  ///
  /// The threshold at which two files are considered "duplicates" is a
  /// policy decision belonging to the orchestrator, not the comparator.
  double compare(CandidateFingerprint a, CandidateFingerprint b);
}
