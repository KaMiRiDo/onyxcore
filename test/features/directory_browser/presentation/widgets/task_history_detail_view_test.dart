import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/background_panel_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_history_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/task_history_detail_view.dart';

class MockTaskHistoryNotifier extends TaskHistoryNotifier {
  @override
  List<TaskHistoryEntry> build() {
    return [
      TaskHistoryEntry(
        id: '1',
        title: 'Copy Files',
        subtitle: 'Copied 5 files',
        statusName: 'completed',
        createdAt: DateTime.now(),
        startedAt: DateTime.now().subtract(const Duration(seconds: 10)),
        completedAt: DateTime.now(),
        processedCount: 5,
        totalCount: 5,
        totalSizeBytes: 1024 * 1024,
        sourcePaths: ['/home/user/file1.txt', '/home/user/file2.txt'],
        targetPath: '/home/user/Downloads',
        logs: ['Created file: /home/user/Downloads/file1.txt'],
      ),
    ];
  }

  @override
  TaskHistoryEntry? getEntry(String id) {
    if (id == '1') {
      return state.first;
    }
    return null;
  }

  @override
  void deleteEntry(String id) {
    state = state.where((entry) => entry.id != id).toList();
  }
}

void main() {
  testWidgets('TaskHistoryDetailView displays task details and handles delete/back/logs', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mockHistory = MockTaskHistoryNotifier();
    final container = ProviderContainer(
      overrides: [
        taskHistoryProvider.overrideWith(() => mockHistory),
        selectedHistoryIdProvider.overrideWith((ref) => '1'),
        backgroundPanelViewProvider.overrideWith((ref) => BackgroundPanelView.historyDetail),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: TaskHistoryDetailView(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Task Details'), findsOneWidget);
    expect(find.text('Copy Files'), findsOneWidget);
    expect(find.text('DURATION'), findsOneWidget);
    expect(find.text('ITEMS'), findsOneWidget);
    expect(find.text('SIZE'), findsOneWidget);
    expect(find.text('5/5'), findsOneWidget);

    // Expand logs
    await tester.tap(find.text('Execution Logs'));
    await tester.pumpAndSettle();
    expect(find.text('Created file: /home/user/Downloads/file1.txt'), findsOneWidget);

    // Confirm Back Navigation
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(container.read(selectedHistoryIdProvider), isNull);
    expect(container.read(backgroundPanelViewProvider), BackgroundPanelView.history);

    // Re-select to test delete confirmation
    container.read(selectedHistoryIdProvider.notifier).state = '1';
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    // Verify confirmation overlay
    expect(find.text('Delete History?'), findsOneWidget);

    // Confirm delete
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(mockHistory.state, isEmpty);
  });
}
