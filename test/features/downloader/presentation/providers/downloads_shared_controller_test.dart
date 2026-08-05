// ignore_for_file: cascade_invocations
import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_shared_controller.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

class MockDownloadEngine extends Mock implements DownloadEngine {}

class MockDownloadTaskNotifier extends Notifier<List<DownloadTask>>
    with Mock
    implements DownloadTaskNotifier {
  @override
  List<DownloadTask> build() => [];
}

class MockSettingsNotifier extends AsyncNotifier<AppSettings>
    with Mock
    implements SettingsNotifier {
  MockSettingsNotifier(this._settings);
  final AppSettings _settings;
  @override
  Future<AppSettings> build() async => _settings;
}

void main() {
  late MockDownloadEngine mockEngine;
  late MockDownloadTaskNotifier mockTaskNotifier;

  setUpAll(() {
    registerFallbackValue(MediaInfo(id: '', title: '', originalUrl: '', isVideo: false));
  });

  setUp(() {
    mockEngine = MockDownloadEngine();
    mockTaskNotifier = MockDownloadTaskNotifier();

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
        downloadTaskProvider.overrideWith(() => mockTaskNotifier),
      ],
    );
    addTearDown(container.dispose);
    await container.read(settingsProvider.future);
    return container;
  }

  group('Downloads Shared Controller Unit Tests', () {
    test('U-DL-SHC-01: constructor / fields initialize derived counters predictably', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);

      expect(controller.totalListSize, 0);
      expect(controller.totalListImages, 0);
      expect(controller.totalListVideos, 0);
      expect(controller.hasUnderestimatedSize, false);
      expect(controller.backgroundLoadingProfiles, isEmpty);
      expect(controller.activeHydrationPids, isEmpty);
      expect(controller.hydrationNotifier.value, 0);
    });

    test('U-DL-SHC-02: dispose stops future notifications', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      var notified = false;
      controller.addListener(() => notified = true);
      
      controller.dispose();
      controller.recalculateFilteredStatistics();
      
      expect(notified, false);
    });

    test('U-DL-SHC-03: cache getter reads the shared list cache', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      final cache = container.read(downloadsListCacheProvider);
      
      expect(controller.cache, equals(cache));
    });

    test('U-DL-SHC-04: recalculateFilteredStatistics null path zeros out', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      controller.totalListSize = 100;
      controller.cache.parsedItems = null;
      
      var notified = false;
      controller.addListener(() => notified = true);
      
      controller.recalculateFilteredStatistics();
      
      expect(controller.totalListSize, 0);
      expect(notified, true);
    });

    test('U-DL-SHC-05: recalculateFilteredStatistics normal mode sums images and videos', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      final group = MediaGroup(
        originalUrl: 'url',
        items: [
          MediaInfo(id: '1', title: 'v1', originalUrl: 'url', filesize: 100),
          MediaInfo(id: '2', title: 'i1', isVideo: false, originalUrl: 'url', filesize: 50),
          MediaInfo(id: '3', title: 'err', originalUrl: 'url', filesize: 200, isError: true),
        ],
      );
      
      controller.cache.parsedItems = [group];
      controller.cache.configs[0] = DownloadConfig();
      
      controller.recalculateFilteredStatistics();
      
      expect(controller.totalListSize, 150);
      expect(controller.totalListVideos, 1);
      expect(controller.totalListImages, 1);
    });

    test('U-DL-SHC-06: recalculateFilteredStatistics underestimated flag', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      final group = MediaGroup(
        originalUrl: 'url',
        items: [MediaInfo(id: '1', title: 'p', isVideo: false, originalUrl: 'url', isPlaylist: true)],
      );
      
      controller.cache.parsedItems = [group];
      controller.recalculateFilteredStatistics();
      
      expect(controller.hasUnderestimatedSize, true);
    });

    test('U-DL-SHC-07: _getGroupBytes normal mode filters branch sizes', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      final group = MediaGroup(
        originalUrl: 'url',
        items: [
          MediaInfo(id: '1', title: 'v1', originalUrl: 'url', filesize: 100),
          MediaInfo(id: '2', title: 'i1', isVideo: false, originalUrl: 'url', filesize: 50),
        ],
      );
      controller.cache.parsedItems = [group];
      
      // Video only
      controller.cache.configs[0] = DownloadConfig(groupFilter: GroupDownloadType.videos);
      controller.recalculateFilteredStatistics();
      expect(controller.totalListSize, 100);
      
      // Image only
      controller.cache.configs[0] = DownloadConfig(groupFilter: GroupDownloadType.images);
      controller.recalculateFilteredStatistics();
      expect(controller.totalListSize, 50);
    });

    test('U-DL-SHC-08: _getGroupBytes item-format mode', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      final group = MediaGroup(originalUrl: 'url', items: [
        MediaInfo(id: '1', title: 'v1', originalUrl: 'url')
      ]);
      controller.cache.parsedItems = [group];
      
      final config = DownloadConfig(mode: DownloadMode.mute);
      config.itemFormats['1'] = MediaFormat(formatId: 'fmt_1', extension: 'mp4', formatString: 'fmt1', resolution: '720p', filesize: 80);
      controller.cache.configs[0] = config;
      
      controller.recalculateFilteredStatistics();
      expect(controller.totalListSize, 80);
      
      config.itemFormats.clear();
      controller.recalculateFilteredStatistics();
      expect(controller.totalListSize, 0);
    });

    test('U-DL-SHC-09: _getHeight parses numeric resolution via hydrateProfile sorting', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      when(() => mockEngine.fetchMetadata(
        url: any(named: 'url'),
        browser: any(named: 'browser'),
        fetchDeep: any(named: 'fetchDeep'),
        isPlaylist: any(named: 'isPlaylist'),
        onProgress: any(named: 'onProgress'),
        onProcessStarted: any(named: 'onProcessStarted'),
      )).thenAnswer((_) async => [
        MediaInfo(
          id: 'v1',
          title: 'vid',
          originalUrl: 'url',
          formats: [
            MediaFormat(formatId: 'f1', extension: 'mp4', formatString: 'f1', resolution: '720p', filesize: 100),
            MediaFormat(formatId: 'f2', extension: 'mp4', formatString: 'f2', resolution: '1080p', filesize: 200),
            MediaFormat(formatId: 'f3', extension: 'mp4', formatString: 'f3', resolution: 'best', filesize: 50),
          ]
        )
      ]);
      
      controller.cache.parsedItems = [
        MediaGroup(originalUrl: 'url', items: [MediaInfo(id: 'p', title: 'p', isVideo: false, originalUrl: 'url', isProfile: true)])
      ];
      controller.cache.configs[0] = DownloadConfig();
      
      await controller.hydrateProfile('url');
      
      final config = controller.cache.configs[0]!;
      expect(config.format?.resolution, '1080p');
    });

    test('U-DL-SHC-10: analyzeUrls input parsing', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      when(() => mockEngine.fetchMetadata(
        url: any(named: 'url'),
        browser: any(named: 'browser'),
        fetchDeep: any(named: 'fetchDeep'),
        isPlaylist: any(named: 'isPlaylist'),
        onProgress: any(named: 'onProgress'),
        onProcessStarted: any(named: 'onProcessStarted'),
      )).thenAnswer((_) async => [MediaInfo(id: '1', title: 't', originalUrl: 'url', isVideo: false)]);
      
      await controller.analyzeUrls(' url1 \nurl2\n\nurl1');
      
      expect(controller.cache.parsedItems?.length, 2);
      expect(controller.cache.parsedItems?[0].originalUrl, 'url1');
      expect(controller.cache.parsedItems?[1].originalUrl, 'url2');
    });

    test('U-DL-SHC-11: analyzeUrls placeholder insertion', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      final completer = Completer<List<MediaInfo>>();
      when(() => mockEngine.fetchMetadata(
        url: any(named: 'url'),
        browser: any(named: 'browser'),
        fetchDeep: any(named: 'fetchDeep'),
        isPlaylist: any(named: 'isPlaylist'),
        onProgress: any(named: 'onProgress'),
        onProcessStarted: any(named: 'onProcessStarted'),
      )).thenAnswer((_) => completer.future);
      
      final future = controller.analyzeUrls('url1');
      
      expect(controller.cache.parsedItems?.length, 1);
      expect(controller.cache.parsedItems?.first.items.first.id, 'fetch_loading');
      expect(controller.backgroundLoadingProfiles, contains('url1'));
      expect(controller.cache.configs.containsKey(0), true);
      
      completer.complete([MediaInfo(id: '1', title: '1', originalUrl: 'url1', isVideo: false)]);
      await future;
    });

    test('U-DL-SHC-12: analyzeUrls duplicate guard', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      controller.cache.parsedItems = [
        MediaGroup(originalUrl: 'url1', items: [MediaInfo(id: '1', title: '1', originalUrl: 'url1', isVideo: false)])
      ];
      
      when(() => mockEngine.fetchMetadata(
        url: any(named: 'url'),
        browser: any(named: 'browser'),
        fetchDeep: any(named: 'fetchDeep'),
        isPlaylist: any(named: 'isPlaylist'),
        onProgress: any(named: 'onProgress'),
        onProcessStarted: any(named: 'onProcessStarted'),
      )).thenAnswer((_) async => [MediaInfo(id: 'updated', title: '1', originalUrl: 'url1', isVideo: false)]);

      await controller.analyzeUrls('url1');
      
      expect(controller.cache.parsedItems?.length, 1);
      expect(controller.cache.parsedItems?.first.items.first.id, 'updated');
    });

    test('U-DL-SHC-13: analyzeUrls process-start callback tracks pids', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      when(() => mockEngine.fetchMetadata(
        url: any(named: 'url'),
        browser: any(named: 'browser'),
        fetchDeep: any(named: 'fetchDeep'),
        isPlaylist: any(named: 'isPlaylist'),
        onProgress: any(named: 'onProgress'),
        onProcessStarted: any(named: 'onProcessStarted'),
      )).thenAnswer((invocation) async {
        final onProcessStarted = invocation.namedArguments[#onProcessStarted] as void Function(int)?;
        onProcessStarted?.call(12345);
        return [MediaInfo(id: '1', title: '1', originalUrl: 'url1', isVideo: false)];
      });
      
      var notified = false;
      controller.addListener(() {
        if (controller.activeHydrationPids.containsKey('url1')) notified = true;
      });
      
      await controller.analyzeUrls('url1');
      
      expect(notified, true);
    });

    test('U-DL-SHC-14: analyzeUrls empty result branch inserts error group', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      when(() => mockEngine.fetchMetadata(
        url: any(named: 'url'),
        browser: any(named: 'browser'),
        fetchDeep: any(named: 'fetchDeep'),
        isPlaylist: any(named: 'isPlaylist'),
        onProgress: any(named: 'onProgress'),
        onProcessStarted: any(named: 'onProcessStarted'),
      )).thenAnswer((_) async => []);
      
      await controller.analyzeUrls('url1');
      
      final group = controller.cache.parsedItems!.first;
      expect(group.items.first.id, '');
      expect(group.items.first.isError, true);
    });

    test('U-DL-SHC-15: analyzeUrls success branch replaces placeholder and triggers deep hydration', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      var fetchDeepCalled = false;
      when(() => mockEngine.fetchMetadata(
        url: any(named: 'url'),
        browser: any(named: 'browser'),
        fetchDeep: any(named: 'fetchDeep'),
        isPlaylist: any(named: 'isPlaylist'),
        onProgress: any(named: 'onProgress'),
        onProcessStarted: any(named: 'onProcessStarted'),
      )).thenAnswer((invocation) async {
        if (invocation.namedArguments[#fetchDeep] == true) {
          fetchDeepCalled = true;
          return [MediaInfo(id: 'p1', title: 'p', originalUrl: 'url')];
        }
        return [MediaInfo(id: 'playlist', title: 'list', originalUrl: 'url', isVideo: false, isPlaylist: true)];
      });
      
      await controller.analyzeUrls('url1');
      
      expect(fetchDeepCalled, true);
    });

    test('U-DL-SHC-16: analyzeUrls catchError clears state', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      when(() => mockEngine.fetchMetadata(
        url: any(named: 'url'),
        browser: any(named: 'browser'),
        fetchDeep: any(named: 'fetchDeep'),
        isPlaylist: any(named: 'isPlaylist'),
        onProgress: any(named: 'onProgress'),
        onProcessStarted: any(named: 'onProcessStarted'),
      )).thenThrow(Exception('fetch fail'));
      
      await controller.analyzeUrls('url1');
      
      expect(controller.backgroundLoadingProfiles, isEmpty);
      expect(controller.activeHydrationPids, isEmpty);
    });

    test('U-DL-SHC-17: hydrateProfile startup marks URL and sets flags', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      controller.cache.parsedItems = [
        MediaGroup(originalUrl: 'url', items: [MediaInfo(id: '1', title: 'p', originalUrl: 'url', isVideo: false, isPlaylist: true)])
      ];
      
      final completer = Completer<List<MediaInfo>>();
      when(() => mockEngine.fetchMetadata(
        url: any(named: 'url'),
        browser: any(named: 'browser'),
        fetchDeep: any(named: 'fetchDeep'),
        isPlaylist: any(named: 'isPlaylist'),
        onProgress: any(named: 'onProgress'),
        onProcessStarted: any(named: 'onProcessStarted'),
      )).thenAnswer((invocation) {
        expect(invocation.namedArguments[#fetchDeep], true);
        expect(invocation.namedArguments[#isPlaylist], true);
        return completer.future;
      });
      
      final future = controller.hydrateProfile('url');
      expect(controller.backgroundLoadingProfiles, contains('url'));
      
      completer.complete([]);
      await future;
    });

    test('U-DL-SHC-18: hydrateProfile progressive updates append/replace items', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      controller.cache.parsedItems = [
        MediaGroup(originalUrl: 'url', items: [
          MediaInfo(id: 'header', title: 'h', originalUrl: 'url', isVideo: false, isPlaylist: true),
          MediaInfo(id: 'hydration_loading', title: 'loading', originalUrl: 'url', isVideo: false),
        ])
      ];
      
      when(() => mockEngine.fetchMetadata(
        url: any(named: 'url'),
        browser: any(named: 'browser'),
        fetchDeep: any(named: 'fetchDeep'),
        isPlaylist: any(named: 'isPlaylist'),
        onProgress: any(named: 'onProgress'),
        onProcessStarted: any(named: 'onProcessStarted'),
      )).thenAnswer((invocation) async {
        final onProgress = invocation.namedArguments[#onProgress] as void Function(MediaInfo)?;
        onProgress?.call(MediaInfo(id: 'i1', title: 'i1', originalUrl: 'url', fetchLogs: 'logs'));
        
        // At this point, group.items should be: header, i1, hydration_loading
        var group = controller.cache.parsedItems!.first;
        expect(group.items.length, 3);
        expect(group.items[1].id, 'i1');
        expect(group.items[2].id, 'hydration_loading');

        onProgress?.call(MediaInfo(id: 'i1', title: 'i1_updated', originalUrl: 'url'));
        
        // Still 3 items, i1 is replaced
        group = controller.cache.parsedItems!.first;
        expect(group.items.length, 3);
        expect(group.items[1].title, 'i1_updated');

        return [MediaInfo(id: 'final', title: 'final', originalUrl: 'url')];
      });
      
      await controller.hydrateProfile('url');
    });
    
    test('U-DL-SHC-19: hydrateProfile duplicate profile guard ignores fallback profiles', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      controller.cache.parsedItems = [
        MediaGroup(originalUrl: 'url', items: [
          MediaInfo(id: 'p1', title: 'p', originalUrl: 'url', isVideo: false, isProfile: true)
        ])
      ];
      
      when(() => mockEngine.fetchMetadata(
        url: any(named: 'url'),
        browser: any(named: 'browser'),
        fetchDeep: any(named: 'fetchDeep'),
        isPlaylist: any(named: 'isPlaylist'),
        onProgress: any(named: 'onProgress'),
        onProcessStarted: any(named: 'onProcessStarted'),
      )).thenAnswer((invocation) async {
        final onProgress = invocation.namedArguments[#onProgress] as void Function(MediaInfo)?;
        onProgress?.call(MediaInfo(id: 'p2', title: 'fallback', originalUrl: 'url', isVideo: false, isProfile: true));
        
        // p2 is skipped because p1 is already there
        final group = controller.cache.parsedItems!.first;
        expect(group.items.length, 1);
        expect(group.items.first.id, 'p1');

        return [MediaInfo(id: 'p1', title: 'p', originalUrl: 'url', isVideo: false, isProfile: true)];
      });
      
      await controller.hydrateProfile('url');
    });

    test('U-DL-SHC-20: hydrateProfile throttled stats recalculate every 5th update', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      controller.cache.parsedItems = [
        MediaGroup(originalUrl: 'url', items: [MediaInfo(id: '1', title: '1', originalUrl: 'url', isVideo: false)])
      ];
      
      when(() => mockEngine.fetchMetadata(
        url: any(named: 'url'),
        browser: any(named: 'browser'),
        fetchDeep: any(named: 'fetchDeep'),
        isPlaylist: any(named: 'isPlaylist'),
        onProgress: any(named: 'onProgress'),
        onProcessStarted: any(named: 'onProcessStarted'),
      )).thenAnswer((invocation) async {
        final onProgress = invocation.namedArguments[#onProgress] as void Function(MediaInfo)?;
        for (var i = 0; i < 6; i++) {
          onProgress?.call(MediaInfo(id: 'i$i', title: 'i', originalUrl: 'url'));
        }
        return [];
      });
      
      await controller.hydrateProfile('url');
      expect(controller.pendingStatsUpdate, 6);
    });

    test('U-DL-SHC-21: hydrateProfile final replacement preserves header and logs', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      controller.cache.parsedItems = [
        MediaGroup(originalUrl: 'url', items: [
          MediaInfo(id: 'head', title: 'h', originalUrl: 'url', isVideo: false, isPlaylist: true)
        ])
      ];
      
      when(() => mockEngine.fetchMetadata(
        url: any(named: 'url'),
        browser: any(named: 'browser'),
        fetchDeep: any(named: 'fetchDeep'),
        isPlaylist: any(named: 'isPlaylist'),
        onProgress: any(named: 'onProgress'),
        onProcessStarted: any(named: 'onProcessStarted'),
      )).thenAnswer((_) async => [
        MediaInfo(id: 'i1', title: 'i', originalUrl: 'url', errorMessage: 'err', fetchLogs: 'logs')
      ]);
      
      await controller.hydrateProfile('url');
      
      final group = controller.cache.parsedItems!.first;
      expect(group.items.length, 2);
      expect(group.items[0].id, 'head');
      expect(group.items[0].errorMessage, 'err');
      expect(group.items[0].fetchLogs, contains('logs'));
      expect(group.items[1].id, 'i1');
    });

    test('U-DL-SHC-22: hydrateProfile generic sorting', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      controller.cache.parsedItems = [
        MediaGroup(originalUrl: 'url', items: [
          MediaInfo(id: 'h', title: 'h', originalUrl: 'url', isVideo: false, isPlaylist: true, extractor: 'generic')
        ])
      ];
      
      when(() => mockEngine.fetchMetadata(
        url: any(named: 'url'),
        browser: any(named: 'browser'),
        fetchDeep: any(named: 'fetchDeep'),
        isPlaylist: any(named: 'isPlaylist'),
        onProgress: any(named: 'onProgress'),
        onProcessStarted: any(named: 'onProcessStarted'),
      )).thenAnswer((_) async => [
        MediaInfo(id: 'i1', title: 'i1', originalUrl: 'url', filesize: 100, duration: 10),
        MediaInfo(id: 'i2', title: 'i2', originalUrl: 'url', filesize: 200, duration: 10),
        MediaInfo(id: 'i3', title: 'i3', originalUrl: 'url', filesize: 50, duration: 20),
      ]);
      
      await controller.hydrateProfile('url');
      
      final items = controller.cache.parsedItems!.first.items;
      // Header, then i3 (longest duration), then i2 (largest size of duration 10), then i1
      expect(items[1].id, 'i3');
      expect(items[2].id, 'i2');
      expect(items[3].id, 'i1');
    });

    test('U-DL-SHC-23: hydrateProfile format auto-selection chooses best video format', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      controller.cache.parsedItems = [
        MediaGroup(originalUrl: 'url', items: [
          MediaInfo(id: 'h', title: 'h', originalUrl: 'url', isVideo: false, isPlaylist: true)
        ])
      ];
      controller.cache.configs[0] = DownloadConfig(itemFormats: {'old': MediaFormat(formatId: 'old_fmt', extension: 'mp4', formatString: 'old', resolution: '360p')});
      
      when(() => mockEngine.fetchMetadata(
        url: any(named: 'url'),
        browser: any(named: 'browser'),
        fetchDeep: any(named: 'fetchDeep'),
        isPlaylist: any(named: 'isPlaylist'),
        onProgress: any(named: 'onProgress'),
        onProcessStarted: any(named: 'onProcessStarted'),
      )).thenAnswer((_) async => [
        MediaInfo(id: 'i1', title: 'i1', originalUrl: 'url', formats: [
          MediaFormat(formatId: '4k', extension: 'mp4', formatString: '4k', resolution: '4K', filesize: 5000),
          MediaFormat(formatId: '1080', extension: 'mp4', formatString: '1080', resolution: '1080p', filesize: 2000),
        ]),
      ]);
      
      await controller.hydrateProfile('url');
      
      final config = controller.cache.configs[0]!;
      expect(config.itemFormats, isEmpty);
      expect(config.format?.resolution, '1080p');
    });

    test('U-DL-SHC-24: hydrateProfile completion and callback forwards results', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      controller.cache.parsedItems = [MediaGroup(originalUrl: 'url', items: [])];
      
      final items = [MediaInfo(id: '1', title: '1', originalUrl: 'url')];
      when(() => mockEngine.fetchMetadata(
        url: any(named: 'url'),
        browser: any(named: 'browser'),
        fetchDeep: any(named: 'fetchDeep'),
        isPlaylist: any(named: 'isPlaylist'),
        onProgress: any(named: 'onProgress'),
        onProcessStarted: any(named: 'onProcessStarted'),
      )).thenAnswer((_) async => items);
      
      var notifierCalled = false;
      when(() => mockTaskNotifier.onHydrationFinished('url', items)).thenAnswer((_) {
        notifierCalled = true;
      });
      
      await controller.hydrateProfile('url');
      expect(notifierCalled, true);
      expect(controller.hydrationNotifier.value, 1);
    });

    test('U-DL-SHC-25: hydrateProfile error path clears loading flag', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      when(() => mockEngine.fetchMetadata(
        url: any(named: 'url'),
        browser: any(named: 'browser'),
        fetchDeep: any(named: 'fetchDeep'),
        isPlaylist: any(named: 'isPlaylist'),
        onProgress: any(named: 'onProgress'),
        onProcessStarted: any(named: 'onProcessStarted'),
      )).thenThrow(Exception('deep error'));
      
      await controller.hydrateProfile('url');
      
      expect(controller.backgroundLoadingProfiles, isEmpty);
    });

    test('U-DL-SHC-26: importListFromFile cache hit switches list', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      controller.cache.switchList('/path/to/list.json');
      controller.cache.parsedItems = [];
      controller.cache.switchList('default');
      
      await controller.importListFromFile('/path/to/list.json', 'list.json');
      
      expect(controller.cache.importedListPath, isNull); // Because it returned early and just switched active path
      expect(controller.cache.parsedItems, isEmpty);
    });

    test('U-DL-SHC-27: importListFromFile JSON / text handling', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      final tempDir = await Directory.systemTemp.createTemp();
      final jsonFile = File('${tempDir.path}/test.json');
      final textFile = File('${tempDir.path}/test.txt');
      
      await jsonFile.writeAsString('[{"originalUrl": "url1", "items": [{"id": "1", "title": "t", "originalUrl": "url1", "isVideo": false}]}]');
      await textFile.writeAsString('url2');
      
      when(() => mockEngine.fetchMetadata(
        url: 'url2',
        browser: any(named: 'browser'),
        fetchDeep: any(named: 'fetchDeep'),
        isPlaylist: any(named: 'isPlaylist'),
        onProgress: any(named: 'onProgress'),
        onProcessStarted: any(named: 'onProcessStarted'),
      )).thenAnswer((_) async => [MediaInfo(id: '2', title: 't2', originalUrl: 'url2', isVideo: false)]);
      
      await controller.importListFromFile(jsonFile.path, 'test.json');
      expect(controller.cache.parsedItems?.length, 1);
      expect(controller.cache.configs.containsKey(0), true);
      
      await controller.importListFromFile(textFile.path, 'test.txt');
      // textFile delegates to analyzeUrls
      expect(controller.cache.parsedItems?.first.originalUrl, 'url2');
      
      await tempDir.delete(recursive: true);
    });

    test('U-DL-SHC-28: exportListToFile saves JSON and txt', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);
      
      final tempDir = await Directory.systemTemp.createTemp();
      final jsonFile = File('${tempDir.path}/out.json');
      final textFile = File('${tempDir.path}/out.txt');
      
      controller.cache.parsedItems = [
        MediaGroup(originalUrl: 'url3', items: [MediaInfo(id: '3', title: 't3', originalUrl: 'url3', isVideo: false)])
      ];
      controller.totalListSize = 1000;
      
      await controller.exportListToFile(jsonFile.path);
      final jsonContent = await jsonFile.readAsString();
      expect(jsonContent, contains('url3'));
      expect(jsonContent, contains('1000'));
      
      await controller.exportListToFile(textFile.path);
      final textContent = await textFile.readAsString();
      expect(textContent, contains('url3'));
      
      await tempDir.delete(recursive: true);
    });

    test('U-DL-SHC-29: cancelHydration removes loading placeholder and preserves already hydrated items', () async {
      final container = await createContainer();
      final controller = container.read(downloadsSharedControllerProvider);

      const targetUrl = 'https://youtube.com/playlist?list=test';
      final item1 = MediaInfo(id: 'item_1', title: 'Video 1', originalUrl: targetUrl, filesize: 500);
      final loadingItem = MediaInfo(id: 'hydration_loading', title: 'Loading...', originalUrl: targetUrl);
      final group = MediaGroup(originalUrl: targetUrl, items: [item1, loadingItem]);

      controller.cache.parsedItems = [group];
      controller.backgroundLoadingProfiles.add(targetUrl);
      controller.activeHydrationPids[targetUrl] = [999999]; // dummy PID

      await controller.cancelHydration(targetUrl);

      expect(controller.backgroundLoadingProfiles.contains(targetUrl), isFalse);
      expect(controller.activeHydrationPids.containsKey(targetUrl), isFalse);
      expect(controller.cache.parsedItems!.first.items.length, 1);
      expect(controller.cache.parsedItems!.first.items.first.id, 'item_1');
      expect(controller.cache.parsedItems!.first.items.any((i) => i.id == 'hydration_loading'), isFalse);
    });
  });
}
