import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/dialogs.dart';

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

  testWidgets('showVibrantConfirmDialog returns true on confirm', (tester) async {
    bool? result;
    await pumpTestWidget(tester, 
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showVibrantConfirmDialog(
                  context: context,
                  title: 'Vibrant Title',
                  message: 'Vibrant Message',
                  confirmLabel: 'Confirm Label',
                  confirmColor: Colors.red,
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Vibrant Title'), findsOneWidget);
    expect(find.text('Vibrant Message'), findsOneWidget);
    expect(find.text('Confirm Label'), findsOneWidget);

    await tester.tap(find.text('Confirm Label'));
    await tester.pumpAndSettle();

    expect(result, true);
  });

  testWidgets('showInputDialog returns input text', (tester) async {
    String? result;
    await pumpTestWidget(tester, 
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showInputDialog(
                  context: context,
                  title: 'Input Title',
                  hint: 'Input Hint',
                  initialValue: 'initial',
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Input Title'), findsOneWidget);
    
    // Type new text
    await tester.enterText(find.byType(TextField), 'new value');
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    expect(result, 'new value');
  });

  testWidgets('ConfirmDialog renders and returns false on cancel', (tester) async {
    bool? result;
    await pumpTestWidget(tester, 
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showDialog<bool>(
                  context: context,
                  builder: (context) => const ConfirmDialog(
                    title: 'Confirm Title',
                    message: 'Confirm Message',
                    isDestructive: true,
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Title'), findsOneWidget);
    
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(result, false);
  });

  testWidgets('PermanentDeleteDialog handles dontAskAgain', (tester) async {
    bool dontAskAgainResult = false;
    await pumpTestWidget(tester, 
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => PermanentDeleteDialog(
                    filesCount: 2,
                    foldersCount: 1,
                    totalSize: '3 MB',
                    onDontAskAgainChanged: (val) => dontAskAgainResult = val,
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Are you sure?'), findsOneWidget);
    
    // Tap don't ask again
    await tester.tap(find.text("Don't ask for confirmation in this session"));
    await tester.pumpAndSettle();

    // Confirm delete
    await tester.tap(find.text('Yes, Delete'));
    await tester.pumpAndSettle();

    expect(dontAskAgainResult, true);
  });

  testWidgets('ViewerDeleteDialog logic works', (tester) async {
    await pumpTestWidget(tester, 
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => const ViewerDeleteDialog(
                    fileName: 'test.png',
                    permanent: false,
                  ),
                );
              },
              child: const Text('Show Dialog'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Move to Trash?'), findsOneWidget);
    expect(find.text('test.png'), findsOneWidget);

    await tester.tap(find.text('Yes, Trash'));
    await tester.pumpAndSettle();
  });
}
