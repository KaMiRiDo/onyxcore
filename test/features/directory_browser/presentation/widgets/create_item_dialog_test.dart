import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/create_item_dialog.dart';

void main() {
  Future<void> pumpTestWidget(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(0.2)),
        child: widget,
      ),
    );
  }

  Widget buildTestWidget({
    String currentPath = '/home/user',
    List<String> existingNames = const ['existing_folder', 'existing_file.txt'],
    bool initialIsFolder = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                final result = await CreateItemDialog.show(
                  context: context,
                  currentPath: currentPath,
                  existingNames: existingNames,
                  initialIsFolder: initialIsFolder,
                );
                // Optionally show result in UI for testing
                if (result != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Result: $result')),
                  );
                }
              },
              child: const Text('Show Dialog'),
            );
          },
        ),
      ),
    );
  }

  testWidgets('CreateItemDialog renders and toggles types', (tester) async {
    await pumpTestWidget(tester, buildTestWidget());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('New Folder'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    // Tap Document
    await tester.tap(find.text('Document'));
    await tester.pumpAndSettle();

    expect(find.text('New Document'), findsOneWidget);

    // Tap Folder
    await tester.tap(find.text('Folder'));
    await tester.pumpAndSettle();

    expect(find.text('New Folder'), findsOneWidget);
  });

  testWidgets('CreateItemDialog validates invalid characters and existing names', (tester) async {
    await pumpTestWidget(tester, buildTestWidget());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Type invalid chars
    await tester.enterText(find.byType(TextField), 'bad/name');
    await tester.pumpAndSettle();
    expect(find.text('Name contains invalid characters'), findsOneWidget);

    // Type existing name
    await tester.enterText(find.byType(TextField), 'existing_folder');
    await tester.pumpAndSettle();
    expect(find.textContaining('already exists'), findsOneWidget);

    // Type valid name
    await tester.enterText(find.byType(TextField), 'new_folder');
    await tester.pumpAndSettle();
    expect(find.textContaining('already exists'), findsNothing);
    expect(find.text('Name contains invalid characters'), findsNothing);
  });

  testWidgets('CreateItemDialog submits correctly', (tester) async {
    await pumpTestWidget(tester, buildTestWidget());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'my_folder');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(find.text('Result: folder:my_folder'), findsOneWidget);
  });

  testWidgets('CreateItemDialog handles keyboard events', (tester) async {
    await pumpTestWidget(tester, buildTestWidget());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Toggle type with arrow keys
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('New Document'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'my_doc.txt');
    await tester.pumpAndSettle();

    // Submit with enter
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('Result: file:my_doc.txt'), findsOneWidget);
  });
}
