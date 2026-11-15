import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:onyxcore/features/directory_browser/domain/repositories/directory_repository.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/clipboard_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/dialogs.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/providers/compare_selection_notifier.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/providers/comparison_runner_notifier.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/compare_results_view.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/duplicate_group_card.dart';

class _FakeRepo implements DirectoryRepository {
  List<String> trashedPaths = [];
  List<String> deletedPaths = [];
  bool lastPermanent = false;

  @override
  Future<void> trashItems(
    List<String> paths, {
    String? taskId,
    void Function(String message)? onLog,
    void Function(int current, int total)? onProgress,
  }) async {
    trashedPaths.addAll(paths);
  }

  @override
  Future<void> deleteItems(
    List<String> paths, {
    bool permanent = false,
    String? taskId,
    void Function(String message)? onLog,
    void Function(int current, int total)? onProgress,
  }) async {
    deletedPaths.addAll(paths);
    lastPermanent = permanent;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('CompareResultsView Side-Separated Selection & Actions', () {
    late Directory tempDir;
    late File src1;
    late File src2;
    late File dst1;
    late File dst2;
    late File dst3;
    late ComparisonResult result;
    late _FakeRepo fakeRepo;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('actions_side_test_');
      src1 = File('${tempDir.path}/src1.jpg')..writeAsBytesSync(List.filled(10, 1));
      src2 = File('${tempDir.path}/src2.jpg')..writeAsBytesSync(List.filled(10, 1));
      dst1 = File('${tempDir.path}/dst1.jpg')..writeAsBytesSync(List.filled(10, 1));
      dst2 = File('${tempDir.path}/dst2.jpg')..writeAsBytesSync(List.filled(10, 1));
      dst3 = File('${tempDir.path}/dst3.jpg')..writeAsBytesSync(List.filled(10, 1));

      fakeRepo = _FakeRepo();

      result = ComparisonResult(
        requestId: 'req_1',
        matches: [
          DuplicateMatch(
            sourcePath: src1.path,
            destinationMatches: [
              MatchedPair(
                sourcePath: src1.path,
                destinationPath: dst1.path,
                similarityScore: 1,
              ),
              MatchedPair(
                sourcePath: src1.path,
                destinationPath: dst2.path,
                similarityScore: 1,
              ),
            ],
          ),
          DuplicateMatch(
            sourcePath: src2.path,
            destinationMatches: [
              MatchedPair(
                sourcePath: src2.path,
                destinationPath: dst3.path,
                similarityScore: 1,
              ),
            ],
          ),
        ],
        totalSourceCandidates: 2,
        totalDestinationCandidates: 3,
        completedAt: DateTime.now(),
      );
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    Widget buildTestWidget({ComparisonResult? customResult}) {
      return ProviderScope(
        overrides: [
          directoryRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: CompareResultsView(
              result: customResult ?? result,
              sourceFolder: tempDir.path,
              destinationFolder: tempDir.path,
            ),
          ),
        ),
      );
    }

    testWidgets('source folder checkbox selects all sources on left side only', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CompareResultsView)),
      );

      // Initially no items selected
      expect(container.read(compareSelectionProvider), isEmpty);

      // Locate the SOURCE FOLDER header card
      final sourceHeaderFinder = find.widgetWithText(Row, 'SOURCE FOLDER');
      expect(sourceHeaderFinder, findsOneWidget);

      final sourceCheckbox = find.descendant(
        of: sourceHeaderFinder,
        matching: find.byType(Checkbox),
      );
      expect(sourceCheckbox, findsOneWidget);

      // Tap Source Select All checkbox
      await tester.tap(sourceCheckbox);
      await tester.pumpAndSettle();

      final selected = container.read(compareSelectionProvider);
      // All sources (src1, src2) selected
      expect(selected, containsAll([src1.path, src2.path]));
      // NO destination items selected
      expect(selected.contains(dst1.path), isFalse);
      expect(selected.contains(dst2.path), isFalse);
      expect(selected.contains(dst3.path), isFalse);

      // Tap again to deselect all sources
      await tester.tap(sourceCheckbox);
      await tester.pumpAndSettle();

      expect(container.read(compareSelectionProvider), isEmpty);
    });

    testWidgets('destination folder checkbox selects all destinations on right side only', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CompareResultsView)),
      );

      // Locate the DESTINATION FOLDER header card
      final destHeaderFinder = find.widgetWithText(Row, 'DESTINATION FOLDER');
      expect(destHeaderFinder, findsOneWidget);

      final destCheckbox = find.descendant(
        of: destHeaderFinder,
        matching: find.byType(Checkbox),
      );
      expect(destCheckbox, findsOneWidget);

      // Tap Destination Select All checkbox
      await tester.tap(destCheckbox);
      await tester.pumpAndSettle();

      final selected = container.read(compareSelectionProvider);
      // All destinations (dst1, dst2, dst3) selected
      expect(selected, containsAll([dst1.path, dst2.path, dst3.path]));
      // NO source items selected
      expect(selected.contains(src1.path), isFalse);
      expect(selected.contains(src2.path), isFalse);

      // Tap again to deselect all destinations
      await tester.tap(destCheckbox);
      await tester.pumpAndSettle();

      expect(container.read(compareSelectionProvider), isEmpty);
    });

    testWidgets('no button exists to select all items on both sides at once', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CompareResultsView)),
      );

      // Select 1 item to reveal selection toolbar
      container.read(compareSelectionProvider.notifier).select(dst1.path);
      await tester.pumpAndSettle();

      // There must be NO "Select All" button in the selection toolbar that selects both sides
      expect(find.widgetWithText(TextButton, 'Select All'), findsNothing);
      // Clear button should exist
      expect(find.widgetWithText(TextButton, 'Clear'), findsOneWidget);
    });

    testWidgets('group destination Select All selects only that group destinations', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CompareResultsView)),
      );

      // Group 1 has 2 destination matches: dst1 and dst2
      final group1DestSelectAll = find.widgetWithText(Row, 'Select All (2 matches)');
      expect(group1DestSelectAll, findsOneWidget);

      final group1Checkbox = find.descendant(
        of: group1DestSelectAll,
        matching: find.byType(Checkbox),
      );
      expect(group1Checkbox, findsOneWidget);

      await tester.tap(group1Checkbox);
      await tester.pumpAndSettle();

      final selected = container.read(compareSelectionProvider);
      // dst1 and dst2 are selected
      expect(selected, containsAll([dst1.path, dst2.path]));
      // src1 is NOT selected
      expect(selected.contains(src1.path), isFalse);
      // dst3 from group 2 is NOT selected
      expect(selected.contains(dst3.path), isFalse);
    });

    testWidgets('individual match tile checkbox selects that single item only', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CompareResultsView)),
      );

      // Find the group card for group 2
      final groupCards = find.byType(DuplicateGroupCard);
      expect(groupCards, findsNWidgets(2));

      // In group 2, find the destination tile checkbox for dst3
      final dst3Text = find.text('dst3.jpg');
      expect(dst3Text, findsOneWidget);

      // Find the nearest checkbox for dst3
      final dst3Tile = find.ancestor(
        of: dst3Text,
        matching: find.byType(Container),
      ).first;

      final tileCheckbox = find.descendant(
        of: dst3Tile,
        matching: find.byType(Checkbox),
      ).first;

      await tester.tap(tileCheckbox);
      await tester.pumpAndSettle();

      final selected = container.read(compareSelectionProvider);
      expect(selected.length, 1);
      expect(selected, contains(dst3.path));
    });

    testWidgets('Copy action copies selected items and shows SnackBar', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CompareResultsView)),
      );

      container.read(compareSelectionProvider.notifier).select(dst1.path);
      await tester.pumpAndSettle();

      final copyBtn = find.widgetWithText(TextButton, 'Copy');
      expect(copyBtn, findsOneWidget);
      await tester.tap(copyBtn);
      await tester.pumpAndSettle();

      final clipboard = container.read(clipboardProvider);
      expect(clipboard.isCopy, isTrue);
      expect(clipboard.paths, contains(dst1.path));
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Move action cuts selected items and shows SnackBar', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CompareResultsView)),
      );

      container.read(compareSelectionProvider.notifier).select(src1.path);
      await tester.pumpAndSettle();

      final moveBtn = find.widgetWithText(TextButton, 'Move');
      expect(moveBtn, findsOneWidget);
      await tester.tap(moveBtn);
      await tester.pumpAndSettle();

      final clipboard = container.read(clipboardProvider);
      expect(clipboard.isCut, isTrue);
      expect(clipboard.paths, contains(src1.path));
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('Delete action confirms and trashes selected items', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CompareResultsView)),
      );

      container.read(comparisonRunnerProvider.notifier).state =
          ComparisonRunnerState(result: result);

      container.read(compareSelectionProvider.notifier).select(dst1.path);
      await tester.pumpAndSettle();

      final deleteBtn = find.widgetWithText(TextButton, 'Trash');
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      expect(find.byType(ViewerDeleteDialog), findsOneWidget);
      await tester.tap(find.text('Yes, Trash'));
      await tester.pumpAndSettle();

      expect(fakeRepo.trashedPaths, contains(dst1.path));
      expect(container.read(compareSelectionProvider), isEmpty);
    });

    testWidgets('Escape deselects all selected items', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(CompareResultsView)),
      );

      container.read(compareSelectionProvider.notifier).selectAll([
        src1.path,
        dst1.path,
      ]);
      await tester.pumpAndSettle();

      expect(container.read(compareSelectionProvider).length, 2);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(container.read(compareSelectionProvider), isEmpty);
    });

    testWidgets(
      'action toolbar is always visible with buttons disabled when no items selected',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(CompareResultsView)),
        );

        // Initially no items selected
        expect(container.read(compareSelectionProvider), isEmpty);

        // Action bar is always visible with '0 selected'
        expect(find.text('0 selected'), findsOneWidget);

        final copyBtn =
            tester.widget<TextButton>(find.widgetWithText(TextButton, 'Copy'));
        final moveBtn =
            tester.widget<TextButton>(find.widgetWithText(TextButton, 'Move'));
        final trashBtn =
            tester.widget<TextButton>(find.widgetWithText(TextButton, 'Trash'));
        final deleteBtn = tester.widget<TextButton>(
          find.widgetWithText(TextButton, 'Delete Permanently'),
        );
        final clearBtn =
            tester.widget<TextButton>(find.widgetWithText(TextButton, 'Clear'));

        expect(copyBtn.onPressed, isNull);
        expect(moveBtn.onPressed, isNull);
        expect(trashBtn.onPressed, isNull);
        expect(deleteBtn.onPressed, isNull);
        expect(clearBtn.onPressed, isNull);

        // Select an item -> buttons become active
        container.read(compareSelectionProvider.notifier).select(src1.path);
        await tester.pumpAndSettle();

        expect(find.text('1 selected'), findsOneWidget);
        final copyBtnActive =
            tester.widget<TextButton>(find.widgetWithText(TextButton, 'Copy'));
        expect(copyBtnActive.onPressed, isNotNull);
      },
    );

    testWidgets(
      'collapsed group cards show separate group-level checkboxes for source and destination',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        // Collapse all groups
        final collapseBtn = find.text('Collapse All');
        expect(collapseBtn, findsOneWidget);
        await tester.tap(collapseBtn);
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(CompareResultsView)),
        );

        // Find first group card
        final group1 = find.byKey(ValueKey(src1.path));
        expect(group1, findsOneWidget);

        // Group 1 header has source checkbox and destination checkbox
        final group1Checkboxes = find.descendant(
          of: group1,
          matching: find.byType(Checkbox),
        );
        expect(group1Checkboxes, findsNWidgets(2));

        // Tap destination checkbox of group 1 while collapsed
        await tester.tap(group1Checkboxes.last);
        await tester.pumpAndSettle();

        final selected = container.read(compareSelectionProvider);
        expect(selected, containsAll([dst1.path, dst2.path]));
        expect(selected.contains(src1.path), isFalse);

        // Tap source checkbox of group 1 while collapsed
        await tester.tap(group1Checkboxes.first);
        await tester.pumpAndSettle();

        expect(container.read(compareSelectionProvider), contains(src1.path));
      },
    );

    testWidgets(
      'horizontal stats banner displays comparison statistics and separate collapse button',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());
        await tester.pumpAndSettle();

        expect(find.textContaining('Duplicate Groups'), findsOneWidget);
        expect(find.textContaining('Total Matches'), findsOneWidget);
        expect(find.textContaining('candidates evaluated'), findsOneWidget);
        expect(find.byType(OutlinedButton), findsOneWidget);
      },
    );
  });
}
