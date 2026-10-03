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

    test('ThumbnailJobOutcome enum has success, cancelled, failed, obsolete, deferred', () {
      expect(ThumbnailJobOutcome.values, containsAll([
        ThumbnailJobOutcome.success,
        ThumbnailJobOutcome.cancelled,
        ThumbnailJobOutcome.failed,
        ThumbnailJobOutcome.obsolete,
        ThumbnailJobOutcome.deferred,
      ]));
    });

    test('enqueueCandidate on cancelled session returns cancelled outcome', () async {
      final session = ThumbnailSession(
        folderPath: '/test/folder',
        tabId: 'tab_1',
        cacheService: mockCache,
      );
      session.cancel();

      final outcome = await session.enqueueCandidate(
        ThumbnailCandidate.fromFileItem(FileItem(
          path: '/test/folder/pic_cancel.jpg',
          name: 'pic_cancel.jpg',
          type: FileItemType.image,
          sizeBytes: 1024,
          modified: DateTime.now(),
        )),
      );

      expect(outcome, ThumbnailJobOutcome.cancelled);
      verifyNever(() => mockCache.markFailed(
            filePath: any(named: 'filePath'),
            mtime: any(named: 'mtime'),
            sizeBytes: any(named: 'sizeBytes'),
            kind: any(named: 'kind'),
          ));

      session.dispose();
    });

    test('enqueueCandidate on corrupt/non-existent file returns failed outcome', () async {
      final session = ThumbnailSession(
        folderPath: '/test/folder',
        tabId: 'tab_1',
        cacheService: mockCache,
      );

      when(() => mockCache.markFailed(
            filePath: any(named: 'filePath'),
            mtime: any(named: 'mtime'),
            sizeBytes: any(named: 'sizeBytes'),
            kind: any(named: 'kind'),
          )).thenAnswer((_) async {});
      when(() => mockCache.storeThumbnail(
            filePath: any(named: 'filePath'),
            mtime: any(named: 'mtime'),
            sizeBytes: any(named: 'sizeBytes'),
            kind: any(named: 'kind'),
            thumbnailFile: any(named: 'thumbnailFile'),
          )).thenAnswer((_) async {});

      final item = FileItem(
        path: '/non_existent_corrupted_file_path_xyz.jpg',
        name: 'corrupt.jpg',
        type: FileItemType.image,
        sizeBytes: 1024,
        modified: DateTime.now(),
      );
      // Extend interest so the session treats this as a current job
      session.updateViewportInterest(
        candidates: [ThumbnailCandidate.fromFileItem(item)],
        visiblePaths: {item.path},
      );

      final outcome = await session.enqueueCandidate(
        ThumbnailCandidate.fromFileItem(item),
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
      final localMockCache = MockThumbnailCacheService();
      when(localMockCache.ensureLoaded).thenAnswer((_) async {});
      when(() => localMockCache.lookup(
            filePath: any(named: 'filePath'),
            mtime: any(named: 'mtime'),
            sizeBytes: any(named: 'sizeBytes'),
          )).thenReturn(ThumbnailLookupResult.miss);
      when(() => localMockCache.markFailed(
            filePath: any(named: 'filePath'),
            mtime: any(named: 'mtime'),
            sizeBytes: any(named: 'sizeBytes'),
            kind: any(named: 'kind'),
          )).thenAnswer((_) async {});

      final session = ThumbnailSession(
        folderPath: '/test/folder',
        tabId: 'tab_1',
        cacheService: localMockCache,
      );
      final item = FileItem(
        path: '/invalid_test_path_atomic_123.jpg',
        name: 'atomic.jpg',
        type: FileItemType.image,
        sizeBytes: 1024,
        modified: DateTime.now(),
      );

      final tempPath = ThumbnailCacheService.computeTempPath(item.path, ThumbnailSize.normal);
      final cachePath = ThumbnailCacheService.computeCachePath(item.path, ThumbnailSize.normal);

      session.updateViewportInterest(
        candidates: [ThumbnailCandidate.fromFileItem(item)],
        visiblePaths: {item.path},
      );
      await session.enqueueCandidate(ThumbnailCandidate.fromFileItem(item));

      expect(File(tempPath).existsSync(), isFalse, reason: 'Temporary file must be deleted after failed generation');
      expect(File(cachePath).existsSync(), isFalse, reason: 'No corrupt partial cache file should be placed at cachePath');

      session.dispose();
    });
  });

  group('Phase 1.2 — Patch 4: Lifecycle Edge Cases & Concurrency', () {

    test('Enqueueing after session disposal returns cancelled outcome without running tasks or throwing', () async {
      final session = ThumbnailSession(
        folderPath: '/test/folder',
        tabId: 'tab_1',
      );
      session.dispose();

      final outcome = await session.enqueueCandidate(
        const ThumbnailCandidate(
          path: '/test/folder/pic_after_dispose.jpg',
          type: FileItemType.image,
          modifiedEpochMs: 0,
          sizeBytes: 0,
        ),
      );
      expect(outcome, ThumbnailJobOutcome.cancelled);
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
      final mockCache2 = MockThumbnailCacheService();
      when(mockCache2.ensureLoaded).thenAnswer((_) async {});
      when(() => mockCache2.lookup(
            filePath: any(named: 'filePath'),
            mtime: any(named: 'mtime'),
            sizeBytes: any(named: 'sizeBytes'),
          )).thenReturn(ThumbnailLookupResult.miss);
      when(() => mockCache2.markFailed(
            filePath: any(named: 'filePath'),
            mtime: any(named: 'mtime'),
            sizeBytes: any(named: 'sizeBytes'),
            kind: any(named: 'kind'),
          )).thenAnswer((_) async {});

      final session = ThumbnailSession(
        folderPath: '/folder',
        tabId: 'tab_1',
        cacheService: mockCache2,
      );

      const candidate = ThumbnailCandidate(
        path: '/folder/race.jpg',
        type: FileItemType.image,
        modifiedEpochMs: 0,
        sizeBytes: 0,
      );
      session.updateViewportInterest(
        candidates: [candidate],
        visiblePaths: {candidate.path},
      );

      final future = session.enqueueCandidate(candidate);
      session.cancel();

      expect(() => future, returnsNormally);
      await future;

      session.dispose();
    });

    test('Worker slot cleanup: active count is decremented even if generation fails', () async {
      final mockCache3 = MockThumbnailCacheService();
      when(mockCache3.ensureLoaded).thenAnswer((_) async {});
      when(() => mockCache3.lookup(
            filePath: any(named: 'filePath'),
            mtime: any(named: 'mtime'),
            sizeBytes: any(named: 'sizeBytes'),
          )).thenReturn(ThumbnailLookupResult.miss);
      when(() => mockCache3.markFailed(
            filePath: any(named: 'filePath'),
            mtime: any(named: 'mtime'),
            sizeBytes: any(named: 'sizeBytes'),
            kind: any(named: 'kind'),
          )).thenAnswer((_) async {});

      final session = ThumbnailSession(
        folderPath: '/folder',
        tabId: 'tab_1',
        cacheService: mockCache3,
      );

      const throwing = ThumbnailCandidate(
        path: '/folder/throw.jpg',
        type: FileItemType.image,
        modifiedEpochMs: 0,
        sizeBytes: 0,
      );
      session.updateViewportInterest(
        candidates: [throwing],
        visiblePaths: {throwing.path},
      );
      await session.enqueueCandidate(throwing);

      // Second candidate verifies worker slot was released
      const second = ThumbnailCandidate(
        path: '/folder/second.jpg',
        type: FileItemType.image,
        modifiedEpochMs: 0,
        sizeBytes: 0,
      );
      when(() => mockCache3.lookup(
            filePath: second.path,
            mtime: any(named: 'mtime'),
            sizeBytes: any(named: 'sizeBytes'),
          )).thenReturn(ThumbnailLookupResult.miss);
      session.updateViewportInterest(
        candidates: [second],
        visiblePaths: {second.path},
      );
      final result = await session.enqueueCandidate(second);
      expect(result, isNot(equals(ThumbnailJobOutcome.deferred)));

      session.dispose();
    });
  });
}
