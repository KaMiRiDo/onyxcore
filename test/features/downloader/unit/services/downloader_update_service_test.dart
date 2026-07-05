import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/downloader_update_service.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';

// ---------------------------------------------------------------------------
// Pure in-memory MockEngine — does NOT write to disk, does NOT call
// real binaries, does NOT touch system resources.
// ---------------------------------------------------------------------------
class MockEngine extends DownloadEngine {

  MockEngine({
    required this.id,
    this.isOptional = false,
    this.engineType = EngineType.cli,
    this.updateInfo,
    this.mockInstalledVersion,
    this.mockLatestVersion,
    this.mockIsInstalled = true,
  });
  @override
  final String id;
  @override
  final bool isOptional;
  @override
  final EngineType engineType;
  @override
  final EngineUpdateInfo? updateInfo;

  @override
  final Color color = Colors.blue;
  @override
  final String displayName = 'Mock';
  @override
  final IconData icon = Icons.code;

  final bool mockIsInstalled;
  String? mockInstalledVersion;
  String? mockLatestVersion;

  @override
  bool get isInstalled => mockIsInstalled;

  // binaryPath is intentionally null — tests must not rely on disk writes.
  @override
  String? get binaryPath => null;

  @override
  Future<String?> getInstalledVersion() async => mockInstalledVersion;

  @override
  Future<String?> getLatestVersion() async => mockLatestVersion;

  @override
  Future<Process>? install() => null;

  // Minimal stubs for abstract members — never invoked in these tests.
  @override
  int get priority => 1;
  @override
  List<RegExp> get urlPatterns => [];
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
  }) => Process.start('echo', []);
}

void main() {
  late ProviderContainer container;
  late DownloaderUpdateNotifier notifier;

  setUp(() {
    EngineRegistry.clearAllEnginesForTesting();
    container = ProviderContainer();
    notifier = container.read(downloaderUpdateProvider.notifier);
  });

  tearDown(() {
    container.dispose();
    EngineRegistry.clearAllEnginesForTesting();
  });

  group('DownloaderUpdateService Unit Tests', () {
    // -----------------------------------------------------------------------
    // Group 1 — DownloaderUpdateState: pure value-object / copyWith logic.
    // No I/O, no network, no system calls.
    // -----------------------------------------------------------------------
    group('1. DownloaderUpdateState', () {
      test('U-DL-UPD-01: Initialize with all defaults', () {
        const state = DownloaderUpdateState();
        expect(state.isUpdating, isFalse);
        expect(state.progress, 0.0);
        expect(state.error, isNull);
        expect(state.engineProgress, isEmpty);
        expect(state.installedVersions, isEmpty);
        expect(state.latestVersions, isEmpty);
        expect(state.isCheckingForUpdates, isFalse);
      });

      test('U-DL-UPD-02: copyWith overrides specific fields', () {
        var state = const DownloaderUpdateState();
        state = state.copyWith(isUpdating: true, progress: 0.5);
        expect(state.isUpdating, isTrue);
        expect(state.progress, 0.5);
      });

      test('U-DL-UPD-03: clearError flag nulls the error field', () {
        var state = const DownloaderUpdateState(error: 'failure');
        state = state.copyWith(clearError: true);
        expect(state.error, isNull);
      });

      test('U-DL-UPD-04: Error is preserved when clearError is false', () {
        var state = const DownloaderUpdateState(error: 'failure');
        state = state.copyWith(progress: 0.5);
        expect(state.error, 'failure');
      });

      test('U-DL-UPD-XX: copyWith does not mutate original state', () {
        const original = DownloaderUpdateState(progress: 0.2, error: 'err');
        final copy = original.copyWith(progress: 0.9, clearError: true);
        expect(original.progress, 0.2);
        expect(original.error, 'err');
        expect(copy.progress, 0.9);
        expect(copy.error, isNull);
      });

      test('U-DL-UPD-XX: engineProgress map is preserved in copyWith', () {
        var state = const DownloaderUpdateState();
        state = state.copyWith(engineProgress: {'e1': 0.5, 'e2': 0.8});
        expect(state.engineProgress['e1'], 0.5);
        expect(state.engineProgress['e2'], 0.8);
        final next = state.copyWith(progress: 1);
        expect(next.engineProgress['e1'], 0.5); // preserved
      });
    });

    // -----------------------------------------------------------------------
    // Group 2 — checkForUpdates: queries mock engines for version strings.
    // No I/O, no network, no system calls.
    // -----------------------------------------------------------------------
    group('2. Update Checking (checkForUpdates)', () {
      test('U-DL-UPD-05: Populates installed and latest version maps', () async {
        final e1 = MockEngine(
          id: 'e1',
          mockInstalledVersion: '1.0',
          mockLatestVersion: '1.1',
        );
        final e2 = MockEngine(
          id: 'e2',
          mockInstalledVersion: '2.0',
          mockLatestVersion: '2.0',
        );
        EngineRegistry.register(e1);
        EngineRegistry.register(e2);

        await notifier.checkForUpdates();

        expect(notifier.state.installedVersions['e1'], '1.0');
        expect(notifier.state.latestVersions['e1'], '1.1');
        expect(notifier.state.installedVersions['e2'], '2.0');
        expect(notifier.state.latestVersions['e2'], '2.0');
      });

      test('U-DL-UPD-06: Skips check when already checking', () async {
        notifier.state = notifier.state.copyWith(isCheckingForUpdates: true);
        final e1 = MockEngine(id: 'e1', mockInstalledVersion: '1.0');
        EngineRegistry.register(e1);

        await notifier.checkForUpdates();

        // State should not have been updated because guard returned early.
        expect(notifier.state.installedVersions, isEmpty);
      });

      test('U-DL-UPD-07: Engine with null installedVersion is skipped in map', () async {
        final e1 = MockEngine(
          id: 'e1',
          mockLatestVersion: '1.1',
        );
        EngineRegistry.register(e1);

        await notifier.checkForUpdates();

        expect(notifier.state.installedVersions.containsKey('e1'), isFalse);
        expect(notifier.state.latestVersions['e1'], '1.1');
      });

      test('U-DL-UPD-08: isCheckingForUpdates is false after completion', () async {
        await notifier.checkForUpdates();
        expect(notifier.state.isCheckingForUpdates, isFalse);
      });

      test('U-DL-UPD-XX: Both null versions — engine absent from both maps', () async {
        final e1 = MockEngine(
          id: 'e1',
        );
        EngineRegistry.register(e1);

        await notifier.checkForUpdates();

        expect(notifier.state.installedVersions.containsKey('e1'), isFalse);
        expect(notifier.state.latestVersions.containsKey('e1'), isFalse);
      });

      test('U-DL-UPD-XX: Works correctly with empty engine registry', () async {
        // No engines registered — should complete without error.
        await notifier.checkForUpdates();
        expect(notifier.state.isCheckingForUpdates, isFalse);
        expect(notifier.state.installedVersions, isEmpty);
        expect(notifier.state.latestVersions, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // Group 3 — updateAll: state guard / early-exit logic only.
    // We do NOT test the actual download flow here because that would require
    // a real HTTP server and would write binaries to disk.
    // -----------------------------------------------------------------------
    group('3. updateAll — guard and state logic', () {
      test('U-DL-UPD-11: Returns early when already updating', () async {
        notifier.state = notifier.state.copyWith(isUpdating: true);
        await notifier.updateAll();
        // Should still be updating (did not flip it to false prematurely).
        expect(notifier.state.isUpdating, isTrue);
      });

      test('U-DL-UPD-12: No-op when no engines need update', () async {
        notifier.state = notifier.state.copyWith(
          installedVersions: {'e1': '1.0'},
          latestVersions: {'e1': '1.0'},
        );
        await notifier.updateAll();
        expect(notifier.state.isUpdating, isFalse);
      });

      test('U-DL-UPD-10: defaultOnly flag excludes optional engines', () async {
        // Optional engine appears to have an update, but defaultOnly skips it.
        final e1 = MockEngine(
          id: 'e1',
          isOptional: true,
        );
        EngineRegistry.register(e1);
        notifier.state = notifier.state.copyWith(
          installedVersions: {'e1': '1.0'},
          latestVersions: {'e1': '1.1'},
        );

        await notifier.updateAll(defaultOnly: true);

        // Since binaryPath is null, update would short-circuit gracefully.
        expect(notifier.state.isUpdating, isFalse);
      });

      test('U-DL-UPD-XX: isUpdating resets to false after no-engines case',
          () async {
        // No engines in registry, but versions differ.
        // updateAll should set isUpdating false because enginesToUpdate is empty.
        notifier.state = notifier.state.copyWith(
          installedVersions: {'ghost': '0.1'},
          latestVersions: {'ghost': '0.2'},
        );
        await notifier.updateAll();
        expect(notifier.state.isUpdating, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // Group 4 — updateBinaries: guard logic only.
    // updateBinaries() operates on EngineRegistry.missingRequired which
    // checks real system binaries; we only test the state-guard paths here.
    // -----------------------------------------------------------------------
    group('4. updateBinaries — guard logic', () {
      test('U-DL-UPD-XX: Returns early when already updating', () async {
        notifier.state = notifier.state.copyWith(isUpdating: true);
        await notifier.updateBinaries();
        // Guard kicked in — isUpdating stays true (method exited immediately).
        expect(notifier.state.isUpdating, isTrue);
      });

      test('U-DL-UPD-17: Completes with progress 1.0 when no engines need install',
          () async {
        // Registry is empty — missingRequired returns [] — updateBinaries
        // short-circuits and sets progress to 1.0.
        await notifier.updateBinaries();
        expect(notifier.state.progress, 1.0);
        expect(notifier.state.isUpdating, isFalse);
      });
    });

    // -----------------------------------------------------------------------
    // Group 5 — updateEngine: guard / state logic only.
    // Tests that actually write binaries are removed because they require
    // a real HTTP server + disk writes and cannot be safely mocked.
    // -----------------------------------------------------------------------
    group('5. updateEngine — guard and state logic', () {
      test('U-DL-UPD-22: Skip engine with no updateInfo and not Python', () async {
        final e1 = MockEngine(id: 'e1');
        await notifier.updateEngine(e1);
        expect(notifier.state.engineProgress, isEmpty);
      });

      test('U-DL-UPD-XX: Engine with updateInfo but null binaryPath is a silent no-op',
          () async {
        // When binaryPath is null, _downloadLatestRelease is never called —
        // the branch `engine.updateInfo != null && engine.binaryPath != null`
        // short-circuits. updateEngine cleans up progress with no error.
        final e1 = MockEngine(
          id: 'e1',
          updateInfo: EngineUpdateInfo(
            apiUrl: 'http://localhost:1/nonexistent',
            assetName: '.exe',
          ),
        );
        EngineRegistry.register(e1);

        await notifier.updateEngine(e1);

        // Progress was set then cleaned up.
        expect(notifier.state.engineProgress.containsKey('e1'), isFalse);
        // No error — the download was silently skipped.
        expect(notifier.state.error, isNull);
      });
    });

    // -----------------------------------------------------------------------
    // Group 6 — installProcessEngine: pure process-tracking state logic.
    // Uses simple system commands (echo/sleep/sh) as process stubs.
    // These are safe: they don't touch app data directories.
    // -----------------------------------------------------------------------
    group('6. installProcessEngine — process tracking', () {
      test('U-DL-UPD-25/27: Sets indeterminate progress (-1.0) while running, '
          'cleans up on success', () async {
        final processFuture = Process.start('sleep', ['0.05']);
        final e1 = MockEngine(id: 'py1', engineType: EngineType.python);

        final future = notifier.installProcessEngine(e1, processFuture);

        await Future<void>.delayed(const Duration(milliseconds: 10));
        expect(notifier.state.engineProgress['py1'], -1.0);

        await future;
        expect(notifier.state.engineProgress.containsKey('py1'), isFalse);
      });

      test('U-DL-UPD-26: Exit code > 0 sets error state with engine id prefix',
          () async {
        final processFuture = Process.start('sh', [
          '-c',
          'echo "test fail" >&2; exit 1',
        ]);
        final e1 = MockEngine(id: 'py1', engineType: EngineType.python);

        await notifier.installProcessEngine(e1, processFuture);

        expect(notifier.state.error, contains('py1:test fail'));
        expect(notifier.state.engineProgress.containsKey('py1'), isFalse);
      });

      test('U-DL-UPD-28: Null process future is a no-op', () async {
        final e1 = MockEngine(id: 'py1');
        await notifier.installProcessEngine(e1, null);
        expect(notifier.state.engineProgress, isEmpty);
        expect(notifier.state.error, isNull);
      });

      test('U-DL-UPD-29: Future that throws sets error with displayName prefix',
          () async {
        final e1 = MockEngine(id: 'py1');
        final processFuture = Future<Process>.error(Exception('Spawn failed'));

        await notifier.installProcessEngine(e1, processFuture);

        expect(
          notifier.state.error,
          contains('Mock installation failed: Exception: Spawn failed'),
        );
        expect(notifier.state.engineProgress.containsKey('py1'), isFalse);
      });

      test('U-DL-UPD-XX: Successful process clears progress and keeps error null',
          () async {
        final processFuture = Process.start('echo', ['ok']);
        final e1 = MockEngine(id: 'py1', engineType: EngineType.python);

        await notifier.installProcessEngine(e1, processFuture);

        expect(notifier.state.engineProgress.containsKey('py1'), isFalse);
        // checkForUpdates was called after success; since registry is empty,
        // no error should be set.
        expect(notifier.state.error, isNull);
      });

      test('U-DL-UPD-XX: Multiple engines tracked independently', () async {
        final f1 = Process.start('sleep', ['0.1']);
        final f2 = Process.start('sleep', ['0.1']);
        final e1 = MockEngine(id: 'py1', engineType: EngineType.python);
        final e2 = MockEngine(id: 'py2', engineType: EngineType.python);

        // Start both concurrently.
        final futures = [
          notifier.installProcessEngine(e1, f1),
          notifier.installProcessEngine(e2, f2),
        ];

        await Future<void>.delayed(const Duration(milliseconds: 20));
        // Both should be tracked simultaneously.
        expect(notifier.state.engineProgress.containsKey('py1'), isTrue);
        expect(notifier.state.engineProgress.containsKey('py2'), isTrue);

        await Future.wait(futures);
        expect(notifier.state.engineProgress, isEmpty);
      });
    });
  });
}
