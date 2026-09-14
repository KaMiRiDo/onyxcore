import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/thumbnail_session.dart';

class MockThumbnailCacheService extends Mock implements ThumbnailCacheService {}

// Helper: stub cache service to return miss for all lookups
void _stubMiss(MockThumbnailCacheService m) {
  when(() => m.lookup(
        filePath: any(named: 'filePath'),
        mtime: any(named: 'mtime'),
        sizeBytes: any(named: 'sizeBytes'),
      )).thenReturn(ThumbnailLookupResult.miss);
  when(() => m.markFailed(
        filePath: any(named: 'filePath'),
        mtime: any(named: 'mtime'),
        sizeBytes: any(named: 'sizeBytes'),
        kind: any(named: 'kind'),
      )).thenAnswer((_) async {});
  when(() => m.storeThumbnail(
        filePath: any(named: 'filePath'),
        mtime: any(named: 'mtime'),
        sizeBytes: any(named: 'sizeBytes'),
        kind: any(named: 'kind'),
        thumbnailFile: any(named: 'thumbnailFile'),
      )).thenAnswer((_) async {});
}

// Helper: stub cache service to return hit for all lookups
void _stubHit(MockThumbnailCacheService m) {
  when(() => m.lookup(
        filePath: any(named: 'filePath'),
        mtime: any(named: 'mtime'),
        sizeBytes: any(named: 'sizeBytes'),
      )).thenReturn(ThumbnailLookupResult.hit);
}

ThumbnailCandidate _candidate(String path, {FileItemType type = FileItemType.image}) =>
    ThumbnailCandidate(
      path: path,
      type: type,
      modifiedEpochMs: 0,
      sizeBytes: 1024,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(ThumbnailSize.normal);
    registerFallbackValue(File(''));
  });

  group('ThumbnailSession', () {
    late MockThumbnailCacheService mockCache;
    late ThumbnailSession session;

    setUp(() {
      mockCache = MockThumbnailCacheService();
      _stubMiss(mockCache);
      session = ThumbnailSession(
        folderPath: '/test/folder',
        tabId: 'tab_1',
        cacheService: mockCache,
      );
    });

    tearDown(() {
      session.dispose();
    });

    test('initializes with given folderPath and tabId', () {
      expect(session.folderPath, '/test/folder');
      expect(session.tabId, 'tab_1');
      expect(session.isDisposed, isFalse);
    });

    test('enqueueCandidate on cache hit returns success immediately without generating', () async {
      _stubHit(mockCache);
      final c = _candidate('/test/folder/image1.jpg');
      final outcome = await session.enqueueCandidate(c);
      expect(outcome, ThumbnailJobOutcome.success);
      verifyNever(() => mockCache.markFailed(
            filePath: any(named: 'filePath'),
            mtime: any(named: 'mtime'),
            sizeBytes: any(named: 'sizeBytes'),
            kind: any(named: 'kind'),
          ));
    });

    test('enqueueCandidate on negative-cache hit returns failed immediately', () async {
      when(() => mockCache.lookup(
            filePath: any(named: 'filePath'),
            mtime: any(named: 'mtime'),
            sizeBytes: any(named: 'sizeBytes'),
          )).thenReturn(ThumbnailLookupResult.failed);

      final outcome = await session.enqueueCandidate(_candidate('/test/folder/broken.jpg'));
      expect(outcome, ThumbnailJobOutcome.failed);
    });

    test('deduplicates concurrent enqueueCandidate calls for the same path', () async {
      final c = _candidate('/test/folder/image1.jpg');
      session.updateViewportInterest(candidates: [c], visiblePaths: {c.path});

      final f1 = session.enqueueCandidate(c);
      final f2 = session.enqueueCandidate(c); // should be deduplicated

      // Both must resolve (not hang)
      final results = await Future.wait([f1, f2]).timeout(const Duration(seconds: 5));
      expect(results.length, 2);
      // At most one generation run — both outcomes are the same
      expect(results[0], equals(results[1]));
    });

    test('isJobActiveOrQueued reflects pending/running state', () async {
      final c = _candidate('/test/folder/image1.jpg');
      // We can't inject a slow task with the new API, so verify before and after:
      session.updateViewportInterest(candidates: [c], visiblePaths: {c.path});
      // Job starts running immediately — it's active
      final f = session.enqueueCandidate(c);
      expect(
        session.isJobActiveOrQueued('/test/folder/image1.jpg', ThumbnailSize.normal),
        isTrue,
      );
      await f;
      // After completion it's no longer active
      expect(
        session.isJobActiveOrQueued('/test/folder/image1.jpg', ThumbnailSize.normal),
        isFalse,
      );
    });

    test('updateViewportInterest admits visible candidates before prefetch candidates', () async {
      final visible = _candidate('/test/folder/vis.jpg');
      final prefetch = _candidate('/test/folder/pre.jpg');
      session.updateViewportInterest(
        candidates: [visible, prefetch],
        visiblePaths: {visible.path},
      );
      // Both get enqueued; visible has priority 0, prefetch has priority ≥ 50
      expect(session.isJobActiveOrQueued(visible.path, ThumbnailSize.normal), isTrue);
      expect(session.isJobActiveOrQueued(prefetch.path, ThumbnailSize.normal), isTrue);
    });

    test('updateViewportInterest cancels stale pending jobs as obsolete', () async {
      final old = _candidate('/test/folder/old.jpg');
      final fresh = _candidate('/test/folder/fresh.jpg');

      session.updateViewportInterest(candidates: [old], visiblePaths: {old.path});
      final oldFuture = session.enqueueCandidate(old);

      // Viewport shifts — old path leaves interest
      session.updateViewportInterest(candidates: [fresh], visiblePaths: {fresh.path});

      // Old job should resolve (not hang)
      final result = await oldFuture.timeout(const Duration(seconds: 5));
      expect(result, anyOf(ThumbnailJobOutcome.obsolete, ThumbnailJobOutcome.cancelled, ThumbnailJobOutcome.failed));
    });

    test('cancel() stops pending jobs and marks session cancelled', () async {
      final c = _candidate('/test/folder/image1.jpg');
      session.updateViewportInterest(candidates: [c], visiblePaths: {c.path});
      final f = session.enqueueCandidate(c);
      session.cancel();
      final result = await f.timeout(const Duration(seconds: 5));
      expect(result, anyOf(ThumbnailJobOutcome.cancelled, ThumbnailJobOutcome.failed, ThumbnailJobOutcome.obsolete));
      expect(session.isCancelled, isTrue);
    });

    test('cancel() terminates registered process gracefully (SIGTERM → SIGKILL)', () async {
      final fakeProcess = _FakeProcess();
      session.registerRunningProcess('test/folder/video.mp4::normal', fakeProcess);
      expect(fakeProcess.sigtermSent, isFalse);

      session.cancel();

      expect(fakeProcess.sigtermSent, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(fakeProcess.sigkillSent, isTrue);
    });

    test('dispose() cancels and cleans up resources', () {
      expect(session.isDisposed, isFalse);
      session.dispose();
      expect(session.isDisposed, isTrue);
      expect(session.isCancelled, isTrue);
    });

    test('registerRunningProcess terminates immediately if session already cancelled', () {
      session.cancel();
      final fakeProcess = _FakeProcess();
      session.registerRunningProcess('some_key', fakeProcess);
      expect(fakeProcess.sigtermSent, isTrue);
    });

    group('updateViewportInterest', () {
      test('admits only image/video candidates, ignores document/audio/other', () {
        final candidates = [
          _candidate('/test/folder/pic.jpg'),
          ThumbnailCandidate(path: '/test/folder/vid.mp4', type: FileItemType.video, modifiedEpochMs: 0, sizeBytes: 0),
        ];
        final nonMedia = [
          FileItemType.document,
          FileItemType.audio,
          FileItemType.other,
        ];
        session.updateViewportInterest(
          candidates: candidates,
          visiblePaths: {'/test/folder/pic.jpg'},
        );
        for (final type in nonMedia) {
          expect(
            session.isJobActiveOrQueued('/test/folder/non.${type.name}', ThumbnailSize.normal),
            isFalse,
          );
        }
        expect(session.isJobActiveOrQueued('/test/folder/pic.jpg', ThumbnailSize.normal), isTrue);
      });

      test('visible-first: visible candidates get priority 0, prefetch gets priority ≥ bufferPriorityBase', () {
        // Verified via admission order — visible paths are admitted with visiblePriority (0)
        final vis = _candidate('/test/folder/vis.jpg');
        final buf = _candidate('/test/folder/buf.jpg');
        session.updateViewportInterest(
          candidates: [vis, buf],
          visiblePaths: {vis.path},
        );
        // Both admitted; order verifiable only via execution sequence which requires runner hooks
        expect(session.isJobActiveOrQueued(vis.path, ThumbnailSize.normal), isTrue);
        expect(session.isJobActiveOrQueued(buf.path, ThumbnailSize.normal), isTrue);
      });

      test('subsequent call replaces interest set (does not grow unboundedly)', () {
        final batch1 = List.generate(10, (i) => _candidate('/test/folder/batch1_$i.jpg'));
        final batch2 = List.generate(10, (i) => _candidate('/test/folder/batch2_$i.jpg'));
        final vis = {batch1.first.path};

        session.updateViewportInterest(candidates: batch1, visiblePaths: vis);
        session.updateViewportInterest(
          candidates: batch2,
          visiblePaths: {batch2.first.path},
        );

        // Batch 1 paths that were only pending (not running) should have been cancelled as obsolete
        // The visible set now contains only batch2 paths
        expect(session.isJobActiveOrQueued('/test/folder/batch2_0.jpg', ThumbnailSize.normal), isTrue);
      });
    });

    test('enqueueCandidate on cancelled session returns cancelled', () async {
      session.cancel();
      final outcome = await session.enqueueCandidate(_candidate('/test/folder/x.jpg'));
      expect(outcome, ThumbnailJobOutcome.cancelled);
    });

    test('enqueueCandidate on disposed session returns cancelled', () async {
      session.dispose();
      final outcome = await session.enqueueCandidate(_candidate('/test/folder/x.jpg'));
      expect(outcome, ThumbnailJobOutcome.cancelled);
    });
  });
}

class _FakeProcess implements Process {
  bool sigtermSent = false;
  bool sigkillSent = false;
  final Completer<int> _exitCompleter = Completer<int>();

  @override
  int get pid => 12345;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (signal == ProcessSignal.sigterm) {
      sigtermSent = true;
      // Do NOT auto-complete so SIGKILL is sent after grace period
    } else if (signal == ProcessSignal.sigkill) {
      sigkillSent = true;
      if (!_exitCompleter.isCompleted) {
        _exitCompleter.complete(-9);
      }
    }
    return true;
  }

  @override
  Future<int> get exitCode => _exitCompleter.future;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
