import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';
import 'package:onyxcore/features/downloader/services/download_history_database.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_history_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';

void main() {
  late ProviderContainer container;
  late Directory testDir;

  setUpAll(() {
    testDir = Directory('${Directory.systemTemp.path}/onyxcore_test');
    if (!testDir.existsSync()) {
      testDir.createSync(recursive: true);
    }
  });

  setUp(() {
    // Clear the test database file before each test
    final dbFile = File('${testDir.path}/download_history.sqlite');
    if (dbFile.existsSync()) {
      dbFile.deleteSync();
    }
    final db = DownloadHistoryDatabase();
    db.init();
    db.clearAll();
    db.dispose();
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  tearDownAll(() {
    if (testDir.existsSync()) {
      testDir.deleteSync(recursive: true);
    }
  });

  group('DownloadHistoryProvider Unit Tests', () {
    // ═══════════════════════════════════════════════════════════════
    // 1. DownloadHistoryEntry Entity
    // ═══════════════════════════════════════════════════════════════
    group('1. DownloadHistoryEntry Entity', () {
      test('U-DL-HST-01: creates with all required fields', () {
        final now = DateTime.now();
        final entry = DownloadHistoryEntry(
          id: '1',
          title: 'T',
          statusName: 'completed',
          downloadType: 'video',
          errorMessage: 'err',
          url: 'U',
          destination: 'D',
          logs: ['log'],
          createdAt: now,
          completedAt: now,
        );

        expect(entry.id, '1');
        expect(entry.title, 'T');
        expect(entry.statusName, 'completed');
        expect(entry.downloadType, 'video');
        expect(entry.errorMessage, 'err');
        expect(entry.url, 'U');
        expect(entry.destination, 'D');
        expect(entry.logs, ['log']);
        expect(entry.createdAt, now);
        expect(entry.completedAt, now);
      });

      test('U-DL-HST-02: uses default values for optional fields', () {
        final now = DateTime.now();
        final entry = DownloadHistoryEntry(
          id: '1',
          title: 'T',
          statusName: 'completed',
          url: 'U',
          destination: 'D',
          createdAt: now,
        );

        expect(entry.downloadType, 'generic');
        expect(entry.logs, isEmpty);
        expect(entry.completedAt, isNull);
        expect(entry.errorMessage, isNull);
      });

      test('U-DL-HST-03: maps all DownloadTask fields correctly', () {
        final now = DateTime.now();
        final task = DownloadTask(
          id: '1',
          title: 'T',
          status: DownloadStatus.error,
          downloadType: 'audio',
          error: 'Oops',
          url: 'U',
          destination: 'D',
          logs: ['A', 'B'],
          createdAt: now,
          completedAt: now.add(const Duration(minutes: 1)),
        );

        final entry = DownloadHistoryEntry.fromTask(task);
        expect(entry.id, '1');
        expect(entry.title, 'T');
        expect(entry.statusName, 'error');
        expect(entry.downloadType, 'audio');
        expect(entry.errorMessage, 'Oops');
        expect(entry.url, 'U');
        expect(entry.destination, 'D');
        expect(entry.logs, ['A', 'B']);
        expect(entry.createdAt, now);
        expect(entry.completedAt, task.completedAt);
      });

      test('U-DL-HST-04: parses JSON with all fields', () {
        final now = DateTime.now().toIso8601String();
        final json = {
          'id': '1',
          'title': 'T',
          'statusName': 'completed',
          'downloadType': 'audio',
          'errorMessage': 'err',
          'url': 'U',
          'destination': 'D',
          'logs': ['A'],
          'createdAt': now,
          'completedAt': now,
        };

        final entry = DownloadHistoryEntry.fromJson(json);
        expect(entry.id, '1');
        expect(entry.title, 'T');
        expect(entry.statusName, 'completed');
        expect(entry.downloadType, 'audio');
        expect(entry.errorMessage, 'err');
        expect(entry.url, 'U');
        expect(entry.destination, 'D');
        expect(entry.logs, ['A']);
        expect(entry.createdAt.toIso8601String(), now);
        expect(entry.completedAt?.toIso8601String(), now);
      });

      test('U-DL-HST-05: handles missing/null fields gracefully', () {
        final json = {'id': '1'};
        final entry = DownloadHistoryEntry.fromJson(json);

        expect(entry.id, '1');
        expect(entry.title, 'Untitled Download');
        expect(entry.statusName, 'completed');
        expect(entry.url, '');
        expect(entry.logs, isEmpty);
        expect(entry.createdAt.year, DateTime.now().year);
      });

      test('U-DL-HST-06: serializes all fields to JSON', () {
        final now = DateTime.now();
        final entry = DownloadHistoryEntry(
          id: '1',
          title: 'T',
          statusName: 'completed',
          downloadType: 'audio',
          errorMessage: 'err',
          url: 'U',
          destination: 'D',
          logs: ['A'],
          createdAt: now,
          completedAt: now,
        );

        final json = entry.toJson();
        expect(json['id'], '1');
        expect(json['title'], 'T');
        expect(json['statusName'], 'completed');
        expect(json['downloadType'], 'audio');
        expect(json['errorMessage'], 'err');
        expect(json['url'], 'U');
        expect(json['destination'], 'D');
        expect(json['logs'], ['A']);
        expect(json['createdAt'], now.toIso8601String());
        expect(json['completedAt'], now.toIso8601String());
      });

      test('U-DL-HST-07: round-trip serialization', () {
        final now = DateTime.now();
        final original = DownloadHistoryEntry(
          id: '1',
          title: 'T',
          statusName: 'completed',
          url: 'U',
          destination: 'D',
          createdAt: now,
        );

        final result = DownloadHistoryEntry.fromJson(original.toJson());
        expect(result.id, original.id);
        expect(result.title, original.title);
        expect(result.createdAt, original.createdAt);
      });

      test('U-DL-HST-08: returns correct duration when completedAt is set', () {
        final now = DateTime.now();
        final entry = DownloadHistoryEntry(
          id: '1',
          title: 'T',
          statusName: 'completed',
          url: 'U',
          destination: 'D',
          createdAt: now,
          completedAt: now.add(const Duration(minutes: 5)),
        );
        expect(entry.duration, const Duration(minutes: 5));
      });

      test('U-DL-HST-09: returns null duration when completedAt is null', () {
        final entry = DownloadHistoryEntry(
          id: '1',
          title: 'T',
          statusName: 'completed',
          url: 'U',
          destination: 'D',
          createdAt: DateTime.now(),
        );
        expect(entry.duration, isNull);
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 2. DownloadHistoryNotifier — Pagination
    // ═══════════════════════════════════════════════════════════════
    group('2. DownloadHistoryNotifier — Pagination', () {
      void seedDatabase(int count) {
        final notifier = container.read(downloadHistoryProvider.notifier);
        for (var i = 0; i < count; i++) {
          notifier.addEntry(DownloadTask(
            id: 'id_$i',
            title: 'T_$i',
            url: 'U',
            destination: 'D',
            createdAt: DateTime.now().subtract(Duration(seconds: count - i)),
          ));
        }
      }

      test('U-DL-HST-10: loads initial page of 50 results', () {
        seedDatabase(100);
        // We re-initialize the container to trigger build()
        final newContainer = ProviderContainer();
        addTearDown(newContainer.dispose);
        
        final state = newContainer.read(downloadHistoryProvider);
        final notifier = newContainer.read(downloadHistoryProvider.notifier);
        
        expect(state.length, 50);
        expect(notifier.hasMore, isTrue);
      });

      test('U-DL-HST-11: loads subsequent page', () {
        seedDatabase(60);
        final newContainer = ProviderContainer();
        addTearDown(newContainer.dispose);
        
        final notifier = newContainer.read(downloadHistoryProvider.notifier);
        expect(newContainer.read(downloadHistoryProvider).length, 50);
        
        notifier.loadMore();
        expect(newContainer.read(downloadHistoryProvider).length, 60);
        expect(notifier.hasMore, isFalse);
      });

      test('U-DL-HST-12: no-op when no more entries', () {
        seedDatabase(30);
        final newContainer = ProviderContainer();
        addTearDown(newContainer.dispose);
        
        final notifier = newContainer.read(downloadHistoryProvider.notifier);
        expect(newContainer.read(downloadHistoryProvider).length, 30);
        
        notifier.loadMore(); // should do nothing
        expect(newContainer.read(downloadHistoryProvider).length, 30);
      });

      test('U-DL-HST-13: returns false when all entries loaded', () {
        seedDatabase(30);
        final newContainer = ProviderContainer();
        addTearDown(newContainer.dispose);
        
        final notifier = newContainer.read(downloadHistoryProvider.notifier);
        expect(notifier.hasMore, isFalse);
      });

      test('U-DL-HST-14: returns total count from DB', () {
        seedDatabase(150);
        final newContainer = ProviderContainer();
        addTearDown(newContainer.dispose);
        
        final notifier = newContainer.read(downloadHistoryProvider.notifier);
        expect(notifier.totalEntries, 150);
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 3. DownloadHistoryNotifier — Mutations
    // ═══════════════════════════════════════════════════════════════
    group('3. DownloadHistoryNotifier — Mutations', () {
      test('U-DL-HST-15: prepends new entry to state', () {
        final notifier = container.read(downloadHistoryProvider.notifier);
        notifier.addEntry(DownloadTask(id: 'A', title: 'T', url: 'U', destination: 'D', createdAt: DateTime.now()));
        
        final state = container.read(downloadHistoryProvider);
        expect(state.length, 1);
        expect(state[0].id, 'A');
        
        notifier.addEntry(DownloadTask(id: 'B', title: 'T', url: 'U', destination: 'D', createdAt: DateTime.now()));
        final state2 = container.read(downloadHistoryProvider);
        expect(state2.length, 2);
        expect(state2[0].id, 'B'); // B should be prepended
      });

      test('U-DL-HST-16: inserts into DB', () {
        final notifier = container.read(downloadHistoryProvider.notifier);
        notifier.addEntry(DownloadTask(id: 'A', title: 'T', url: 'U', destination: 'D', createdAt: DateTime.now()));
        expect(notifier.totalEntries, 1);
        expect(notifier.getEntry('A'), isNotNull);
      });

      test('U-DL-HST-17: removes multiple entries by IDs', () {
        final notifier = container.read(downloadHistoryProvider.notifier);
        notifier.addEntry(DownloadTask(id: 'A', title: 'T', url: 'U', destination: 'D', createdAt: DateTime.now()));
        notifier.addEntry(DownloadTask(id: 'B', title: 'T', url: 'U', destination: 'D', createdAt: DateTime.now()));
        notifier.addEntry(DownloadTask(id: 'C', title: 'T', url: 'U', destination: 'D', createdAt: DateTime.now()));
        
        notifier.deleteEntries({'A', 'C'});
        final state = container.read(downloadHistoryProvider);
        expect(state.length, 1);
        expect(state[0].id, 'B');
        expect(notifier.totalEntries, 1);
      });

      test('U-DL-HST-18: removes single entry by ID', () {
        final notifier = container.read(downloadHistoryProvider.notifier);
        notifier.addEntry(DownloadTask(id: 'A', title: 'T', url: 'U', destination: 'D', createdAt: DateTime.now()));
        notifier.addEntry(DownloadTask(id: 'B', title: 'T', url: 'U', destination: 'D', createdAt: DateTime.now()));
        
        notifier.deleteEntry('A');
        final state = container.read(downloadHistoryProvider);
        expect(state.length, 1);
        expect(state[0].id, 'B');
      });

      test('U-DL-HST-19: _loadedCount clamps to 0', () {
        final notifier = container.read(downloadHistoryProvider.notifier);
        notifier.addEntry(DownloadTask(id: 'A', title: 'T', url: 'U', destination: 'D', createdAt: DateTime.now()));
        notifier.deleteEntries({'A', 'B', 'C', 'D', 'E'}); // Over-delete
        // If it didn't crash, it clamped safely
        final state = container.read(downloadHistoryProvider);
        expect(state, isEmpty);
      });

      test('U-DL-HST-20: clears all state and counters', () {
        final notifier = container.read(downloadHistoryProvider.notifier);
        notifier.addEntry(DownloadTask(id: 'A', title: 'T', url: 'U', destination: 'D', createdAt: DateTime.now()));
        notifier.clearAll();
        
        final state = container.read(downloadHistoryProvider);
        expect(state, isEmpty);
        expect(notifier.totalEntries, 0);
      });

      test('U-DL-HST-21: retrieves specific entry from DB', () {
        final notifier = container.read(downloadHistoryProvider.notifier);
        notifier.addEntry(DownloadTask(id: 'abc', title: 'T', url: 'U', destination: 'D', createdAt: DateTime.now()));
        final entry = notifier.getEntry('abc');
        expect(entry, isNotNull);
        expect(entry!.id, 'abc');
      });

      test('U-DL-HST-22: returns DB file size', () {
        final notifier = container.read(downloadHistoryProvider.notifier);
        notifier.addEntry(DownloadTask(id: 'abc', title: 'T', url: 'U', destination: 'D', createdAt: DateTime.now()));
        expect(notifier.historyFileSize, greaterThan(0));
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 4. DownloadHistoryNotifier — Filtered Deletion
    // ═══════════════════════════════════════════════════════════════
    group('4. DownloadHistoryNotifier — Filtered Deletion', () {
      test('U-DL-HST-23: deletes all items matching filter', () {
        final notifier = container.read(downloadHistoryProvider.notifier);
        notifier.addEntry(DownloadTask(id: '1', title: 'T', status: DownloadStatus.completed, url: 'U', destination: 'D', createdAt: DateTime.now()));
        notifier.addEntry(DownloadTask(id: '2', title: 'T', status: DownloadStatus.error, url: 'U', destination: 'D', createdAt: DateTime.now()));
        notifier.addEntry(DownloadTask(id: '3', title: 'T', status: DownloadStatus.error, url: 'U', destination: 'D', createdAt: DateTime.now()));
        
        notifier.deleteFiltered(const DownloadHistoryFilter(status: 'error'));
        
        final state = container.read(downloadHistoryProvider);
        expect(state.length, 1);
        expect(state[0].id, '1'); // Only completed remains
      });

      test('U-DL-HST-24: deletes all items when filter is empty', () {
        final notifier = container.read(downloadHistoryProvider.notifier);
        notifier.addEntry(DownloadTask(id: '1', title: 'T', url: 'U', destination: 'D', createdAt: DateTime.now()));
        notifier.addEntry(DownloadTask(id: '2', title: 'T', url: 'U', destination: 'D', createdAt: DateTime.now()));
        
        notifier.deleteFiltered(const DownloadHistoryFilter()); // Empty filter
        
        final state = container.read(downloadHistoryProvider);
        expect(state, isEmpty);
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 5. DownloadHistoryFilter
    // ═══════════════════════════════════════════════════════════════
    group('5. DownloadHistoryFilter', () {
      test('U-DL-HST-25: isEmpty returns true when no dates and status is null', () {
        const filter = DownloadHistoryFilter();
        expect(filter.isEmpty, isTrue);
      });

      test('U-DL-HST-26: isEmpty returns true when status is "All"', () {
        const filter = DownloadHistoryFilter(status: 'All');
        expect(filter.isEmpty, isTrue);
      });

      test('U-DL-HST-27: isEmpty returns false when selectedDates is non-empty', () {
        final filter = DownloadHistoryFilter(selectedDates: {DateTime.now()});
        expect(filter.isEmpty, isFalse);
      });

      test('U-DL-HST-28: isEmpty returns false when status is specific', () {
        const filter = DownloadHistoryFilter(status: 'error');
        expect(filter.isEmpty, isFalse);
      });

      test('U-DL-HST-29: copyWith overrides specific fields', () {
        const filter = DownloadHistoryFilter(status: 'All');
        final updated = filter.copyWith(status: 'error');
        expect(updated.status, 'error');
        expect(updated.selectedDates, isNull);
      });
      
      // Note: _matchesFilter is private, but it's used indirectly by filteredDownloadHistoryProvider.
      // We will test it directly via the provider in section 6.
    });

    // ═══════════════════════════════════════════════════════════════
    // 6. Derived Providers
    // ═══════════════════════════════════════════════════════════════
    group('6. Derived Providers', () {
      test('U-DL-HST-33: filteredDownloadHistoryProvider returns full list when filter is empty', () {
        final notifier = container.read(downloadHistoryProvider.notifier);
        for (var i = 0; i < 10; i++) {
          notifier.addEntry(DownloadTask(id: '$i', title: 'T', url: 'U', destination: 'D', createdAt: DateTime.now()));
        }
        
        final filtered = container.read(filteredDownloadHistoryProvider);
        expect(filtered.length, 10);
      });

      test('U-DL-HST-34: filteredDownloadHistoryProvider filters by status', () {
        final notifier = container.read(downloadHistoryProvider.notifier);
        notifier.addEntry(DownloadTask(id: '1', title: 'T', status: DownloadStatus.completed, url: 'U', destination: 'D', createdAt: DateTime.now()));
        notifier.addEntry(DownloadTask(id: '2', title: 'T', status: DownloadStatus.error, url: 'U', destination: 'D', createdAt: DateTime.now()));
        notifier.addEntry(DownloadTask(id: '3', title: 'T', status: DownloadStatus.error, url: 'U', destination: 'D', createdAt: DateTime.now()));
        
        container.read(downloadHistoryFilterProvider.notifier).state = const DownloadHistoryFilter(status: 'error');
        
        final filtered = container.read(filteredDownloadHistoryProvider);
        expect(filtered.length, 2);
        expect(filtered[0].statusName, 'error');
      });

      test('U-DL-HST-35: availableDownloadDatesProvider extracts unique dates', () {
        final notifier = container.read(downloadHistoryProvider.notifier);
        final today = DateTime.now();
        final yesterday = today.subtract(const Duration(days: 1));
        
        notifier.addEntry(DownloadTask(id: '1', title: 'T', url: 'U', destination: 'D', createdAt: today));
        notifier.addEntry(DownloadTask(id: '2', title: 'T', url: 'U', destination: 'D', createdAt: yesterday));
        notifier.addEntry(DownloadTask(id: '3', title: 'T', url: 'U', destination: 'D', createdAt: today)); // duplicate date
        
        final dates = container.read(availableDownloadDatesProvider);
        expect(dates.length, 2);
      });

      test('U-DL-HST-36: downloadHistoryFilterProvider defaults to empty', () {
        final filter = container.read(downloadHistoryFilterProvider);
        expect(filter.isEmpty, isTrue);
      });
      
      test('U-DL-HST-30/31/32: tests _matchesFilter via derived provider', () {
        final notifier = container.read(downloadHistoryProvider.notifier);
        final today = DateTime.now();
        final yesterday = today.subtract(const Duration(days: 1));
        
        notifier.addEntry(DownloadTask(id: '1', title: 'T', status: DownloadStatus.completed, url: 'U', destination: 'D', createdAt: today));
        notifier.addEntry(DownloadTask(id: '2', title: 'T', status: DownloadStatus.error, url: 'U', destination: 'D', createdAt: today));
        notifier.addEntry(DownloadTask(id: '3', title: 'T', status: DownloadStatus.completed, url: 'U', destination: 'D', createdAt: yesterday));
        
        // Match by date
        container.read(downloadHistoryFilterProvider.notifier).state = DownloadHistoryFilter(
          selectedDates: {DateTime(today.year, today.month, today.day)}
        );
        expect(container.read(filteredDownloadHistoryProvider).length, 2);
        
        // Match by status
        container.read(downloadHistoryFilterProvider.notifier).state = const DownloadHistoryFilter(status: 'Completed');
        expect(container.read(filteredDownloadHistoryProvider).length, 2);
        
        // Combined match (Today AND Error)
        container.read(downloadHistoryFilterProvider.notifier).state = DownloadHistoryFilter(
          selectedDates: {DateTime(today.year, today.month, today.day)},
          status: 'error'
        );
        final filtered = container.read(filteredDownloadHistoryProvider);
        expect(filtered.length, 1);
        expect(filtered.first.id, '2');
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 7. DownloadHistorySelectionNotifier
    // ═══════════════════════════════════════════════════════════════
    group('7. DownloadHistorySelectionNotifier', () {
      test('U-DL-HST-37: initializes with empty set', () {
        final selection = container.read(downloadHistorySelectionProvider);
        expect(selection, isEmpty);
      });

      test('U-DL-HST-38: toggles adding item to selection', () {
        final notifier = container.read(downloadHistorySelectionProvider.notifier);
        notifier.toggle('1');
        expect(container.read(downloadHistorySelectionProvider), contains('1'));
      });

      test('U-DL-HST-39: toggles removing item from selection', () {
        final notifier = container.read(downloadHistorySelectionProvider.notifier);
        notifier.toggle('1');
        notifier.toggle('1');
        expect(container.read(downloadHistorySelectionProvider), isEmpty);
      });

      test('U-DL-HST-40: sets anchor to toggled item', () {
        final notifier = container.read(downloadHistorySelectionProvider.notifier);
        notifier.toggle('A');
        
        // We can't access _lastSelectedId directly, but we can test selectRange behavior
        // which depends on it
        final entries = [
          DownloadHistoryEntry(id: 'A', title: 'T', statusName: 'completed', url: 'U', destination: 'D', createdAt: DateTime.now()),
          DownloadHistoryEntry(id: 'B', title: 'T', statusName: 'completed', url: 'U', destination: 'D', createdAt: DateTime.now()),
        ];
        notifier.selectRange(entries, 'B');
        
        final state = container.read(downloadHistorySelectionProvider);
        expect(state, containsAll(['A', 'B']));
      });

      test('U-DL-HST-41: clears anchor when item removed', () {
        final notifier = container.read(downloadHistorySelectionProvider.notifier);
        notifier.toggle('A'); // anchor set to A
        notifier.toggle('A'); // removed, anchor should be null
        
        final entries = [
          DownloadHistoryEntry(id: 'A', title: 'T', statusName: 'completed', url: 'U', destination: 'D', createdAt: DateTime.now()),
          DownloadHistoryEntry(id: 'B', title: 'T', statusName: 'completed', url: 'U', destination: 'D', createdAt: DateTime.now()),
        ];
        notifier.selectRange(entries, 'B'); // Since anchor is null, this should fallback to toggle('B')
        
        final state = container.read(downloadHistorySelectionProvider);
        expect(state, contains('B'));
        expect(state.contains('A'), isFalse);
      });

      test('U-DL-HST-42: explicitly sets anchor', () {
        final notifier = container.read(downloadHistorySelectionProvider.notifier);
        notifier.setAnchor('X');
        
        final entries = [
          DownloadHistoryEntry(id: 'X', title: 'T', statusName: 'completed', url: 'U', destination: 'D', createdAt: DateTime.now()),
          DownloadHistoryEntry(id: 'Y', title: 'T', statusName: 'completed', url: 'U', destination: 'D', createdAt: DateTime.now()),
        ];
        notifier.selectRange(entries, 'Y');
        
        final state = container.read(downloadHistorySelectionProvider);
        expect(state, containsAll(['X', 'Y']));
      });

      test('U-DL-HST-43: selects range from anchor to target', () {
        final entries = [
          DownloadHistoryEntry(id: 'A', title: 'T', statusName: 'completed', url: 'U', destination: 'D', createdAt: DateTime.now()),
          DownloadHistoryEntry(id: 'B', title: 'T', statusName: 'completed', url: 'U', destination: 'D', createdAt: DateTime.now()),
          DownloadHistoryEntry(id: 'C', title: 'T', statusName: 'completed', url: 'U', destination: 'D', createdAt: DateTime.now()),
          DownloadHistoryEntry(id: 'D', title: 'T', statusName: 'completed', url: 'U', destination: 'D', createdAt: DateTime.now()),
        ];
        
        final notifier = container.read(downloadHistorySelectionProvider.notifier);
        notifier.setAnchor('A');
        notifier.selectRange(entries, 'D');
        
        final state = container.read(downloadHistorySelectionProvider);
        expect(state, containsAll(['A', 'B', 'C', 'D']));
      });

      test('U-DL-HST-44: fallbacks to toggle when no anchor', () {
        final entries = [
          DownloadHistoryEntry(id: 'A', title: 'T', statusName: 'completed', url: 'U', destination: 'D', createdAt: DateTime.now()),
          DownloadHistoryEntry(id: 'B', title: 'T', statusName: 'completed', url: 'U', destination: 'D', createdAt: DateTime.now()),
        ];
        
        final notifier = container.read(downloadHistorySelectionProvider.notifier);
        notifier.selectRange(entries, 'B');
        
        final state = container.read(downloadHistorySelectionProvider);
        expect(state, contains('B'));
      });

      test('U-DL-HST-45: fallbacks to toggle when ID not found', () {
        final entries = [
          DownloadHistoryEntry(id: 'A', title: 'T', statusName: 'completed', url: 'U', destination: 'D', createdAt: DateTime.now()),
          DownloadHistoryEntry(id: 'B', title: 'T', statusName: 'completed', url: 'U', destination: 'D', createdAt: DateTime.now()),
        ];
        
        final notifier = container.read(downloadHistorySelectionProvider.notifier);
        notifier.setAnchor('Z'); // Not in entries
        notifier.selectRange(entries, 'B');
        
        final state = container.read(downloadHistorySelectionProvider);
        expect(state, contains('B'));
      });

      test('U-DL-HST-46: handles reverse range (target before anchor)', () {
        final entries = [
          DownloadHistoryEntry(id: 'A', title: 'T', statusName: 'completed', url: 'U', destination: 'D', createdAt: DateTime.now()),
          DownloadHistoryEntry(id: 'B', title: 'T', statusName: 'completed', url: 'U', destination: 'D', createdAt: DateTime.now()),
          DownloadHistoryEntry(id: 'C', title: 'T', statusName: 'completed', url: 'U', destination: 'D', createdAt: DateTime.now()),
          DownloadHistoryEntry(id: 'D', title: 'T', statusName: 'completed', url: 'U', destination: 'D', createdAt: DateTime.now()),
        ];
        
        final notifier = container.read(downloadHistorySelectionProvider.notifier);
        notifier.setAnchor('D');
        notifier.selectRange(entries, 'A');
        
        final state = container.read(downloadHistorySelectionProvider);
        expect(state, containsAll(['A', 'B', 'C', 'D']));
      });

      test('U-DL-HST-47: resets selection and anchor via clear()', () {
        final notifier = container.read(downloadHistorySelectionProvider.notifier);
        notifier.toggle('A');
        notifier.toggle('B');
        
        notifier.clear();
        expect(container.read(downloadHistorySelectionProvider), isEmpty);
        
        // Verify anchor is cleared by doing a range select that should fallback to toggle
        final entries = [
          DownloadHistoryEntry(id: 'C', title: 'T', statusName: 'completed', url: 'U', destination: 'D', createdAt: DateTime.now()),
        ];
        notifier.selectRange(entries, 'C');
        expect(container.read(downloadHistorySelectionProvider), contains('C'));
      });
    });
  });
}
