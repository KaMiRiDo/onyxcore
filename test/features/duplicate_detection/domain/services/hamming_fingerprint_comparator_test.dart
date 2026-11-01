import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/candidate_fingerprint.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/hamming_fingerprint_comparator.dart';

void main() {
  group('HammingFingerprintComparator', () {
    const comparator = HammingFingerprintComparator();

    CandidateFingerprint makeFp(String path, List<int> bytes) =>
        CandidateFingerprint(candidatePath: path, bytes: bytes);

    test('returns 1.0 for identical fingerprints (0 bit differences)', () {
      final fpA = makeFp('/a', List.filled(32, 0xAB));
      final fpB = makeFp('/b', List.filled(32, 0xAB));

      expect(comparator.compare(fpA, fpB), 1.0);
    });

    test(
      'returns 0.0 for completely inverted fingerprints (256 bit differences)',
      () {
        final fpA = makeFp('/a', List.filled(32, 0x00));
        final fpB = makeFp('/b', List.filled(32, 0xFF));

        expect(comparator.compare(fpA, fpB), 0.0);
      },
    );

    test('calculates exact similarity for 1 bit difference', () {
      final bytesA = List.filled(32, 0x00);
      final bytesB = List.filled(32, 0x00);
      bytesB[0] = 0x01; // 1 bit different

      final fpA = makeFp('/a', bytesA);
      final fpB = makeFp('/b', bytesB);

      // 1.0 - (1 / 256) = 0.99609375
      expect(comparator.compare(fpA, fpB), closeTo(0.99609375, 1e-6));
    });

    test('calculates exact similarity for 16 bit differences', () {
      // 2 bytes with all 8 bits set = 16 bits
      final bytesA = List.filled(32, 0x00);
      final bytesB = List.filled(32, 0x00);
      bytesB[0] = 0xFF;
      bytesB[1] = 0xFF;

      final fpA = makeFp('/a', bytesA);
      final fpB = makeFp('/b', bytesB);

      // 1.0 - (16 / 256) = 0.9375
      expect(comparator.compare(fpA, fpB), closeTo(0.9375, 1e-6));
    });

    test('comparison is strictly symmetric', () {
      final bytesA = List.generate(32, (i) => i * 7 % 256);
      final bytesB = List.generate(32, (i) => (i * 13 + 5) % 256);

      final fpA = makeFp('/a', bytesA);
      final fpB = makeFp('/b', bytesB);

      expect(
        comparator.compare(fpA, fpB),
        equals(comparator.compare(fpB, fpA)),
      );
    });

    test('distance helper returns exact Hamming distance', () {
      final bytesA = List.filled(32, 0x00);
      final bytesB = List.filled(32, 0x00);
      bytesB[0] = 0x03; // 2 bits
      bytesB[5] = 0x07; // 3 bits -> total 5 bits

      final fpA = makeFp('/a', bytesA);
      final fpB = makeFp('/b', bytesB);

      expect(comparator.hammingDistance(fpA, fpB), 5);
    });
  });
}
