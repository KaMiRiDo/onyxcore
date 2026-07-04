import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/conflict_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/conflict_dialog.dart';

void main() {
  group('ConflictNotifier Widget Tests', () {
    testWidgets('resolveConflict shows dialog and returns resolution', (WidgetTester tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late BuildContext testContext;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  testContext = context;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      final notifier = container.read(conflictProvider.notifier);
      
      final future = notifier.resolveConflict(
        fileName: 'test.txt',
        destinationPath: '/dest',
        isFolder: false,
        context: testContext,
      );

      await tester.pumpAndSettle();

      // Dialog should be showing
      expect(find.byType(ConflictDialog), findsOneWidget);

      Navigator.of(testContext).pop(ConflictResult(ConflictResolution.replace, false));
      
      await tester.pumpAndSettle();

      final result = await future;
      expect(result, ConflictResolution.replace);
      
      // State should be empty
      expect(container.read(conflictProvider), isEmpty);
    });

    testWidgets('resolveConflict uses global resolution if applyToAll is true', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer();
      addTearDown(container.dispose);

      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      late BuildContext testContext;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  testContext = context;
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );

      final notifier = container.read(conflictProvider.notifier);
      
      final future1 = notifier.resolveConflict(
        fileName: 'test1.txt',
        destinationPath: '/dest',
        isFolder: false,
        context: testContext,
      );

      await tester.pumpAndSettle();

      Navigator.of(testContext).pop(ConflictResult(ConflictResolution.skip, true));
      await tester.pumpAndSettle();
      
      final result1 = await future1;
      expect(result1, ConflictResolution.skip);

      // Second conflict should auto-resolve without dialog
      final future2 = notifier.resolveConflict(
        fileName: 'test2.txt',
        destinationPath: '/dest',
        isFolder: false,
        context: testContext,
      );

      // Don't need to pump because it completes synchronously due to global resolution
      final result2 = await future2;
      expect(result2, ConflictResolution.skip);

      // Verify no dialog is shown
      await tester.pumpAndSettle();
      expect(find.byType(ConflictDialog), findsNothing);

      // Clear global resolution
      notifier.clearGlobalResolution();
      
      final future3 = notifier.resolveConflict(
        fileName: 'test3.txt',
        destinationPath: '/dest',
        isFolder: false,
        context: testContext,
      );

      await tester.pumpAndSettle();
      expect(find.byType(ConflictDialog), findsOneWidget);
      
      Navigator.of(testContext).pop();
      await tester.pumpAndSettle();
      
      // Defaults to skip if null result
      final result3 = await future3;
      expect(result3, ConflictResolution.skip);
    });
  });
}
