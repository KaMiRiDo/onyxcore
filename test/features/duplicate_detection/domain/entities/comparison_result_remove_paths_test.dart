import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';

void main() {
  group('ComparisonResult.removePaths', () {
    final now = DateTime.now();

    final testMatch1 = DuplicateMatch(
      sourcePath: '/src/a.jpg',
      destinationMatches: const [
        MatchedPair(
          sourcePath: '/src/a.jpg',
          destinationPath: '/dst/a1.jpg',
          similarityScore: 1,
        ),
        MatchedPair(
          sourcePath: '/src/a.jpg',
          destinationPath: '/dst/a2.jpg',
          similarityScore: 0.95,
        ),
      ],
    );

    final testMatch2 = DuplicateMatch(
      sourcePath: '/src/b.jpg',
      destinationMatches: const [
        MatchedPair(
          sourcePath: '/src/b.jpg',
          destinationPath: '/dst/b.jpg',
          similarityScore: 1,
        ),
      ],
    );

    final initialResult = ComparisonResult(
      requestId: 'test_req',
      matches: [testMatch1, testMatch2],
      totalSourceCandidates: 10,
      totalDestinationCandidates: 20,
      completedAt: now,
    );

    test('removing non-matching path leaves matches unchanged', () {
      final updated = initialResult.removePaths({'/unrelated/path.jpg'});
      expect(updated.matches.length, 2);
      expect(updated.matches[0].destinationMatches.length, 2);
    });

    test('removing single destination path keeps source and other destinations', () {
      final updated = initialResult.removePaths({'/dst/a1.jpg'});
      expect(updated.matches.length, 2);
      expect(updated.matches[0].sourcePath, '/src/a.jpg');
      expect(updated.matches[0].destinationMatches.length, 1);
      expect(updated.matches[0].destinationMatches.first.destinationPath, '/dst/a2.jpg');
    });

    test('removing the only destination path removes that entire duplicate match', () {
      final updated = initialResult.removePaths({'/dst/b.jpg'});
      expect(updated.matches.length, 1);
      expect(updated.matches.first.sourcePath, '/src/a.jpg');
    });

    test('removing source path removes that entire duplicate match', () {
      final updated = initialResult.removePaths({'/src/a.jpg'});
      expect(updated.matches.length, 1);
      expect(updated.matches.first.sourcePath, '/src/b.jpg');
    });

    test('removing all paths results in empty comparison result', () {
      final updated = initialResult.removePaths({
        '/src/a.jpg',
        '/dst/b.jpg',
      });
      expect(updated.matches, isEmpty);
      expect(updated.isEmpty, isTrue);
    });
  });
}
