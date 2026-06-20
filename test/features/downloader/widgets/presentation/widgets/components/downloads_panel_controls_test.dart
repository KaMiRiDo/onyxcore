import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/downloads_panel.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';

import '../mock_providers.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Removed MockBinaryHelper
  });

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

  group('DownloadsPanelControls Tests', () {
    setUp(() {
      EngineRegistry.clearAllEnginesForTesting();
      EngineRegistry.register(MockYtDlpEngine());
      EngineRegistry.register(MockGroupedEngine());
    });

    testWidgets('Renders engine dropdown and handles selection', (tester) async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(() => MockSettingsNotifier()),
          currentPathProvider.overrideWith(() => MockCurrentPathNotifier()),
          downloadTaskProvider.overrideWith(() => MockDownloadTaskNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createPanelTestWidget(container));
      while (container.read(settingsProvider).value == null) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(seconds: 1));

      // Find the Auto Select text which is the default in the engine dropdown
      expect(find.text('Auto Select'), findsOneWidget);

      // Tap the dropdown to open it
      await tester.tap(find.text('Auto Select'));
      await tester.pump(const Duration(seconds: 1));

      // Ensure mock engines are shown
      expect(find.text('Mock yt-dlp'), findsOneWidget);
      expect(find.text('Mock Grouped'), findsOneWidget);

      // Select 'Mock yt-dlp' by invoking onSelected on the PopupMenuButton
      final popupFinder = find.byType(PopupMenuButton<String>);
      final popupWidget = tester.widget<PopupMenuButton<String>>(popupFinder.first);
      popupWidget.onSelected!('yt-dlp');
      await tester.pump(const Duration(seconds: 1));

      // Now the dropdown should display 'Mock yt-dlp' (it replaces the 'Auto Select' text)
      expect(find.text('Mock yt-dlp'), findsWidgets);
    });

    testWidgets('Renders group filter dropdown when applicable', (tester) async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(() => MockSettingsNotifier()),
          currentPathProvider.overrideWith(() => MockCurrentPathNotifier()),
          downloadTaskProvider.overrideWith(() => MockDownloadTaskNotifier()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(createPanelTestWidget(container));
      while (container.read(settingsProvider).value == null) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(seconds: 1));

      // To render the group filter dropdown, we need _parsedItems to contain a MediaGroup
      // with items that are a mix of videos and images, or isProfile = true.
      // Wait, we can't easily inject _parsedItems without interacting with the UI.
      // We can enter a URL and hit Fetch.
      
      // Tap the auto select dropdown, select Mock Grouped BEFORE enterText
      final popup = tester.widget<PopupMenuButton<String>>(find.byType(PopupMenuButton<String>).first);
      popup.onSelected?.call('mock-grouped');
      await tester.pump(const Duration(seconds: 1));

      final urlField = find.byType(TextField);
      await tester.enterText(urlField, 'https://instagram.com/p/mock_grouped');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(seconds: 1));
      
      // Tap Fetch
      await tester.tap(find.widgetWithText(ElevatedButton, 'Fetch'));
      int pumpCount = 0;
      while (find.textContaining('Grouped Post').evaluate().isEmpty && pumpCount < 50) {
        await tester.pump(const Duration(milliseconds: 100));
        pumpCount++;
      }
      await tester.pump(const Duration(seconds: 1));

      // MockGroupedEngine now returns a mix of video and image, so the filter dropdown
      // is enabled. It should show 'All' initially.
      debugDumpApp();
      expect(find.text('All'), findsOneWidget);

      // Call onSelected directly to bypass overlay tap issues
      final groupPopup = tester.widget<PopupMenuButton<GroupDownloadType>>(find.byType(PopupMenuButton<GroupDownloadType>).first);
      groupPopup.onSelected?.call(GroupDownloadType.images);
      await tester.pump(const Duration(seconds: 1));

      // Now the dropdown should display 'Images Only'
      expect(find.text('Images Only'), findsOneWidget);
    });
  });
}
