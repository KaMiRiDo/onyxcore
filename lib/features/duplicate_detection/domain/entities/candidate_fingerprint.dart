import 'package:equatable/equatable.dart';

/// An opaque 256-bit fingerprint of a comparison candidate.
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

  /// Formats the 32-byte fingerprint as a 64-character lowercase hex string.
  String toHexString() {
    final buffer = StringBuffer();
    for (final b in bytes) {
      buffer.write((b & 0xFF).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  @override
  List<Object?> get props => [candidatePath, bytes];
}
