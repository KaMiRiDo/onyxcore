import 'dart:async';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/utils/app_launcher_utils.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/open_with_dialog.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    // Always clear and populate cachedApps with dummy apps for testing to avoid pollution
    AppLauncherUtils.cachedApps.clear();
    AppLauncherUtils.cachedApps.addAll([
      AppInfo(
        id: 'test-editor',
        name: 'Test Editor',
        exec: 'test-editor %f',
        mimeTypes: ['text/plain'],
        desktopFilePath: '/usr/share/applications/test-editor.desktop',
      ),
      AppInfo(
        id: 'test-viewer',
        name: 'Test Viewer',
        exec: 'test-viewer %f',
        mimeTypes: ['image/png'],
        desktopFilePath: '/usr/share/applications/test-viewer.desktop',
      ),
    ]);
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

  void handleZonedError(Object error, StackTrace stack) {
    if (error.toString().contains('Failed to load font') || error.toString().contains('google_fonts')) {
      // Ignore google_fonts network exceptions in tests
      return;
    }
    if (error is Exception) {
      throw error;
    } else if (error is Error) {
      throw error;
    } else {
      throw Exception(error.toString());
    }
  }

  testWidgets('OpenWithDialog renders and shows loading initially', (tester) async {
    await runZonedGuarded(() async {
      await tester.runAsync(() async {
        await tester.pumpWidget(buildTestWidget());
        await tester.tap(find.text('Show Dialog'));
        await tester.pump();

        expect(find.byType(OpenWithDialog), findsOneWidget);
        expect(find.text('OPEN WITH'), findsOneWidget);
        expect(find.text('document.txt'), findsOneWidget);

        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();
      });
    }, handleZonedError);
  });

  testWidgets('OpenWithDialog allows cancel', (tester) async {
    await runZonedGuarded(() async {
      await tester.runAsync(() async {
        await tester.pumpWidget(buildTestWidget());
        await tester.tap(find.text('Show Dialog'));
        await tester.pump(); 

        await tester.tap(find.text('CANCEL'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();

        expect(find.byType(OpenWithDialog), findsNothing);
      });
    }, handleZonedError);
  });

  testWidgets('OpenWithDialog interaction and key navigation', (tester) async {
    await runZonedGuarded(() async {
      await tester.runAsync(() async {
        await tester.pumpWidget(buildTestWidget());
        await tester.tap(find.text('Show Dialog'));
        await tester.pump();

        // Wait for loading to finish by polling the widget tree
        var isLoading = true;
        for (var i = 0; i < 15; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          await tester.pump();
          final finder = find.text('Test Editor');
          if (finder.evaluate().isNotEmpty) {
            isLoading = false;
            break;
          }
        }

        expect(isLoading, isFalse, reason: 'OpenWithDialog failed to load within time limit');
        expect(find.text('Test Editor'), findsOneWidget);

        // Test Search Filtering
        await tester.enterText(find.byType(TextField), 'Viewer');
        await tester.pumpAndSettle();

        expect(find.text('Test Editor'), findsNothing);
        expect(find.text('Test Viewer'), findsOneWidget);

        // Clear search
        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();

        // Test arrow down key selection navigation
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();

        // Test double tap selection and launch
        final finder = find.text('Test Editor').first;
        await tester.tap(finder);
        await Future<void>.delayed(const Duration(milliseconds: 40));
        await tester.tap(finder);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pumpAndSettle();
      });
    }, handleZonedError);
  });

  testWidgets('OpenWithDialog resize handle', (tester) async {
    await runZonedGuarded(() async {
      await tester.runAsync(() async {
        await tester.pumpWidget(buildTestWidget());
        await tester.tap(find.text('Show Dialog'));
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await tester.pumpAndSettle();

        final resizeGesture = await tester.startGesture(tester.getBottomRight(find.byType(OpenWithDialog)));
        await resizeGesture.moveBy(const Offset(50, 50));
        await resizeGesture.up();
        await tester.pumpAndSettle();
      });
    }, handleZonedError);
  });
}
