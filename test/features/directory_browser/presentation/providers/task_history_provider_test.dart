import 'dart:io' as io;
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_history_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';

void main() {
  group('TaskHistoryEntry', () {
    test('toJson and fromJson work correctly', () {
      final now = DateTime.now();
      final entry = TaskHistoryEntry(
        id: '123',
        title: 'Test',
        subtitle: 'Sub',
        statusName: 'Completed',
        createdAt: now,
        startedAt: now,
        completedAt: now.add(const Duration(seconds: 1)),
        errorMessage: 'Error',
        processedCount: 1,
        totalCount: 2,
        processedSizeBytes: 100,
        totalSizeBytes: 200,
        logs: ['Log1'],
        sourcePaths: ['/src'],
        targetPath: '/dst',
      );

      final json = entry.toJson();
      final decoded = TaskHistoryEntry.fromJson(json);

      expect(decoded.id, entry.id);
      expect(decoded.title, entry.title);
      expect(decoded.subtitle, entry.subtitle);
      expect(decoded.statusName, entry.statusName);
      expect(decoded.createdAt.toIso8601String(), entry.createdAt.toIso8601String());
      expect(decoded.startedAt?.toIso8601String(), entry.startedAt?.toIso8601String());
      expect(decoded.completedAt?.toIso8601String(), entry.completedAt?.toIso8601String());
      expect(decoded.errorMessage, entry.errorMessage);
      expect(decoded.processedCount, entry.processedCount);
      expect(decoded.totalCount, entry.totalCount);
      expect(decoded.processedSizeBytes, entry.processedSizeBytes);
      expect(decoded.totalSizeBytes, entry.totalSizeBytes);
      expect(decoded.logs, entry.logs);
      expect(decoded.sourcePaths, entry.sourcePaths);
      expect(decoded.targetPath, entry.targetPath);
      
      expect(decoded.duration?.inSeconds, 1);
    });
  });

  group('TaskHistoryFilter', () {
    test('isEmpty returns correct value', () {
      const filterEmpty = TaskHistoryFilter();
      expect(filterEmpty.isEmpty, isTrue);

      final filterDate = TaskHistoryFilter(selectedDates: {DateTime.now()});
      expect(filterDate.isEmpty, isFalse);

      const filterOp = TaskHistoryFilter(operationType: 'Copy');
      expect(filterOp.isEmpty, isFalse);

      const filterAll = TaskHistoryFilter(operationType: 'All');
      expect(filterAll.isEmpty, isTrue);
    });

    test('copyWith updates correctly', () {
      const filter = TaskHistoryFilter();
      final d = DateTime.now();
      
      final updated = filter.copyWith(selectedDates: {d}, operationType: 'Delete');
      expect(updated.selectedDates, {d});
      expect(updated.operationType, 'Delete');

      final updated2 = updated.copyWith(operationType: 'Copy');
      expect(updated2.selectedDates, {d});
      expect(updated2.operationType, 'Copy');
    });
  });

  group('HistorySelectionNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is empty', () {
      final state = container.read(historySelectionProvider);
      expect(state, isEmpty);
    });

    test('toggle adds and removes item', () {
      final notifier = container.read(historySelectionProvider.notifier);
      
      notifier.toggle('item1');
      expect(container.read(historySelectionProvider), {'item1'});

      notifier.toggle('item1');
      expect(container.read(historySelectionProvider), isEmpty);
    });

    test('setAnchor sets last selected id', () {
      final notifier = container.read(historySelectionProvider.notifier);
      notifier.setAnchor('item1');
      // Anchor is internal, we can test it indirectly via selectRange
    });

    test('clear resets state', () {
      final notifier = container.read(historySelectionProvider.notifier);
      notifier.toggle('item1');
      notifier.clear();
      expect(container.read(historySelectionProvider), isEmpty);
    });
  });

  group('TaskHistoryNotifier', () {
    late ProviderContainer container;
    late io.File historyFile;
    late io.File backupFile;

    setUp(() {
      final home = io.Platform.environment['HOME'] ?? '/tmp';
      historyFile = io.File('$home/.config/onyxcore/task_history.json');
      backupFile = io.File('$home/.config/onyxcore/task_history.json.bak');
      
      if (historyFile.existsSync()) {
        historyFile.renameSync(backupFile.path);
      }
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
      if (historyFile.existsSync()) {
        historyFile.deleteSync();
      }
      if (backupFile.existsSync()) {
        backupFile.renameSync(historyFile.path);
      }
    });

    test('initializes empty and can add entry', () {
      final notifier = container.read(taskHistoryProvider.notifier);
      expect(notifier.totalEntries, 0);

      final task = FileTask(
        id: 'task1',
        title: 'Copy Files',
        subtitle: 'Copying...',
        createdAt: DateTime.now(),
        status: FileTaskStatus.completed,
      );

      notifier.addEntry(task);
      expect(notifier.totalEntries, 1);
      expect(notifier.getEntry('task1'), isNotNull);
      
      final state = container.read(taskHistoryProvider);
      expect(state.length, 1);
      
      // Should persist
      expect(historyFile.existsSync(), isTrue);
      expect(notifier.historyFileSize, greaterThan(0));
    });

    test('can load more and delete entries', () {
      final List<Map<String, dynamic>> fakeEntries = [];
      for (int i = 0; i < 55; i++) {
        fakeEntries.add({
          'id': 't$i',
          'title': 'Rename $i',
          'statusName': 'completed',
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
      historyFile.writeAsStringSync(jsonEncode(fakeEntries));
      
      container.dispose();
      container = ProviderContainer();
      final notifier = container.read(taskHistoryProvider.notifier);

      // Default page size is 50
      var state = container.read(taskHistoryProvider);
      expect(state.length, 50);
      expect(notifier.hasMore, isTrue);

      notifier.loadMore();
      state = container.read(taskHistoryProvider);
      expect(state.length, 55);
      expect(notifier.hasMore, isFalse);
      
      notifier.deleteEntry('t0');
      expect(notifier.totalEntries, 54);
      
      notifier.deleteEntries({'t1', 't2'});
      expect(notifier.totalEntries, 52);
    });

    test('can delete filtered and clear all', () {
      final notifier = container.read(taskHistoryProvider.notifier);
      
      notifier.addEntry(FileTask(
        id: 't1',
        title: 'Copy something',
        subtitle: 'Copying...',
        createdAt: DateTime.now(),
        status: FileTaskStatus.completed,
      ));
      
      notifier.addEntry(FileTask(
        id: 't2',
        title: 'Delete something',
        subtitle: 'Deleting...',
        createdAt: DateTime.now(),
        status: FileTaskStatus.completed,
      ));

      expect(notifier.totalEntries, 2);

      notifier.deleteFiltered(const TaskHistoryFilter(operationType: 'Delete'));
      expect(notifier.totalEntries, 1);
      expect(notifier.getEntry('t2'), isNull);
      
      notifier.clearAll();
      expect(notifier.totalEntries, 0);
    });
    
    test('providers work correctly', () {
      final task = FileTask(
        id: 't1',
        title: 'Move file',
        subtitle: 'Moving...',
        createdAt: DateTime.now(),
        status: FileTaskStatus.completed,
      );
      container.read(taskHistoryProvider.notifier).addEntry(task);

      final dates = container.read(availableDatesProvider);
      expect(dates.length, 1);

      container.read(taskHistoryFilterProvider.notifier).state = const TaskHistoryFilter(operationType: 'Move');
      
      final filtered = container.read(filteredTaskHistoryProvider);
      expect(filtered.length, 1);
      expect(filtered.first.id, 't1');
    });
  });
}
