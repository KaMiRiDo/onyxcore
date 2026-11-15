import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/duplicate_group_card.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/file_comparison_tile.dart';

void main() {
  group('DuplicateGroupCard Side-Separated Selection', () {
    late Directory tempDir;
    late File src;
    late File dst1;
    late File dst2;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('card_side_sel_test_');
      src = File('${tempDir.path}/src.jpg')..writeAsBytesSync(List.filled(10, 1));
      dst1 = File('${tempDir.path}/dst1.jpg')..writeAsBytesSync(List.filled(10, 1));
      dst2 = File('${tempDir.path}/dst2.jpg')..writeAsBytesSync(List.filled(10, 1));
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('when collapsed, shows separate checkboxes in group header for source and destination sides', (
      tester,
    ) async {
      final match = DuplicateMatch(
        sourcePath: src.path,
        destinationMatches: [
          MatchedPair(
            sourcePath: src.path,
            destinationPath: dst1.path,
            similarityScore: 1,
          ),
          MatchedPair(
            sourcePath: src.path,
            destinationPath: dst2.path,
            similarityScore: 1,
          ),
        ],
      );

      var sourceToggled = false;
      var destToggled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DuplicateGroupCard(
                match: match,
                isExpanded: false, // collapsed, only header visible
                isSourceGroupSelected: false,
                onToggleSelectSourceGroup: () {
                  sourceToggled = true;
                },
                isDestinationGroupSelected: false,
                onToggleSelectDestinationGroup: () {
                  destToggled = true;
                },
              ),
            ),
          ),
        ),
      );

      // In the collapsed group card header, there are 2 side-specific checkboxes (source and destination)
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsNWidgets(2));

      // Tap source checkbox (left side)
      await tester.tap(checkboxes.first);
      await tester.pump();
      expect(sourceToggled, isTrue);

      // Tap destination checkbox (right side)
      await tester.tap(checkboxes.last);
      await tester.pump();
      expect(destToggled, isTrue);
    });

    testWidgets('destination side in group has a group-level Select All checkbox for destination items', (
      tester,
    ) async {
      final match = DuplicateMatch(
        sourcePath: src.path,
        destinationMatches: [
          MatchedPair(
            sourcePath: src.path,
            destinationPath: dst1.path,
            similarityScore: 1,
          ),
          MatchedPair(
            sourcePath: src.path,
            destinationPath: dst2.path,
            similarityScore: 1,
          ),
        ],
      );

      var destGroupToggled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DuplicateGroupCard(
                match: match,
                isDestinationGroupSelected: false,
                onToggleSelectDestinationGroup: () {
                  destGroupToggled = true;
                },
              ),
            ),
          ),
        ),
      );

      // Must find the group destination Select All checkbox
      final destSelectAllFinder = find.widgetWithText(
        Row,
        'Select All (2 matches)',
      );
      expect(destSelectAllFinder, findsOneWidget);

      final destCheckbox = find.descendant(
        of: destSelectAllFinder,
        matching: find.byType(Checkbox),
      );
      expect(destCheckbox, findsOneWidget);

      await tester.tap(destCheckbox);
      await tester.pump();

      expect(destGroupToggled, isTrue);
    });

    testWidgets('individual child tiles have separate checkboxes that toggle only that item', (
      tester,
    ) async {
      final match = DuplicateMatch(
        sourcePath: src.path,
        destinationMatches: [
          MatchedPair(
            sourcePath: src.path,
            destinationPath: dst1.path,
            similarityScore: 1,
          ),
        ],
      );

      String? toggledPath;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: DuplicateGroupCard(
                match: match,
                selectedPaths: {src.path}, // only source selected
                onToggleSelectPath: (path) {
                  toggledPath = path;
                },
              ),
            ),
          ),
        ),
      );

      final tiles = tester.widgetList<FileComparisonTile>(
        find.byType(FileComparisonTile),
      ).toList();
      expect(tiles.length, 2);
      expect(tiles[0].isSelected, isTrue); // source
      expect(tiles[1].isSelected, isFalse); // dest

      // Tap the destination tile's checkbox
      final destTileCheckboxes = find.descendant(
        of: find.byWidget(tiles[1]),
        matching: find.byType(Checkbox),
      );
      expect(destTileCheckboxes, findsOneWidget);
      await tester.tap(destTileCheckboxes);
      await tester.pump();

      expect(toggledPath, equals(dst1.path));
    });
  });
}
