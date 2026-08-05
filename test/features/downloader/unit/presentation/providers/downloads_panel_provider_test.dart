// ignore_for_file: cascade_invocations
import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUpAll(() {
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  setUp(() {
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.delete(db.settings).go();
  });

  tearDownAll(() async {
    await db.close();
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

      test('U-DL-PNL-05: isDownloadsPanelFocusedProvider defaults to false', () {
        expect(container.read(isDownloadsPanelFocusedProvider), isFalse);
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
      test('U-DL-PNL-09: loads width from AppDatabase', () async {
        await db.delete(db.settings).go();
        await db.into(db.settings).insertOnConflictUpdate(
          const SettingsCompanion(key: Value('side_panel_width_pixels'), value: Value('400.0')),
        );
        final customContainer = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
        );
        
        final widthAsync = await customContainer.read(downloadsPanelWidthProvider.future);
        expect(widthAsync, 400.0);
        customContainer.dispose();
      });

      test('U-DL-PNL-10: defaults to 320.0 if database key missing', () async {
        await db.delete(db.settings).go();
        final customContainer = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
          ],
        );
        
        final widthAsync = await customContainer.read(downloadsPanelWidthProvider.future);
        expect(widthAsync, 320.0);
        customContainer.dispose();
      });

      test('U-DL-PNL-11: updates state and persists to database', () async {
        await db.delete(db.settings).go();
        await container.read(downloadsPanelWidthProvider.future);
        final notifier = container.read(downloadsPanelWidthProvider.notifier);
        await notifier.updateWidth(500);
        
        expect(container.read(downloadsPanelWidthProvider).value, 500.0);
        
        final row = await (db.select(db.settings)..where((t) => t.key.equals('side_panel_width_pixels'))).getSingleOrNull();
        expect(row?.value, '500.0');
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

      test('U-DL-PNL-14: switchList changes active state bucket', () {
        final cache = DownloadsListCache();
        cache.switchList('/a');
        cache.importedListName = 'List A';
        
        cache.switchList('/b');
        expect(cache.importedListName, isNull); // Bucket B is empty
      });

      test('U-DL-PNL-15: Lists are fully isolated from each other', () {
        final cache = DownloadsListCache();
        cache.switchList('/a');
        cache.parsedItems = [];
        
        cache.switchList('/b');
        expect(cache.parsedItems, isNull);
        
        cache.switchList('/a');
        expect(cache.parsedItems, isNotNull);
      });

      test('U-DL-PNL-16: switchList with null defaults to default', () {
        final cache = DownloadsListCache();
        cache.switchList('default');
        cache.importedListName = 'Default';
        
        cache.switchList(null);
        expect(cache.importedListName, 'Default');
      });

      test('U-DL-PNL-17: switchList triggers notifyListeners', () {
        final cache = DownloadsListCache();
        var notifyCount = 0;
        cache.addListener(() => notifyCount++);
        
        cache.switchList('/new');
        expect(notifyCount, 1);
      });

      test('U-DL-PNL-18: hasCache returns false for a path never touched', () {
        final cache = DownloadsListCache();
        expect(cache.hasCache('/untouched'), isFalse);
      });

      test('U-DL-PNL-19: hasCache returns true after any state is set for that path', () {
        final cache = DownloadsListCache();
        cache.switchList('/touched');
        cache.parsedItems = [];
        expect(cache.hasCache('/touched'), isTrue);
      });

      test('U-DL-PNL-20: isCacheChanged returns false for untouched path', () {
        final cache = DownloadsListCache();
        expect(cache.isCacheChanged('/untouched'), isFalse);
      });

      test('U-DL-PNL-21: isCacheChanged returns correct per-path changed flag', () {
        final cache = DownloadsListCache();
        cache.switchList('/a');
        cache.isListChanged = true;
        cache.switchList('/b');
        cache.isListChanged = false;
        
        expect(cache.isCacheChanged('/a'), isTrue);
        expect(cache.isCacheChanged('/b'), isFalse);
      });

      test('U-DL-PNL-22: invalidateCache removes a list state', () {
        final cache = DownloadsListCache();
        cache.switchList('/a');
        cache.parsedItems = [];
        cache.invalidateCache('/a');
        expect(cache.hasCache('/a'), isFalse);
      });

      test('U-DL-PNL-23: invalidateCache on active path resets active to default', () {
        final cache = DownloadsListCache();
        cache.switchList('default');
        cache.importedListName = 'Default';
        
        cache.switchList('/a');
        cache.invalidateCache('/a');
        
        expect(cache.importedListName, 'Default');
      });

      test('U-DL-PNL-24: invalidateCache triggers notifyListeners only when active', () {
        final cache = DownloadsListCache();
        cache.switchList('default');
        cache.switchList('/a');
        cache.switchList('default');
        
        var notifyCount = 0;
        cache.addListener(() => notifyCount++);
        
        cache.invalidateCache('/a'); // not active, shouldn't notify
        expect(notifyCount, 0);
        
        cache.switchList('/b');
        notifyCount = 0;
        cache.invalidateCache('/b'); // active, should notify
        expect(notifyCount, 1);
      });

      test('U-DL-PNL-25: Invalidating a non-active path does not affect active state', () {
        final cache = DownloadsListCache();
        cache.switchList('/a');
        cache.importedListName = 'A';
        cache.switchList('/b');
        cache.importedListName = 'B';
        
        cache.invalidateCache('/a');
        expect(cache.importedListName, 'B');
      });

      test('U-DL-PNL-26: notify() triggers ChangeNotifier listeners', () {
        final cache = DownloadsListCache();
        var notifyCount = 0;
        cache.addListener(() => notifyCount++);
        
        cache.notify();
        expect(notifyCount, 1);
      });

      test('U-DL-PNL-27: clear() resets only active list, other lists preserved', () {
        final cache = DownloadsListCache();
        cache.switchList('/a');
        cache.importedListName = 'A';
        cache.switchList('/b');
        cache.importedListName = 'B';
        
        cache.clear(); // clears B
        
        cache.switchList('/a');
        expect(cache.importedListName, 'A');
      });

      test('U-DL-PNL-28: configs getter always reflects active list config map', () {
        final cache = DownloadsListCache();
        cache.switchList('/a');
        cache.configs[0] = DownloadConfig();
        
        cache.switchList('/b');
        expect(cache.configs, isEmpty);
        
        cache.switchList('/a');
        expect(cache.configs, isNotEmpty);
      });

      test('U-DL-PNL-29: Setting parsedItems, importedListName, importedListPath, isListChanged triggers notifyListeners', () {
        final cache = DownloadsListCache();
        var notifyCount = 0;
        cache.addListener(() => notifyCount++);
        
        cache.parsedItems = [];
        expect(notifyCount, 1);
        
        cache.importedListName = 'Test';
        expect(notifyCount, 2);
        
        cache.importedListPath = '/test';
        expect(notifyCount, 3);
        
        cache.isListChanged = true;
        expect(notifyCount, 4);
      });

      test('U-DL-PNL-30: customLists returns list of custom list names and paths', () {
        final cache = DownloadsListCache();
        cache.switchList('default');
        
        cache.switchList('/a');
        cache.importedListPath = '/a';
        cache.importedListName = 'List A';
        
        cache.switchList('/b');
        cache.importedListPath = '/b';
        cache.importedListName = 'List B';
        
        cache.switchList('default');
        
        final lists = cache.customLists;
        expect(lists.length, 2);
        
        // Assert sorting or content
        final hasA = lists.any((l) => l.path == '/a' && l.name == 'List A');
        final hasB = lists.any((l) => l.path == '/b' && l.name == 'List B');
        
        expect(hasA, isTrue);
        expect(hasB, isTrue);
      });
    });
  });
}
