import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/background_panel_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/background_panel.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/task_tile.dart';

class MockTaskNotifier extends TaskNotifier {
  MockTaskNotifier(this.initialTasks);
  final List<FileTask> initialTasks;
  @override
  List<FileTask> build() => initialTasks;
}

void main() {
  Widget buildTestWidget({
    required List<FileTask> tasks,
    BackgroundPanelView view = BackgroundPanelView.tasks,
  }) {
    return ProviderScope(
      overrides: [
        taskProvider.overrideWith(() => MockTaskNotifier(tasks)),
        backgroundPanelViewProvider.overrideWith((ref) => view),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: BackgroundPanel(),
        ),
      ),
    );
  }

  testWidgets('BackgroundPanel renders empty tasks view correctly', (tester) async {
    await tester.pumpWidget(buildTestWidget(tasks: []));
    await tester.pumpAndSettle();

    expect(find.text('Background Processes'), findsOneWidget);
    expect(find.text('No active tasks'), findsOneWidget);
    expect(find.byIcon(Icons.hourglass_empty_rounded), findsOneWidget);
  });

  testWidgets('BackgroundPanel renders active tasks and Cancel All button', (tester) async {
    final tasks = [
      FileTask(
        id: 'task1',
        title: 'Copying files',
        subtitle: '',
        status: FileTaskStatus.running,
        createdAt: DateTime.now(),
      ),
    ];
    await tester.pumpWidget(buildTestWidget(tasks: tasks));
    await tester.pumpAndSettle();

    expect(find.byType(TaskTile), findsOneWidget);
    expect(find.text('Cancel All Tasks'), findsOneWidget);
  });

  testWidgets('BackgroundPanel handles Cancel All confirmation flow', (tester) async {
    final tasks = <FileTask>[
      FileTask(
        id: 'task1',
        title: 'Copying files',
        subtitle: '',
        status: FileTaskStatus.running,
        createdAt: DateTime.now(),
      ),
    ];
    await tester.pumpWidget(buildTestWidget(tasks: tasks));
    await tester.pumpAndSettle();

    // Tap 'Cancel All Tasks'
    await tester.tap(find.text('Cancel All Tasks'));
    await tester.pumpAndSettle();

    // Dialog appears
    expect(find.text('Cancel All Tasks?'), findsOneWidget);

    // Tap 'No, Keep'
    await tester.tap(find.text('No, Keep'));
    await tester.pumpAndSettle();

    // Dialog disappears
    expect(find.text('Cancel All Tasks?'), findsNothing);

    // Tap 'Cancel All Tasks' again
    await tester.tap(find.text('Cancel All Tasks'));
    await tester.pumpAndSettle();

    // Tap 'Yes, Cancel'
    await tester.tap(find.text('Yes, Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel All Tasks?'), findsNothing);
  });
}
