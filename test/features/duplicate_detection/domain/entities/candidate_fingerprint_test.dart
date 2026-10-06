import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/candidate_fingerprint.dart';

void main() {
  group('CandidateFingerprint', () {
    final tBytes = List<int>.filled(32, 0xAB);

    test('can be constructed with exactly 32 bytes', () {
      final fp = CandidateFingerprint(
        candidatePath: '/source/photo.jpg',
        bytes: tBytes,
      );
      expect(fp.bytes.length, 32);
      expect(fp.candidatePath, '/source/photo.jpg');
    });

    test('asserts when bytes length is not 32', () {
      expect(
        () => CandidateFingerprint(
          candidatePath: '/source/photo.jpg',
          bytes: List.filled(16, 0), // wrong size
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts when bytes is empty', () {
      expect(
        () =>
            CandidateFingerprint(candidatePath: '/source/photo.jpg', bytes: []),
        throwsA(isA<AssertionError>()),
      );
    });

    test('supports value equality via Equatable', () {
      final fp1 = CandidateFingerprint(
        candidatePath: '/source/photo.jpg',
        bytes: List<int>.filled(32, 0xAB),
      );
      final fp2 = CandidateFingerprint(
        candidatePath: '/source/photo.jpg',
        bytes: List<int>.filled(32, 0xAB),
      );
      expect(fp1, equals(fp2));
    });

    test('inequal when bytes differ', () {
      final fp1 = CandidateFingerprint(
        candidatePath: '/source/photo.jpg',
        bytes: List<int>.filled(32, 0xAA),
      );
      final fp2 = CandidateFingerprint(
        candidatePath: '/source/photo.jpg',
        bytes: List<int>.filled(32, 0xBB),
      );
      expect(fp1, isNot(equals(fp2)));
    });

    test('inequal when candidatePath differs', () {
      final fp1 = CandidateFingerprint(candidatePath: '/a.jpg', bytes: tBytes);
      final fp2 = CandidateFingerprint(candidatePath: '/b.jpg', bytes: tBytes);
      expect(fp1, isNot(equals(fp2)));
    });
  });
}
