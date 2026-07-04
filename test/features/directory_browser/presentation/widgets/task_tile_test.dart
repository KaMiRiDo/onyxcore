import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/task_tile.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';

void main() {
  testWidgets('TaskTile renders complete state correctly', (tester) async {
    final task = FileTask(
      id: '1',
      title: 'Copy Files',
      subtitle: 'Copied 5 files',
      status: FileTaskStatus.completed,
      createdAt: DateTime.now(),
      processedCount: 5,
      totalCount: 5,
      totalSizeBytes: 1024,
      sourcePaths: ['/a/b.txt'],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TaskTile(task: task),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Copy Files'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('TaskTile renders failed state correctly', (tester) async {
    final task = FileTask(
      id: '2',
      title: 'Move Files',
      subtitle: 'Failed to move',
      status: FileTaskStatus.error,
      errorMessage: 'Failed to move',
      createdAt: DateTime.now(),
      processedCount: 2,
      totalCount: 5,
      totalSizeBytes: 1024,
      sourcePaths: ['/a/b.txt'],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TaskTile(task: task),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Move Files'), findsOneWidget);
    expect(find.text('Error'), findsOneWidget);
  });

  testWidgets('TaskTile renders running state correctly', (tester) async {
    final task = FileTask(
      id: '3',
      title: 'Delete Files',
      subtitle: 'Deleting...',
      status: FileTaskStatus.running,
      createdAt: DateTime.now(),
      processedCount: 2,
      totalCount: 5,
      totalSizeBytes: 1024,
      sourcePaths: ['/a/b.txt'],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: TaskTile(task: task),
          ),
        ),
      ),
    );

    // Don't pump and settle for running animation
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Delete Files'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
