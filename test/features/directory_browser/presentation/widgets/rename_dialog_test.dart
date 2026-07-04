import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/rename_dialog.dart';

void main() {
  Widget buildTestWidget({required List<String> paths}) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              final result = await showDialog(
                context: context,
                builder: (context) => RenameDialog(paths: paths),
              );
              if (result != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Result: $result')),
                );
              }
            },
            child: const Text('Show Dialog'),
          ),
        ),
      ),
    );
  }

  testWidgets('RenameDialog renders single file correctly', (tester) async {
    await tester.pumpWidget(buildTestWidget(paths: ['/home/user/test.txt']));
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Rename Item'), findsOneWidget);
    expect(find.text('NEW ITEM NAME'), findsOneWidget);
    
    // TextField should have the initial value 'test'
    expect(find.widgetWithText(TextField, 'test'), findsOneWidget);

    // Cancel
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.byType(RenameDialog), findsNothing);
  });

  testWidgets('RenameDialog renders bulk files correctly', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget(paths: ['/home/user/file1.txt', '/home/user/file2.txt']));
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Bulk Rename'), findsOneWidget);
    expect(find.text('RENAMING MODE'), findsOneWidget);
    expect(find.text('Add Prefix'), findsOneWidget);
    expect(find.text('Constant Name'), findsOneWidget);
    
    // Type a prefix
    await tester.enterText(find.byType(TextField), 'prefix_');
    await tester.pumpAndSettle();

    // Verify preview
    expect(find.text('prefix_file1.txt'), findsOneWidget);
    expect(find.text('prefix_file2.txt'), findsOneWidget);

    // Switch to constant name
    await tester.tap(find.text('Constant Name'));
    await tester.pumpAndSettle();

    // Verify preview
    expect(find.text('prefix__1.txt'), findsOneWidget);
    expect(find.text('prefix__2.txt'), findsOneWidget);
  });

  testWidgets('RenameDialog returns single string for single file rename', (tester) async {
    await tester.pumpWidget(buildTestWidget(paths: ['/home/user/single.txt']));
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'new_single');
    await tester.pumpAndSettle();

    await tester.tap(find.text('RENAME'));
    await tester.pumpAndSettle();

    expect(find.text('Result: new_single'), findsOneWidget);
  });
}
