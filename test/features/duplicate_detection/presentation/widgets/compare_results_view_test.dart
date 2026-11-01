import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/compare_results_view.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/duplicate_group_card.dart';

void main() {
  group('CompareResultsView', () {
    late Directory tempDir;
    late File src;
    late File dest;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('results_view_test_');
      src = File('${tempDir.path}/photo.jpg')
        ..writeAsBytesSync(List.filled(100, 1));
      dest = File('${tempDir.path}/photo_dup.jpg')
        ..writeAsBytesSync(List.filled(100, 1));
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('renders empty state when result has no matches', (
      tester,
    ) async {
      var newCompClicked = false;
      final emptyResult = ComparisonResult(
        requestId: '/source',
        matches: const [],
        totalSourceCandidates: 12,
        totalDestinationCandidates: 25,
        completedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CompareResultsView(
              result: emptyResult,
              onNewComparison: () => newCompClicked = true,
            ),
          ),
        ),
      );

      expect(find.text('No Duplicates Found'), findsOneWidget);
      expect(
        find.textContaining('Analyzed 12 source and 25 destination candidates'),
        findsOneWidget,
      );
      final newCompBtn = find.text('New Comparison');
      expect(newCompBtn, findsOneWidget);
      await tester.tap(newCompBtn);
      await tester.pump();

      expect(newCompClicked, isTrue);
    });

    testWidgets('renders summary header and group cards when matches exist', (
      tester,
    ) async {
      final result = ComparisonResult(
        requestId: '/source',
        matches: [
          DuplicateMatch(
            sourcePath: src.path,
            destinationMatches: [
              MatchedPair(
                sourcePath: src.path,
                destinationPath: dest.path,
                similarityScore: 1,
              ),
            ],
          ),
        ],
        totalSourceCandidates: 5,
        totalDestinationCandidates: 8,
        completedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CompareResultsView(result: result)),
        ),
      );

      expect(find.textContaining('1 Duplicate Group'), findsOneWidget);
      expect(find.textContaining('5 source / 8 destination'), findsOneWidget);
      expect(find.byType(DuplicateGroupCard), findsOneWidget);
    });

    testWidgets('Expand All and Collapse All toggle group cards', (
      tester,
    ) async {
      final result = ComparisonResult(
        requestId: '/source',
        matches: [
          DuplicateMatch(
            sourcePath: src.path,
            destinationMatches: [
              MatchedPair(
                sourcePath: src.path,
                destinationPath: dest.path,
                similarityScore: 1,
              ),
            ],
          ),
        ],
        totalSourceCandidates: 5,
        totalDestinationCandidates: 8,
        completedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CompareResultsView(result: result)),
        ),
      );

      // Initially expanded
      expect(find.text('Collapse All'), findsOneWidget);
      await tester.tap(find.text('Collapse All'));
      await tester.pumpAndSettle();

      // Now collapsed
      expect(find.text('Expand All'), findsOneWidget);
    });
  });
}
