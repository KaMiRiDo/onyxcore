// ignore_for_file: cascade_invocations
import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_history_view.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/downloads_panel.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

import 'mock_providers.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1600, 1000);
    view.devicePixelRatio = 1.0;

    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed')) {
        return;
      }
      FlutterError.presentError(details);
    };
  });

  tearDownAll(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
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

  group('Downloads Panel Widgets Unit Tests', () {
    late AppDatabase appDb;

    setUp(() {
      appDb = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    });

    // ── 1. Top-Level Panel & Navigation ──

    testWidgets('W-DL-PNL-01: Navigate based on downloadsPanelViewProvider', (tester) async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(MockSettingsNotifier.new),
          currentPathProvider.overrideWith(MockCurrentPathNotifier.new),
          downloadTaskProvider.overrideWith(MockDownloadTaskNotifier.new),
          databaseProvider.overrideWithValue(appDb),
        ],
      );
      addTearDown(container.dispose);
      container.read(downloadsPanelViewProvider.notifier).state = DownloadsPanelView.tasks;

      await tester.pumpWidget(createPanelTestWidget(container));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Download Manager'), findsOneWidget);
    });

    testWidgets('W-DL-PNL-02: Navigate to History View', (tester) async {
      final container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(MockSettingsNotifier.new),
          currentPathProvider.overrideWith(MockCurrentPathNotifier.new),
          downloadTaskProvider.overrideWith(MockDownloadTaskNotifier.new),
          databaseProvider.overrideWithValue(appDb),
        ],
      );
      addTearDown(container.dispose);
      container.read(downloadsPanelViewProvider.notifier).state = DownloadsPanelView.history;

      await tester.pumpWidget(createPanelTestWidget(container));
      await tester.pump(const Duration(milliseconds: 500));

      // Ensure History View is rendered
      expect(find.byType(DownloadHistoryView), findsOneWidget);
    });
  });
}
