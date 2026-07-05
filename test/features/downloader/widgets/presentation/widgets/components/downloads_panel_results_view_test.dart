import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/downloads_panel.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

import '../mock_providers.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  tearDownAll(() {
    // Removed MockBinaryHelper
  });

  Widget createPanelTestWidget(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: DownloadsPanel(),
        ),
      ),
    );
  }

  group('DownloadsPanelResultsView Tests', () {
    late AppDatabase appDb;

    setUp(() {
      EngineRegistry.clearAllEnginesForTesting();
      EngineRegistry.register(MockYtDlpEngine());
      appDb = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    });

    tearDown(() async {
      // await appDb.close();
    });

    testWidgets('Renders empty state initially, checking Import / Export buttons', (tester) async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(MockSettingsNotifier.new),
          currentPathProvider.overrideWith(MockCurrentPathNotifier.new),
          downloadTaskProvider.overrideWith(MockDownloadTaskNotifier.new),
          databaseProvider.overrideWithValue(appDb),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createPanelTestWidget(container));
      await tester.pump(const Duration(seconds: 1));

      // Import should be present
      expect(find.text('Import'), findsOneWidget);
      // Export should be present but ignored/disabled (Opacity 0.4 handles visual, IgnorePointer handles taps)
      expect(find.text('Export'), findsOneWidget);

      // Download All should be present but disabled
      expect(find.text('Download All'), findsOneWidget);
    });

    testWidgets('Renders results view and sort dropdown after fetching items', (tester) async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(MockSettingsNotifier.new),
          currentPathProvider.overrideWith(MockCurrentPathNotifier.new),
          downloadTaskProvider.overrideWith(MockDownloadTaskNotifier.new),
          databaseProvider.overrideWithValue(appDb),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createPanelTestWidget(container));
      await tester.pump(const Duration(seconds: 1));

      // Should initially render empty box if _parsedItems is empty

      final urlField = find.byType(TextField);
      await tester.enterText(urlField, 'https://test.com/some_url');
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Fetch'));
      
      // Wait for fetch to complete instead of pumpAndSettle
      var pumpCount = 0;
      while (find.byIcon(Icons.broken_image).evaluate().isEmpty && pumpCount < 50) {
        await tester.pump(const Duration(milliseconds: 100));
        pumpCount++;
      }
      await tester.pump(const Duration(seconds: 1));

      // Sort dropdown is visible, "Added" is default
      expect(find.text('Added'), findsOneWidget);

      // Open the Sort dropdown
      await tester.tap(find.text('Added'));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Size'), findsWidgets);

      // Should see sort options
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Size'), findsWidgets);

      // Current folder toggle in statistics strip should be present
      expect(find.text('Current Folder'), findsOneWidget);
      
      // Tap Clear to clear the list
      expect(find.text('Clear'), findsOneWidget);
      await tester.tap(find.text('Clear'), warnIfMissed: false);
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
