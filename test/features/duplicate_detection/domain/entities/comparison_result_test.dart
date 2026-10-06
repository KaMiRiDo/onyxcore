import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';

void main() {
  final tCompletedAt = DateTime(2024, 6, 15, 12);

  // ── MatchedPair ─────────────────────────────────────────────────────────────

  group('MatchedPair', () {
    const tPair = MatchedPair(
      sourcePath: '/source/a.jpg',
      destinationPath: '/dest/a.jpg',
      similarityScore: 0.98,
    );

    test('supports value equality via Equatable', () {
      const tPair2 = MatchedPair(
        sourcePath: '/source/a.jpg',
        destinationPath: '/dest/a.jpg',
        similarityScore: 0.98,
      );
      expect(tPair, equals(tPair2));
    });

    test('inequal when destinationPath differs', () {
      const other = MatchedPair(
        sourcePath: '/source/a.jpg',
        destinationPath: '/other/a.jpg',
        similarityScore: 0.98,
      );
      expect(tPair, isNot(equals(other)));
    });

    test('inequal when similarityScore differs', () {
      const other = MatchedPair(
        sourcePath: '/source/a.jpg',
        destinationPath: '/dest/a.jpg',
        similarityScore: 0.5,
      );
      expect(tPair, isNot(equals(other)));
    });
  });

  // ── DuplicateMatch ──────────────────────────────────────────────────────────

  group('DuplicateMatch', () {
    const tPair = MatchedPair(
      sourcePath: '/source/a.jpg',
      destinationPath: '/dest/a.jpg',
      similarityScore: 0.98,
    );

    test('one-to-one: matchCount is 1 for a single destination match', () {
      const match = DuplicateMatch(
        sourcePath: '/source/a.jpg',
        destinationMatches: [tPair],
      );
      expect(match.matchCount, 1);
      expect(match.hasMatches, isTrue);
    });

    test('one-to-many: matchCount reflects multiple destination matches', () {
      const pair2 = MatchedPair(
        sourcePath: '/source/a.jpg',
        destinationPath: '/dest/subfolder/a.jpg',
        similarityScore: 0.95,
      );
      const match = DuplicateMatch(
        sourcePath: '/source/a.jpg',
        destinationMatches: [tPair, pair2],
      );
      expect(match.matchCount, 2);
      expect(match.hasMatches, isTrue);
    });

    test('hasMatches is false when destinationMatches is empty', () {
      const match = DuplicateMatch(
        sourcePath: '/source/a.jpg',
        destinationMatches: [],
      );
      expect(match.hasMatches, isFalse);
      expect(match.matchCount, 0);
    });

    test('supports value equality via Equatable', () {
      const match1 = DuplicateMatch(
        sourcePath: '/source/a.jpg',
        destinationMatches: [tPair],
      );
      const match2 = DuplicateMatch(
        sourcePath: '/source/a.jpg',
        destinationMatches: [tPair],
      );
      expect(match1, equals(match2));
    });
  });

  // ── ComparisonResult ────────────────────────────────────────────────────────

  group('ComparisonResult', () {
    final tResult = ComparisonResult(
      requestId: 'req-001',
      matches: const [
        DuplicateMatch(
          sourcePath: '/source/a.jpg',
          destinationMatches: [
            MatchedPair(
              sourcePath: '/source/a.jpg',
              destinationPath: '/dest/a.jpg',
              similarityScore: 0.99,
            ),
          ],
        ),
      ],
      totalSourceCandidates: 100,
      totalDestinationCandidates: 200,
      completedAt: DateTime(2024, 6, 15, 12),
    );

    test('matchedSourceCount equals the number of DuplicateMatches', () {
      expect(tResult.matchedSourceCount, 1);
    });

    test('isEmpty is false when matches are present', () {
      expect(tResult.isEmpty, isFalse);
    });

    test('isEmpty is true when no matches exist', () {
      final emptyResult = ComparisonResult(
        requestId: 'req-002',
        matches: const [],
        totalSourceCandidates: 10,
        totalDestinationCandidates: 20,
        completedAt: tCompletedAt,
      );
      expect(emptyResult.isEmpty, isTrue);
    });

    test('multiple source files → destination matches', () {
      final multiResult = ComparisonResult(
        requestId: 'req-003',
        matches: const [
          DuplicateMatch(
            sourcePath: '/source/a.jpg',
            destinationMatches: [
              MatchedPair(
                sourcePath: '/source/a.jpg',
                destinationPath: '/dest/a.jpg',
                similarityScore: 0.99,
              ),
            ],
          ),
          DuplicateMatch(
            sourcePath: '/source/b.jpg',
            destinationMatches: [
              MatchedPair(
                sourcePath: '/source/b.jpg',
                destinationPath: '/dest/b.jpg',
                similarityScore: 0.97,
              ),
              MatchedPair(
                sourcePath: '/source/b.jpg',
                destinationPath: '/dest/sub/b.jpg',
                similarityScore: 0.95,
              ),
            ],
          ),
        ],
        totalSourceCandidates: 2,
        totalDestinationCandidates: 3,
        completedAt: tCompletedAt,
      );

      expect(multiResult.matchedSourceCount, 2);
      // b.jpg matched 2 destinations
      expect(multiResult.matches[1].matchCount, 2);
    });

    test('supports value equality via Equatable', () {
      final tResult2 = ComparisonResult(
        requestId: 'req-001',
        matches: const [
          DuplicateMatch(
            sourcePath: '/source/a.jpg',
            destinationMatches: [
              MatchedPair(
                sourcePath: '/source/a.jpg',
                destinationPath: '/dest/a.jpg',
                similarityScore: 0.99,
              ),
            ],
          ),
        ],
        totalSourceCandidates: 100,
        totalDestinationCandidates: 200,
        completedAt: DateTime(2024, 6, 15, 12),
      );
      expect(tResult, equals(tResult2));
    });
  });
}
