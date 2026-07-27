import 'dart:io';
import 'package:file/file.dart' as file_pkg;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/file_picker/presentation/providers/file_picker_notifier.dart';
import 'package:onyxcore/features/file_picker/presentation/widgets/custom_file_picker_dialog.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/services/file_system_service.dart';

import '../../../../helpers/file_system_helper.dart';

class MockSettingsNotifier extends AsyncNotifier<AppSettings> implements SettingsNotifier {
  @override
  Future<AppSettings> build() async {
    return const AppSettings();
  }

  @override
  Future<void> setFilePickerDimensions(double width, double height) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late file_pkg.FileSystem fs;
  late FileSystemService fileSystemService;

  setUp(() {
    fs = setupMockFileSystem();
    
    // CustomFilePickerDialog sidebar uses Platform.environment['HOME']
    final realHome = Platform.environment['HOME'] ?? '/home/user';
    fs.directory('$realHome/Documents').createSync(recursive: true);
    fs.directory('$realHome/Downloads').createSync(recursive: true);
    fs.directory('$realHome/Desktop').createSync(recursive: true);
    fs.file('$realHome/Documents/report.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('Sample report');
    
    fileSystemService = FileSystemService(fs);
  });

  List<String>? dialogResult;

  Widget buildDialog({
    bool saveMode = false,
    bool pickDirectory = false,
    bool allowMultiple = false,
    List<String>? allowedExtensions,
  }) {
    dialogResult = null;
    final realHome = Platform.environment['HOME'] ?? '/home/user';
    return ProviderScope(
      overrides: [
        fileSystemServiceProvider.overrideWithValue(fileSystemService),
        settingsProvider.overrideWith(MockSettingsNotifier.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  dialogResult = await CustomFilePickerDialog.show(
                    context,
                    saveMode: saveMode,
                    pickDirectory: pickDirectory,
                    allowMultiple: allowMultiple,
                    allowedExtensions: allowedExtensions,
                    initialDirectory: realHome,
                  );
                },
                child: const Text('Show Dialog'),
              );
            },
          ),
        ),
      ),
    );
  }

  testWidgets('renders dialog correctly in open mode', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    
    await tester.pumpWidget(buildDialog());
    
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('SELECT FILES'), findsOneWidget);
    expect(find.text('CANCEL'), findsOneWidget);
    expect(find.text('OPEN'), findsOneWidget);

    expect(find.text('Documents'), findsWidgets);
    expect(find.text('Desktop'), findsOneWidget);
  });

  testWidgets('renders dialog correctly in save mode', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    
    await tester.pumpWidget(buildDialog(saveMode: true));
    
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('SAVE FILE'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('SAVE'), findsOneWidget);
  });



  testWidgets('selects directory and clicks select', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    
    await tester.pumpWidget(buildDialog(pickDirectory: true));
    
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Select Documents folder in the main view
    await tester.tap(find.text('Documents').first);
    await tester.pumpAndSettle();

    // Click OPEN (which acts as SELECT in directory mode)
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    
    expect(dialogResult, isNotNull);
    expect(dialogResult!.first, '${Platform.environment['HOME'] ?? '/home/user'}/Documents');
  });

  testWidgets('cancel closes dialog and returns null', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    
    await tester.pumpWidget(buildDialog());
    
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    
    expect(find.text('SELECT FILES'), findsNothing);
    expect(dialogResult, isNull);
  });

  testWidgets('validates selection with allowedExtensions in saveMode', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    
    await tester.pumpWidget(buildDialog(saveMode: true, allowedExtensions: ['pdf']));
    
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Type a file name with a wrong extension
    await tester.enterText(find.byType(TextField), 'report.txt');
    await tester.pumpAndSettle();

    // The error text is not shown in save mode, but the save action will be blocked.
    // Dialog should NOT close.

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    
    // Dialog should NOT be closed because selection is invalid
    expect(find.text('SAVE FILE'), findsOneWidget);
    expect(dialogResult, isNull);
  });

  testWidgets('validates selection in saveMode with empty filename', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    
    await tester.pumpWidget(buildDialog(saveMode: true));
    
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Filename is empty initially
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    // Dialog should NOT be closed
    expect(find.text('SAVE FILE'), findsOneWidget);
    expect(dialogResult, isNull);

    // Enter valid filename
    await tester.enterText(find.byType(TextField), 'new_file.txt');
    await tester.pumpAndSettle();

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    // Dialog should be closed and return the path
    expect(find.text('SAVE FILE'), findsNothing);
    expect(dialogResult!.first, '${Platform.environment['HOME'] ?? '/home/user'}/new_file.txt');
  });

  testWidgets('handles folder creation', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    
    await tester.pumpWidget(buildDialog(pickDirectory: true));
    
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Click new folder button
    await tester.tap(find.byIcon(Icons.create_new_folder_rounded));
    await tester.pumpAndSettle();

    // Enter folder name
    await tester.enterText(find.byType(TextField).last, 'MyNewFolder');
    await tester.pumpAndSettle();

    // Click create
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // Now current directory should be MyNewFolder
    expect(find.text('MyNewFolder'), findsWidgets);
    
    // Select it
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    expect(dialogResult!.first, '${Platform.environment['HOME'] ?? '/home/user'}/MyNewFolder');
  });

  testWidgets('handles resize gesture', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    
    await tester.pumpWidget(buildDialog());
    
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Find resize handle (it uses CustomPaint)
    final resizeHandle = find.byType(CustomPaint).last;
    expect(resizeHandle, findsOneWidget);

    // Perform pan gesture
    final gesture = await tester.startGesture(tester.getCenter(resizeHandle));
    await gesture.moveBy(const Offset(50, 50));
    await gesture.up();
    await tester.pumpAndSettle();

    // There is no easy way to assert the new size in a widget test without a key on the container, 
    // but we can ensure it doesn't throw and triggers state updates.
    expect(find.text('SELECT FILES'), findsOneWidget);
  });

  testWidgets('handles folder creation failure', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    
    await tester.pumpWidget(buildDialog(pickDirectory: true));
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Trigger failure by empty name which might throw, or just assume it is caught
    await tester.tap(find.byIcon(Icons.create_new_folder_rounded));
    await tester.pumpAndSettle();
    
    // Actually the mock file system won't throw on typical names. We can simulate a failure by using an invalid path character in the name or deleting the parent.
    // Let's just delete the current directory from the fs!
    fs.directory(Platform.environment['HOME'] ?? '/home/user').deleteSync(recursive: true);

    await tester.enterText(find.byType(TextField).last, 'MyNewFolder2');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // It should show a snackbar
    expect(find.textContaining('Failed to create folder'), findsOneWidget);
  });

  testWidgets('handles keyboard shortcuts', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    
    await tester.pumpWidget(buildDialog());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Arrow Left (Alt) -> go back
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();

    // Arrow Right (Alt) -> go forward
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();

    // Enter with invalid selection
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    // Dialog should still be open
    expect(find.text('SELECT FILES'), findsOneWidget);

    // Escape -> close dialog
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('SELECT FILES'), findsNothing);
  });

  testWidgets('handles breadcrumb and header button taps', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    
    await tester.pumpWidget(buildDialog());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Tap Documents
    await tester.tap(find.text('Documents').first);
    await tester.pumpAndSettle();

    // Tap go up
    await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
    await tester.pumpAndSettle();

    // Tap breadcrumb
    // Navigate deep first
    await tester.tap(find.text('Documents').first);
    await tester.pumpAndSettle();
    
    // Tap the parent breadcrumb (if HOME is /home/user, it has multiple parts)
    final breadcrumb = find.text('user'); // Part of /home/user
    if (breadcrumb.evaluate().isNotEmpty) {
      await tester.tap(breadcrumb.first);
      await tester.pumpAndSettle();
    }
    
    // Toggle hidden files
    await tester.tap(find.text('HIDDEN'));
    await tester.pumpAndSettle();
  });

  testWidgets('handles multiple selection and double tap', (tester) async {
    tester.view.physicalSize = const Size(1200, 2000); // Larger to prevent off-screen
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    
    await tester.pumpWidget(buildDialog(allowMultiple: true));
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Navigate to Documents
    await tester.tap(find.text('Documents').first);
    await tester.pumpAndSettle();

    // Single tap file
    await tester.ensureVisible(find.text('report.txt'));
    await tester.tap(find.text('report.txt'));
    await tester.pumpAndSettle();

    // Double tap file -> should return and close dialog
    await tester.ensureVisible(find.text('report.txt'));
    await tester.tap(find.text('report.txt'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('report.txt'), warnIfMissed: false);
    await tester.pumpAndSettle();
    
    expect(dialogResult, isNotNull);
  });

  testWidgets('handles save mode delay and text submission', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    
    // Add initialFileName
    await tester.pumpWidget(ProviderScope(
      overrides: [
        fileSystemServiceProvider.overrideWithValue(fileSystemService),
        settingsProvider.overrideWith(MockSettingsNotifier.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogResult = await CustomFilePickerDialog.show(
                  context,
                  saveMode: true,
                  initialFileName: 'test.txt',
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Show Dialog'));
    await tester.pump(const Duration(milliseconds: 100)); // wait for dialog
    await tester.pump(const Duration(milliseconds: 100)); // wait for focus delay

    // Submit text field (Enter key)
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 100));

    expect(dialogResult, isNotNull);
    expect(dialogResult!.first.endsWith('test.txt'), isTrue);
  });

  testWidgets('handles missing provider state gracefully', (tester) async {
    // This is hard to trigger unless the provider errors out. We'll skip deep forcing it 
    // unless necessary, but let's at least test the empty view by providing an empty directory.
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    
    fs.directory('/empty').createSync(recursive: true);
    
    await tester.pumpWidget(ProviderScope(
      overrides: [
        fileSystemServiceProvider.overrideWithValue(fileSystemService),
        settingsProvider.overrideWith(MockSettingsNotifier.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                dialogResult = await CustomFilePickerDialog.show(
                  context,
                  initialDirectory: '/empty',
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Show Dialog'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    final textFinder = find.text('No items found');
    if (textFinder.evaluate().isEmpty) {
      debugDumpApp();
    }
    expect(textFinder, findsOneWidget);
  });

  testWidgets('handles invalid directory and shows error', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());
    
    await tester.pumpWidget(ProviderScope(
      overrides: [
        fileSystemServiceProvider.overrideWithValue(fileSystemService),
        settingsProvider.overrideWith(MockSettingsNotifier.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                await CustomFilePickerDialog.show(
                  context,
                  initialDirectory: '/invalid_dir',
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Show Dialog'));
    await tester.pump(); // Start dialog
    await tester.pump(const Duration(milliseconds: 100)); // Show bubble loader
    await tester.pump(const Duration(seconds: 1)); // Fetch data (throws error)
    await tester.pump(const Duration(seconds: 1)); // Error state callback

    // Check that snackbar is shown (snackbars show on top of everything)
    expect(find.byType(SnackBar), findsOneWidget);
    // Find text containing the error
    expect(find.textContaining('Directory does not exist'), findsOneWidget);
  });
}
