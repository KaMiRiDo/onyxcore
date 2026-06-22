import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_history_provider.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:flutter/material.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';

class DummyEngine extends DownloadEngine {
  @override
  String get id => 'dummy';
  @override
  String get name => 'Dummy';
  @override
  int get priority => 100;
  @override
  bool get isInstalled => true;
  @override
  List<RegExp> get urlPatterns => [RegExp(r'.*')];
  @override
  String get displayName => 'Dummy';
  @override
  IconData get icon => Icons.abc;
  @override
  Color get color => Colors.red;
  @override
  EngineType get engineType => EngineType.cli;
  @override
  String? get binaryPath => null;
  @override
  EngineUpdateInfo? get updateInfo => null;
  
  @override
  Future<List<MediaInfo>> fetchMetadata({
    required String url,
    String? browser,
    bool fetchDeep = false,
    bool isPlaylist = false,
    void Function(MediaInfo info)? onProgress,
    void Function(int pid)? onProcessStarted,
  }) async => [];

  @override
  Future<Process> startDownload({
    required String url,
    required String destination,
    String? title,
    MediaFormat? format,
    bool audioOnly = false,
    bool mute = false,
    int? galleryIndex,
    bool isPlaylist = false,
    bool isProfile = false,
    String? browser,
    bool isZip = false,
    String? filterType,
    int? totalItems,
    String? singleItemId,
    String? directUrl,
  }) async {
    // Return a dummy process that exits immediately
    return await Process.start('echo', ['dummy']);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;

  setUpAll(() {
    EngineRegistry.clearAllEnginesForTesting();
    EngineRegistry.register(DummyEngine());
  });

  setUp(() {
    container = ProviderContainer(
      overrides: [
        // Prevent history provider from trying to init sqlite in temp
        downloadHistoryProvider.overrideWith(() => DownloadHistoryNotifier()),
      ],
    );
  });

  tearDown(() async {
    await Future.delayed(const Duration(milliseconds: 50));
    container.dispose();
  });

  group('DownloadTaskProvider Unit Tests', () {
    // ═══════════════════════════════════════════════════════════════
    // 1. DownloadTask Entity
    // ═══════════════════════════════════════════════════════════════
    group('1. DownloadTask Entity', () {
      test('U-DL-TSK-01: creates with all defaults', () {
        final now = DateTime.now();
        final task = DownloadTask(
          id: '1',
          url: 'U',
          destination: 'D',
          title: 'T',
          createdAt: now,
        );

        expect(task.status, DownloadStatus.pending);
        expect(task.progress, 0.0);
        expect(task.speed, '');
        expect(task.eta, '');
        expect(task.totalSize, '');
        expect(task.expectedBytes, 0);
        expect(task.downloadedBytes, 0);
        expect(task.completedItems, 0);
        expect(task.totalItems, 0);
        expect(task.error, isNull);
        expect(task.process, isNull);
        expect(task.logs, isEmpty);
        expect(task.completedAt, isNull);
      });

      test('U-DL-TSK-02: copyWith overrides specific fields', () {
        final task = DownloadTask(
          id: '1',
          url: 'U',
          destination: 'D',
          title: 'T',
          createdAt: DateTime.now(),
        );

        final updated = task.copyWith(progress: 0.5, speed: '2MB/s');
        expect(updated.progress, 0.5);
        expect(updated.speed, '2MB/s');
        expect(updated.id, '1'); // unchanged
      });

      test('U-DL-TSK-03: copyWith preserves immutable fields', () {
        final now = DateTime.now();
        final task = DownloadTask(
          id: '1',
          url: 'U',
          destination: 'D',
          title: 'T',
          createdAt: now,
        );

        final updated = task.copyWith(title: 'T2');
        expect(updated.id, '1');
        expect(updated.url, 'U');
        expect(updated.destination, 'D');
        expect(updated.createdAt, now);
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // 2. DownloadStatus Enum
    // ═══════════════════════════════════════════════════════════════
    group('2. DownloadStatus Enum', () {
      test('U-DL-TSK-04: contains exactly 6 values', () {
        expect(DownloadStatus.values.length, 6);
        expect(DownloadStatus.values, containsAllInOrder([
          DownloadStatus.pending,
          DownloadStatus.running,
          DownloadStatus.cancelling,
          DownloadStatus.completed,
          DownloadStatus.error,
          DownloadStatus.cancelled,
        ]));
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // Progress Parsing (Sections 4-11 & 21)
    // ═══════════════════════════════════════════════════════════════
    group('Progress Parsing & Logs', () {
      late DownloadTaskNotifier notifier;
      const testId = 'test_id';

      setUp(() {
        notifier = container.read(downloadTaskProvider.notifier);
        // Inject a fake task directly into state so we can test parsing without starting a real process
        notifier.state = [
          DownloadTask(id: testId, url: 'U', destination: 'D', title: 'T', createdAt: DateTime.now())
        ];
      });

      test('U-DL-TSK-09: parses standard yt-dlp progress', () {
        notifier.parseProgressForTesting(testId, '[download]  13.0% of  107.0MiB at  16.0MiB/s ETA 00:05');
        final task = notifier.state.first;
        expect(task.progress, 0.13);
        expect(task.totalSize, '107.0MiB');
        expect(task.speed, '16.0MiB/s');
        expect(task.eta, '00:05');
      });

      test('U-DL-TSK-10: parses yt-dlp with unknown size', () {
        notifier.parseProgressForTesting(testId, '[download]  13.0% of ~10.0MiB at Unknown B/s ETA Unknown');
        final task = notifier.state.first;
        expect(task.progress, 0.13);
        expect(task.totalSize, '~10.0MiB');
        expect(task.speed, 'Unknown');
        expect(task.eta, 'Unknown');
      });

      test('U-DL-TSK-11: parses yt-dlp 100%', () {
        notifier.parseProgressForTesting(testId, '[download] 100% of 10.0MiB in 00:01');
        final task = notifier.state.first;
        expect(task.progress, 1.0);
      });

      test('U-DL-TSK-12: parses playlist item index', () {
        // Need to set totalItems in internal _taskArgs. We'll do it by using the public startDownload
        // but we'll cancel it so it doesn't run the backend
        notifier.state = [];
        notifier.startDownload(url: 'U', destination: 'D', title: 'T', totalItems: 25, engine: 'dummy');
        final id = notifier.state.first.id;
        
        notifier.parseProgressForTesting(id, '[download] Downloading video 1 of 25');
        final task = notifier.state.firstWhere((t) => t.id == id);
        expect(task.completedItems, 0); // 1-based, so 0 completed
        expect(task.totalItems, 25);
        notifier.removeTask(id);
      });

      test('U-DL-TSK-13: strips ANSI escape codes', () {
        notifier.parseProgressForTesting(testId, '\x1B[32m[download]\x1B[0m  50.0% of 10MiB at 1MiB/s ETA 00:10');
        final task = notifier.state.first;
        expect(task.progress, 0.5);
      });

      test('U-DL-TSK-14: parses fragmented progress (start)', () {
        notifier.parseProgressForTesting(testId, '[download] Frag 1/10');
        final task = notifier.state.first;
        expect(task.progress, 0.10);
        expect(task.totalSize, '1 / 10 Frags');
      });

      test('U-DL-TSK-15: parses fragmented progress (end)', () {
        notifier.parseProgressForTesting(testId, '[download] Frag 10/10');
        final task = notifier.state.first;
        expect(task.progress, 1.0);
        expect(task.totalSize, '10 / 10 Frags');
      });

      test('U-DL-TSK-16: parses unknown total size (no percentage)', () {
        notifier.parseProgressForTesting(testId, '[download] 10.0MiB at 5.0MiB/s');
        final task = notifier.state.first;
        expect(task.progress, 0.0);
        expect(task.speed, '5.0MiB/s');
        expect(task.totalSize, '10.0MiB / ?');
      });

      test('U-DL-TSK-17: parses aria2c progress', () {
        notifier.parseProgressForTesting(testId, '[#bb8141 1.7MiB/113MiB(1%) CN:16 DL:2.7MiB ETA:41s]');
        final task = notifier.state.first;
        expect(task.progress, 0.01);
        expect(task.totalSize, '1.7MiB / 113MiB');
        expect(task.speed, '2.7MiB');
        expect(task.eta, '41s');
      });

      test('U-DL-TSK-18: parses aria2c download complete', () {
        notifier.parseProgressForTesting(testId, 'Download complete: /path/file.mp4');
        final task = notifier.state.first;
        expect(task.progress, 1.0);
      });

      test('U-DL-TSK-20: parses You-Get progress', () {
        notifier.parseProgressForTesting(testId, '98.5% ( 24.0/ 24.4MB) [==============>');
        final task = notifier.state.first;
        expect(task.progress, closeTo(0.985, 0.001));
        expect(task.totalSize, '24.4MB');
      });

      test('U-DL-TSK-21: parses You-Get download complete', () {
        notifier.parseProgressForTesting(testId, ' (✓) Downloaded to: /path');
        final task = notifier.state.first;
        expect(task.progress, 1.0);
      });

      test('U-DL-TSK-22: parses Lux progress', () {
        notifier.parseProgressForTesting(testId, ' 50.00% |████████░░░░| 25.0/50.0 MiB 5.0 MiB/s 5s');
        final task = notifier.state.first;
        expect(task.progress, 0.5);
        expect(task.totalSize, '25.0/50.0 MiB');
        expect(task.speed, '5.0 MiB/s');
        expect(task.eta, '5s');
      });

      test('U-DL-TSK-23: parses FFmpeg elapsed time', () {
        notifier.parseProgressForTesting(testId, 'frame=  100 fps= 30 q=-1.0 size= 1024kB time=00:01:30.00 bitrate= 93.2kbits/s speed=  1x');
        final task = notifier.state.first;
        expect(task.totalSize, 'Elapsed: 00:01:30');
      });

      test('U-DL-TSK-64: appendLog adds non-empty trimmed lines', () {
        notifier.appendLogForTesting(testId, 'Line 1\n  \nLine 2 \n');
        final task = notifier.state.first;
        expect(task.logs, ['Line 1', 'Line 2']);
      });

      test('U-DL-TSK-65: appendLog skips whitespace-only lines', () {
        notifier.appendLogForTesting(testId, '  \n  \n  ');
        final task = notifier.state.first;
        expect(task.logs, isEmpty);
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // Multi-Item Progress Aggregation (12)
    // ═══════════════════════════════════════════════════════════════
    group('Multi-Item Progress', () {
      late DownloadTaskNotifier notifier;
      late String id;

      setUp(() {
        notifier = container.read(downloadTaskProvider.notifier);
        notifier.startDownload(url: 'U', destination: 'D', title: 'T', totalItems: 25);
        id = notifier.state.first.id;
      });

      test('U-DL-TSK-29: aggregates progress across multiple items', () {
        notifier.parseProgressForTesting(id, '[download] Downloading video 4 of 25'); // Sets completed=3
        notifier.parseProgressForTesting(id, '[download]  45.0% of 10MiB'); // 45% of 4th item
        
        final task = notifier.state.firstWhere((t) => t.id == id);
        // (300 + 45) / 2500 = 0.138
        expect(task.progress, closeTo(0.138, 0.001));
      });

      test('U-DL-TSK-30: enforces monotonic progress', () {
        notifier.parseProgressForTesting(id, '[download] Downloading video 4 of 25');
        notifier.parseProgressForTesting(id, '[download]  50.0% of 10MiB'); 
        final task1 = notifier.state.firstWhere((t) => t.id == id);
        expect(task1.progress, closeTo(0.14, 0.001));
        
        // Simulating an out-of-order log or parsing bug returning smaller percentage
        notifier.parseProgressForTesting(id, '[download]  10.0% of 10MiB'); 
        final task2 = notifier.state.firstWhere((t) => t.id == id);
        expect(task2.progress, closeTo(0.14, 0.001)); // Should NOT go down
      });

      test('U-DL-TSK-31: caps progress at 1.0', () {
        notifier.parseProgressForTesting(id, '[download] Downloading video 26 of 25'); // completed=25
        notifier.parseProgressForTesting(id, '[download] 100.0% of 10MiB'); 
        
        final task = notifier.state.firstWhere((t) => t.id == id);
        expect(task.progress, 1.0);
      });

      test('U-DL-TSK-32: only updates speed/eta with non-empty values', () {
        notifier.parseProgressForTesting(id, '[download]  13.0% of 100MiB at 5MiB/s ETA 00:10');
        notifier.parseProgressForTesting(id, '[download]  14.0% of 100MiB'); // Missing speed/eta
        
        final task = notifier.state.firstWhere((t) => t.id == id);
        expect(task.speed, '5MiB/s'); // preserved
        expect(task.eta, '00:10'); // preserved
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // Hydration Callback (17)
    // ═══════════════════════════════════════════════════════════════
    group('Hydration Callback', () {
      late DownloadTaskNotifier notifier;
      late String id;

      setUp(() {
        notifier = container.read(downloadTaskProvider.notifier);
        notifier.startDownload(url: 'hyd_url', destination: 'D', title: 'T');
        id = notifier.state.first.id;
      });

      test('U-DL-TSK-52: updates totalItems for matching URL', () {
        final items = List.generate(20, (i) => MediaInfo(id: '$i', title: '$i', originalUrl: 'U'));
        notifier.onHydrationFinished('hyd_url', items);
        
        final task = notifier.state.firstWhere((t) => t.id == id);
        expect(task.totalItems, 20);
      });

      test('U-DL-TSK-53: respects filterType images', () {
        notifier.removeTask(id);
        notifier.startDownload(url: 'hyd_url', destination: 'D', title: 'T', filterType: 'images');
        id = notifier.state.first.id;
        
        final items = [
          const MediaInfo(id: '1', title: '1', originalUrl: 'U', isVideo: true),
          const MediaInfo(id: '2', title: '2', originalUrl: 'U', isVideo: false),
          const MediaInfo(id: '3', title: '3', originalUrl: 'U', isVideo: false),
        ];
        
        notifier.onHydrationFinished('hyd_url', items);
        final task = notifier.state.firstWhere((t) => t.id == id);
        expect(task.totalItems, 2); // 2 images
      });

      test('U-DL-TSK-54: respects filterType videos', () {
        notifier.removeTask(id);
        notifier.startDownload(url: 'hyd_url', destination: 'D', title: 'T', filterType: 'videos');
        id = notifier.state.first.id;
        
        final items = [
          const MediaInfo(id: '1', title: '1', originalUrl: 'U', isVideo: true),
          const MediaInfo(id: '2', title: '2', originalUrl: 'U', isVideo: false),
          const MediaInfo(id: '3', title: '3', originalUrl: 'U', isVideo: false),
        ];
        
        notifier.onHydrationFinished('hyd_url', items);
        final task = notifier.state.firstWhere((t) => t.id == id);
        expect(task.totalItems, 1); // 1 video
      });

      test('U-DL-TSK-55: no-op for non-matching URLs', () {
        final items = [const MediaInfo(id: '1', title: '1', originalUrl: 'U')];
        notifier.onHydrationFinished('wrong_url', items);
        
        final task = notifier.state.firstWhere((t) => t.id == id);
        expect(task.totalItems, 0); // unchanged
      });
    });

    // ═══════════════════════════════════════════════════════════════
    // Task Removal & Archival (16)
    // ═══════════════════════════════════════════════════════════════
    group('Task Removal & History Archival', () {
      test('U-DL-TSK-48: removeTask removes task from state', () {
        final notifier = container.read(downloadTaskProvider.notifier);
        notifier.startDownload(url: 'U', destination: 'D', title: 'T');
        final id = notifier.state.first.id;
        
        expect(notifier.state.length, 1);
        notifier.removeTask(id);
        expect(notifier.state, isEmpty);
      });

      test('U-DL-TSK-49: clearHistory keeps only running/pending/cancelling tasks', () {
        final notifier = container.read(downloadTaskProvider.notifier);
        // Inject states directly
        notifier.state = [
          DownloadTask(id: '1', url: 'U', destination: 'D', title: 'T', createdAt: DateTime.now(), status: DownloadStatus.running),
          DownloadTask(id: '2', url: 'U', destination: 'D', title: 'T', createdAt: DateTime.now(), status: DownloadStatus.completed),
          DownloadTask(id: '3', url: 'U', destination: 'D', title: 'T', createdAt: DateTime.now(), status: DownloadStatus.error),
          DownloadTask(id: '4', url: 'U', destination: 'D', title: 'T', createdAt: DateTime.now(), status: DownloadStatus.pending),
        ];
        
        notifier.clearHistory();
        expect(notifier.state.length, 2);
        expect(notifier.state.map((t) => t.status), containsAll([DownloadStatus.running, DownloadStatus.pending]));
      });
    });
    
    // ═══════════════════════════════════════════════════════════════
    // Derived Providers (20)
    // ═══════════════════════════════════════════════════════════════
    group('Derived Providers', () {
      test('U-DL-TSK-62: activeDownloadTaskProvider filters running/pending/cancelling', () {
        final notifier = container.read(downloadTaskProvider.notifier);
        notifier.state = [
          DownloadTask(id: '1', url: 'U', destination: 'D', title: 'T', createdAt: DateTime.now(), status: DownloadStatus.running),
          DownloadTask(id: '2', url: 'U', destination: 'D', title: 'T', createdAt: DateTime.now(), status: DownloadStatus.running),
          DownloadTask(id: '3', url: 'U', destination: 'D', title: 'T', createdAt: DateTime.now(), status: DownloadStatus.completed),
          DownloadTask(id: '4', url: 'U', destination: 'D', title: 'T', createdAt: DateTime.now(), status: DownloadStatus.pending),
        ];
        
        final active = container.read(activeDownloadTaskProvider);
        expect(active.length, 3);
      });

      test('U-DL-TSK-63: completedDownloadTaskProvider filters completed/error/cancelled', () {
        final notifier = container.read(downloadTaskProvider.notifier);
        notifier.state = [
          DownloadTask(id: '1', url: 'U', destination: 'D', title: 'T', createdAt: DateTime.now(), status: DownloadStatus.running),
          DownloadTask(id: '2', url: 'U', destination: 'D', title: 'T', createdAt: DateTime.now(), status: DownloadStatus.cancelled),
          DownloadTask(id: '3', url: 'U', destination: 'D', title: 'T', createdAt: DateTime.now(), status: DownloadStatus.error),
          DownloadTask(id: '4', url: 'U', destination: 'D', title: 'T', createdAt: DateTime.now(), status: DownloadStatus.completed),
        ];
        
        final completed = container.read(completedDownloadTaskProvider);
        expect(completed.length, 3);
      });
    });
  });
}
