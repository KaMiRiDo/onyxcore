import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide ComparisonResult;
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_progress.dart';
import 'package:onyxcore/features/duplicate_detection/domain/entities/comparison_result.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/providers/compare_config_notifier.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/providers/comparison_runner_notifier.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/compare_progress_view.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/compare_results_view.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/compare_setup_view.dart';
import 'package:onyxcore/features/duplicate_detection/presentation/widgets/compare_window.dart';

void main() {
  group('CompareWindow', () {
    final tFile = FileItem(
      path: '/source',
      name: 'source',
      type: FileItemType.folder,
      modified: DateTime.now(),
    );

    final tParams = WindowParams(
      viewerType: ViewerType.duplicateCompare,
      file: tFile,
      initParams: {'sourceFolder': '/source', 'destinationFolder': '/dest'},
    );

    testWidgets('shows CompareSetupView when idle', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: CompareWindow(windowId: 101, initialParams: tParams),
          ),
        ),
      );

      expect(find.byType(CompareSetupView), findsOneWidget);
      expect(find.byType(CompareProgressView), findsNothing);
      expect(find.byType(CompareResultsView), findsNothing);
    });

    testWidgets('shows CompareProgressView when comparison is running', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            comparisonRunnerProvider.overrideWith(
              () => ComparisonRunnerNotifier(
                initialState: const ComparisonRunnerState(
                  isProcessing: true,
                  progress: ComparisonProgress(
                    requestId: '/source',
                    status: ComparisonStatus.discovering,
                    processedFiles: 5,
                    totalFiles: 20,
                  ),
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: CompareWindow(windowId: 101, initialParams: tParams),
          ),
        ),
      );

      expect(find.byType(CompareProgressView), findsOneWidget);
      expect(find.byType(CompareSetupView), findsNothing);
      expect(find.byType(CompareResultsView), findsNothing);
    });

    testWidgets('shows CompareResultsView when comparison completes', (
      tester,
    ) async {
      final tResult = ComparisonResult(
        requestId: '/source',
        matches: const [],
        totalSourceCandidates: 10,
        totalDestinationCandidates: 10,
        completedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            comparisonRunnerProvider.overrideWith(
              () => ComparisonRunnerNotifier(
                initialState: ComparisonRunnerState(result: tResult),
              ),
            ),
          ],
          child: MaterialApp(
            home: CompareWindow(windowId: 101, initialParams: tParams),
          ),
        ),
      );

      expect(find.byType(CompareResultsView), findsOneWidget);
      expect(find.byType(CompareSetupView), findsNothing);
    });

    testWidgets('shows cancelled view when comparison was cancelled', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            comparisonRunnerProvider.overrideWith(
              () => ComparisonRunnerNotifier(
                initialState: const ComparisonRunnerState(
                  progress: ComparisonProgress(
                    requestId: '/source',
                    status: ComparisonStatus.cancelled,
                  ),
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: CompareWindow(windowId: 101, initialParams: tParams),
          ),
        ),
      );

      expect(find.text('Comparison Cancelled'), findsOneWidget);
      expect(find.text('Reconfigure'), findsOneWidget);
    });

    testWidgets('shows error view when comparison fails', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            comparisonRunnerProvider.overrideWith(
              () => ComparisonRunnerNotifier(
                initialState: const ComparisonRunnerState(
                  error: 'Access Denied',
                ),
              ),
            ),
          ],
          child: MaterialApp(
            home: CompareWindow(windowId: 101, initialParams: tParams),
          ),
        ),
      );

      expect(find.text('Comparison Failed'), findsOneWidget);
      expect(find.text('Access Denied'), findsOneWidget);
      expect(find.text('Reconfigure'), findsOneWidget);
    });

    testWidgets(
      'resets comparison state and configuration when window is disposed/closed',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: CompareWindow(windowId: 101, initialParams: tParams),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(container.read(compareConfigProvider).sourceFolder, '/source');
        expect(container.read(compareConfigProvider).destinationFolder, '/dest');

        // Unmount / close the CompareWindow
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SizedBox()),
          ),
        );
        await tester.pumpAndSettle();

        // State must be cleared on window close
        expect(container.read(compareConfigProvider).sourceFolder, '');
        expect(container.read(compareConfigProvider).destinationFolder, '');
        expect(container.read(comparisonRunnerProvider).isProcessing, isFalse);
        expect(container.read(comparisonRunnerProvider).result, isNull);
      },
    );

    testWidgets(
      'starts fresh session when reopened with different params',
      (tester) async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        // First session with /source and /dest
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: CompareWindow(windowId: 101, initialParams: tParams),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(container.read(compareConfigProvider).sourceFolder, '/source');
        expect(container.read(compareConfigProvider).destinationFolder, '/dest');

        // Close the window
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: SizedBox()),
          ),
        );
        await tester.pumpAndSettle();

        // Second session with only new source
        final tParams2 = WindowParams(
          viewerType: ViewerType.duplicateCompare,
          file: tFile,
          initParams: {'sourceFolder': '/new_source'},
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: CompareWindow(windowId: 102, initialParams: tParams2),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(container.read(compareConfigProvider).sourceFolder, '/new_source');
        // Destination folder should be empty in fresh session, not stale '/dest'
        expect(container.read(compareConfigProvider).destinationFolder, '');
      },
    );
  });
}
