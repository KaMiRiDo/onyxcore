import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/candidate_fingerprint.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/fingerprint_comparator.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/fingerprint_generator.dart';

// ── Fakes ────────────────────────────────────────────────────────────────────

class _FakeFingerprintGenerator extends Fake implements FingerprintGenerator {

  _FakeFingerprintGenerator({required bool supports, List<int>? bytes})
    : _supports = supports,
      _bytes = bytes;
  final bool _supports;
  final List<int>? _bytes;

  @override
  bool supports(ComparisonCandidate candidate) => _supports;

  @override
  Future<CandidateFingerprint> generate(ComparisonCandidate candidate) async {
    if (_bytes != null) {
      return CandidateFingerprint(
        candidatePath: candidate.file.path,
        bytes: _bytes,
      );
    }
    throw FingerprintGenerationException(
      candidate.file.path,
      'generation failed',
    );
  }
}

class _FakeFingerprintComparator extends Fake implements FingerprintComparator {
  _FakeFingerprintComparator(this._score);
  final double _score;

  @override
  double compare(CandidateFingerprint a, CandidateFingerprint b) => _score;
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  final tModified = DateTime(2024, 6, 15);
  final tBytes = List<int>.filled(32, 0xAB);

  final tCandidate = ComparisonCandidate(
    file: FileItem(
      path: '/source/photo.jpg',
      name: 'photo.jpg',
      type: FileItemType.image,
      sizeBytes: 2048,
      modified: tModified,
    ),
    isSource: true,
  );

  group('FingerprintGenerator contract', () {
    test('supports returns true for supported candidate', () {
      final gen = _FakeFingerprintGenerator(supports: true, bytes: tBytes);
      expect(gen.supports(tCandidate), isTrue);
    });

    test('supports returns false for unsupported candidate', () {
      final gen = _FakeFingerprintGenerator(supports: false);
      expect(gen.supports(tCandidate), isFalse);
    });

    test('generate returns a 256-bit fingerprint', () async {
      final gen = _FakeFingerprintGenerator(supports: true, bytes: tBytes);
      final fp = await gen.generate(tCandidate);
      expect(fp.bytes.length, 32);
      expect(fp.candidatePath, tCandidate.file.path);
    });

    test('generate throws FingerprintGenerationException on failure', () async {
      final gen = _FakeFingerprintGenerator(supports: true);
      expect(
        () => gen.generate(tCandidate),
        throwsA(isA<FingerprintGenerationException>()),
      );
    });

    test(
      'FingerprintGenerationException carries candidatePath and message',
      () {
        const ex = FingerprintGenerationException('/photo.jpg', 'read timeout');
        expect(ex.candidatePath, '/photo.jpg');
        expect(ex.message, 'read timeout');
        expect(ex.toString(), contains('/photo.jpg'));
        expect(ex.toString(), contains('read timeout'));
      },
    );
  });

  group('FingerprintComparator contract', () {
    final fpA = CandidateFingerprint(
      candidatePath: '/source/a.jpg',
      bytes: List<int>.filled(32, 0xAA),
    );
    final fpB = CandidateFingerprint(
      candidatePath: '/dest/b.jpg',
      bytes: List<int>.filled(32, 0xBB),
    );

    test('compare returns a score between 0.0 and 1.0', () {
      final comparator = _FakeFingerprintComparator(0.85);
      final score = comparator.compare(fpA, fpB);
      expect(score, inInclusiveRange(0.0, 1.0));
    });

    test('compare returns 1.0 for identical fingerprints', () {
      final comparator = _FakeFingerprintComparator(1);
      final score = comparator.compare(fpA, fpA);
      expect(score, 1.0);
    });

    test('compare returns 0.0 for completely different fingerprints', () {
      final comparator = _FakeFingerprintComparator(0);
      final score = comparator.compare(fpA, fpB);
      expect(score, 0.0);
    });
  });
}
