import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'dart:ui';
import 'package:onyxcore/features/downloader/presentation/widgets/downloads_panel.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';

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

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      final window = TestWidgetsFlutterBinding.instance.window;
      window.physicalSizeTestValue = const Size(1600, 1000);
      window.devicePixelRatioTestValue = 1.0;
      MockBinaryHelper.setupMockBinaries();
    });

    tearDownAll(() {
      final window = TestWidgetsFlutterBinding.instance.window;
      window.clearPhysicalSizeTestValue();
      window.clearDevicePixelRatioTestValue();
    });

    setUp(() {
      EngineRegistry.clearAllEnginesForTesting();
      EngineRegistry.register(MockYtDlpEngine());
      container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(() => MockSettingsNotifier()),
          currentPathProvider.overrideWith(() => MockCurrentPathNotifier()),
          downloadTaskProvider.overrideWith(() => MockDownloadTaskNotifier()),
        ],
      );
    });

    testWidgets('W-DL-PRE-01: Open single preview overlay and close it', (tester) async {
      await tester.pumpWidget(createTestWidget(container));
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

      for (int i = 0; i < 5; i++) {
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
  });
}
