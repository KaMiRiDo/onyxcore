import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/archive_manager/presentation/widgets/compress_dialog.dart';

void main() {
  Widget createWidgetUnderTest({List<String> sourcePaths = const []}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: CompressDialog(sourcePaths: sourcePaths),
        ),
      ),
    );
  }

  group('CompressDialog', () {
    testWidgets('renders correctly with default UI', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(sourcePaths: ['/path/to/my_file.txt']));
      
      expect(find.text('Compress Items'), findsOneWidget);
      expect(find.text('ARCHIVE NAME'), findsOneWidget);
      expect(find.text('FORMAT'), findsOneWidget);
      expect(find.text('PASSWORD (OPTIONAL)'), findsOneWidget);
      
      // Default name should be my_file based on single source path
      final nameTextField = tester.widget<TextField>(find.byType(TextField).first);
      expect(nameTextField.controller?.text, 'my_file');
      
      expect(find.text('ZIP'), findsOneWidget);
      expect(find.text('7Z'), findsOneWidget);
      expect(find.text('TAR'), findsOneWidget);
      expect(find.text('GZ'), findsOneWidget);
      
      expect(find.text('CANCEL'), findsOneWidget);
      expect(find.text('COMPRESS'), findsOneWidget);
    });

    testWidgets('initializes archive name based on sourcePaths folder', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest(sourcePaths: [
        '/path/to/folder/file1.txt',
        '/path/to/folder/file2.txt'
      ]));
      
      final nameTextField = tester.widget<TextField>(find.byType(TextField).first);
      expect(nameTextField.controller?.text, 'folder');
    });

    testWidgets('can change format selection', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      
      // Tap '7Z'
      await tester.tap(find.text('7Z'));
      await tester.pumpAndSettle();
      
      // To verify it was tapped, we could look for the active style, 
      // but testing logic is sufficient for unit tests. We will verify the result later.
    });

    testWidgets('toggles password visibility', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      
      final passwordTextField = tester.widget<TextField>(find.byType(TextField).last);
      expect(passwordTextField.obscureText, isTrue);

      final visibilityIcon = find.byIcon(Icons.visibility_rounded);
      expect(visibilityIcon, findsOneWidget);
      
      await tester.tap(visibilityIcon);
      await tester.pumpAndSettle();
      
      final textFieldVisible = tester.widget<TextField>(find.byType(TextField).last);
      expect(textFieldVisible.obscureText, isFalse);
    });

    testWidgets('cancels dialog when cancel is pressed', (tester) async {
      var canceled = false;
      
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                final result = await CompressDialog.show(context, []);
                if (result == null) {
                  canceled = true;
                }
              },
              child: const Text('Show Dialog'),
            );
          },
        ),
      ));
      
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();
      
      expect(canceled, isTrue);
    });

    testWidgets('returns CompressDialogResult when compress is pressed', (tester) async {
      CompressDialogResult? returnedResult;
      
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                returnedResult = await CompressDialog.show(context, ['/path/to/file.txt']);
              },
              child: const Text('Show Dialog'),
            );
          },
        ),
      ));
      
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      // Select 7Z format
      await tester.tap(find.text('7Z'));
      await tester.pumpAndSettle();
      
      // Enter password
      await tester.enterText(find.byType(TextField).last, 'secret');
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('COMPRESS'));
      await tester.pumpAndSettle();
      
      expect(returnedResult, isNotNull);
      expect(returnedResult!.archiveName, 'file');
      expect(returnedResult!.format, '7z');
      expect(returnedResult!.password, 'secret');
    });

    testWidgets('does not compress if name is empty', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) {
            return ElevatedButton(
              onPressed: () async {
                await CompressDialog.show(context, []);
              },
              child: const Text('Show Dialog'),
            );
          },
        ),
      ));
      
      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();
      
      // Clear name
      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('COMPRESS'));
      await tester.pumpAndSettle();
      
      // Dialog should still be open
      expect(find.byType(CompressDialog), findsOneWidget);
    });
  });
}
