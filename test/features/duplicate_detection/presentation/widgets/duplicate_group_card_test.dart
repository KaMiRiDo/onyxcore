import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/duplicate_group_card.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/file_comparison_tile.dart';

void main() {
  group('DuplicateGroupCard', () {
    late Directory tempDir;
    late File src;
    late File dest1;
    late File dest2;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('group_test_');
      src = File('${tempDir.path}/img_source.png')
        ..writeAsBytesSync(List.filled(1024, 1));
      dest1 = File('${tempDir.path}/dest_copy1.png')
        ..writeAsBytesSync(List.filled(1024, 1));
      dest2 = File('${tempDir.path}/dest_copy2.png')
        ..writeAsBytesSync(List.filled(1024, 1));
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('renders one-to-one match side-by-side', (tester) async {
      final match = DuplicateMatch(
        sourcePath: src.path,
        destinationMatches: [
          MatchedPair(
            sourcePath: src.path,
            destinationPath: dest1.path,
            similarityScore: 1,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DuplicateGroupCard(match: match),
            ),
          ),
        ),
      );

      expect(find.text('img_source.png'), findsWidgets);
      expect(find.text('1 Match'), findsOneWidget);
      expect(find.text('Exact Match'), findsWidgets);
      // Both source and destination tiles are present
      expect(find.byType(FileComparisonTile), findsNWidgets(2));
      expect(find.text('dest_copy1.png'), findsOneWidget);
    });

    testWidgets('renders one-to-many matches with all destination files', (
      tester,
    ) async {
      final match = DuplicateMatch(
        sourcePath: src.path,
        destinationMatches: [
          MatchedPair(
            sourcePath: src.path,
            destinationPath: dest1.path,
            similarityScore: 1,
          ),
          MatchedPair(
            sourcePath: src.path,
            destinationPath: dest2.path,
            similarityScore: 0.95,
            matchType: MatchType.perceptual,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: DuplicateGroupCard(match: match),
            ),
          ),
        ),
      );

      expect(find.text('2 Matches'), findsOneWidget);
      // 1 source + 2 destination = 3 tiles
      expect(find.byType(FileComparisonTile), findsNWidgets(3));
      expect(find.text('dest_copy1.png'), findsOneWidget);
      expect(find.text('dest_copy2.png'), findsOneWidget);
    });

    testWidgets('collapsing hides comparison body tiles', (tester) async {
      final match = DuplicateMatch(
        sourcePath: src.path,
        destinationMatches: [
          MatchedPair(
            sourcePath: src.path,
            destinationPath: dest1.path,
            similarityScore: 1,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DuplicateGroupCard(match: match, isExpanded: false),
          ),
        ),
      );

      // Header is visible
      expect(find.text('img_source.png'), findsOneWidget);
      // Detailed comparison tiles are hidden
      expect(find.byType(FileComparisonTile), findsNothing);
    });

    testWidgets('tapping header or toggle invokes onToggleExpanded', (
      tester,
    ) async {
      var toggled = false;
      final match = DuplicateMatch(
        sourcePath: src.path,
        destinationMatches: [
          MatchedPair(
            sourcePath: src.path,
            destinationPath: dest1.path,
            similarityScore: 1,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DuplicateGroupCard(
              match: match,
              onToggleExpanded: () => toggled = true,
            ),
          ),
        ),
      );

      final toggleFinder = find.byTooltip('Toggle Group');
      expect(toggleFinder, findsOneWidget);
      await tester.tap(toggleFinder);
      await tester.pump();

      expect(toggled, isTrue);
    });
  });
}
