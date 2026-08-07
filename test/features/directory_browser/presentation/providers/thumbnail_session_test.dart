import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/thumbnail_session.dart';

class MockThumbnailCacheService extends Mock implements ThumbnailCacheService {}

void main() {
  setUpAll(() {
    registerFallbackValue(ThumbnailSize.normal);
    registerFallbackValue(File(''));
  });

  group('ThumbnailSession', () {
    late ThumbnailSession session;

    setUp(() {
      session = ThumbnailSession(
        folderPath: '/test/folder',
        tabId: 'tab_1',
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

    test('enqueue executes tasks sequentially and tracks completion', () async {
      final executionOrder = <int>[];
      final completer1 = Completer<void>();
      final completer2 = Completer<void>();

      final job1 = ThumbnailJob(
        filePath: '/test/folder/image1.jpg',
        size: ThumbnailSize.normal,
        task: () async {
          await completer1.future;
          executionOrder.add(1);
        },
      );

      final job2 = ThumbnailJob(
        filePath: '/test/folder/image2.jpg',
        size: ThumbnailSize.normal,
        task: () async {
          await completer2.future;
          executionOrder.add(2);
        },
      );

      final f1 = session.enqueue(job1);
      final f2 = session.enqueue(job2);

      expect(session.isJobActiveOrQueued('/test/folder/image1.jpg', ThumbnailSize.normal), isTrue);
      expect(session.isJobActiveOrQueued('/test/folder/image2.jpg', ThumbnailSize.normal), isTrue);

      completer1.complete();
      await f1;
      expect(executionOrder, [1]);

      completer2.complete();
      await f2;
      expect(executionOrder, [1, 2]);

      expect(session.isJobCompleted('/test/folder/image1.jpg', ThumbnailSize.normal), isTrue);
      expect(session.isJobCompleted('/test/folder/image2.jpg', ThumbnailSize.normal), isTrue);
    });

    test('deduplicates duplicate enqueue calls for the same file and size', () async {
      var callCount = 0;
      final completer = Completer<void>();

      final job1 = ThumbnailJob(
        filePath: '/test/folder/image1.jpg',
        size: ThumbnailSize.normal,
        task: () async {
          callCount++;
          await completer.future;
        },
      );

      final job2 = ThumbnailJob(
        filePath: '/test/folder/image1.jpg',
        size: ThumbnailSize.normal,
        task: () async {
          callCount++;
        },
      );

      final f1 = session.enqueue(job1);
      final f2 = session.enqueue(job2);

      // job2 should be deduplicated and return same or immediate future without queuing second task
      completer.complete();
      await Future.wait([f1, f2]);

      expect(callCount, 1);
    });

    test('does not re-enqueue already completed jobs', () async {
      var callCount = 0;

      final job1 = ThumbnailJob(
        filePath: '/test/folder/image1.jpg',
        size: ThumbnailSize.normal,
        task: () async {
          callCount++;
        },
      );

      await session.enqueue(job1);
      expect(callCount, 1);
      expect(session.isJobCompleted('/test/folder/image1.jpg', ThumbnailSize.normal), isTrue);

      // Second enqueue after completion
      final job2 = ThumbnailJob(
        filePath: '/test/folder/image1.jpg',
        size: ThumbnailSize.normal,
        task: () async {
          callCount++;
        },
      );

      await session.enqueue(job2);
      expect(callCount, 1); // Not called again
    });

    test('reprioritize reorders pending jobs based on visiblePaths', () async {
      final executionOrder = <int>[];
      final gate = Completer<void>();

      // Active running job
      final job1 = ThumbnailJob(
        filePath: '/test/folder/image1.jpg',
        size: ThumbnailSize.normal,
        priority: 10,
        task: () async {
          await gate.future;
          executionOrder.add(1);
        },
      );

      // Pending job 2 (default priority 20)
      final job2 = ThumbnailJob(
        filePath: '/test/folder/image2.jpg',
        size: ThumbnailSize.normal,
        priority: 20,
        task: () async {
          executionOrder.add(2);
        },
      );

      // Pending job 3 (default priority 30)
      final job3 = ThumbnailJob(
        filePath: '/test/folder/image3.jpg',
        size: ThumbnailSize.normal,
        priority: 30,
        task: () async {
          executionOrder.add(3);
        },
      );

      final f1 = session.enqueue(job1);
      final f2 = session.enqueue(job2);
      final f3 = session.enqueue(job3);

      // Reprioritize job3 so it is prioritized ahead of job2
      session.reprioritize({'/test/folder/image3.jpg'});

      gate.complete();
      await Future.wait([f1, f2, f3]);

      // Order should be 1, 3, 2
      expect(executionOrder, [1, 3, 2]);
    });

    test('cancel() stops pending jobs and marks session cancelled', () async {
      final executed = <int>[];
      final gate = Completer<void>();

      final job1 = ThumbnailJob(
        filePath: '/test/folder/image1.jpg',
        size: ThumbnailSize.normal,
        task: () async {
          await gate.future;
          executed.add(1);
        },
      );

      final job2 = ThumbnailJob(
        filePath: '/test/folder/image2.jpg',
        size: ThumbnailSize.normal,
        task: () async {
          executed.add(2);
        },
      );

      final f1 = session.enqueue(job1);
      final f2 = session.enqueue(job2);

      session.cancel();

      gate.complete();
      await f1;
      await f2;

      expect(executed, [1]); // job2 was never executed
      expect(session.isCancelled, isTrue);
    });

    test('cancel() terminates registered process gracefully (SIGTERM -> SIGKILL)', () async {
      final fakeProcess = _FakeProcess();
      final job = ThumbnailJob(
        filePath: '/test/folder/video.mp4',
        size: ThumbnailSize.normal,
        task: () async {
          // Register process with the job context
        },
      );

      session.registerRunningProcess(job.key, fakeProcess);
      expect(fakeProcess.sigtermSent, isFalse);

      session.cancel();

      expect(fakeProcess.sigtermSent, isTrue);
      // Fast forward or wait grace period
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(fakeProcess.sigkillSent, isTrue);
    });

    test('dispose() cancels and cleans up resources', () {
      expect(session.isDisposed, isFalse);
      session.dispose();
      expect(session.isDisposed, isTrue);
      expect(session.isCancelled, isTrue);
    });

    group('enqueueAllFolderItems', () {
      late MockThumbnailCacheService mockCache;

      setUp(() {
        mockCache = MockThumbnailCacheService();
        when(mockCache.ensureLoaded).thenAnswer((_) async {});
        when(() => mockCache.lookup(
              filePath: any(named: 'filePath'),
              mtime: any(named: 'mtime'),
              sizeBytes: any(named: 'sizeBytes'),
            )).thenReturn(ThumbnailLookupResult.hit);
        when(() => mockCache.getCachedPath(any(), size: any(named: 'size')))
            .thenReturn('/cached/path.jpg');
      });

      test('enqueues items radiating outward from centerVisibleIndex', () async {
        final items = List.generate(
          20,
          (i) => FileItem(
            path: '/test/folder/pic_$i.jpg',
            name: 'pic_$i.jpg',
            type: FileItemType.image,
            sizeBytes: 1024,
            modified: DateTime.now(),
          ),
        );

        // Viewport: 10..16, center is 13
        // Buffer: 6..20
        session.enqueueAllFolderItems(
          items: items,
          cacheService: mockCache,
          firstVisibleIndex: 10,
          lastVisibleIndex: 16,
          firstBufferIndex: 6,
          lastBufferIndex: 20,
        );

        // Center item (index 13) has priority 0
        // Adjacent items (12 and 14) have priority 1
        // Viewport edges (10 and 15) have priority 3 and 2
        // Buffer item (9) has priority 50 + 4 = 54
        // Folder item (0) has priority 200 + 13 = 213
        expect(session.isJobActiveOrQueued('/test/folder/pic_13.jpg', ThumbnailSize.normal), isTrue);
        expect(session.isJobActiveOrQueued('/test/folder/pic_0.jpg', ThumbnailSize.normal), isTrue);
      });

      test('reprioritizes existing queued items when scrolling to new viewport', () async {
        final items = List.generate(
          30,
          (i) => FileItem(
            path: '/test/folder/img_$i.jpg',
            name: 'img_$i.jpg',
            type: FileItemType.image,
            sizeBytes: 1024,
            modified: DateTime.now(),
          ),
        );

        // Initial viewport: 0..6 (center = 3)
        session
          ..enqueueAllFolderItems(
            items: items,
            cacheService: mockCache,
            firstVisibleIndex: 0,
            lastVisibleIndex: 6,
            firstBufferIndex: 0,
            lastBufferIndex: 12,
          )
          // Now scroll to 20..26 (new center = 23)
          ..enqueueAllFolderItems(
            items: items,
            cacheService: mockCache,
            firstVisibleIndex: 20,
            lastVisibleIndex: 26,
            firstBufferIndex: 14,
            lastBufferIndex: 30,
          );

        // All items remain queued or active with updated priorities
        expect(session.isJobActiveOrQueued('/test/folder/img_23.jpg', ThumbnailSize.normal), isTrue);
      });

      test('ignores non-image and non-video files', () {
        final items = [
          FileItem(
            path: '/test/folder/doc.pdf',
            name: 'doc.pdf',
            type: FileItemType.document,
            sizeBytes: 1024,
            modified: DateTime.now(),
          ),
          FileItem(
            path: '/test/folder/text.txt',
            name: 'text.txt',
            type: FileItemType.other,
            sizeBytes: 512,
            modified: DateTime.now(),
          ),
          FileItem(
            path: '/test/folder/song.mp3',
            name: 'song.mp3',
            type: FileItemType.audio,
            sizeBytes: 2048,
            modified: DateTime.now(),
          ),
        ];

        session.enqueueAllFolderItems(
          items: items,
          cacheService: mockCache,
          firstVisibleIndex: 0,
          lastVisibleIndex: 3,
          firstBufferIndex: 0,
          lastBufferIndex: 3,
        );

        expect(session.isJobActiveOrQueued('/test/folder/doc.pdf', ThumbnailSize.normal), isFalse);
        expect(session.isJobActiveOrQueued('/test/folder/text.txt', ThumbnailSize.normal), isFalse);
        expect(session.isJobActiveOrQueued('/test/folder/song.mp3', ThumbnailSize.normal), isFalse);
      });

      test('pre-empts running off-screen job when higher-priority job arrives', () async {
        final fakeProcess = _FakeProcess();
        final lowPriorityJob = ThumbnailJob(
          filePath: '/test/folder/far_offscreen.mp4',
          size: ThumbnailSize.normal,
          priority: 250,
          task: () async {
            // Simulated long running video extraction
          },
        );

        final future = session.enqueue(lowPriorityJob);
        session.registerRunningProcess(lowPriorityJob.key, fakeProcess);

        expect(fakeProcess.sigtermSent, isFalse);

        // High priority job arrives (priority 0)
        final highPriorityJob = ThumbnailJob(
          filePath: '/test/folder/center_visible.mp4',
          size: ThumbnailSize.normal,
          priority: 0,
          task: () async {},
        );
        await session.enqueue(highPriorityJob);

        // Low priority job process should be pre-empted with SIGTERM
        expect(fakeProcess.sigtermSent, isTrue);
        await future;
      });
    });
  });
}

class _FakeProcess implements Process {
  bool sigtermSent = false;
  bool sigkillSent = false;
  final Completer<int> _exitCompleter = Completer<int>();

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (signal == ProcessSignal.sigterm) {
      sigtermSent = true;
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
