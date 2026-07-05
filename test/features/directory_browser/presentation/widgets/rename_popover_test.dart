import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/rename_popover.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('RenamePopover shows correctly for single file', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? renameResult;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.8)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                RenamePopover.show(
                  context: context,
                  position: const Offset(400, 300),
                  paths: ['/home/user/file.txt'],
                  existingNames: ['file.txt', 'other.txt'],
                  onRename: (result) {
                    renameResult = result as String?;
                  },
                );
              },
              child: const Text('Show Popover'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Popover'));
    await pump(tester);

    expect(find.text('Rename File'), findsOneWidget);
    // Find the Rename button (there's one in title and one as action)
    expect(find.text('Rename'), findsWidgets);

    // Enter new name
    await tester.enterText(find.byType(TextField).first, 'new.txt');
    await pump(tester);

    expect(find.text('  Already exists'), findsNothing);

    // Submit
    await tester.tap(find.text('Rename').last, warnIfMissed: false);
    await pump(tester);

    expect(renameResult, 'new.txt');
  });

  testWidgets('RenamePopover shows correctly for bulk files', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Map<String, dynamic>? renameResult;

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.8)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                RenamePopover.show(
                  context: context,
                  position: const Offset(400, 300),
                  paths: ['/home/user/file1.txt', '/home/user/file2.txt'],
                  existingNames: [],
                  onRename: (result) {
                    renameResult = result as Map<String, dynamic>?;
                  },
                );
              },
              child: const Text('Show Popover'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Popover'));
    await pump(tester);

    expect(find.text('Bulk Rename'), findsOneWidget);
    expect(find.text('Add Prefix'), findsOneWidget);
    expect(find.text('Constant Name + Counter'), findsOneWidget);

    // Switch to constant
    await tester.tap(find.text('Constant Name + Counter'));
    await pump(tester);

    // Type name
    await tester.enterText(find.byType(TextField).first, 'const_');
    await pump(tester);

    // Submit
    await tester.tap(find.text('Rename').last, warnIfMissed: false);
    await pump(tester);

    expect(renameResult?['mode'], RenameMode.constant);
    expect(renameResult?['value'], 'const_');
  });

  testWidgets('RenamePopover hides on tap outside', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(0.8)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                RenamePopover.show(
                  context: context,
                  position: const Offset(400, 300),
                  paths: ['/home/user/file.txt'],
                  existingNames: [],
                  onRename: (result) {},
                );
              },
              child: const Text('Show Popover'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Popover'));
    await pump(tester);

    expect(find.text('Rename File'), findsOneWidget);

    // Tap outside (top-left corner, far from popover at 400,300)
    await tester.tapAt(const Offset(10, 10));
    await pump(tester);

    expect(find.text('Rename File'), findsNothing);
  });
}
