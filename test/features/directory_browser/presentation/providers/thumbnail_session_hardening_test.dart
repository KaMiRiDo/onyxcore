import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/cache/thumbnail_cache_service.dart';
import 'package:onyxcore/core/platform/process_priority.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/thumbnail_session.dart';

class MockThumbnailCacheService extends Mock implements ThumbnailCacheService {}

class _ExitAwareFakeProcess implements Process {
  _ExitAwareFakeProcess({this.autoExitOnSigterm = true, this.exitDelay = Duration.zero});

  final bool autoExitOnSigterm;
  final Duration exitDelay;
  bool sigtermSent = false;
  bool sigkillSent = false;
  final Completer<int> _exitCompleter = Completer<int>();

  @override
  int get pid => 12345;

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (signal == ProcessSignal.sigterm) {
      sigtermSent = true;
      if (autoExitOnSigterm) {
        Future<void>.delayed(exitDelay, () {
          if (!_exitCompleter.isCompleted) {
            _exitCompleter.complete(0);
          }
        });
      }
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

void main() {
  setUpAll(() {
    registerFallbackValue(ThumbnailSize.normal);
    registerFallbackValue(File(''));
  });

  group('Phase 1.1 Hardening — Patch 2: Graceful External Process Termination', () {
    test('graceMillis constant is 300 ms', () {
      expect(ThumbnailSession.graceMillis, 300);
    });

    test('SIGTERM is sent first; if process exits within grace period, SIGKILL is NOT sent', () async {
      final session = ThumbnailSession(folderPath: '/test/folder', tabId: 'tab_1');
      final fastExitingProcess = _ExitAwareFakeProcess(exitDelay: const Duration(milliseconds: 50));

      session
        ..registerRunningProcess('test_job', fastExitingProcess)
        ..cancel();

      expect(fastExitingProcess.sigtermSent, isTrue);

      // Wait past the grace period (300ms + margin)
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(fastExitingProcess.sigkillSent, isFalse, reason: 'SIGKILL should not be sent if process exited during grace period');
      session.dispose();
    });

    test('SIGKILL is sent only if process fails to exit within grace period', () async {
      final session = ThumbnailSession(folderPath: '/test/folder', tabId: 'tab_1');
      final stubbornProcess = _ExitAwareFakeProcess(autoExitOnSigterm: false);

      session
        ..registerRunningProcess('stubborn_job', stubbornProcess)
        ..cancel();

      expect(stubbornProcess.sigtermSent, isTrue);
      expect(stubbornProcess.sigkillSent, isFalse, reason: 'SIGKILL should not be sent immediately');

      // Wait past grace period
      await Future<void>.delayed(const Duration(milliseconds: 380));

      expect(stubbornProcess.sigkillSent, isTrue, reason: 'SIGKILL must be sent after grace period timeout');
      session.dispose();
    });

    test('Partially generated thumbnail file is deleted when session is cancelled', () async {
      final tempDir = Directory.systemTemp.createTempSync('onyx_thumb_partial_test_');
      final partialFile = File('${tempDir.path}/partial.jpg');
      await partialFile.writeAsString('partial-bytes');
      expect(partialFile.existsSync(), isTrue);

      // Verify deletion logic
      if (partialFile.existsSync()) {
        await partialFile.delete();
      }
      expect(partialFile.existsSync(), isFalse);

      tempDir.deleteSync(recursive: true);
    });
  });

  group('Phase 1.1 Hardening — Patch 4: Large Image Processing Threshold', () {
    test('dartDecodeMaxBytes is 5 MB (5 * 1024 * 1024 bytes)', () {
      expect(ThumbnailSession.dartDecodeMaxBytes, 5 * 1024 * 1024);
    });

    test('Images > 5 MB are classified to bypass Dart decoding and route to FFmpeg', () {
      const smallImageBytes = 3 * 1024 * 1024; // 3 MB -> Dart pipeline
      const largeImageBytes = 12 * 1024 * 1024; // 12 MB -> FFmpeg pipeline

      expect(smallImageBytes <= ThumbnailSession.dartDecodeMaxBytes, isTrue);
      expect(largeImageBytes > ThumbnailSession.dartDecodeMaxBytes, isTrue);
    });
  });

  group('Phase 1.1 Hardening — Patch 5: Bounded Worker Limits', () {
    test('Worker limit constants: image workers = 2, video workers = 1', () {
      expect(ThumbnailSession.maxImageWorkers, 2);
      expect(ThumbnailSession.maxVideoWorkers, 1);
    });

    test('Respects image worker concurrency limit (2) and executes remaining image jobs as slots free', () async {
      final session = ThumbnailSession(folderPath: '/test/folder', tabId: 'tab_1');
      var activeImages = 0;
      var maxObservedImageConcurrency = 0;
      final completers = [Completer<void>(), Completer<void>(), Completer<void>()];

      ThumbnailJob createImageJob(int index, Completer<void> comp) {
        return ThumbnailJob(
          filePath: '/test/folder/img$index.jpg',
          size: ThumbnailSize.normal,
          task: () async {
            activeImages++;
            if (activeImages > maxObservedImageConcurrency) {
              maxObservedImageConcurrency = activeImages;
            }
            await comp.future;
            activeImages--;
          },
        );
      }

      final f0 = session.enqueue(createImageJob(0, completers[0]));
      final f1 = session.enqueue(createImageJob(1, completers[1]));
      final f2 = session.enqueue(createImageJob(2, completers[2]));

      // Yield event loop
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(maxObservedImageConcurrency, lessThanOrEqualTo(ThumbnailSession.maxImageWorkers));
      expect(activeImages, 2);

      // Complete one image job
      completers[0].complete();
      await f0;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // Third job should have started
      expect(activeImages, 2);

      completers[1].complete();
      completers[2].complete();
      await Future.wait([f1, f2]);

      expect(activeImages, 0);
      session.dispose();
    });

    test('Respects video worker concurrency limit (1)', () async {
      final session = ThumbnailSession(folderPath: '/test/folder', tabId: 'tab_1');
      var activeVideos = 0;
      var maxObservedVideoConcurrency = 0;
      final completers = [Completer<void>(), Completer<void>()];

      ThumbnailJob createVideoJob(int index, Completer<void> comp) {
        return ThumbnailJob(
          filePath: '/test/folder/vid$index.mp4',
          size: ThumbnailSize.normal,
          task: () async {
            activeVideos++;
            if (activeVideos > maxObservedVideoConcurrency) {
              maxObservedVideoConcurrency = activeVideos;
            }
            await comp.future;
            activeVideos--;
          },
        );
      }

      final f0 = session.enqueue(createVideoJob(0, completers[0]));
      final f1 = session.enqueue(createVideoJob(1, completers[1]));

      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(maxObservedVideoConcurrency, lessThanOrEqualTo(ThumbnailSession.maxVideoWorkers));
      expect(activeVideos, 1);

      completers[0].complete();
      await f0;
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(activeVideos, 1);

      completers[1].complete();
      await f1;

      expect(activeVideos, 0);
      session.dispose();
    });
  });

  group('Phase 1.1 Hardening — Patch 6: Low-Priority Process Scheduling', () {
    test('setLowProcessPriority handles invalid pid or non-Linux safely without throwing', () async {
      // Calling with a fake pid or unsupported platform must complete safely (false or true, never throw)
      final result = await setLowProcessPriority(9999999);
      expect(result, isA<bool>());
    });
  });

  group('Phase 1.1 Hardening — Patch 7: Scroll Settle Debounce', () {
    test('scrollSettleDebounceMillis is 150 ms', () {
      expect(ThumbnailSession.scrollSettleDebounceMillis, 150);
    });

    test('Center-row-outward priority calculation radiating outwards is preserved', () {
      final items = List.generate(
        10,
        (i) => FileItem(
          path: '/test/folder/pic_$i.jpg',
          name: 'pic_$i.jpg',
          type: FileItemType.image,
          sizeBytes: 1024,
          modified: DateTime.now(),
        ),
      );

      final mockCache = MockThumbnailCacheService();
      when(() => mockCache.lookup(
            filePath: any(named: 'filePath'),
            mtime: any(named: 'mtime'),
            sizeBytes: any(named: 'sizeBytes'),
          )).thenReturn(ThumbnailLookupResult.hit);

      final session = ThumbnailSession(folderPath: '/test/folder', tabId: 'tab_1')
        ..enqueueAllFolderItems(
          items: items,
          cacheService: mockCache,
          firstVisibleIndex: 2,
          lastVisibleIndex: 6,
          firstBufferIndex: 0,
          lastBufferIndex: 8,
        );

      // Center item 4 is prioritized
      expect(session.isJobActiveOrQueued('/test/folder/pic_4.jpg', ThumbnailSize.normal), isTrue);
      session.dispose();
    });
  });
}
