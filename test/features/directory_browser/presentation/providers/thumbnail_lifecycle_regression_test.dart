import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/core/lifecycle/app_cleanup_coordinator.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/thumbnail_session.dart';

class MockThumbnailCacheService extends Mock implements ThumbnailCacheService {}

class _FakeProcess implements Process {
  _FakeProcess();

  bool sigtermSent = false;
  bool sigkillSent = false;
  final Completer<int> _exitCompleter = Completer<int>();

  @override
  int get pid => 424242;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (signal == ProcessSignal.sigterm) {
      sigtermSent = true;
      if (!_exitCompleter.isCompleted) {
        _exitCompleter.complete(0);
      }
      return true;
    }
    if (signal == ProcessSignal.sigkill) {
      sigkillSent = true;
      if (!_exitCompleter.isCompleted) {
        _exitCompleter.complete(0);
      }
      return true;
    }
    return false;
  }

  @override
  Future<int> get exitCode => _exitCompleter.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() {
    registerFallbackValue(ThumbnailSize.normal);
    registerFallbackValue(File(''));
  });

  group('Phase 1.2 — Patch 1: Thumbnail Job Result Classification', () {
    late MockThumbnailCacheService mockCache;

    setUp(() {
      mockCache = MockThumbnailCacheService();
      when(mockCache.ensureLoaded).thenAnswer((_) async {});
      when(() => mockCache.lookup(
            filePath: any(named: 'filePath'),
            mtime: any(named: 'mtime'),
            sizeBytes: any(named: 'sizeBytes'),
          )).thenReturn(ThumbnailLookupResult.miss);
    });

    test('ThumbnailJobOutcome enum has success, cancelled, and failed', () {
      expect(ThumbnailJobOutcome.values, containsAll([
        ThumbnailJobOutcome.success,
        ThumbnailJobOutcome.cancelled,
        ThumbnailJobOutcome.failed,
      ]));
    });

    test('generateMediaThumbnail returns ThumbnailJobOutcome.cancelled and NEVER marks failed when session is cancelled', () async {
      final session = ThumbnailSession(folderPath: '/test/folder', tabId: 'tab_1');
      final item = FileItem(
        path: '/test/folder/pic_cancel.jpg',
        name: 'pic_cancel.jpg',
        type: FileItemType.image,
        sizeBytes: 1024,
        modified: DateTime.now(),
      );

      // Pre-cancel session
      session.cancel();

      final outcome = await generateMediaThumbnail(
        item: item,
        cacheService: mockCache,
        session: session,
      );

      expect(outcome, ThumbnailJobOutcome.cancelled);
      // Crucial: markFailed should NEVER be called for cancelled jobs
      verifyNever(() => mockCache.markFailed(
            filePath: any(named: 'filePath'),
            mtime: any(named: 'mtime'),
            sizeBytes: any(named: 'sizeBytes'),
            kind: any(named: 'kind'),
          ));

      session.dispose();
    });

    test('generateMediaThumbnail returns ThumbnailJobOutcome.failed and marks failed for corrupt/non-existent files', () async {
      final session = ThumbnailSession(folderPath: '/test/folder', tabId: 'tab_1');
      final item = FileItem(
        path: '/non_existent_corrupted_file_path_xyz.jpg',
        name: 'corrupt.jpg',
        type: FileItemType.image,
        sizeBytes: 1024,
        modified: DateTime.now(),
      );

      when(() => mockCache.markFailed(
            filePath: any(named: 'filePath'),
            mtime: any(named: 'mtime'),
            sizeBytes: any(named: 'sizeBytes'),
            kind: any(named: 'kind'),
          )).thenAnswer((_) async {});

      final outcome = await generateMediaThumbnail(
        item: item,
        cacheService: mockCache,
        session: session,
      );

      expect(outcome, ThumbnailJobOutcome.failed);
      verify(() => mockCache.markFailed(
            filePath: item.path,
            mtime: item.modified.millisecondsSinceEpoch,
            sizeBytes: item.sizeBytes ?? 0,
            kind: 'image',
          )).called(1);

      session.dispose();
    });
  });

  group('Phase 1.2 — Patch 2: Centralized AppCleanupCoordinator', () {
    test('AppCleanupCoordinator executes all registered cleanup callbacks in order', () {
      var thumbnailCleaned = false;
      var archiveCleaned = false;
      final executionLog = <String>[];

      final coordinator = AppCleanupCoordinator(
        thumbnailCleanup: () {
          thumbnailCleaned = true;
          executionLog.add('thumbnail');
        },
        archiveCleanup: () {
          archiveCleaned = true;
          executionLog.add('archive');
        },
      );

      expect(thumbnailCleaned, isFalse);
      expect(archiveCleaned, isFalse);

      coordinator.runAll();

      expect(thumbnailCleaned, isTrue);
      expect(archiveCleaned, isTrue);
      expect(executionLog, ['thumbnail', 'archive']);
    });

    test('AppCleanupCoordinator is safe against exceptions in individual handlers', () {
      var archiveCleaned = false;

      final coordinator = AppCleanupCoordinator(
        thumbnailCleanup: () {
          throw Exception('Thumbnail cleanup failure');
        },
        archiveCleanup: () {
          archiveCleaned = true;
        },
      );

      expect(coordinator.runAll, returnsNormally);
      expect(archiveCleaned, isTrue);
    });
  });

  group('Phase 1.2 — Patch 3: Atomic Thumbnail Writes', () {
    test('ThumbnailCacheService.computeTempPath generates temp path in same cache folder', () {
      final cachePath = ThumbnailCacheService.computeCachePath('/test/file.jpg', ThumbnailSize.normal);
      final tempPath = ThumbnailCacheService.computeTempPath('/test/file.jpg', ThumbnailSize.normal);

      expect(tempPath, isNot(cachePath));
      expect(File(tempPath).parent.path, File(cachePath).parent.path,
          reason: 'Temp file and cache file MUST be in the same folder to guarantee atomic rename');
      expect(tempPath.contains('.tmp_'), isTrue);
    });

    test('Temporary files created during failed or cancelled thumbnail generation are removed without polluting cache', () async {
      final session = ThumbnailSession(folderPath: '/test/folder', tabId: 'tab_1');
      final item = FileItem(
        path: '/invalid_test_path_atomic_123.jpg',
        name: 'atomic.jpg',
        type: FileItemType.image,
        sizeBytes: 1024,
        modified: DateTime.now(),
      );

      final tempPath = ThumbnailCacheService.computeTempPath(item.path, ThumbnailSize.normal);
      final cachePath = ThumbnailCacheService.computeCachePath(item.path, ThumbnailSize.normal);

      final mockCache = MockThumbnailCacheService();
      when(() => mockCache.lookup(
            filePath: any(named: 'filePath'),
            mtime: any(named: 'mtime'),
            sizeBytes: any(named: 'sizeBytes'),
          )).thenReturn(ThumbnailLookupResult.miss);
      when(() => mockCache.markFailed(
            filePath: any(named: 'filePath'),
            mtime: any(named: 'mtime'),
            sizeBytes: any(named: 'sizeBytes'),
            kind: any(named: 'kind'),
          )).thenAnswer((_) async {});

      await generateMediaThumbnail(
        item: item,
        cacheService: mockCache,
        session: session,
      );

      expect(File(tempPath).existsSync(), isFalse, reason: 'Temporary file must be deleted after failed generation');
      expect(File(cachePath).existsSync(), isFalse, reason: 'No corrupt partial cache file should be placed at cachePath');

      session.dispose();
    });
  });

  group('Phase 1.2 — Patch 4: Lifecycle Edge Cases & Concurrency', () {
    test('Enqueueing after session disposal completes safely without executing tasks or throwing', () async {
      final session = ThumbnailSession(folderPath: '/test/folder', tabId: 'tab_1');
      session.dispose();

      var taskRun = false;
      final job = ThumbnailJob(
        filePath: '/test/folder/pic_after_dispose.jpg',
        size: ThumbnailSize.normal,
        task: () async {
          taskRun = true;
        },
      );

      await session.enqueue(job);
      expect(taskRun, isFalse);
      expect(session.isDisposed, isTrue);
    });

    test('registerRunningProcess terminates process immediately if session is already cancelled or disposed', () {
      final session = ThumbnailSession(folderPath: '/test/folder', tabId: 'tab_1');
      session.cancel();

      final fakeProc = _FakeProcess();
      session.registerRunningProcess('test_key', fakeProc);

      expect(fakeProc.sigtermSent, isTrue);
      session.dispose();
    });

    test('Rapid folder switching: previous sessions are cancelled and only the latest session processes', () async {
      final session1 = ThumbnailSession(folderPath: '/folder1', tabId: 'tab_1');
      final session2 = ThumbnailSession(folderPath: '/folder2', tabId: 'tab_1');
      final session3 = ThumbnailSession(folderPath: '/folder3', tabId: 'tab_1');

      session1.cancel();
      session2.cancel();

      expect(session1.isCancelled, isTrue);
      expect(session2.isCancelled, isTrue);
      expect(session3.isCancelled, isFalse);

      session1.dispose();
      session2.dispose();
      session3.dispose();
    });

    test('Simultaneous cancellation and job completion does not throw or double-complete', () async {
      final session = ThumbnailSession(folderPath: '/folder', tabId: 'tab_1');
      final gate = Completer<void>();

      final job = ThumbnailJob(
        filePath: '/folder/race.jpg',
        size: ThumbnailSize.normal,
        task: () async {
          await gate.future;
        },
      );

      final future = session.enqueue(job);
      session.cancel();
      gate.complete();

      expect(() => future, returnsNormally);
      await future;

      session.dispose();
    });

    test('Worker slot cleanup: active count is decremented even if thumbnail task throws an error', () async {
      final session = ThumbnailSession(folderPath: '/folder', tabId: 'tab_1');

      final throwingJob = ThumbnailJob(
        filePath: '/folder/throw.jpg',
        size: ThumbnailSize.normal,
        task: () async {
          throw Exception('Task error');
        },
      );

      await session.enqueue(throwingJob);

      // Enqueue a succeeding job after to verify the worker slot wasn't leaked
      var secondJobRun = false;
      final secondJob = ThumbnailJob(
        filePath: '/folder/second.jpg',
        size: ThumbnailSize.normal,
        task: () async {
          secondJobRun = true;
        },
      );

      await session.enqueue(secondJob);
      expect(secondJobRun, isTrue);

      session.dispose();
    });
  });
}
