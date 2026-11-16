import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:onyxcore/features/directory_browser/domain/repositories/directory_repository.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/providers/compare_selection_notifier.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/compare_results_view.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/duplicate_group_card.dart';

class _FakeRepo implements DirectoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CompareResultsView Match Status Filter & Scoped Selection', () {
    late Directory tempDir;
    late File srcExact;
    late File dstExact;
    late File srcSimilar;
    late File dstSimilar;
    late ComparisonResult result;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('filter_test_');
      srcExact = File('${tempDir.path}/exact_src.png')
        ..writeAsBytesSync([1, 2, 3]);
      dstExact = File('${tempDir.path}/exact_dst.png')
        ..writeAsBytesSync([1, 2, 3]);
      srcSimilar = File('${tempDir.path}/similar_src.png')
        ..writeAsBytesSync([4, 5, 6]);
      dstSimilar = File('${tempDir.path}/similar_dst.png')
        ..writeAsBytesSync([4, 5, 7]);

      result = ComparisonResult(
        requestId: 'req_filter',
        matches: [
          DuplicateMatch(
            sourcePath: srcExact.path,
            destinationMatches: [
              MatchedPair(
                sourcePath: srcExact.path,
                destinationPath: dstExact.path,
                similarityScore: 1,
              ),
            ],
          ),
          DuplicateMatch(
            sourcePath: srcSimilar.path,
            destinationMatches: [
              MatchedPair(
                sourcePath: srcSimilar.path,
                destinationPath: dstSimilar.path,
                similarityScore: 0.95,
                matchType: MatchType.perceptual,
              ),
            ],
          ),
        ],
        totalSourceCandidates: 2,
        totalDestinationCandidates: 2,
        completedAt: DateTime.now(),
      );
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
          directoryRepositoryProvider.overrideWithValue(_FakeRepo()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CompareResultsView(
              result: result,
              sourceFolder: tempDir.path,
              destinationFolder: tempDir.path,
            ),
          ),
        ),
      );
    }

    testWidgets('displays match status filter dropdown defaulting to All Matches', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Find the filter dropdown button with "All Matches"
      expect(find.text('All Matches'), findsOneWidget);

      // Open the dropdown menu
      await tester.tap(find.text('All Matches'));
      await tester.pumpAndSettle();

      // Dropdown menu items must contain All Matches, Exact Match, and 95% Similarity
      expect(find.textContaining('Exact Match'), findsWidgets);
      expect(find.textContaining('95% Similarity'), findsWidgets);
    });

    testWidgets(
      'selecting a filter highlights dropdown and filters displayed comparison matches',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Initially both groups are displayed
        expect(find.byType(DuplicateGroupCard), findsNWidgets(2));

        // Open filter dropdown and select "95% Similarity"
        await tester.tap(find.text('All Matches'));
        await tester.pumpAndSettle();

        final optionFinder = find.textContaining('95% Similarity').last;
        await tester.tap(optionFinder);
        await tester.pumpAndSettle();

        // Only the 95% similarity match card should remain displayed
        expect(find.byType(DuplicateGroupCard), findsOneWidget);
        expect(find.text('similar_src.png'), findsWidgets);
        expect(find.text('exact_src.png'), findsNothing);
      },
    );

    testWidgets(
      'destination Select All under active filter selects ONLY visible filtered matches',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(CompareResultsView)),
        );

        // Filter to 95% Similarity
        await tester.tap(find.text('All Matches'));
        await tester.pumpAndSettle();

        final optionFinder = find.textContaining('95% Similarity').last;
        await tester.tap(optionFinder);
        await tester.pumpAndSettle();

        // Find DESTINATION FOLDER header
        final destHeaderFinder = find.widgetWithText(Row, 'DESTINATION FOLDER');
        expect(destHeaderFinder, findsOneWidget);

        final destCheckbox = find.descendant(
          of: destHeaderFinder,
          matching: find.byType(Checkbox),
        );
        expect(destCheckbox, findsOneWidget);

        // Tap Destination Select All
        await tester.tap(destCheckbox);
        await tester.pumpAndSettle();

        final selected = container.read(compareSelectionProvider);
        // ONLY dstSimilar must be selected!
        expect(selected, contains(dstSimilar.path));
        expect(selected.contains(dstExact.path), isFalse);
        expect(selected.contains(srcSimilar.path), isFalse);
        expect(selected.contains(srcExact.path), isFalse);
        expect(selected.length, equals(1));
      },
    );
  });
}
