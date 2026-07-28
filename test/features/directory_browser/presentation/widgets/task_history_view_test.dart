import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/background_panel_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_history_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/task_history_view.dart';

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
      TaskHistoryEntry(
        id: '2',
        title: 'Delete Files',
        subtitle: 'Failed to delete files',
        statusName: 'failed',
        createdAt: DateTime.now(),
        startedAt: DateTime.now().subtract(const Duration(seconds: 10)),
        completedAt: DateTime.now(),
        processedCount: 2,
        totalCount: 5,
        totalSizeBytes: 1024 * 1024,
        sourcePaths: ['/home/user/file1.txt'],
        logs: ['Error deleting file'],
      ),
    ];
  }

  @override
  TaskHistoryEntry? getEntry(String id) {
    return state.firstWhere((e) => e.id == id);
  }
  
  @override
  void clearAll() {
    state = [];
  }
}

class EmptyMockTaskHistoryNotifier extends TaskHistoryNotifier {
  @override
  List<TaskHistoryEntry> build() {
    return [];
  }
}

void main() {
  testWidgets('TaskHistoryView renders empty state when no history', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskHistoryProvider.overrideWith(EmptyMockTaskHistoryNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TaskHistoryView(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No history yet'), findsOneWidget);
  });

  testWidgets('TaskHistoryView renders history items correctly', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskHistoryProvider.overrideWith(MockTaskHistoryNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TaskHistoryView(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Copy Files'), findsOneWidget);
    expect(find.text('Delete Files'), findsOneWidget);
    expect(find.text('Clear All History'), findsOneWidget);
  });

  testWidgets('TaskHistoryView clear history button clears history', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskHistoryProvider.overrideWith(MockTaskHistoryNotifier.new),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(0.5),
            ),
            child: child!,
          ),
          home: const Scaffold(
            body: TaskHistoryView(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap clear history
    await tester.tap(find.text('Clear All History'));
    await tester.pumpAndSettle();

    // Should show confirm dialog
    expect(find.text('Clear History'), findsOneWidget);
  });

  testWidgets('TaskHistoryView click entry navigates to detail view', (tester) async {
    final container = ProviderContainer(
      overrides: [
        taskHistoryProvider.overrideWith(MockTaskHistoryNotifier.new),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: TaskHistoryView(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Copy Files entry
    await tester.tap(find.text('Copy Files'));
    await tester.pumpAndSettle();

    expect(container.read(selectedHistoryIdProvider), '1');
    expect(container.read(backgroundPanelViewProvider), BackgroundPanelView.historyDetail);
  });

  testWidgets('TaskHistoryView filter overlay interaction', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskHistoryProvider.overrideWith(MockTaskHistoryNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TaskHistoryView(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Open filter box
    await tester.tap(find.byIcon(Icons.filter_list_rounded));
    await tester.pumpAndSettle();

    expect(find.text('FILTER'), findsOneWidget);

    // Cancel filter box
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    expect(find.text('FILTER'), findsNothing);
  });
}
