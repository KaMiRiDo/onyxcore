import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/action_bar.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/directory_browser/domain/repositories/directory_repository.dart';
import '../pages/mock_utils.dart';

// Dummy Repository for testing
class DummyDirectoryRepository implements DirectoryRepository {
  bool failCreate = false;
  
  @override
  Future<void> createFolder(String path, String name, {String? taskId}) async {
    if (failCreate) throw Exception('Failed to create folder');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockTaskNotifier extends TaskNotifier {
  final List<FileTask> initialTasks;
  MockTaskNotifier(this.initialTasks);
  @override
  List<FileTask> build() => initialTasks;

  @override
  String addTask({
    required String title,
    required String subtitle,
    int totalCount = 0,
    int totalSizeBytes = 0,
    List<String>? sourcePaths,
    String? targetPath,
    bool isLight = false,
  }) => 'task_1';

  @override
  void completeTask(String id) {}

  @override
  void failTask(String id, String error) {}
}

class MockCurrentPathNotifier extends CurrentPathNotifier {
  @override
  String build() => '/test/path';
}

void main() {
  Widget buildTestWidget({required DirectoryRepository repo}) {
    return ProviderScope(
      overrides: [
        currentPathProvider.overrideWith(() => MockCurrentPathNotifier()),
        directoryRepositoryProvider.overrideWithValue(repo),
        taskProvider.overrideWith(() => MockTaskNotifier([])),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: ActionBar(),
        ),
      ),
    );
  }

  testWidgets('ActionBar renders correctly and views options', (tester) async {
    await tester.pumpWidget(buildTestWidget(repo: DummyDirectoryRepository()));
    
    expect(find.text('Add'), findsOneWidget);
    expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
    expect(find.byIcon(Icons.sort_rounded), findsOneWidget);
    expect(find.byIcon(Icons.filter_list_rounded), findsOneWidget);
  });

  testWidgets('ActionBar Add button triggers create folder flow successfully', (tester) async {
    final repo = DummyDirectoryRepository();
    await tester.pumpWidget(buildTestWidget(repo: repo));
    
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    
    // Expect input dialog
    expect(find.text('New Folder'), findsOneWidget);
    
    // Enter folder name
    await tester.enterText(find.byType(TextField), 'my_new_folder');
    await tester.pumpAndSettle();
    
    // Tap OK/Create (Usually dialogs have an OK or Create button, we can just find 'Create' or 'OK')
    final okButton = find.text('Create');
    if (tester.any(okButton)) {
      await tester.tap(okButton);
    } else {
      await tester.tap(find.text('OK'));
    }
    await tester.pumpAndSettle();
    
    // Check if dialog is gone
    expect(find.text('New Folder'), findsNothing);
  });

  testWidgets('ActionBar Add button triggers error snackbar on failure', (tester) async {
    final repo = DummyDirectoryRepository()..failCreate = true;
    await tester.pumpWidget(buildTestWidget(repo: repo));
    
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
    
    await tester.enterText(find.byType(TextField), 'fail_folder');
    await tester.pumpAndSettle();
    
    final okButton = find.text('Create');
    if (tester.any(okButton)) {
      await tester.tap(okButton);
    } else {
      await tester.tap(find.text('OK'));
    }
    
    await tester.pumpAndSettle();
    
    // Check for snackbar
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('Failed to create folder'), findsOneWidget);
  });
}
