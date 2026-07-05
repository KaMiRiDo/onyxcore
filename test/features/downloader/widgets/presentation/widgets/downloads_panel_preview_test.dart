import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/downloads_panel.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

import 'mock_providers.dart';

void main() {
  Widget createTestWidget(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: const DownloadsPanel(),
        ),
      ),
    );
  }

  group('Downloads Panel Preview & Results View Tests', () {
    late ProviderContainer container;
    late AppDatabase appDb;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.physicalSize = const Size(1600, 1000);
      view.devicePixelRatio = 1.0;
    });

    tearDownAll(() {
      final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    setUp(() {
      EngineRegistry.clearAllEnginesForTesting();
      EngineRegistry.register(MockYtDlpEngine());
      appDb = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
      container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(MockSettingsNotifier.new),
          currentPathProvider.overrideWith(MockCurrentPathNotifier.new),
          downloadTaskProvider.overrideWith(MockDownloadTaskNotifier.new),
          databaseProvider.overrideWithValue(appDb),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      // await appDb.close();
    });

    testWidgets('W-DL-PRE-01: Open single preview overlay and close it', (tester) async {
      await tester.pumpWidget(createTestWidget(container));
      while (container.read(settingsProvider).value == null) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(seconds: 1));

      // 1. Enter URL and fetch
      final urlField = find.byType(TextField);
      await tester.tap(urlField);
      await tester.enterText(urlField, 'https://test.com/mock');
      await tester.pump();

      // Wait for settings
      while (container.read(settingsProvider).value == null) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final fetchButton = find.widgetWithText(ElevatedButton, 'Fetch');
      await tester.tap(fetchButton);
      await tester.pump();

      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // 2. We should see "Mock Video Content" in the tile
      expect(find.textContaining('Mock Video Content'), findsWidgets);

      // 3. Tap on the tile image to open preview overlay
      // The image is loaded from FallbackThumb in our mock since thumbnail is not valid or empty
      final fallbackThumb = find.byIcon(Icons.broken_image);
      expect(fallbackThumb, findsWidgets);

      await tester.tap(fallbackThumb.first);
      await tester.pump(const Duration(milliseconds: 500));

      // 4. Overlay should be visible
      // It has a BackdropFilter and an IconButton with Icons.close
      final closeButton = find.descendant(
        of: find.byType(BackdropFilter),
        matching: find.byIcon(Icons.close)
      );
      expect(closeButton, findsOneWidget);

      // We should see the title in the overlay
      expect(find.descendant(
        of: find.byType(BackdropFilter),
        matching: find.text('Mock Video Content')
      ), findsWidgets);

      // 5. Click the close button
      await tester.tap(closeButton);
      await tester.pump(const Duration(milliseconds: 500));

      // Overlay should be gone
      expect(find.descendant(
        of: find.byType(BackdropFilter),
        matching: find.byIcon(Icons.close)
      ), findsNothing);
    });

    testWidgets('W-DL-PRE-02: Open group preview overlay and close it', (tester) async {
      EngineRegistry.clearAllEnginesForTesting();
      EngineRegistry.register(MockGroupedEngine());
      
      await tester.pumpWidget(createTestWidget(container));
      while (container.read(settingsProvider).value == null) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(seconds: 1));

      final urlField = find.byType(TextField);
      await tester.enterText(urlField, 'https://instagram.com/p/group123/');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Fetch'));
      
      var pumpCount = 0;
      while (find.byIcon(Icons.broken_image).evaluate().isEmpty && pumpCount < 50) {
        await tester.pump(const Duration(milliseconds: 100));
        pumpCount++;
      }

      // Open group preview
      final fallbackThumb = find.byIcon(Icons.broken_image);
      await tester.tap(fallbackThumb.first);
      await tester.pump(const Duration(milliseconds: 500));

      final closeButton = find.descendant(of: find.byType(BackdropFilter), matching: find.byIcon(Icons.close));
      expect(closeButton, findsOneWidget);

      // Verify first grouped item info is visible
      expect(find.textContaining('Grouped Post'), findsWidgets);
      // There's a 1/2 indicator since it's a gallery
      expect(find.text('1 / 2'), findsOneWidget);

      // Close it
      await tester.tap(closeButton);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.descendant(of: find.byType(BackdropFilter), matching: find.byIcon(Icons.close)), findsNothing);
    });

    testWidgets('W-DL-PRE-03: Carousel navigation with Arrow keys in Group overlay', (tester) async {
      EngineRegistry.clearAllEnginesForTesting();
      EngineRegistry.register(MockGroupedEngine());
      
      await tester.pumpWidget(createTestWidget(container));
      while (container.read(settingsProvider).value == null) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(seconds: 1));

      final urlField = find.byType(TextField);
      await tester.enterText(urlField, 'https://instagram.com/p/group123/');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Fetch'));
      
      // Wait for fetch to complete and tile to appear
      var pumpCount = 0;
      while (find.byIcon(Icons.broken_image).evaluate().isEmpty && pumpCount < 50) {
        await tester.pump(const Duration(milliseconds: 100));
        pumpCount++;
      }

      // Open group preview
      final fallbackThumb = find.byIcon(Icons.broken_image);
      await tester.tap(fallbackThumb.first);
      await tester.pump(const Duration(milliseconds: 500));

      // Initially, index 1 / 2 is shown
      expect(find.text('1 / 2'), findsOneWidget);

      // Dispatch ArrowRight
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 500));

      // Now index 2 / 2 should be shown
      expect(find.text('2 / 2'), findsOneWidget);

      // Dispatch ArrowRight again (should not go beyond 2)
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('2 / 2'), findsOneWidget);

      // Dispatch ArrowLeft
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('W-DL-PRE-04: Background tap closes overlay', (tester) async {
      EngineRegistry.clearAllEnginesForTesting();
      EngineRegistry.register(MockYtDlpEngine());

      await tester.pumpWidget(createTestWidget(container));
      while (container.read(settingsProvider).value == null) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(seconds: 1));

      final urlField = find.byType(TextField);
      await tester.enterText(urlField, 'https://youtube.com/watch?v=123');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Fetch'));
      
      // Wait for fetch to complete and tile to appear
      var pumpCount = 0;
      while (find.byIcon(Icons.broken_image).evaluate().isEmpty && pumpCount < 50) {
        await tester.pump(const Duration(milliseconds: 100));
        pumpCount++;
      }

      // Open single preview
      final fallbackThumb = find.byIcon(Icons.broken_image);
      await tester.tap(fallbackThumb.first);
      await tester.pump(const Duration(milliseconds: 500));

      // Close button should be visible (overlay is open)
      expect(find.descendant(of: find.byType(BackdropFilter), matching: find.byIcon(Icons.close)), findsOneWidget);

      // Tap the top-left corner of the screen (background)
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 500));

      // Close button should be gone (overlay closed)
      expect(find.descendant(of: find.byType(BackdropFilter), matching: find.byIcon(Icons.close)), findsNothing);
    });
  });
}
