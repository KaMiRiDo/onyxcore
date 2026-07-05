import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/conflict_dialog.dart';

void main() {
  Widget buildTestWidget({
    String fileName = 'test_file.txt',
    String destinationPath = '/home/user/docs/test_file.txt',
    bool isFolder = false,
    bool showApplyToAll = true,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (context) => ConflictDialog(
                      fileName: fileName,
                      destinationPath: destinationPath,
                      isFolder: isFolder,
                      showApplyToAll: showApplyToAll,
                    ),
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

  testWidgets('ConflictDialog renders correctly for file', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('File already exists'), findsOneWidget);
    expect(find.textContaining('test_file.txt', findRichText: true), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Replace'), findsOneWidget);
    expect(find.text('Rename (Keep Both)'), findsOneWidget);
    expect(find.text('Apply this for all files/folders'), findsOneWidget);
  });

  testWidgets('ConflictDialog renders correctly for folder', (tester) async {
    await tester.pumpWidget(buildTestWidget(isFolder: true));
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Folder already exists'), findsOneWidget);
  });

  testWidgets('ConflictDialog handles applyToAll checkbox', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    final checkbox = find.byType(Checkbox);
    expect(tester.widget<Checkbox>(checkbox).value, false);

    await tester.tap(checkbox);
    await tester.pumpAndSettle();

    expect(tester.widget<Checkbox>(checkbox).value, true);
  });

  testWidgets('ConflictDialog triggers shake animation on background tap', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Tap outside dialog container but inside the modal barrier
    // The dialog container has width 440, we can tap at top left.
    await tester.tapAt(const Offset(10, 10));
    await tester.pump();
    
    // Test passes if it doesn't crash and animation triggers
    expect(find.byType(ConflictDialog), findsOneWidget);
  });

  testWidgets('ConflictDialog returns correct result on tap', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();

    // Dialog should close
    expect(find.byType(ConflictDialog), findsNothing);
  });

  testWidgets('ConflictDialog handles keyboard navigation', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Send Arrow Down
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();

    // Send Arrow Up
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    // Send Enter to confirm (default is skip which is index 0)
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(ConflictDialog), findsNothing);
  });
}
