import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/file_picker/presentation/widgets/file_picker_new_folder_dialog.dart';

void main() {
  testWidgets('renders dialog correctly and allows input', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FilePickerNewFolderDialog(),
        ),
      ),
    );

    expect(find.text('New Folder'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Create'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'my_new_folder');
    expect(find.text('my_new_folder'), findsOneWidget);
  });

  testWidgets('tapping Create pops with entered text', (tester) async {
    String? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showDialog<String>(
                    context: context,
                    builder: (ctx) => const FilePickerNewFolderDialog(),
                  );
                },
                child: const Text('Show Dialog'),
              );
            }
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'new_dir');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(result, 'new_dir');
  });

  testWidgets('tapping Cancel pops with null', (tester) async {
    String? result = 'initial';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  final res = await showDialog<String>(
                    context: context,
                    builder: (ctx) => const FilePickerNewFolderDialog(),
                  );
                  if (res == null) result = null;
                },
                child: const Text('Show Dialog'),
              );
            }
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'new_dir');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, isNull);
  });
}
