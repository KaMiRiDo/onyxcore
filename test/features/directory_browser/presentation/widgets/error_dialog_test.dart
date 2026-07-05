import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/error_dialog.dart';

void main() {
  Widget buildTestWidget() {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (context) => const ErrorDialog(
                  title: 'Error Title',
                  message: 'Error Message',
                  buttonText: 'Dismiss',
                ),
              );
            },
            child: const Text('Show Dialog'),
          ),
        ),
      ),
    );
  }

  testWidgets('ErrorDialog renders correctly', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Error Title'), findsOneWidget);
    expect(find.text('Error Message'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);
  });

  testWidgets('ErrorDialog handles button tap to close', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorDialog), findsNothing);
  });

  testWidgets('ErrorDialog handles keyboard enter to close', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Send enter key event
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.byType(ErrorDialog), findsNothing);
  });
}
