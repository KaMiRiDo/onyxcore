import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/candidate_fingerprint.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_candidate.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/fingerprint_cache.dart';
import 'package:onyxcore/features/duplicate_detection/domain/services/fingerprint_generator.dart';

class _CountingGenerator implements FingerprintGenerator {
  int callCount = 0;

  @override
  bool supports(ComparisonCandidate candidate) => true;

  @override
  Future<CandidateFingerprint> generate(ComparisonCandidate candidate) async {
    callCount++;
    return CandidateFingerprint(
      candidatePath: candidate.file.path,
      bytes: List.filled(32, callCount),
    );
  }
}

void main() {
  group('FingerprintCache', () {
    late FingerprintCache cache;
    late ComparisonCandidate candidateA;
    late ComparisonCandidate candidateB;

    setUp(() {
      cache = FingerprintCache();
      candidateA = ComparisonCandidate(
        file: FileItem(
          path: '/source/a.jpg',
          name: 'a.jpg',
          type: FileItemType.image,
          modified: DateTime(2024),
          sizeBytes: 100,
        ),
        isSource: true,
      );
      candidateB = ComparisonCandidate(
        file: FileItem(
          path: '/dest/b.jpg',
          name: 'b.jpg',
          type: FileItemType.image,
          modified: DateTime(2024),
          sizeBytes: 100,
        ),
        isSource: false,
      );
    });

    test('getOrGenerate calls generator once and caches the result', () async {
      final generator = _CountingGenerator();

      final fp1 = await cache.getOrGenerate(candidateA, generator);
      final fp2 = await cache.getOrGenerate(candidateA, generator);

      expect(generator.callCount, 1);
      expect(fp1, equals(fp2));
      expect(cache.size, 1);
    });

    test('caches different candidates independently', () async {
      final generator = _CountingGenerator();

      final fpA = await cache.getOrGenerate(candidateA, generator);
      final fpB = await cache.getOrGenerate(candidateB, generator);

      expect(generator.callCount, 2);
      expect(fpA.candidatePath, candidateA.file.path);
      expect(fpB.candidatePath, candidateB.file.path);
      expect(cache.size, 2);
    });

    test('clear wipes all cached fingerprints and frees references', () async {
      final generator = _CountingGenerator();
      await cache.getOrGenerate(candidateA, generator);
      expect(cache.size, 1);

      cache.clear();
      expect(cache.size, 0);
      expect(cache.get(candidateA.file.path), isNull);

      // Subsequent call re-generates since cache was cleared
      await cache.getOrGenerate(candidateA, generator);
      expect(generator.callCount, 2);
    });
  });
}
