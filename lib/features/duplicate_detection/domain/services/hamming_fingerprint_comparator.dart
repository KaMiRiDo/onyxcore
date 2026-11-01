import 'package:onyxcore/features/duplicate_detection/domain/entities/candidate_fingerprint.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/fingerprint_comparator.dart';

/// In-memory 256-bit fingerprint comparator based on Hamming distance.
class HammingFingerprintComparator implements FingerprintComparator {
  const HammingFingerprintComparator();

  static final List<int> _popcountTable = List<int>.generate(256, (i) {
    var count = 0;
    var v = i;
    while (v > 0) {
      v &= v - 1;
      count++;
    }
    return count;
  });

  /// Computes the bitwise Hamming distance between [a] and [b] (in [0, 256]).
  int hammingDistance(CandidateFingerprint a, CandidateFingerprint b) {
    var distance = 0;
    final aBytes = a.bytes;
    final bBytes = b.bytes;
    for (var i = 0; i < 32; i++) {
      final xor = aBytes[i] ^ bBytes[i];
      distance += _popcountTable[xor & 0xFF];
    }
    return distance;
  }

  /// Returns similarity in [0.0, 1.0] derived from Hamming distance:
  /// `1.0 - (distance / 256.0)`.
  @override
  double compare(CandidateFingerprint a, CandidateFingerprint b) {
    final distance = hammingDistance(a, b);
    return 1.0 - (distance / 256.0);
  }
}
