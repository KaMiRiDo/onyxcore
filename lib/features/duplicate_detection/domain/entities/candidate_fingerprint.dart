import 'package:equatable/equatable.dart';

/// An opaque 256-bit fingerprint of a [ComparisonCandidate].
///
/// Fingerprints are generated once per candidate by the Stage 2 layer and then
/// compared in-memory as compact byte arrays.  The underlying media is
/// released immediately after fingerprint generation so decoded frames are
/// never held in memory longer than necessary.
///
/// The [bytes] field carries exactly 32 bytes (256 bits).  Implementations
/// that produce a fingerprint of a different size must pad or truncate to
/// 32 bytes.
class CandidateFingerprint extends Equatable {
  const CandidateFingerprint({required this.candidatePath, required this.bytes})
    : assert(
        bytes.length == 32,
        'Fingerprint must be exactly 32 bytes (256 bits)',
      );

  /// Path of the candidate that produced this fingerprint.
  final String candidatePath;

  /// Raw 256-bit fingerprint data (exactly 32 bytes).
  final List<int> bytes;

  @override
  List<Object?> get props => [candidatePath, bytes];
}
