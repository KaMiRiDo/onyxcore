import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:io';

import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';

void main() {
  late ProviderContainer container;
  late Box<dynamic> appSettingsBox;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('hive_panel_test');
    Hive.init(tempDir.path);
    appSettingsBox = await Hive.openBox('ui_settings');
  });

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  tearDownAll(() async {
    await appSettingsBox.close();
    await Hive.deleteBoxFromDisk('ui_settings');
  });

  group('DownloadsPanelProvider Unit Tests', () {
    group('Simple State Providers', () {
      test('U-DL-PNL-01: downloadsPanelOpenProvider defaults to false', () {
        expect(container.read(downloadsPanelOpenProvider), isFalse);
      });

      test('U-DL-PNL-02: downloadsPanelViewProvider defaults to tasks', () {
        expect(container.read(downloadsPanelViewProvider), DownloadsPanelView.tasks);
      });

      test('U-DL-PNL-03: selectedDownloadHistoryIdProvider defaults to null', () {
        expect(container.read(selectedDownloadHistoryIdProvider), isNull);
      });

      test('U-DL-PNL-04: isDownloadInputFocusedProvider defaults to false', () {
        expect(container.read(isDownloadInputFocusedProvider), isFalse);
      });

      test('U-DL-PNL-05: isDownloadsPanelFocusedProvider defaults to false', () {
        expect(container.read(isDownloadsPanelFocusedProvider), isFalse);
      });

      test('U-DL-PNL-06: downloadUrlFocusRequestProvider defaults to 0', () {
        expect(container.read(downloadUrlFocusRequestProvider), 0);
      });

      test('U-DL-PNL-07: isDownloadsPanelDraggingProvider defaults to false', () {
        expect(container.read(isDownloadsPanelDraggingProvider), isFalse);
      });
    });

    group('DownloadsPanelView Enum', () {
      test('U-DL-PNL-08: contains exactly 3 values', () {
        expect(DownloadsPanelView.values.length, 3);
        expect(DownloadsPanelView.values, contains(DownloadsPanelView.tasks));
        expect(DownloadsPanelView.values, contains(DownloadsPanelView.history));
        expect(DownloadsPanelView.values, contains(DownloadsPanelView.historyDetail));
      });
    });

    group('DownloadsPanelWidthNotifier', () {
      test('U-DL-PNL-09: loads width from Hive box', () async {
        await appSettingsBox.put('side_panel_width_pixels', 400.0);
        final customContainer = ProviderContainer();
        
        // Read the provider to initialize it
        final width = customContainer.read(downloadsPanelWidthProvider);
        expect(width, 400.0);
        customContainer.dispose();
      });

      test('U-DL-PNL-10: defaults to 320.0 if Hive key missing', () async {
        await appSettingsBox.delete('side_panel_width_pixels');
        final customContainer = ProviderContainer();
        
        final width = customContainer.read(downloadsPanelWidthProvider);
        expect(width, 320.0);
        customContainer.dispose();
      });

      test('U-DL-PNL-11: updates state and persists to Hive', () async {
        await appSettingsBox.delete('side_panel_width_pixels');
        
        final notifier = container.read(downloadsPanelWidthProvider.notifier);
        notifier.updateWidth(500.0);
        
        expect(container.read(downloadsPanelWidthProvider), 500.0);
        expect(appSettingsBox.get('side_panel_width_pixels'), 500.0);
      });
    });

    group('DownloadsListCache', () {
      test('U-DL-PNL-12: initializes with empty/null fields', () {
        final cache = DownloadsListCache();
        expect(cache.parsedItems, isNull);
        expect(cache.configs, isEmpty);
        expect(cache.importedListName, isNull);
        expect(cache.importedListPath, isNull);
        expect(cache.isListChanged, isFalse);
      });

      test('U-DL-PNL-13: clear resets all fields to initial state', () {
        final cache = DownloadsListCache();
        cache.parsedItems = []; // mock data
        cache.configs[0] = DownloadConfig(); // mock data
        cache.importedListName = 'List';
        cache.importedListPath = '/path/to/list';
        cache.isListChanged = true;

        cache.clear();

        expect(cache.parsedItems, isNull);
        expect(cache.configs, isEmpty);
        expect(cache.importedListName, isNull);
        expect(cache.importedListPath, isNull);
        expect(cache.isListChanged, isFalse);
      });
    });
  });
}
