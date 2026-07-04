import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/open_with_dialog.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestWidget() {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              OpenWithDialog.show(context, '/home/user/document.txt');
            },
            child: const Text('Show Dialog'),
          ),
        ),
      ),
    );
  }

  testWidgets('OpenWithDialog renders and shows loading initially', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Show Dialog'));
    await tester.pump(); // Pump without settle because of BubbleLoader animation

    expect(find.byType(OpenWithDialog), findsOneWidget);
    expect(find.text('OPEN WITH'), findsOneWidget);
    expect(find.text('document.txt'), findsOneWidget);
    expect(find.text('Scanning for applications...'), findsOneWidget);

    // Let the timer/future complete, but don't hang on BubbleLoader animation
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('OpenWithDialog allows cancel', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.tap(find.text('Show Dialog'));
    await tester.pump(); 

    // Find and tap Cancel
    await tester.tap(find.text('CANCEL'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(OpenWithDialog), findsNothing);
  });
}
