import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/task_history_detail_view.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_history_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/background_panel_provider.dart';

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
}

void main() {
  testWidgets('TaskHistoryDetailView displays task details', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskHistoryProvider.overrideWith(() => MockTaskHistoryNotifier()),
          selectedHistoryIdProvider.overrideWith((ref) => '1'),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TaskHistoryDetailView(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Task Details'), findsOneWidget);
    // the title will be 'Copy Files'
    expect(find.text('Copy Files'), findsOneWidget);
    
    // Check if stats are rendered
    expect(find.text('DURATION'), findsOneWidget);
    expect(find.text('ITEMS'), findsOneWidget);
    expect(find.text('SIZE'), findsOneWidget);
    expect(find.text('5/5'), findsOneWidget);
    
    // Check if the source files are shown
    expect(find.text('PROCESSED ITEMS'), findsWidgets);
    expect(find.text('file1.txt'), findsWidgets);
    expect(find.text('file2.txt'), findsOneWidget);
  });
}
