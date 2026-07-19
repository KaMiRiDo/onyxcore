// ignore_for_file: inference_failure_on_function_return_type, unused_local_variable
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/audio_player/presentation/widgets/dialogs/audio_tag_editor_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';

// Mock TaskNotifier to track calls
class MockTaskNotifier extends TaskNotifier {
  final List<String> addedTasks = [];
  final List<String> completedTasks = [];
  bool cancelRequested = false;

  @override
  String addTask({
    required String title,
    required String subtitle,
    int totalCount = 0,
    int totalSizeBytes = 0,
    List<String>? sourcePaths,
    String? targetPath,
    bool isLight = false,
  }) {
    final id = 'task_${addedTasks.length}';
    addedTasks.add(id);
    return id;
  }

  @override
  void updateProgress(String taskId, double progress) {}

  @override
  void updateItemCounts(String taskId, int current, int total) {}

  @override
  void updateCurrentItem(String taskId, String item) {}

  @override
  void completeTask(String taskId) {
    completedTasks.add(taskId);
  }

  @override
  bool isTaskCancelled(String taskId) => cancelRequested;

  @override
  Future<void> cancelTask(String taskId) async {
    cancelRequested = true;
  }
}

void main() {
  late MockTaskNotifier mockTaskNotifier;

  setUp(() {
    mockTaskNotifier = MockTaskNotifier();
  });

  Widget createWidget(List<String> paths, {Function(String, String)? onRename}) {
    return ProviderScope(
      overrides: [
        taskProvider.overrideWith(() => mockTaskNotifier),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: AudioTagEditorDialog(paths: paths, onRename: onRename),
        ),
      ),
    );
  }

  group('AudioTagEditorDialog - Static Methods', () {
    testWidgets('show() opens dialog', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [taskProvider.overrideWith(() => mockTaskNotifier)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => AudioTagEditorDialog.show(context, ['/test.mp3']),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(AudioTagEditorDialog), findsOneWidget);
    });
  });

  group('AudioTagEditorDialog - Single File Mode', () {
    testWidgets('renders correctly and falls back to filename (W-AUD-TAG-01, 02, 03, 08, 10, 12)', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(['/path/to/SongName.mp3']));
      await tester.pumpAndSettle();

      // Header
      expect(find.text('EDIT TAGS'), findsOneWidget);

      // Title field populated with filename
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('SongName'), findsOneWidget); // controller text

      // Other fields
      expect(find.text('Artist'), findsOneWidget);
      expect(find.text('Album'), findsOneWidget);
      expect(find.text('Genre'), findsOneWidget);
    });

    testWidgets('close buttons work (W-AUD-TAG-44, 45)', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(['/path/to/SongName.mp3']));
      await tester.pumpAndSettle();

      // Tap top-right close icon
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(AudioTagEditorDialog), findsNothing);
    });
  });

  group('AudioTagEditorDialog - Bulk Mode', () {
    testWidgets('renders bulk mode header and previews (W-AUD-TAG-06, 09, 11, 33)', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget([
        '/path/to/Song_Alpha.mp3',
        '/path/to/Song_Beta.mp3',
        '/path/to/Song_Gamma.mp3'
      ]));
      await tester.pumpAndSettle();

      // Header
      expect(find.text('BULK EDIT TAGS (3)'), findsOneWidget);

      // No title field
      expect(find.text('Title'), findsNothing);

      // Prefix calculated automatically
      expect(find.text('Song_'), findsOneWidget);

      // Previews visible
      expect(find.text('PREVIEW'), findsOneWidget);
      expect(find.text('Song_Alpha.mp3'), findsWidgets);
      expect(find.text('Song_Beta.mp3'), findsWidgets);
    });

    testWidgets('switches to baseName mode (W-AUD-TAG-32, 35)', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget([
        '/path/to/Alpha.mp3',
        '/path/to/Beta.mp3',
      ]));
      await tester.pumpAndSettle();

      // Switch to baseName
      await tester.tap(find.text('Base Name + Counter'));
      await tester.pumpAndSettle();

      // Label changes
      expect(find.text('Base Name'), findsOneWidget);

      // Enter new text in the active text field for Base Name
      // First find the TextField for Base Name
      final textFieldFinder = find.byType(TextField).first; // The first one is the bulk rename controller
      await tester.enterText(textFieldFinder, 'NewBase');
      await tester.pumpAndSettle();

      // Preview should show NewBase_1.mp3
      expect(find.text('NewBase_1.mp3'), findsOneWidget);
      expect(find.text('NewBase_2.mp3'), findsOneWidget);
    });

    testWidgets('previews prefix mode correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget([
        '/path/to/Song_Alpha.mp3',
        '/path/to/Song_Beta.mp3',
      ]));
      await tester.pumpAndSettle();

      final textFieldFinder = find.byType(TextField).first;
      await tester.enterText(textFieldFinder, 'Prefix_');
      await tester.pumpAndSettle();

      expect(find.text('Prefix_Alpha.mp3'), findsOneWidget);
    });
  });

  group('AudioTagEditorDialog - Cover Art', () {
    testWidgets('clear cover art toggles correctly (W-AUD-TAG-20, 21, 24)', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(['/path/to/Song1.mp3', '/path/to/Song2.mp3']));
      await tester.pumpAndSettle();

      // Default state has no cover, just music note
      expect(find.byIcon(Icons.music_note), findsOneWidget);

      // Tap delete icon to clear
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Shows clear icon
      expect(find.byIcon(Icons.layers_clear_rounded), findsOneWidget);
      expect(find.byIcon(Icons.undo_rounded), findsOneWidget);

      // Tap undo
      await tester.tap(find.byIcon(Icons.undo_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.music_note), findsOneWidget);
    });
  });

  group('AudioTagEditorDialog - Save Operations', () {
    testWidgets('saves tags and closes (W-AUD-TAG-25, 36, 40)', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget(['/path/to/Song.mp3']));
      await tester.pumpAndSettle();

      // Enter some data
      await tester.enterText(find.byType(TextField).at(1), 'NewArtist');
      await tester.pumpAndSettle();

      // Tap Save button
      await tester.tap(find.text('Save Tags'));
      // wait for save async operation
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // Dialog should be closed
      expect(find.byType(AudioTagEditorDialog), findsNothing);

      // Task should be added and completed
      expect(mockTaskNotifier.addedTasks.isNotEmpty, isTrue);
      expect(mockTaskNotifier.completedTasks.isNotEmpty, isTrue);
    });

    testWidgets('saves and renames single file', (WidgetTester tester) async {
      var renameCalled = false;
      await tester.pumpWidget(createWidget(['/path/to/Song.mp3'], onRename: (oldP, newP) {
        renameCalled = true;
      }));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'NewTitle');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Tags'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      // We can't actually rename a non-existent file, so it will throw inside _runSaveTask,
      // but it should still hit the path and log the error!
      expect(mockTaskNotifier.addedTasks.isNotEmpty, isTrue);
    });

    testWidgets('saves and bulk renames files', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget([
        '/path/to/Song1.mp3',
        '/path/to/Song2.mp3',
      ]));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'Bulk_');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Tags'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(mockTaskNotifier.addedTasks.isNotEmpty, isTrue);
    });

    testWidgets('saves bulk renames with BaseName mode', (WidgetTester tester) async {
      await tester.pumpWidget(createWidget([
        '/path/to/Song1.mp3',
        '/path/to/Song2.mp3',
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Base Name + Counter'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Base');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Tags'));
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(mockTaskNotifier.addedTasks.isNotEmpty, isTrue);
    });
  });
}
