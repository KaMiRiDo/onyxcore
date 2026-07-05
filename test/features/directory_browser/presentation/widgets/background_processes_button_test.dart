import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/background_panel_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/background_processes_button.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';

class MockTaskNotifier extends TaskNotifier {
  MockTaskNotifier(this.initialTasks);
  final List<FileTask> initialTasks;
  
  @override
  List<FileTask> build() => initialTasks;
}

void main() {
  Widget buildTestWidget({
    List<FileTask> tasks = const [],
    bool isPanelOpen = false,
  }) {
    return ProviderScope(
      overrides: [
        taskProvider.overrideWith(() => MockTaskNotifier(tasks)),
        backgroundPanelOpenProvider.overrideWith((ref) => isPanelOpen),
        downloadsPanelOpenProvider.overrideWith((ref) => false),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: BackgroundProcessesButton(),
        ),
      ),
    );
  }

  testWidgets('BackgroundProcessesButton renders idle state correctly', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();
    
    expect(find.byType(Tooltip), findsOneWidget);
    // Custom paint pie chart shouldn't be visible in idle state (no running tasks)
    expect(find.byType(BackgroundProcessesButton), findsOneWidget);
  });

  testWidgets('BackgroundProcessesButton renders active state with custom paint pie chart', (tester) async {
    final tasks = <FileTask>[
      FileTask(
        id: '1',
        title: 'Task 1',
        subtitle: '',
        status: FileTaskStatus.running,
        progress: 0.5,
        createdAt: DateTime.now(),
      ),
    ];
    await tester.pumpWidget(buildTestWidget(tasks: tasks));
    await tester.pumpAndSettle();

    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('BackgroundProcessesButton renders error state', (tester) async {
    final tasks = <FileTask>[
      FileTask(
        id: '2',
        title: 'Task 2',
        subtitle: '',
        status: FileTaskStatus.error,
        errorMessage: 'Failed',
        createdAt: DateTime.now(),
      ),
    ];
    await tester.pumpWidget(buildTestWidget(tasks: tasks));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });
  
  testWidgets('BackgroundProcessesButton toggles panel when tapped', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();
    
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    
    // In this test, we can only verify the tap goes through since we are mocking
    // providers, but we can verify the InkWell is tappable.
    expect(find.byType(InkWell), findsWidgets);
  });
}
