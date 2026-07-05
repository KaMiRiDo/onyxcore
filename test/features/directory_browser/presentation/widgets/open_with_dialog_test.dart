import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/open_with_dialog.dart';

void main() {
  late AppDatabase db;
  
  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
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
