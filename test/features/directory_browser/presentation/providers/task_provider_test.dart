import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';

void main() {
  group('FileTask Tests', () {
    test('copyWith updates properties correctly', () {
      final now = DateTime.now();
      final task = FileTask(
        id: '1',
        title: 'Title',
        subtitle: 'Sub',
        createdAt: now,
      );

      final updated = task.copyWith(
        title: 'New Title',
        progress: 0.5,
        status: FileTaskStatus.running,
        processedCount: 1,
        totalCount: 10,
        processedSizeBytes: 100,
        totalSizeBytes: 1000,
      );

      expect(updated.title, 'New Title');
      expect(updated.progress, 0.5);
      expect(updated.status, FileTaskStatus.running);
      expect(updated.processedCount, 1);
      expect(updated.totalCount, 10);
      expect(updated.processedSizeBytes, 100);
      expect(updated.totalSizeBytes, 1000);
    });
    
    test('estimatedRemaining calculates correctly', () {
      final now = DateTime.now();
      var t = FileTask(id: '1', title: 'A', subtitle: 'B', createdAt: now);
      expect(t.estimatedRemaining, isNull);

      t = t.copyWith(startedAt: now.subtract(const Duration(seconds: 10)), progress: 0.5);
      expect(t.estimatedRemaining?.inSeconds, 10);
      
      t = t.copyWith(isSyncing: true, progress: 1);
      expect(t.estimatedRemaining, isNull);
      expect(t.progress, 0.99); // syncing clamped
    });
  });

  group('TaskNotifier Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is empty', () {
      final state = container.read(taskProvider);
      expect(state, isEmpty);
    });

    test('addTask adds task to state', () {
      final notifier = container.read(taskProvider.notifier);
      final id = notifier.addTask(
        title: 'Isolate Task',
        subtitle: 'Running...',
      );

      final state = container.read(taskProvider);
      expect(state.length, 1);
      expect(state.first.id, id);
      expect(state.first.title, 'Isolate Task');
      expect(state.first.status, FileTaskStatus.running);
    });

    test('updateProgress and counts updates stream task', () {
      final notifier = container.read(taskProvider.notifier);
      final id = notifier.addTask(title: 'T1', subtitle: 'S1');
      
      notifier.updateProgress(id, 0.5);
      notifier.updateItemCounts(id, 5, 10);
      notifier.updateByteCounts(id, 50, 100);

      final state = container.read(taskProvider);
      final task = state.first;
      
      expect(task.processedCount, 5);
      expect(task.totalCount, 10);
      expect(task.progress, 0.5);
    });

    test('completeTask updates status', () {
      final notifier = container.read(taskProvider.notifier);
      final id = notifier.addTask(title: 'T1', subtitle: 'S1');
      
      notifier.completeTask(id);
      
      final state = container.read(taskProvider);
      final task = state.firstWhere((t) => t.id == id);
      expect(task.status, FileTaskStatus.completed);
    });

    test('failTask updates status to error', () {
      final notifier = container.read(taskProvider.notifier);
      final id = notifier.addTask(title: 'T1', subtitle: 'S1');
      
      notifier.failTask(id, 'Failed!');
      
      final state = container.read(taskProvider);
      final task = state.firstWhere((t) => t.id == id);
      expect(task.status, FileTaskStatus.error);
      expect(task.errorMessage, 'Failed!');
    });

    test('cancelTask marks task as cancelled', () {
      final notifier = container.read(taskProvider.notifier);
      final id = notifier.addTask(title: 'T1', subtitle: 'S1');
      
      notifier.cancelTask(id);
      
      final state = container.read(taskProvider);
      final task = state.firstWhere((t) => t.id == id);
      expect(task.isCancelled, isTrue);
    });

    test('removeTask removes task from state', () {
      final notifier = container.read(taskProvider.notifier);
      final id = notifier.addTask(title: 'T1', subtitle: 'S1');
      
      expect(container.read(taskProvider).length, 1);
      
      notifier.removeTask(id);
      
      expect(container.read(taskProvider), isEmpty);
    });

    test('getters work correctly', () {
      final notifier = container.read(taskProvider.notifier);
      
      notifier.maxConcurrent = 1;
      
      // Heavy task
      notifier.addTask(title: 'H1', subtitle: 'H1');
      // Another heavy task (pending)
      notifier.addTask(title: 'H2', subtitle: 'H2');
      // Light task (always runs)
      notifier.addTask(title: 'L1', subtitle: 'L1', isLight: true);

      expect(notifier.runningHeavyTasks.length, 1);
      expect(notifier.runningTasks.length, 2);
      expect(notifier.pendingTasks.length, 1);
      expect(notifier.hasActiveHeavyTasks, isTrue);
      expect(notifier.hasActiveTasks, isTrue);
      
      // Progress calculation
      notifier.updateProgress(notifier.runningTasks[0].id, 0.5);
      expect(notifier.totalProgress, greaterThan(0));
      
      notifier.failTask(notifier.runningTasks[0].id, 'err');
      expect(notifier.hasErrors, isTrue);
      
      expect(notifier.historyTasks.length, 1);
    });
    
    test('setSyncing, addLog, refreshTasks, currentItem work', () {
      final notifier = container.read(taskProvider.notifier);
      final id = notifier.addTask(title: 'T', subtitle: 'S');
      
      notifier.setSyncing(id);
      expect(container.read(taskProvider).first.isSyncing, isTrue);
      
      notifier.addLog(id, 'Log msg');
      expect(container.read(taskProvider).first.logs, ['Log msg']);
      
      notifier.updateCurrentItem(id, 'file.txt');
      expect(container.read(taskProvider).first.currentItem, 'file.txt');
      
      notifier.refreshTasks();
    });

    test('cancelAllTasks and clearHistory work', () async {
      final notifier = container.read(taskProvider.notifier);
      notifier.addTask(title: 'T1', subtitle: 'S1');
      notifier.addTask(title: 'T2', subtitle: 'S2');
      
      await notifier.cancelAllTasks();
      
      final state = container.read(taskProvider);
      expect(state.every((t) => t.isCancelled), isTrue);
      
      notifier.clearHistory();
      expect(container.read(taskProvider), isEmpty);
    });
    
    test('isTaskCancelled and port registration', () async {
      final notifier = container.read(taskProvider.notifier);
      final id = notifier.addTask(title: 'T', subtitle: 'S');
      
      expect(notifier.isTaskCancelled(id), isFalse);
      
      notifier.cancelTask(id);
      expect(notifier.isTaskCancelled(id), isTrue);
    });
  });
}
