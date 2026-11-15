import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/providers/comparison_runner_notifier.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/compare_window.dart';

void main() {
  group('Compare Window Paste & Removal Synchronization', () {
    late Directory tempDir;
    late File src;
    late File dst;
    late ComparisonResult initialResult;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('paste_sync_test_');
      src = File('${tempDir.path}/src.jpg')..writeAsBytesSync(List.filled(10, 1));
      dst = File('${tempDir.path}/dst.jpg')..writeAsBytesSync(List.filled(10, 1));

      initialResult = ComparisonResult(
        requestId: 'sync_req',
        matches: [
          DuplicateMatch(
            sourcePath: src.path,
            destinationMatches: [
              MatchedPair(
                sourcePath: src.path,
                destinationPath: dst.path,
                similarityScore: 1,
              ),
            ],
          ),
        ],
        totalSourceCandidates: 1,
        totalDestinationCandidates: 1,
        completedAt: DateTime.now(),
      );
    });

    tearDown(() {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('removing cut item via comparisonRunnerProvider updates compare view to empty state', (
      tester,
    ) async {
      final container = ProviderContainer();
      container.read(comparisonRunnerProvider.notifier).state =
          ComparisonRunnerState(result: initialResult);

      final rootFolder = FileItem(
        path: tempDir.path,
        name: 'test_folder',
        type: FileItemType.folder,
        modified: DateTime.now(),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: CompareWindow(
              windowId: 99,
              initialParams: WindowParams(
                viewerType: ViewerType.duplicateCompare,
                file: rootFolder,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Seed result after window initial params reset
      container.read(comparisonRunnerProvider.notifier).state =
          ComparisonRunnerState(result: initialResult);
      await tester.pumpAndSettle();

      // Initially shows 1 duplicate group
      expect(find.textContaining('1 Duplicate Group Found'), findsOneWidget);

      // Simulate the cut item being pasted and moved: removePaths called
      container.read(comparisonRunnerProvider.notifier).removePaths({dst.path});
      await tester.pumpAndSettle();

      // Compare view should instantly update to 'No Duplicates Found' empty state
      expect(find.text('No Duplicates Found'), findsOneWidget);
    });
  });
}
