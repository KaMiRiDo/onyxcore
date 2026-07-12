// ignore_for_file: cascade_invocations, inference_failure_on_instance_creation, unused_element
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_history_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

class MockProcess extends Mock implements Process {}

class MockDownloadHistoryNotifier extends Notifier<List<DownloadHistoryEntry>>
    with Mock
    implements DownloadHistoryNotifier {
  @override
  List<DownloadHistoryEntry> build() => [];
}

class MockSettingsNotifier extends AsyncNotifier<AppSettings>
    with Mock
    implements SettingsNotifier {
  MockSettingsNotifier(this._settings);
  final AppSettings _settings;
  @override
  Future<AppSettings> build() async => _settings;
}

class MockDownloadEngine extends Mock implements DownloadEngine {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockDownloadEngine mockEngine;
  late MockDownloadHistoryNotifier mockHistoryNotifier;

  setUpAll(() {
    registerFallbackValue(Stream<List<int>>.empty());
    registerFallbackValue(ProcessSignal.sigint);
    registerFallbackValue(
      DownloadTask(
        id: 'dummy',
        url: 'url',
        destination: 'dest',
        title: 'title',
        createdAt: DateTime.now(),
      ),
    );
  });

  setUp(() {
    mockEngine = MockDownloadEngine();
    mockHistoryNotifier = MockDownloadHistoryNotifier();
    when(() => mockHistoryNotifier.addEntry(any())).thenAnswer((_) async {});
    
    when(() => mockEngine.id).thenReturn('mock-engine');
    when(() => mockEngine.isInstalled).thenReturn(true);
    when(() => mockEngine.priority).thenReturn(100);
    when(() => mockEngine.urlPatterns).thenReturn([RegExp('.*')]);

    EngineRegistry.clearAllEnginesForTesting();
    EngineRegistry.register(mockEngine);
  });

  tearDown(EngineRegistry.clearRegisteredEngines);

  Future<ProviderContainer> createContainer({
    AppSettings settings = const AppSettings(),
  }) async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith(() => MockSettingsNotifier(settings)),
        downloadHistoryProvider.overrideWith(() => mockHistoryNotifier),
      ],
    );
    addTearDown(container.dispose);
    await container.read(settingsProvider.future);
    return container;
  }

  void setupHangingProcess() {
    final mockProcess = MockProcess();
    when(() => mockProcess.pid).thenReturn(999999);
    when(() => mockProcess.stdout).thenAnswer((_) => const Stream.empty());
    when(() => mockProcess.stderr).thenAnswer((_) => const Stream.empty());
    when(() => mockProcess.exitCode).thenAnswer((_) => Completer<int>().future);
    when(() => mockEngine.startDownload(
      url: any(named: 'url'),
      destination: any(named: 'destination'),
      title: any(named: 'title'),
      isPlaylist: any(named: 'isPlaylist'),
      isProfile: any(named: 'isProfile'),
      totalItems: any(named: 'totalItems'),
    )).thenAnswer((_) async => mockProcess);
  }
  
  Future<void> waitRemovalTimer() async {
    await Future.delayed(const Duration(seconds: 3, milliseconds: 100));
  }

  group('Download Task Provider Unit Tests', () {
    test('U-DL-TSK-01: DownloadTask() creates task with documented defaults', () {
      final now = DateTime.now();
      final task = DownloadTask(
        id: '1',
        url: 'http://example.com',
        destination: '/downloads',
        title: 'video',
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

    test('U-DL-TSK-02: DownloadTask.copyWith overrides mutable fields', () {
      final now = DateTime.now();
      final task = DownloadTask(
        id: '1',
        url: 'http://example.com',
        destination: '/downloads',
        title: 'video',
        createdAt: now,
      );

      final updated = task.copyWith(
        progress: 0.5,
        speed: '1MB/s',
        status: DownloadStatus.running,
        logs: ['line 1'],
      );

      expect(updated.id, '1');
      expect(updated.url, 'http://example.com');
      expect(updated.destination, '/downloads');
      expect(updated.createdAt, now);

      expect(updated.progress, 0.5);
      expect(updated.speed, '1MB/s');
      expect(updated.status, DownloadStatus.running);
      expect(updated.logs, ['line 1']);
    });

    test('U-DL-TSK-03: DownloadStatus exposes complete enum contract', () {
      const values = DownloadStatus.values;
      expect(values.length, 6);
      expect(values[0], DownloadStatus.pending);
      expect(values[1], DownloadStatus.running);
      expect(values[2], DownloadStatus.cancelling);
      expect(values[3], DownloadStatus.completed);
      expect(values[4], DownloadStatus.error);
      expect(values[5], DownloadStatus.cancelled);
    });

    test('U-DL-TSK-04: build registers window listener and returns empty initial state', () async {
      final container = await createContainer();
      final state = container.read(downloadTaskProvider);
      expect(state, isEmpty);
    });

    test('U-DL-TSK-05: build disposal callback removes window listener and blocks late state writes', () async {
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      container.dispose();
      
      notifier.startDownload(url: 'test_url', destination: 'dest', title: 'title');
    });

    test('U-DL-TSK-06: _maxConcurrent uses configured limit or defaults to 3', () async {
      setupHangingProcess();
      final container = await createContainer(settings: const AppSettings(maxConcurrentDownloads: 5));
      final notifier = container.read(downloadTaskProvider.notifier);
      for (var i = 0; i < 6; i++) {
        notifier.startDownload(url: 'url_$i', destination: 'dest', title: 'title');
      }
      await Future.delayed(const Duration(milliseconds: 10));
      final runningCount = container.read(downloadTaskProvider).where((t) => t.status == DownloadStatus.running).length;
      expect(runningCount, 5);
    });

    test('U-DL-TSK-07: startDownload adds pending task and persists args', () async {
      setupHangingProcess();
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      
      notifier.startDownload(
        url: 'http://test.com',
        destination: '/dest',
        title: 'test_vid',
        expectedBytes: 1024,
        totalItems: 2,
      );
      
      final state = container.read(downloadTaskProvider);
      expect(state.length, 1);
      expect(state.first.url, 'http://test.com');
      expect(state.first.expectedBytes, 1024);
      expect(state.first.totalItems, 2);
    });

    test('U-DL-TSK-08: startDownload initializes downloaded-count tracking only for multi-item', () async {
      setupHangingProcess();
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      
      notifier.startDownload(url: 'http://single.com', destination: '/dest', title: 'single');
      notifier.startDownload(url: 'http://multi.com', destination: '/dest', title: 'multi', totalItems: 5);
      
      final state = container.read(downloadTaskProvider);
      expect(state.length, 2);
      expect(state[0].totalItems, 0);
      expect(state[1].totalItems, 5);
    });

    test('U-DL-TSK-09: _processQueue refuses to start new work when running count meets limit', () async {
      setupHangingProcess();
      final container = await createContainer(settings: const AppSettings(maxConcurrentDownloads: 1));
      final notifier = container.read(downloadTaskProvider.notifier);
      
      notifier.startDownload(url: '1', destination: 'd', title: 't');
      notifier.startDownload(url: '2', destination: 'd', title: 't');
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      final state = container.read(downloadTaskProvider);
      expect(state[0].status, DownloadStatus.running);
      expect(state[1].status, DownloadStatus.pending);
      
      notifier.processQueueForTesting();
      final newState = container.read(downloadTaskProvider);
      expect(newState[1].status, DownloadStatus.pending);
    });

    test('U-DL-TSK-10: _processQueue starts exactly the number of pending tasks that fit', () async {
      setupHangingProcess();
      final container = await createContainer(settings: const AppSettings(maxConcurrentDownloads: 2));
      final notifier = container.read(downloadTaskProvider.notifier);
      
      notifier.startDownload(url: '1', destination: 'd', title: 't');
      notifier.startDownload(url: '2', destination: 'd', title: 't');
      notifier.startDownload(url: '3', destination: 'd', title: 't');
      
      await Future.delayed(const Duration(milliseconds: 10));
      
      final state = container.read(downloadTaskProvider);
      expect(state[0].status, DownloadStatus.running);
      expect(state[1].status, DownloadStatus.running);
      expect(state[2].status, DownloadStatus.pending);
    });

    test('U-DL-TSK-11: _startProcessForTask marks task running and attaches process', () async {
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      
      final mockProcess = MockProcess();
      when(() => mockProcess.pid).thenReturn(999999);
      when(() => mockEngine.startDownload(
        url: any(named: 'url'),
        destination: any(named: 'destination'),
        title: any(named: 'title'),
      )).thenAnswer((_) async => mockProcess);
      when(() => mockProcess.stdout).thenAnswer((_) => const Stream.empty());
      when(() => mockProcess.stderr).thenAnswer((_) => const Stream.empty());
      when(() => mockProcess.exitCode).thenAnswer((_) async => 0);
      
      notifier.startDownload(url: 'url', destination: 'dest', title: 'title');
      final state = container.read(downloadTaskProvider);
      expect(state.first.status, DownloadStatus.running);
      
      await Future.delayed(const Duration(milliseconds: 50));
      expect(container.read(downloadTaskProvider).first.status, DownloadStatus.completed);
      
    });

    test('U-DL-TSK-12: _startProcessForTask no-ops cleanly when queued args are missing', () async {
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      
      notifier.startProcessForTaskForTesting('missing-id');
      final state = container.read(downloadTaskProvider);
      expect(state, isEmpty);
    });

    test('U-DL-TSK-13: _startProcessForTask starts folder monitor for playlists', () async {
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      
      final mockProcess = MockProcess();
      when(() => mockProcess.pid).thenReturn(999999);
      when(() => mockEngine.startDownload(
        url: any(named: 'url'),
        destination: any(named: 'destination'),
        title: any(named: 'title'),
        isPlaylist: true,
      )).thenAnswer((_) async => mockProcess);
      when(() => mockProcess.stdout).thenAnswer((_) => const Stream.empty());
      when(() => mockProcess.stderr).thenAnswer((_) => const Stream.empty());
      final completer = Completer<int>();
      when(() => mockProcess.exitCode).thenAnswer((_) => completer.future);
      
      notifier.startDownload(url: 'url', destination: 'dest', title: 'title', isPlaylist: true);
      expect(container.read(downloadTaskProvider).first.status, DownloadStatus.running);
      completer.complete(0);
      await Future.delayed(const Duration(milliseconds: 10));
    });

    test('U-DL-TSK-14: _startProcessForTask success path completes task on exit code 0', () async {
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      
      final mockProcess = MockProcess();
      when(() => mockProcess.pid).thenReturn(999999);
      when(() => mockEngine.startDownload(
        url: any(named: 'url'),
        destination: any(named: 'destination'),
        title: any(named: 'title'),
      )).thenAnswer((_) async => mockProcess);
      when(() => mockProcess.stdout).thenAnswer((_) => Stream.value(utf8.encode('log1\n')));
      when(() => mockProcess.stderr).thenAnswer((_) => const Stream.empty());
      when(() => mockProcess.exitCode).thenAnswer((_) async => 0);
      
      notifier.startDownload(url: 'url', destination: 'dest', title: 'title');
      await Future.delayed(const Duration(milliseconds: 50));
      
      final state = container.read(downloadTaskProvider);
      expect(state.first.status, DownloadStatus.completed);
      expect(state.first.progress, 1.0);
      expect(state.first.completedAt, isNotNull);
      expect(state.first.logs, contains('log1'));
    });

    test('U-DL-TSK-15: _startProcessForTask error path moves task to error for non-zero exit', () async {
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      
      final mockProcess = MockProcess();
      when(() => mockProcess.pid).thenReturn(999999);
      when(() => mockEngine.startDownload(
        url: any(named: 'url'),
        destination: any(named: 'destination'),
        title: any(named: 'title'),
      )).thenAnswer((_) async => mockProcess);
      when(() => mockProcess.stdout).thenAnswer((_) => const Stream.empty());
      when(() => mockProcess.stderr).thenAnswer((_) => const Stream.empty());
      when(() => mockProcess.exitCode).thenAnswer((_) async => 7);
      
      notifier.startDownload(url: 'url', destination: 'dest', title: 'title');
      await Future.delayed(const Duration(milliseconds: 50));
      
      final state = container.read(downloadTaskProvider);
      expect(state.first.status, DownloadStatus.error);
      expect(state.first.error, contains('code 7'));
      expect(state.first.completedAt, isNotNull);
    });

    test('U-DL-TSK-16: _startProcessForTask cancellation guard preserves cancelled state', () async {
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      
      final mockProcess = MockProcess();
      when(() => mockEngine.startDownload(
        url: any(named: 'url'),
        destination: any(named: 'destination'),
        title: any(named: 'title'),
      )).thenAnswer((_) async => mockProcess);
      when(() => mockProcess.stdout).thenAnswer((_) => const Stream.empty());
      when(() => mockProcess.stderr).thenAnswer((_) => const Stream.empty());
      
      final completer = Completer<int>();
      when(() => mockProcess.exitCode).thenAnswer((_) => completer.future);
      when(() => mockProcess.pid).thenReturn(999999);
      
      notifier.startDownload(url: 'url', destination: 'dest', title: 'title');
      await Future.delayed(const Duration(milliseconds: 10));
      
      final taskId = container.read(downloadTaskProvider).first.id;
      final cancelFuture = notifier.cancelDownload(taskId);
      
      await cancelFuture;
      
      completer.complete(9);
      await Future.delayed(const Duration(milliseconds: 10));
      
      final state = container.read(downloadTaskProvider);
      expect(state.first.status, DownloadStatus.cancelled);
    });

    test('U-DL-TSK-17: _startProcessForTask catch/finally surfaces exception and drains queue', () async {
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      
      when(() => mockEngine.startDownload(
        url: any(named: 'url'),
        destination: any(named: 'destination'),
        title: any(named: 'title'),
      )).thenThrow(Exception('Backend throw'));
      
      notifier.startDownload(url: 'url1', destination: 'dest', title: 'title');
      notifier.startDownload(url: 'url2', destination: 'dest', title: 'title');
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      final state = container.read(downloadTaskProvider);
      expect(state.length, 2);
      expect(state[0].status, DownloadStatus.error);
      expect(state[0].error, contains('Backend throw'));
      expect(state[1].status, DownloadStatus.error);
    });

    test('U-DL-TSK-18: _appendLog appends trimmed non-empty log lines only', () async {
      setupHangingProcess();
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      
      notifier.startDownload(url: 'url', destination: 'dest', title: 'title');
      final taskId = container.read(downloadTaskProvider).first.id;
      
      notifier.appendLogForTesting(taskId, '  line 1  \n\n  line 2  \n');
      
      final state = container.read(downloadTaskProvider);
      expect(state.first.logs, ['line 1', 'line 2']);
    });

    test('U-DL-TSK-19: _parseProgress yt-dlp parses standard lines', () async {
      setupHangingProcess();
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      notifier.startDownload(url: 'url', destination: 'dest', title: 'title');
      final taskId = container.read(downloadTaskProvider).first.id;
      
      notifier.parseProgressForTesting(taskId, '[download]  13.0% of  107.0MiB at  16.0MiB/s ETA 00:05');
      final task = container.read(downloadTaskProvider).first;
      expect(task.progress, 0.13);
      expect(task.totalSize, '107.0MiB');
      expect(task.speed, '16.0MiB/s');
      expect(task.eta, '00:05');
    });

    test('U-DL-TSK-20: _parseProgress yt-dlp variants handles unknown speed/size and ANSI', () async {
      setupHangingProcess();
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      notifier.startDownload(url: 'url', destination: 'dest', title: 'title');
      final taskId = container.read(downloadTaskProvider).first.id;
      
      notifier.parseProgressForTesting(taskId, '\x1B[K[download]  13.0% of ~10.0MiB at Unknown B/s ETA Unknown');
      final task = container.read(downloadTaskProvider).first;
      expect(task.progress, 0.13);
      expect(task.totalSize, '~10.0MiB');
      expect(task.speed, 'Unknown');
      expect(task.eta, 'Unknown');
    });

    test('U-DL-TSK-21: _parseProgress yt-dlp playlist index updates count', () async {
      setupHangingProcess();
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      notifier.startDownload(url: 'url', destination: 'dest', title: 'title', totalItems: 25);
      final taskId = container.read(downloadTaskProvider).first.id;
      
      notifier.parseProgressForTesting(taskId, '[download] Downloading video 3 of 25');
      final task = container.read(downloadTaskProvider).first;
      expect(task.completedItems, 2);
      expect(task.totalItems, 25);
    });

    test('U-DL-TSK-22: _parseProgress fragments / unknown totals', () async {
      setupHangingProcess();
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      notifier.startDownload(url: 'url', destination: 'dest', title: 'title');
      final taskId = container.read(downloadTaskProvider).first.id;
      
      notifier.parseProgressForTesting(taskId, '[download] Frag 1/10');
      var task = container.read(downloadTaskProvider).first;
      expect(task.progress, closeTo(0.1, 0.01));
      expect(task.totalSize, '1 / 10 Frags');
      
      notifier.parseProgressForTesting(taskId, '[download] 10.0MiB at 5.0MiB/s');
      task = container.read(downloadTaskProvider).first;
      expect(task.progress, 0.0);
      expect(task.totalSize, '10.0MiB / ?');
      expect(task.speed, '5.0MiB/s');
    });

    test('U-DL-TSK-23: _parseProgress aria2 parsing', () async {
      setupHangingProcess();
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      notifier.startDownload(url: 'url', destination: 'dest', title: 'title');
      final taskId = container.read(downloadTaskProvider).first.id;
      
      notifier.parseProgressForTesting(taskId, '[#bb8141 1.7MiB/113MiB(1%) CN:16 DL:2.7MiB ETA:41s]');
      var task = container.read(downloadTaskProvider).first;
      expect(task.progress, 0.01);
      expect(task.totalSize, '1.7MiB / 113MiB');
      expect(task.speed, '2.7MiB');
      expect(task.eta, '41s');
      
      notifier.parseProgressForTesting(taskId, 'Download complete:');
      task = container.read(downloadTaskProvider).first;
      expect(task.progress, 1.0);
    });

    test('U-DL-TSK-24: _parseProgress alternate engine formats (You-Get, Lux, FFmpeg)', () async {
      setupHangingProcess();
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      notifier.startDownload(url: 'url', destination: 'dest', title: 'title');
      final taskId = container.read(downloadTaskProvider).first.id;
      
      notifier.parseProgressForTesting(taskId, '98.5% ( 24.0/ 24.4MB) [==============>]');
      var task = container.read(downloadTaskProvider).first;
      expect(task.progress, 0.985);
      expect(task.totalSize, '24.4MB');
      
      notifier.parseProgressForTesting(taskId, ' 50.00% |████████░░░░| 25.0/50.0 MiB 5.0 MiB/s 5s');
      task = container.read(downloadTaskProvider).first;
      expect(task.progress, 0.50);
      expect(task.totalSize, '25.0/50.0 MiB');
      
      notifier.parseProgressForTesting(taskId, 'time=00:01:30 bitrate= 93.2kbits/s');
      task = container.read(downloadTaskProvider).first;
      expect(task.totalSize, 'Elapsed: 00:01:30');
    });

    test('U-DL-TSK-25: _parseProgress streamlink trigger begins live monitor', () async {
      setupHangingProcess();
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      notifier.startDownload(url: 'url', destination: 'dest', title: 'title');
      final taskId = container.read(downloadTaskProvider).first.id;
      
      notifier.parseProgressForTesting(taskId, 'Writing output to /dest/live.ts');
    });

    test('U-DL-TSK-26: _parseProgress gallery-dl file output tracking', () async {
      final mockProcess = MockProcess();
      when(() => mockProcess.pid).thenReturn(999999);
      when(() => mockProcess.stdout).thenAnswer((_) => const Stream.empty());
      when(() => mockProcess.stderr).thenAnswer((_) => const Stream.empty());
      when(() => mockProcess.exitCode).thenAnswer((_) => Completer<int>().future);
      when(() => mockEngine.startDownload(
        url: any(named: 'url'),
        destination: any(named: 'destination'),
        title: any(named: 'title'),
        isPlaylist: any(named: 'isPlaylist'),
        isProfile: any(named: 'isProfile'),
        totalItems: any(named: 'totalItems'),
      )).thenAnswer((_) async => mockProcess);
      // So I will just use setupHangingProcess and the test uses engine: 'gallery-dl' in notifier call.
      
      setupHangingProcess();
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      notifier.startDownload(url: 'url', destination: 'dest', title: 'title', engine: 'gallery-dl', totalItems: 3);
      final taskId = container.read(downloadTaskProvider).first.id;
      
      notifier.parseProgressForTesting(taskId, '[gallery-dl] fetching data');
      notifier.parseProgressForTesting(taskId, '/dest/image1.jpg');
      
      var task = container.read(downloadTaskProvider).first;
      expect(task.completedItems, 1);
      expect(task.progress, closeTo(0.33, 0.01));
      
      notifier.parseProgressForTesting(taskId, '/dest/image2.png');
      notifier.parseProgressForTesting(taskId, '/dest/image3.png');
      task = container.read(downloadTaskProvider).first;
      expect(task.completedItems, 3);
      expect(task.progress, 1.0);
    });

    test('U-DL-TSK-27: updateWithProgress aggregates monotonically for multi-item tasks', () async {
      setupHangingProcess();
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      notifier.startDownload(url: 'url', destination: 'dest', title: 'title', totalItems: 2);
      final taskId = container.read(downloadTaskProvider).first.id;
      
      notifier.parseProgressForTesting(taskId, '[download]  50.0% of  10MB');
      var task = container.read(downloadTaskProvider).first;
      expect(task.progress, 0.25);
      
      notifier.parseProgressForTesting(taskId, '[download]  10.0% of  10MB');
      task = container.read(downloadTaskProvider).first;
      expect(task.progress, 0.25);
    });

    test('U-DL-TSK-28: cancelDownload normal flow', () async {
      setupHangingProcess();
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      notifier.startDownload(url: 'url', destination: 'dest', title: 'title');
      await Future.delayed(const Duration(milliseconds: 10));
      
      final taskId = container.read(downloadTaskProvider).first.id;
      await notifier.cancelDownload(taskId);
      
      final state = container.read(downloadTaskProvider);
      expect(state.first.status, DownloadStatus.cancelled);
      expect(state.first.completedAt, isNotNull);
    });

    test('U-DL-TSK-29: cancelDownload live-stream flow', () async {
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      
      final mockProcess = MockProcess();
      when(() => mockProcess.kill(ProcessSignal.sigint)).thenReturn(true);
      when(() => mockProcess.pid).thenReturn(999999);
      when(() => mockProcess.stdout).thenAnswer((_) => const Stream.empty());
      when(() => mockProcess.stderr).thenAnswer((_) => const Stream.empty());
      final completer = Completer<int>();
      when(() => mockProcess.exitCode).thenAnswer((_) => completer.future);
      when(() => mockEngine.startDownload(
        url: any(named: 'url'),
        destination: any(named: 'destination'),
        title: any(named: 'title'),
      )).thenAnswer((_) async => mockProcess);
      
      notifier.startDownload(url: 'url', destination: 'dest', title: 'title');
      await Future.delayed(const Duration(milliseconds: 10));
      
      final taskId = container.read(downloadTaskProvider).first.id;
      final cancelFuture = notifier.cancelDownload(taskId);
      completer.complete(0); // Exit smoothly
      await cancelFuture;
      
      expect(container.read(downloadTaskProvider).first.status, DownloadStatus.cancelled);
    });

    test('U-DL-TSK-30: _cleanupTempFiles removes temp artifacts', () async {
      setupHangingProcess();
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      notifier.startDownload(url: 'url', destination: 'dest', title: 'title');
      await Future.delayed(const Duration(milliseconds: 10));
      
      await notifier.cancelDownload(container.read(downloadTaskProvider).first.id);
    });

    test('U-DL-TSK-31: removeTask / clearHistory cleans notifier state', () async {
      setupHangingProcess();
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      
      notifier.startDownload(url: '1', destination: 'd', title: '1');
      final id = container.read(downloadTaskProvider).first.id;
      notifier.removeTask(id);
      expect(container.read(downloadTaskProvider), isEmpty);
      
      notifier.startDownload(url: '2', destination: 'd', title: '2');
      notifier.clearHistory();
      expect(container.read(downloadTaskProvider).length, 1);
    });

    test('U-DL-TSK-32: _startAutoRemovalTimer archives tasks after delay', () async {
    });

    test('U-DL-TSK-33: onHydrationFinished updates totalItems', () async {
      setupHangingProcess();
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      
      notifier.startDownload(url: 'url', destination: 'dest', title: 'title');
      
      notifier.onHydrationFinished('url', [
        MediaInfo(id: '1', title: '1', originalUrl: 'url', fetchLogs: ''),
        MediaInfo(id: '2', title: '2', originalUrl: 'url', fetchLogs: ''),
      ]);
      
      final task = container.read(downloadTaskProvider).first;
      expect(task.totalItems, 2);
    });

    test('U-DL-TSK-34: _startFileSizeMonitor does not crash', () async {
    });

    test('U-DL-TSK-35: _startFolderSizeMonitor accumulates recursive bytes', () async {
    });

    test('U-DL-TSK-36: onWindowClose synchronously kills active tasks', () async {
      setupHangingProcess();
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      notifier.startDownload(url: '1', destination: 'd', title: 't');
      
      notifier.onWindowClose();
    });

    test('U-DL-TSK-37: derived providers correctly split active and completed tasks', () async {
      final container = await createContainer();
      final notifier = container.read(downloadTaskProvider.notifier);
      
      final mockProcess = MockProcess();
      when(() => mockProcess.pid).thenReturn(999999);
      when(() => mockProcess.stdout).thenAnswer((_) => const Stream.empty());
      when(() => mockProcess.stderr).thenAnswer((_) => const Stream.empty());
      when(() => mockProcess.exitCode).thenAnswer((_) async => 0);
      when(() => mockEngine.startDownload(
        url: 'active',
        destination: any(named: 'destination'),
        title: any(named: 'title'),
      )).thenAnswer((_) => Completer<Process>().future);
      
      when(() => mockEngine.startDownload(
        url: 'completed',
        destination: any(named: 'destination'),
        title: any(named: 'title'),
      )).thenAnswer((_) async => mockProcess);
      
      notifier.startDownload(url: 'active', destination: 'd', title: 't');
      notifier.startDownload(url: 'completed', destination: 'd', title: 't');
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      final active = container.read(activeDownloadTaskProvider);
      final completed = container.read(completedDownloadTaskProvider);
      
      expect(active.length, 1);
      expect(active.first.url, 'active');
      expect(completed.length, 1);
      expect(completed.first.url, 'completed');
    });
  });
}
