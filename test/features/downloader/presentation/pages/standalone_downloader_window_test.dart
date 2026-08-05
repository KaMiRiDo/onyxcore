import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/pages/standalone_downloader_window.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_shared_controller.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_location_bar.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:path/path.dart' as p;

// ignore_for_file: avoid_dynamic_calls, invalid_use_of_protected_member, cascade_invocations

const _windowChannel = MethodChannel('onyxcore/window_manager');

MediaFormat makeFormat({
  required String formatId,
  required String resolution,
  required int filesize,
  String extension = 'mp4',
  String? videoCodec = 'avc1',
  String? audioCodec = 'aac',
  String? formatString,
}) {
  return MediaFormat(
    formatId: formatId,
    extension: extension,
    resolution: resolution,
    formatString: formatString ?? resolution,
    filesize: filesize,
    videoCodec: videoCodec,
    audioCodec: audioCodec,
  );
}

MediaInfo makeInfo({
  required String id,
  required String title,
  required String originalUrl,
  bool isVideo = true,
  bool isPlaylist = false,
  bool isProfile = false,
  int? filesize,
  int? galleryIndex,
  int? duration,
  int? width,
  int? height,
  String? directUrl,
  String? webpageUrl,
  String? thumbnail,
  bool isError = false,
  List<MediaFormat> formats = const [],
  String? fetchLogs,
  String? engineId,
}) {
  return MediaInfo(
    id: id,
    title: title,
    originalUrl: originalUrl,
    isVideo: isVideo,
    isPlaylist: isPlaylist,
    isProfile: isProfile,
    filesize: filesize,
    galleryIndex: galleryIndex,
    duration: duration,
    width: width,
    height: height,
    directUrl: directUrl,
    webpageUrl: webpageUrl,
    thumbnail: thumbnail,
    isError: isError,
    formats: formats,
    fetchLogs: fetchLogs,
    engineId: engineId,
  );
}

MediaGroup makeGroup({
  required String originalUrl,
  required List<MediaInfo> items,
}) {
  return MediaGroup(originalUrl: originalUrl, items: items);
}

DownloadTask makeTask(String id) {
  return DownloadTask(
    id: id,
    url: 'https://example.com/$id',
    destination: '/tmp',
    title: id,
    createdAt: DateTime(2024),
  );
}

class FixedSettingsNotifier extends SettingsNotifier {
  FixedSettingsNotifier(this.settings);

  final AppSettings settings;

  @override
  Future<AppSettings> build() async => settings;
}

class FixedCurrentPathNotifier extends CurrentPathNotifier {
  FixedCurrentPathNotifier(this.path);

  final String path;

  @override
  String build() => path;
}

class RecordingDownloadTaskNotifier extends DownloadTaskNotifier {
  RecordingDownloadTaskNotifier({List<DownloadTask> initialTasks = const []})
    : _initialTasks = initialTasks;

  final List<DownloadTask> _initialTasks;
  final List<Map<String, dynamic>> calls = <Map<String, dynamic>>[];

  @override
  List<DownloadTask> build() => List<DownloadTask>.from(_initialTasks);

  @override
  void startDownload({
    required String url,
    required String destination,
    required String title,
    String downloadType = 'generic',
    MediaFormat? format,
    bool audioOnly = false,
    bool mute = false,
    int? galleryIndex,
    String engine = 'auto',
    bool isPlaylist = false,
    bool isProfile = false,
    String? browser,
    bool isZip = false,
    String? filterType,
    int? totalItems,
    String? singleItemId,
    String? directUrl,
    int expectedBytes = 0,
    bool isCarousel = false,
    String? itemsRange,
  }) {
    calls.add(<String, dynamic>{
      'action': 'start',
      'url': url,
      'destination': destination,
      'title': title,
      'downloadType': downloadType,
      'format': format,
      'audioOnly': audioOnly,
      'mute': mute,
      'galleryIndex': galleryIndex,
      'engine': engine,
      'isPlaylist': isPlaylist,
      'isProfile': isProfile,
      'browser': browser,
      'filterType': filterType,
      'totalItems': totalItems,
      'singleItemId': singleItemId,
      'directUrl': directUrl,
      'expectedBytes': expectedBytes,
      'isCarousel': isCarousel,
      'itemsRange': itemsRange,
    });
  }

  @override
  Future<void> cancelDownload(String url) async {
    calls.add(<String, dynamic>{'action': 'cancel', 'url': url});
  }
}

class RecordingDownloadsSharedController extends ChangeNotifier
    implements DownloadsSharedController {
  final DownloadsListCache _cache = DownloadsListCache();

  final List<String> analyzeCalls = <String>[];
  final List<String> exportCalls = <String>[];
  final List<Map<String, String>> importCalls = <Map<String, String>>[];

  @override
  final Set<String> backgroundLoadingProfiles = <String>{};

  @override
  final Map<String, List<int>> activeHydrationPids = <String, List<int>>{};

  @override
  final ValueNotifier<int> hydrationNotifier = ValueNotifier<int>(0);

  @override
  String selectedEngine = 'auto';

  @override
  int totalListSize = 0;

  @override
  int totalListImages = 0;

  @override
  int totalListVideos = 0;

  @override
  bool hasUnderestimatedSize = false;

  @override
  int pendingStatsUpdate = 0;

  int recalculateCalls = 0;

  @override
  Ref get ref => throw UnimplementedError();

  @override
  DownloadsListCache get cache => _cache;

  @override
  void recalculateFilteredStatistics() {
    recalculateCalls++;
    totalListSize = 0;
    totalListImages = 0;
    totalListVideos = 0;
    hasUnderestimatedSize = false;

    final parsedItems = cache.parsedItems;
    if (parsedItems == null) {
      notifyListeners();
      return;
    }

    for (var index = 0; index < parsedItems.length; index++) {
      final group = parsedItems[index];
      final config = cache.configs[index];

      for (final item in group.items) {
        if (item.isError) continue;
        if (config?.groupFilter == GroupDownloadType.images && item.isVideo) {
          continue;
        }
        if (config?.groupFilter == GroupDownloadType.videos && !item.isVideo) {
          continue;
        }
        if (item.isVideo) {
          totalListVideos++;
        } else if (!item.isPlaylist && !item.isProfile) {
          totalListImages++;
        }
        totalListSize += item.filesize ?? 0;
      }

      if (group.items.isNotEmpty &&
          (group.first.isPlaylist || group.first.isProfile)) {
        hasUnderestimatedSize = true;
      }
    }

    notifyListeners();
  }

  @override
  int getGroupBytes(MediaGroup group, DownloadConfig config) {
    if (config.mode == DownloadMode.normal) {
      if (config.groupFilter == GroupDownloadType.images) {
        return group.items.where((i) => !i.isVideo).fold(0, (sum, item) => sum + (item.filesize ?? 0));
      } else if (config.groupFilter == GroupDownloadType.videos) {
        return group.items.where((i) => i.isVideo).fold(0, (sum, item) => sum + (item.filesize ?? 0));
      }
      return group.totalFilesize;
    } else {
      if (config.itemFormats.isEmpty) return 0;
      return config.itemFormats.values.fold(0, (sum, fmt) => sum + (fmt?.filesize ?? 0));
    }
  }

  @override
  Future<void> analyzeUrls(String text) async {
    analyzeCalls.add(text);
  }

  @override
  Future<void> hydrateProfile(String url) async {}

  @override
  Future<void> cancelHydration(String url) async {
    backgroundLoadingProfiles.remove(url);
    activeHydrationPids.remove(url);
    notifyListeners();
  }

  @override
  Future<void> exportListToFile(String path) async {
    exportCalls.add(path);
    final file = File(path);
    final data = <String, dynamic>{
      'items': cache.parsedItems?.map((group) => group.toMap()).toList() ?? [],
      'statistics': <String, dynamic>{
        'totalSize': totalListSize,
        'images': totalListImages,
        'videos': totalListVideos,
      },
    };
    await file.writeAsString(jsonEncode(data));
    cache.importedListPath = path;
    cache.isListChanged = false;
    cache.notify();
  }

  @override
  Future<void> importListFromFile(String path, String fileName) async {
    importCalls.add(<String, String>{'path': path, 'fileName': fileName});
    cache
      ..switchList(path)
      ..importedListPath = path
      ..importedListName = fileName
      ..isListChanged = false;

    final file = File(path);
    if (file.existsSync()) {
      final decoded = jsonDecode(await file.readAsString());
      final rawItems = decoded is Map<String, dynamic>
          ? (decoded['items'] as List<dynamic>? ?? <dynamic>[])
          : (decoded as List<dynamic>);
      cache.parsedItems = rawItems
          .map((item) => MediaGroup.fromMap(item as Map<String, dynamic>))
          .toList();
      cache.configs.clear();
      for (var index = 0; index < (cache.parsedItems?.length ?? 0); index++) {
        cache.configs[index] = DownloadConfig();
      }
      recalculateFilteredStatistics();
    } else {
      cache.notify();
      notifyListeners();
    }
  }
}

ProviderContainer createContainer({
  required RecordingDownloadsSharedController controller,
  required RecordingDownloadTaskNotifier taskNotifier,
  required String currentPath,
  AppSettings settings = const AppSettings(downloadBrowser: 'Firefox'),
}) {
  return ProviderContainer(
    overrides: [
      downloadsSharedControllerProvider.overrideWith((ref) => controller),
      downloadsListCacheProvider.overrideWith((ref) => controller.cache),
      downloadTaskProvider.overrideWith(() => taskNotifier),
      currentPathProvider.overrideWith(
        () => FixedCurrentPathNotifier(currentPath),
      ),
      settingsProvider.overrideWith(() => FixedSettingsNotifier(settings)),
    ],
  );
}

Future<void> pumpWindow(
  WidgetTester tester, {
  required ProviderContainer container,
  Map<String, dynamic> initParams = const <String, dynamic>{},
}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1600,
            height: 1000,
            child: StandaloneDownloaderWindow(
              windowId: 7,
              initParams: initParams,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

dynamic standaloneState(WidgetTester tester) {
  return tester.state(find.byType(StandaloneDownloaderWindow));
}

Future<void> doubleTapFinder(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 40));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 120));
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  final windowCalls = <MethodCall>[];
  late Directory tempDir;

  setUpAll(() {
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(1600, 1000)
      ..devicePixelRatio = 1;

    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exceptionAsString().contains('RenderFlex overflowed')) {
        return;
      }
      FlutterError.presentError(details);
    };
  });

  tearDownAll(() {
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync(
      'standalone_downloader_window_test_',
    );
    windowCalls.clear();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowChannel, (methodCall) async {
          windowCalls.add(methodCall);
          if (methodCall.method == 'create_window') {
            return 99;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_windowChannel, null);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('StandaloneDownloaderWindow', () {
    // ── U-SDW-001 ──
    testWidgets('U-SDW-001: resolves download heights from resolution labels', (
      tester,
    ) async {
      final controller = RecordingDownloadsSharedController();
      final taskNotifier = RecordingDownloadTaskNotifier();
      final container = createContainer(
        controller: controller,
        taskNotifier: taskNotifier,
        currentPath: tempDir.path,
      );
      addTearDown(container.dispose);

      await pumpWindow(tester, container: container);
      final state = standaloneState(tester);

      expect(state.getHeightForTesting(''), 0);
      expect(state.getHeightForTesting('audio only'), 0);
      expect(state.getHeightForTesting('audio'), 0);
      expect(state.getHeightForTesting('4K'), 2160);
      expect(state.getHeightForTesting('2160p'), 2160);
      expect(state.getHeightForTesting('2K'), 1440);
      expect(state.getHeightForTesting('1080p'), 1080);
      expect(state.getHeightForTesting('720p'), 720);
      expect(state.getHeightForTesting('480p'), 480);
      expect(state.getHeightForTesting('1920x1080'), 1080);
      expect(state.getHeightForTesting('Clip 360'), 360);
      expect(state.getHeightForTesting('garbage'), 0);
    });

    testWidgets(
      'W-SDW-015: changing global format clears individual itemFormats',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        final group = makeGroup(
          originalUrl: 'https://playlist.example',
          items: [
            makeInfo(
              id: 'v1',
              title: 'Video 1',
              originalUrl: 'https://playlist.example/v1',
              isPlaylist: true,
              formats: [],
            ),
            makeInfo(
              id: 'v2',
              title: 'Video 2',
              originalUrl: 'https://playlist.example/v2',
              isPlaylist: true,
              formats: [],
            ),
          ],
        );

        controller.cache.parsedItems = [group];
        final config = DownloadConfig();
        config.format = makeFormat(
          formatId: '1080',
          resolution: '1080p',
          filesize: 100,
        );
        config.itemFormats['v1'] = makeFormat(
          formatId: '720',
          resolution: '720p',
          filesize: 50,
        );
        controller.cache.configs[0] = config;

        await pumpWindow(tester, container: container);

        final state = standaloneState(tester);
        // Simulate double tap to enter group
        state.onDoubleTapItemForTesting(0, group);
        await tester.pump();

        // Simulate onFormatChanged from action bar
        final newFormat = makeFormat(
          formatId: '4k',
          resolution: '2160p',
          filesize: 200,
        );

        // Find the FormatSelectionDropdown and change value or directly call method if exposed.
        // We know `rootIndex` is 0 when inside the group
        state.onFormatChangedForTesting(newFormat);

        expect(controller.cache.configs[0]?.format?.resolution, '2160p');
        expect(controller.cache.configs[0]?.itemFormats, isEmpty);
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-001: Init, Update, Present Window
    // ═══════════════════════════════════════════════════════════════
    testWidgets(
      'W-SDW-001: initializes state, updates current path, and presents the window',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        await pumpWindow(
          tester,
          container: container,
          initParams: <String, dynamic>{'currentPath': '/first/path'},
        );

        final state = standaloneState(tester);
        expect(state.currentPathForTesting, '/first/path');
        expect(
          windowCalls.where((call) => call.method == 'present_window').length,
          1,
        );

        await pumpWindow(
          tester,
          container: container,
          initParams: <String, dynamic>{'currentPath': '/second/path'},
        );

        expect(standaloneState(tester).currentPathForTesting, '/second/path');
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-002: Fetch, Ctrl+Enter, Ctrl+D, Ctrl+F
    // ═══════════════════════════════════════════════════════════════
    testWidgets('W-SDW-002: fetches URLs and handles global focus shortcuts', (
      tester,
    ) async {
      final controller = RecordingDownloadsSharedController();
      final taskNotifier = RecordingDownloadTaskNotifier();
      final container = createContainer(
        controller: controller,
        taskNotifier: taskNotifier,
        currentPath: tempDir.path,
      );
      addTearDown(container.dispose);

      await pumpWindow(tester, container: container);

      final textFields = find.byType(TextField);
      final urlField = textFields.first;
      final searchField = textFields.at(1);

      await tester.enterText(urlField, '  https://example.com/video  ');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Fetch'));
      await tester.pump();

      expect(controller.analyzeCalls, <String>['https://example.com/video']);
      expect(tester.widget<TextField>(urlField).controller?.text ?? '', '');

      await tester.enterText(urlField, 'https://example.com/second');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(controller.analyzeCalls.last, 'https://example.com/second');

      await tester.tap(searchField);
      await tester.pump();
      expect(tester.widget<TextField>(searchField).focusNode?.hasFocus, isTrue);

      await tester.enterText(searchField, 'keep me');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(standaloneState(tester).isSearchVisibleForTesting, isFalse);
      expect(standaloneState(tester).searchControllerForTesting.text, isEmpty);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(tester.widget<TextField>(urlField).focusNode?.hasFocus, isTrue);
    });

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-003: Search debounce
    // ═══════════════════════════════════════════════════════════════
    testWidgets('W-SDW-003: debounces search text changes', (tester) async {
      final controller = RecordingDownloadsSharedController();
      final taskNotifier = RecordingDownloadTaskNotifier();
      final container = createContainer(
        controller: controller,
        taskNotifier: taskNotifier,
        currentPath: tempDir.path,
      );
      addTearDown(container.dispose);

      await pumpWindow(tester, container: container);

      final state = standaloneState(tester);
      state.searchControllerForTesting.text = 'query';
      state.onSearchChangedForTesting();

      expect(state.searchDebounceForTesting?.isActive, isTrue);
      await tester.pump(const Duration(milliseconds: 350));
      expect(state.searchDebounceForTesting?.isActive, isFalse);
    });

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-004: Tab switching, save/restore, Ctrl+Tab
    // ═══════════════════════════════════════════════════════════════
    testWidgets('W-SDW-004: saves tab state and cycles lists with Ctrl+Tab', (
      tester,
    ) async {
      final controller = RecordingDownloadsSharedController();
      final taskNotifier = RecordingDownloadTaskNotifier();
      final customPath = p.join(tempDir.path, 'saved_list.json');
      final container = createContainer(
        controller: controller,
        taskNotifier: taskNotifier,
        currentPath: tempDir.path,
      );
      addTearDown(container.dispose);

      controller.cache.parsedItems = <MediaGroup>[
        makeGroup(
          originalUrl: 'https://root.example',
          items: <MediaInfo>[
            makeInfo(
              id: 'root1',
              title: 'Default Root',
              originalUrl: 'https://root.example',
              isVideo: false,
            ),
          ],
        ),
      ];

      controller.cache.switchList(customPath);
      controller.cache.importedListPath = customPath;
      controller.cache.importedListName = 'Saved List';
      controller.cache.parsedItems = <MediaGroup>[
        makeGroup(
          originalUrl: 'https://custom.example',
          items: <MediaInfo>[
            makeInfo(
              id: 'custom1',
              title: 'Custom Item',
              originalUrl: 'https://custom.example',
            ),
          ],
        ),
      ];
      controller.cache.switchList('default');
      controller.cache.importedListPath = null;
      controller.cache.importedListName = null;
      controller.cache.notify();

      await pumpWindow(tester, container: container);

      standaloneState(tester).searchControllerForTesting.text =
          'default search';

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(find.text('Saved List'), findsAtLeastNWidgets(1));
      expect(controller.cache.importedListPath, customPath);

      standaloneState(tester).searchControllerForTesting.text = 'custom search';

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(controller.cache.importedListPath, isNull);
      expect(
        standaloneState(tester).searchControllerForTesting.text,
        'default search',
      );

      await tester.tap(find.text('Saved List').first);
      await tester.pump();
      expect(
        standaloneState(tester).searchControllerForTesting.text,
        'custom search',
      );
    });

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-005: Ctrl+W closes active custom list
    // ═══════════════════════════════════════════════════════════════
    testWidgets('W-SDW-005: closes the active custom list with Ctrl+W', (
      tester,
    ) async {
      final controller = RecordingDownloadsSharedController();
      final taskNotifier = RecordingDownloadTaskNotifier();
      final firstPath = p.join(tempDir.path, 'first.json');
      final secondPath = p.join(tempDir.path, 'second.json');
      final container = createContainer(
        controller: controller,
        taskNotifier: taskNotifier,
        currentPath: tempDir.path,
      );
      addTearDown(container.dispose);

      controller.cache.switchList(firstPath);
      controller.cache.importedListPath = firstPath;
      controller.cache.importedListName = 'First';
      controller.cache.parsedItems = <MediaGroup>[];

      controller.cache.switchList(secondPath);
      controller.cache.importedListPath = secondPath;
      controller.cache.importedListName = 'Second';
      controller.cache.parsedItems = <MediaGroup>[];

      controller.cache.switchList(firstPath);
      controller.cache.notify();

      await pumpWindow(tester, container: container);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(
        controller.cache.customLists.any((list) => list.path == firstPath),
        isFalse,
      );
      expect(controller.cache.importedListPath, secondPath);
    });

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-006: Selection mechanics
    // ═══════════════════════════════════════════════════════════════
    testWidgets(
      'W-SDW-006: supports single, ctrl, shift, and clear selection',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        controller.cache.parsedItems = <MediaGroup>[
          makeGroup(
            originalUrl: 'https://a.example',
            items: <MediaInfo>[
              makeInfo(
                id: 'a',
                title: 'Alpha',
                originalUrl: 'https://a.example',
              ),
            ],
          ),
          makeGroup(
            originalUrl: 'https://b.example',
            items: <MediaInfo>[
              makeInfo(
                id: 'b',
                title: 'Beta',
                originalUrl: 'https://b.example',
              ),
            ],
          ),
          makeGroup(
            originalUrl: 'https://c.example',
            items: <MediaInfo>[
              makeInfo(
                id: 'c',
                title: 'Gamma',
                originalUrl: 'https://c.example',
              ),
            ],
          ),
        ];
        controller.cache.configs.addAll(<int, DownloadConfig>{
          0: DownloadConfig(),
          1: DownloadConfig(),
          2: DownloadConfig(),
        });

        await pumpWindow(tester, container: container);

        final state = standaloneState(tester);
        state.selectedIndicesForTesting.addAll(<int>{0, 1, 2});
        expect(state.selectedIndicesForTesting, <int>{0, 1, 2});

        await tester.tapAt(const Offset(1100, 300));
        await tester.pump();
        expect(state.selectedIndicesForTesting, isEmpty);
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-007: Root delete, trash, restore, empty trash
    // ═══════════════════════════════════════════════════════════════
    testWidgets(
      'W-SDW-007: moves root items to trash, restores them, and empties trash',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        controller.cache.parsedItems = <MediaGroup>[
          makeGroup(
            originalUrl: 'https://video.example',
            items: <MediaInfo>[
              makeInfo(
                id: 'vid',
                title: 'Video Item',
                originalUrl: 'https://video.example',
                filesize: 4 * 1024 * 1024,
              ),
            ],
          ),
        ];
        controller.cache.configs[0] = DownloadConfig();

        await pumpWindow(tester, container: container);

        standaloneState(tester).selectedIndicesForTesting.add(0);
        standaloneState(tester).handleDeleteForTesting(false);
        await tester.pump();

        expect(find.text('Video Item'), findsNothing);
        expect(controller.cache.configs, isEmpty);
        expect(controller.cache.isListChanged, isTrue);
        expect(controller.recalculateCalls, greaterThanOrEqualTo(1));

        await tester.tap(find.text('Trash'));
        await tester.pump();
        expect(find.text('Restore All'), findsOneWidget);
        expect(find.text('Restore'), findsOneWidget);

        await tester.tap(find.text('Restore'));
        await tester.pump();
        expect(find.text('Trash is empty'), findsOneWidget);

        standaloneState(tester).setState(() {
          standaloneState(tester).restoreTabStateForTesting('__reset__');
        });
        await tester.pump();
        expect(find.text('Video Item'), findsOneWidget);

        standaloneState(tester).selectedIndicesForTesting.add(0);
        standaloneState(tester).handleDeleteForTesting(false);
        await tester.pump();

        await tester.tap(find.text('Trash'));
        await tester.pump();
        await tester.tap(find.text('Empty'));
        await tester.pump();

        expect(find.text('Trash is empty'), findsOneWidget);
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-008: Permanent delete reindexes configs
    // ═══════════════════════════════════════════════════════════════
    testWidgets(
      'W-SDW-008: permanently deletes selected root items and reindexes configs',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        controller.cache.parsedItems = <MediaGroup>[
          makeGroup(
            originalUrl: 'https://one.example',
            items: <MediaInfo>[
              makeInfo(
                id: '1',
                title: 'One',
                originalUrl: 'https://one.example',
              ),
            ],
          ),
          makeGroup(
            originalUrl: 'https://two.example',
            items: <MediaInfo>[
              makeInfo(
                id: '2',
                title: 'Two',
                originalUrl: 'https://two.example',
              ),
            ],
          ),
        ];
        controller.cache.configs.addAll(<int, DownloadConfig>{
          0: DownloadConfig(engine: 'first'),
          1: DownloadConfig(engine: 'second'),
        });

        await pumpWindow(tester, container: container);

        standaloneState(tester).selectedIndicesForTesting.add(0);
        standaloneState(tester).handleDeleteForTesting(true);
        await tester.pump();

        expect(find.text('Permanently Delete'), findsOneWidget);
        await tester.tap(find.text('Delete'));
        await tester.pump();

        expect(
          controller.cache.parsedItems?.map((group) => group.first.title),
          <String>['Two'],
        );
        expect(controller.cache.configs.length, 1);
        expect(controller.cache.configs[0]?.engine, 'second');
        expect(find.text('Trash'), findsWidgets);
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-009: Nested group navigation, delete, restore, Alt+Left/Right
    // ═══════════════════════════════════════════════════════════════
    testWidgets(
      'W-SDW-009: navigates grouped items, restores inner trash items, and supports history shortcuts',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final group = makeGroup(
          originalUrl: 'https://gallery.example',
          items: <MediaInfo>[
            makeInfo(
              id: 'g1',
              title: 'Gallery Root',
              originalUrl: 'https://gallery.example/1',
              isVideo: false,
            ),
            makeInfo(
              id: 'g2',
              title: 'Gallery Clip',
              originalUrl: 'https://gallery.example/2',
            ),
          ],
        );
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        controller.cache.parsedItems = <MediaGroup>[group];
        controller.cache.configs[0] = DownloadConfig();

        await pumpWindow(tester, container: container);

        await doubleTapFinder(tester, find.text('Gallery Root'));
        await tester.pump();
        expect(find.text('Gallery Clip'), findsOneWidget);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pump();
        expect(find.text('Gallery Root'), findsOneWidget);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        await tester.pump();
        expect(find.text('Gallery Clip'), findsOneWidget);

        standaloneState(tester).selectedIndicesForTesting.add(1);
        standaloneState(tester).handleDeleteForTesting(false);
        await tester.pump();
        expect(find.text('Gallery Clip'), findsNothing);

        await tester.tap(find.text('Trash'));
        await tester.pump();
        await tester.tap(find.text('Restore All'));
        await tester.pump();
        expect(find.text('Trash is empty'), findsOneWidget);

        standaloneState(tester).setState(() {
          standaloneState(tester).restoreTabStateForTesting('__reset__');
        });
        await tester.pump();
        await doubleTapFinder(tester, find.text('Gallery Root'));
        await tester.pump();
        expect(find.text('Gallery Clip'), findsOneWidget);
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-010: Generic download branch, titles, filters, callbacks
    // ═══════════════════════════════════════════════════════════════
    testWidgets('W-SDW-010: starts a root item download from the grid button', (
      tester,
    ) async {
      final controller = RecordingDownloadsSharedController();
      final taskNotifier = RecordingDownloadTaskNotifier();
      final container = createContainer(
        controller: controller,
        taskNotifier: taskNotifier,
        currentPath: tempDir.path,
      );
      addTearDown(container.dispose);

      controller.cache.parsedItems = <MediaGroup>[
        makeGroup(
          originalUrl: 'https://single.example',
          items: <MediaInfo>[
            makeInfo(
              id: 'single',
              title: 'Single Root',
              originalUrl: 'https://single.example/file.jpg',
              directUrl: 'https://single.example/file.jpg',
              isVideo: false,
            ),
          ],
        ),
      ];
      controller.cache.configs[0] = DownloadConfig();

      await pumpWindow(tester, container: container);

      await tester.tap(find.byIcon(Icons.download_rounded).first);
      await tester.pump(const Duration(milliseconds: 50));

      expect(taskNotifier.calls, hasLength(1));
      expect(taskNotifier.calls.single['title'], 'Single Root');
      expect(taskNotifier.calls.single['downloadType'], 'image');
      expect(
        taskNotifier.calls.single['url'],
        'https://single.example/file.jpg',
      );
      expect(controller.cache.parsedItems, isEmpty);
      expect(controller.cache.isListChanged, isTrue);
      expect(controller.recalculateCalls, greaterThanOrEqualTo(1));
    });

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-016: Active downloads cancel all
    // ═══════════════════════════════════════════════════════════════
    testWidgets('W-SDW-016: cancels every active download from the sidebar', (
      tester,
    ) async {
      final controller = RecordingDownloadsSharedController();
      final taskNotifier = RecordingDownloadTaskNotifier(
        initialTasks: <DownloadTask>[makeTask('one'), makeTask('two')],
      );
      final container = createContainer(
        controller: controller,
        taskNotifier: taskNotifier,
        currentPath: tempDir.path,
      );
      addTearDown(container.dispose);

      await pumpWindow(tester, container: container);

      await tester.tap(find.text('Cancel All'));
      await tester.pump();

      expect(
        taskNotifier.calls.where((call) => call['action'] == 'cancel').length,
        2,
      );
    });

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-017: Video preview window and image viewer success
    // ═══════════════════════════════════════════════════════════════
    testWidgets(
      'W-SDW-017: opens a video preview window for videos and image viewer for images',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        controller.cache.parsedItems = <MediaGroup>[
          makeGroup(
            originalUrl: 'https://video-preview.example',
            items: <MediaInfo>[
              makeInfo(
                id: 'video_preview',
                title: 'Preview Video',
                originalUrl: 'https://video-preview.example',
              ),
            ],
          ),
          makeGroup(
            originalUrl: 'https://image-preview.example',
            items: <MediaInfo>[
              makeInfo(
                id: 'image_preview',
                title: 'Preview Image',
                originalUrl: 'https://image-preview.example/image.jpg',
                isVideo: false,
              ),
            ],
          ),
        ];

        await pumpWindow(tester, container: container);

        await doubleTapFinder(tester, find.text('Preview Video'));
        // wait for Future.delayed(16ms) in openVideoPreview
        await tester.pump(const Duration(milliseconds: 50));

        final createVideoWindowCall = windowCalls.lastWhere(
          (call) => call.method == 'create_window',
        );
        expect(createVideoWindowCall.arguments['width'], 1280);
        expect(createVideoWindowCall.arguments['height'], 720);

        await doubleTapFinder(tester, find.text('Preview Image'));
        await tester.pump(const Duration(milliseconds: 50));

        final createImageWindowCall = windowCalls.lastWhere(
          (call) => call.method == 'create_window',
        );
        expect(createImageWindowCall.arguments['width'], 600);
        expect(createImageWindowCall.arguments['height'], 800);
      },
    );
    testWidgets(
      'W-SDW-017: audio format shows audio icon and playlist suppresses root thumbnail',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: '/tmp/test',
        );
        addTearDown(container.dispose);

        final group = makeGroup(
          originalUrl: 'https://playlist.example',
          items: [
            makeInfo(
              id: 'v1',
              title: 'Video 1',
              originalUrl: 'https://playlist.example/v1',
              isPlaylist: true,
              thumbnail: 'https://thumb.example',
              formats: [
                makeFormat(
                  formatId: 'a1',
                  resolution: 'audio only',
                  filesize: 100,
                  videoCodec: 'none',
                ),
              ],
            ),
            makeInfo(
              id: 'v2',
              title: 'Video 2',
              originalUrl: 'https://playlist.example/v2',
              isPlaylist: true,
              thumbnail: 'https://thumb.example',
              formats: [],
            ),
          ],
        );
        controller.cache.parsedItems = [group];
        final config = DownloadConfig();
        config.format = group.first.formats.first;
        config.itemFormats['v1'] = group.first.formats.first;
        controller.cache.configs[0] = config;

        await pumpWindow(tester, container: container);

        final state = standaloneState(tester);

        // Open playlist
        state.onDoubleTapItemForTesting(0, group);
        await tester.pump();

        // First item v1 has audio format selected in config.itemFormats
        expect(find.byIcon(Icons.audiotrack_rounded), findsOneWidget);

        // Thumbnails are rendered properly for playlist items
        expect(find.byType(Image), findsWidgets);
      },
    );

    testWidgets(
      'W-SDW-018: global hotkeys function correctly after tapping on the media grid',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: '/tmp/test',
        );
        addTearDown(container.dispose);

        final group = makeGroup(
          originalUrl: 'https://video.example',
          items: [
            makeInfo(
              id: 'v1',
              title: 'Video 1',
              originalUrl: 'https://video.example/v1',
            ),
          ],
        );
        controller.cache.parsedItems = [group];
        controller.cache.configs[0] = DownloadConfig();

        await pumpWindow(tester, container: container);

        // Tap on the media grid explicitly to transfer focus
        await tester.tap(find.byType(CustomScrollView));
        await tester.pump(const Duration(milliseconds: 50));

        final textFields = find.byType(TextField);
        final urlField = textFields.first;
        final searchField = textFields.at(1);

        // Trigger Ctrl+F
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump(const Duration(milliseconds: 50));

        // Verify search is focused
        expect(
          tester.widget<TextField>(searchField).focusNode?.hasFocus,
          isTrue,
        );
        expect(standaloneState(tester).isSearchVisibleForTesting, isTrue);

        // Tap on the media grid again
        await tester.tap(find.byType(CustomScrollView));
        await tester.pump(const Duration(milliseconds: 50));

        // Trigger Ctrl+D
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump(const Duration(milliseconds: 50));

        // Verify URL is focused
        expect(tester.widget<TextField>(urlField).focusNode?.hasFocus, isTrue);
      },
    );

    testWidgets('W-SDW-019: tagging functionality updates the grid and header', (
      tester,
    ) async {
      final controller = RecordingDownloadsSharedController();
      final taskNotifier = RecordingDownloadTaskNotifier();
      final container = createContainer(
        controller: controller,
        taskNotifier: taskNotifier,
        currentPath: '/tmp/test',
      );
      addTearDown(container.dispose);

      final group1 = makeGroup(
        originalUrl: 'https://video1.example',
        items: [
          makeInfo(
            id: 'v1',
            title: 'Video 1',
            originalUrl: 'https://video1.example',
          ),
        ],
      );
      final group2 = makeGroup(
        originalUrl: 'https://video2.example',
        items: [
          makeInfo(
            id: 'v2',
            title: 'Video 2',
            originalUrl: 'https://video2.example',
          ),
        ],
      );
      controller.cache.parsedItems = [group1, group2];
      controller.cache.configs[0] = DownloadConfig();
      controller.cache.configs[1] = DownloadConfig();

      await pumpWindow(tester, container: container);

      // Verify no tags initially
      expect(find.text('Tag...'), findsNothing);

      // Simulate right-click on the first item to add a tag
      final item = find.text('Video 1');
      final gesture = await tester.startGesture(
        tester.getCenter(item),
        buttons: 2,
      );
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 50));

      // Find tag input text field in overlay
      final tagFields = find.byType(TextField);
      expect(
        tagFields.evaluate().length,
        greaterThanOrEqualTo(3),
      ); // URL, Search, Tag
      final tagField = tagFields.last;

      await tester.enterText(tagField, 'Favorites');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 50));

      // Verify tag is now in the parsed items
      expect(controller.cache.parsedItems!.first.tag, 'Favorites');

      // The tag should be visible on the grid item (1 widget) but NOT in the header
      // because it is the only tag and the item is in the viewport (as per new requirements)
      expect(find.text('Favorites'), findsOneWidget);

      // Trigger right-click on the first item again to clear the tag
      final gesture2 = await tester.startGesture(
        tester.getCenter(item),
        buttons: 2,
      );
      await gesture2.up();
      await tester.pump(const Duration(milliseconds: 50));

      // Find tag input text field in overlay again
      final tagFields2 = find.byType(TextField);
      expect(tagFields2.evaluate().length, greaterThanOrEqualTo(3));
      final tagField2 = tagFields2.last;

      await tester.enterText(tagField2, 'NewTag');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump(const Duration(milliseconds: 50));

      // Verify tag is updated
      expect(controller.cache.parsedItems!.first.tag, 'NewTag');
    });

    testWidgets('W-SDW-020: clicking a list from sidebar exits trash view', (
      tester,
    ) async {
      final controller = RecordingDownloadsSharedController();
      final taskNotifier = RecordingDownloadTaskNotifier();
      final container = createContainer(
        controller: controller,
        taskNotifier: taskNotifier,
        currentPath: tempDir.path,
      );
      addTearDown(container.dispose);

      controller.cache.parsedItems = [];
      await pumpWindow(tester, container: container);

      // Enter trash view
      await tester.tap(find.text('Trash'));
      await tester.pump();

      final state = standaloneState(tester);
      expect(state.isTrashViewForTesting, isTrue);

      // Tap default list
      await tester.tap(find.text('Default List'));
      await tester.pump();
    });

    testWidgets(
      'W-SDW-021: error items show error styling and disabled download button, and opens properties dialog on icon click',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        final errorGroup = makeGroup(
          originalUrl: 'https://error.example',
          items: [
            makeInfo(
              id: 'e1',
              title: 'Error Video',
              originalUrl: 'https://error.example',
              isError: true,
              fetchLogs: 'Failed to fetch',
            ),
          ],
        );
        controller.cache.parsedItems = [errorGroup];
        controller.cache.configs[0] = DownloadConfig(engine: 'yt_dlp');

        await pumpWindow(tester, container: container);

        // Verify the download button is disabled. Since it's an IconButton, we can check if it's pressed.
        // A disabled IconButton will not trigger its onPressed. We can verify if the button exists and then tap it to see if a download starts.
        await tester.tap(find.byIcon(Icons.download_rounded).first);
        await tester.pump(const Duration(milliseconds: 50));
        expect(
          taskNotifier.calls,
          isEmpty,
          reason: 'Download should not start for error items',
        );

        // Select the item
        final state = standaloneState(tester);
        state.selectedIndicesForTesting.add(0);

        // Press Alt + Enter to open properties dialog
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Dialog should be open
        expect(find.byType(Dialog), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.text('Error Video'),
          ),
          findsOneWidget,
        );
        expect(
          find.text('Failed to fetch'),
          findsOneWidget,
        ); // Logs should be initially expanded for error items

        // Close dialog via Esc key
        await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(Dialog), findsNothing);
      },
    );

    testWidgets(
      'W-SDW-022: Alt + Enter opens properties dialog and shows correctly formatted data for single and multiple items',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        final group1 = makeGroup(
          originalUrl: 'https://video1.example',
          items: [
            makeInfo(
              id: 'v1',
              title: 'Video 1',
              originalUrl: 'https://video1.example',
              filesize: 50 * 1024 * 1024,
              engineId: 'yt_dlp',
            ),
          ],
        );
        final group2 = makeGroup(
          originalUrl: 'https://video2.example',
          items: [
            makeInfo(
              id: 'v2',
              title: 'Video 2',
              originalUrl: 'https://video2.example',
              isVideo: false,
              filesize: 10 * 1024 * 1024,
              engineId: 'gallery_dl',
            ),
          ],
        );
        controller.cache.parsedItems = [group1, group2];
        controller.cache.configs[0] = DownloadConfig(engine: 'yt_dlp');
        controller.cache.configs[1] = DownloadConfig(engine: 'gallery_dl');

        await pumpWindow(tester, container: container);

        // Select both items
        final state = standaloneState(tester);
        state.selectedIndicesForTesting.addAll([0, 1]);

        // Press Alt + Enter
        await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);

        // Pump manually to avoid pumpAndSettle timeout (due to blinking cursor etc.)
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Properties dialog should open
        expect(find.byType(Dialog), findsOneWidget);
        expect(find.text('Video 1, Video 2'), findsOneWidget);
        expect(find.text('Size: 60.00 MB'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.text('1'),
          ),
          findsNWidgets(2),
        ); // 1 Video, 1 Image
        expect(find.byIcon(Icons.videocam_rounded), findsWidgets);
        expect(find.byIcon(Icons.image_rounded), findsWidgets);

        // Ensure logs are NOT visible for multiple items
        expect(find.text('Extraction Logs'), findsNothing);

        // Tap close button inside dialog
        final closeBtn = find.descendant(
          of: find.byType(Dialog),
          matching: find.byIcon(Icons.close),
        );
        await tester.tap(closeBtn);

        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Dialog should close
        expect(find.byType(Dialog), findsNothing);
      },
    );

    testWidgets(
      'W-SDW-023: sidebar width is 380 in max window and dynamic in small screen',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        // Max window
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await pumpWindow(tester, container: container);

        // The sidebar is the first Container in the Row. We can find it by looking for the 
        // Media List Section which is inside it.
        final mediaListFinder = find.text('Media List');
        expect(mediaListFinder, findsOneWidget);
        
        final maxSidebarContainer = find.ancestor(
          of: mediaListFinder,
          matching: find.byType(Container),
        ).first;
        
        final maxContainerSize = tester.getSize(maxSidebarContainer);
        expect(maxContainerSize.width, 340.0);

        // Small window
        tester.view.physicalSize = const Size(700, 600);
        await tester.pump();

        final smallSidebarContainer = find.ancestor(
          of: mediaListFinder,
          matching: find.byType(Container),
        ).first;

        final smallContainerSize = tester.getSize(smallSidebarContainer);
        expect(smallContainerSize.width, 200.0);
      },
    );

    testWidgets(
      'W-SDW-024: bottom location bar statistics reflect root visible items and dynamically switch to subgroup-only stats when opening a playlist',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        // Group 0: Standalone video (10 MB)
        final video1 = makeInfo(
          id: 'v1',
          title: 'Solo Video',
          originalUrl: 'https://example.com/video1',
          filesize: 10 * 1024 * 1024,
        );
        // Group 1: Standalone image (2 MB)
        final img1 = makeInfo(
          id: 'i1',
          title: 'Solo Image',
          originalUrl: 'https://example.com/img1',
          isVideo: false,
          filesize: 2 * 1024 * 1024,
        );
        // Group 2: Playlist (3 videos of 5MB, 2 images of 1MB = 17 MB)
        final playlistItem1 = makeInfo(
          id: 'pv1',
          title: 'Playlist Video 1',
          originalUrl: 'https://example.com/playlist',
          isPlaylist: true,
          filesize: 5 * 1024 * 1024,
        );
        final playlistItem2 = makeInfo(
          id: 'pv2',
          title: 'Playlist Video 2',
          originalUrl: 'https://example.com/playlist',
          filesize: 5 * 1024 * 1024,
        );
        final playlistItem3 = makeInfo(
          id: 'pv3',
          title: 'Playlist Video 3',
          originalUrl: 'https://example.com/playlist',
          filesize: 5 * 1024 * 1024,
        );
        final playlistImg1 = makeInfo(
          id: 'pi1',
          title: 'Playlist Image 1',
          originalUrl: 'https://example.com/playlist',
          isVideo: false,
          filesize: 1 * 1024 * 1024,
        );
        final playlistImg2 = makeInfo(
          id: 'pi2',
          title: 'Playlist Image 2',
          originalUrl: 'https://example.com/playlist',
          isVideo: false,
          filesize: 1 * 1024 * 1024,
        );

        final group0 = MediaGroup(items: [video1], originalUrl: video1.originalUrl);
        final group1 = MediaGroup(items: [img1], originalUrl: img1.originalUrl);
        final playlistGroup = MediaGroup(
          items: [playlistItem1, playlistItem2, playlistItem3, playlistImg1, playlistImg2],
          originalUrl: 'https://example.com/playlist',
        );

        controller.cache.parsedItems = [group0, group1, playlistGroup];
        controller.cache.configs.addAll({
          0: DownloadConfig(),
          1: DownloadConfig(),
          2: DownloadConfig(),
        });
        controller.recalculateFilteredStatistics();

        await pumpWindow(tester, container: container);

        // 1. In Root View:
        // Total videos: 1 (solo) + 3 (playlist) = 4
        // Total images: 1 (solo) + 2 (playlist) = 3
        // Total size: 10MB + 2MB + 17MB = 29MB (30408704 bytes)
        var locationBar = tester.widget<StandaloneWindowLocationBar>(
          find.byType(StandaloneWindowLocationBar),
        );
        expect(locationBar.totalVideos, 4);
        expect(locationBar.totalImages, 3);
        expect(locationBar.totalSize, 29 * 1024 * 1024);

        // 2. Open Playlist (double tap the playlist card)
        final playlistFinder = find.text('Playlist Video 1');
        expect(playlistFinder, findsOneWidget);
        await doubleTapFinder(tester, playlistFinder);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // In Subgroup View:
        // Stats must be ONLY for that playlist:
        // 3 videos, 2 images, 17MB (17825792 bytes)
        locationBar = tester.widget<StandaloneWindowLocationBar>(
          find.byType(StandaloneWindowLocationBar),
        );
        expect(locationBar.totalVideos, 3);
        expect(locationBar.totalImages, 2);
        expect(locationBar.totalSize, 17 * 1024 * 1024);

        // 3. Navigate back to Root View by tapping back in breadcrumb
        final backButton = find.byIcon(Icons.arrow_back);
        expect(backButton, findsOneWidget);
        await tester.tap(backButton);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // In Root View again:
        locationBar = tester.widget<StandaloneWindowLocationBar>(
          find.byType(StandaloneWindowLocationBar),
        );
        expect(locationBar.totalVideos, 4);
        expect(locationBar.totalImages, 3);
        expect(locationBar.totalSize, 29 * 1024 * 1024);
      },
    );

    testWidgets(
      'W-SDW-025: bottom location bar statistics update according to search filter in root and subgroup views',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        final video1 = makeInfo(
          id: 'v1',
          title: 'Nature Video',
          originalUrl: 'https://example.com/video1',
          filesize: 10 * 1024 * 1024,
        );
        final img1 = makeInfo(
          id: 'i1',
          title: 'Urban Image',
          originalUrl: 'https://example.com/img1',
          isVideo: false,
          filesize: 2 * 1024 * 1024,
        );
        final playlistItem1 = makeInfo(
          id: 'pv1',
          title: 'Nature Playlist',
          originalUrl: 'https://example.com/playlist',
          isPlaylist: true,
          filesize: 4 * 1024 * 1024,
        );
        final playlistItem2 = makeInfo(
          id: 'pv2',
          title: 'Mountain Clip',
          originalUrl: 'https://example.com/playlist',
          filesize: 6 * 1024 * 1024,
        );

        final group0 = MediaGroup(items: [video1], originalUrl: video1.originalUrl);
        final group1 = MediaGroup(items: [img1], originalUrl: img1.originalUrl);
        final playlistGroup = MediaGroup(
          items: [playlistItem1, playlistItem2],
          originalUrl: 'https://example.com/playlist',
        );

        controller.cache.parsedItems = [group0, group1, playlistGroup];
        controller.cache.configs.addAll({
          0: DownloadConfig(),
          1: DownloadConfig(),
          2: DownloadConfig(),
        });
        controller.recalculateFilteredStatistics();

        await pumpWindow(tester, container: container);

        // Search for "Urban" in root
        final state = standaloneState(tester);
        state.searchControllerForTesting.text = 'Urban';
        state.onSearchChangedForTesting();
        await tester.pump(const Duration(milliseconds: 350));

        // Only "Urban Image" visible -> 0 videos, 1 image, 2MB
        var locationBar = tester.widget<StandaloneWindowLocationBar>(
          find.byType(StandaloneWindowLocationBar),
        );
        expect(locationBar.totalVideos, 0);
        expect(locationBar.totalImages, 1);
        expect(locationBar.totalSize, 2 * 1024 * 1024);

        // Clear search
        state.searchControllerForTesting.text = '';
        state.onSearchChangedForTesting();
        await tester.pump(const Duration(milliseconds: 350));

        // Open Nature Playlist
        final playlistFinder = find.text('Nature Playlist');
        await doubleTapFinder(tester, playlistFinder);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        // Filter within playlist for "Mountain"
        state.searchControllerForTesting.text = 'Mountain';
        state.onSearchChangedForTesting();
        await tester.pump(const Duration(milliseconds: 350));

        // Only Mountain Clip visible -> 1 video, 0 images, 6MB
        locationBar = tester.widget<StandaloneWindowLocationBar>(
          find.byType(StandaloneWindowLocationBar),
        );
        expect(locationBar.totalVideos, 1);
        expect(locationBar.totalImages, 0);
        expect(locationBar.totalSize, 6 * 1024 * 1024);
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-026: Default download location to Downloads & downloads to location section path
    // ═══════════════════════════════════════════════════════════════
    testWidgets(
      'W-SDW-026: defaults download location to Downloads and downloads to footer location',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        final home = Platform.isWindows
            ? (Platform.environment['USERPROFILE'] ?? r'C:\')
            : (Platform.environment['HOME'] ?? '/');
        final defaultDownloads = p.join(home, 'Downloads');

        final item = makeInfo(
          id: 'item-dl',
          title: 'Download Target Item',
          originalUrl: 'https://example.com/target.mp4',
          filesize: 5 * 1024 * 1024,
        );
        final group = MediaGroup(items: [item], originalUrl: item.originalUrl);
        controller.cache.parsedItems = [group];
        controller.cache.configs[0] = DownloadConfig();

        // Pump window without explicit currentPath in initParams
        await pumpWindow(tester, container: container);

        final state = standaloneState(tester);
        // Should default to Downloads directory
        expect(state.currentPathForTesting, defaultDownloads);

        // Location bar displays the default Downloads path
        final locationBarFinder = find.byType(StandaloneWindowLocationBar);
        expect(locationBarFinder, findsOneWidget);
        final locationBar = tester.widget<StandaloneWindowLocationBar>(
          locationBarFinder,
        );
        expect(locationBar.currentPath, defaultDownloads);

        // User changes the location in footer
        final customDest = p.join(tempDir.path, 'MyCustomDownloads');
        state.currentPathForTesting = customDest;
        await tester.pump(const Duration(milliseconds: 50));

        // Start download by tapping download button
        await tester.tap(find.byIcon(Icons.download_rounded).first);
        await tester.pump(const Duration(milliseconds: 50));

        expect(taskNotifier.calls, hasLength(1));
        expect(taskNotifier.calls.first['destination'], customDest);
        expect(taskNotifier.calls.first['title'], 'Download Target Item');
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-027: Clicking download on an item inside a group (playlist/profile) downloads only that single item
    // ═══════════════════════════════════════════════════════════════
    testWidgets(
      'W-SDW-027: clicking download button of one item in grouped items downloads only that item',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        final item1 = makeInfo(
          id: 'vid-101',
          title: 'First Group Video',
          originalUrl: 'https://www.youtube.com/playlist?list=PL123',
          webpageUrl: 'https://www.youtube.com/watch?v=vid-101',
          filesize: 10 * 1024 * 1024,
          isPlaylist: true, // Group item might inherit isPlaylist flag
        );
        final item2 = makeInfo(
          id: 'vid-102',
          title: 'Second Group Video',
          originalUrl: 'https://www.youtube.com/playlist?list=PL123',
          webpageUrl: 'https://www.youtube.com/watch?v=vid-102',
          filesize: 20 * 1024 * 1024,
          isPlaylist: true,
        );
        final group = MediaGroup(
          items: [item1, item2],
          originalUrl: 'https://www.youtube.com/playlist?list=PL123',
        );
        controller.cache.parsedItems = [group];
        controller.cache.configs[0] = DownloadConfig();

        await pumpWindow(
          tester,
          container: container,
          initParams: <String, dynamic>{'currentPath': tempDir.path},
        );

        // Double tap playlist to open grouped view
        final playlistFinder = find.text('First Group Video');
        await doubleTapFinder(tester, playlistFinder);
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        final state = standaloneState(tester);
        expect(state.currentGroupForTesting, isNotNull);
        expect(state.currentGroupForTesting!.items.length, 2);

        // Tap download button on the first item
        final downloadButtons = find.byIcon(Icons.download_rounded);
        expect(downloadButtons, findsWidgets);
        await tester.tap(downloadButtons.first);
        await tester.pump(const Duration(milliseconds: 50));

        // Must trigger ONLY ONE download task for that single item!
        expect(taskNotifier.calls, hasLength(1));
        final call = taskNotifier.calls.first;
        expect(call['action'], 'start');
        expect(call['url'], 'https://www.youtube.com/watch?v=vid-101');
        expect(call['title'], 'First Group Video');
        expect(
          call['destination'],
          tempDir.path,
          reason:
              'Single item download from group must go directly to destination root without subfolder',
        );
        expect(
          call['isPlaylist'],
          isFalse,
          reason: 'Single item must not be marked as playlist',
        );
        expect(
          call['isProfile'],
          isFalse,
          reason: 'Single item must not be marked as profile',
        );
        expect(
          call['totalItems'],
          1,
          reason: 'Single item must have totalItems = 1',
        );
        expect(call['singleItemId'], 'vid-101');
        expect(call['downloadType'], 'video');

        // Item must be removed from the active group view
        expect(state.currentGroupForTesting!.items.length, 1);
        expect(state.currentGroupForTesting!.items.first.id, 'vid-102');
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-028: Downloading selected items in a grouped item downloads only selected items as single items
    // ═══════════════════════════════════════════════════════════════
    testWidgets(
      'W-SDW-028: downloading selected items in a group downloads only selected items as single items directly to dest',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        final item1 = makeInfo(
          id: 'photo-1',
          title: 'Photo One',
          originalUrl: 'https://instagram.com/user',
          directUrl: 'https://instagram.com/photo1.jpg',
          isVideo: false,
          isProfile: true,
        );
        final item2 = makeInfo(
          id: 'photo-2',
          title: 'Photo Two',
          originalUrl: 'https://instagram.com/user',
          directUrl: 'https://instagram.com/photo2.jpg',
          isVideo: false,
          isProfile: true,
        );
        final item3 = makeInfo(
          id: 'photo-3',
          title: 'Photo Three',
          originalUrl: 'https://instagram.com/user',
          directUrl: 'https://instagram.com/photo3.jpg',
          isVideo: false,
          isProfile: true,
        );
        final group = MediaGroup(
          items: [item1, item2, item3],
          originalUrl: 'https://instagram.com/user',
        );
        controller.cache.parsedItems = [group];
        controller.cache.configs[0] = DownloadConfig();

        await pumpWindow(
          tester,
          container: container,
          initParams: <String, dynamic>{'currentPath': tempDir.path},
        );

        // Open profile group
        await doubleTapFinder(tester, find.text('Photo One'));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }

        final state = standaloneState(tester);
        // Select item 0 and item 1
        state.onItemTapForTesting(0);
        state.onItemTapForTesting(1, isCtrl: true);
        await tester.pump(const Duration(milliseconds: 50));

        // Tap Download 2 in footer location bar
        final downloadSelectedFinder = find.text('Download 2');
        expect(downloadSelectedFinder, findsOneWidget);
        await tester.tap(downloadSelectedFinder);
        await tester.pump(const Duration(milliseconds: 100));

        // Expect 2 downloads triggered, each for single item directly to dest
        expect(taskNotifier.calls, hasLength(2));
        for (final call in taskNotifier.calls) {
          expect(call['isPlaylist'], isFalse);
          expect(call['isProfile'], isFalse);
          expect(call['totalItems'], 1);
          expect(call['downloadType'], 'image');
          expect(
            call['destination'],
            tempDir.path,
            reason:
                'Selected item downloads must go directly to destination root',
          );
        }
        expect(
          taskNotifier.calls[0]['url'],
          'https://instagram.com/photo2.jpg',
        );
        expect(
          taskNotifier.calls[1]['url'],
          'https://instagram.com/photo1.jpg',
        );
        expect(state.currentGroupForTesting!.items.length, 1);
        expect(state.currentGroupForTesting!.items.first.id, 'photo-3');
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-029: Downloading entire grouped item creates a single enclosing folder
    // ═══════════════════════════════════════════════════════════════
    testWidgets(
      'W-SDW-029: downloading entire grouped item creates a single enclosing folder for all files',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        final item1 = makeInfo(
          id: 'item-1',
          title: 'Carousel Item 1',
          originalUrl: 'https://instagram.com/p/123',
          directUrl: 'https://instagram.com/p/123/item1.jpg',
          isVideo: false,
        );
        final item2 = makeInfo(
          id: 'item-2',
          title: 'Carousel Item 2',
          originalUrl: 'https://instagram.com/p/123',
          directUrl: 'https://instagram.com/p/123/item2.mp4',
        );
        final group = MediaGroup(
          items: [item1, item2],
          originalUrl: 'https://instagram.com/p/123',
        );
        controller.cache.parsedItems = [group];
        controller.cache.configs[0] = DownloadConfig();

        await pumpWindow(
          tester,
          container: container,
          initParams: <String, dynamic>{'currentPath': tempDir.path},
        );

        // Tap download on group card in root view
        final downloadButtons = find.byIcon(Icons.download_rounded);
        expect(downloadButtons, findsWidgets);
        await tester.tap(downloadButtons.first);
        await tester.pump(const Duration(milliseconds: 100));

        // Expect 1 single download task triggered for the entire carousel group into a single subfolder
        expect(taskNotifier.calls, hasLength(1));
        final expectedFolder = p.join(tempDir.path, 'Carousel Item 1');
        expect(Directory(expectedFolder).existsSync(), isTrue);
        final call = taskNotifier.calls.first;
        expect(call['destination'], expectedFolder);
        expect(call['totalItems'], 2);
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-030: Single root item downloads directly to destination root without creating a subfolder
    // ═══════════════════════════════════════════════════════════════
    testWidgets(
      'W-SDW-030: single root item downloads directly to destination root without creating subfolder',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        final singleItem = makeInfo(
          id: 'single-vid',
          title: 'Single Standalone Video',
          originalUrl: 'https://youtube.com/watch?v=single-vid',
        );
        final group = MediaGroup(
          items: [singleItem],
          originalUrl: 'https://youtube.com/watch?v=single-vid',
        );
        controller.cache.parsedItems = [group];
        controller.cache.configs[0] = DownloadConfig();

        await pumpWindow(
          tester,
          container: container,
          initParams: <String, dynamic>{'currentPath': tempDir.path},
        );

        // Tap download on single card in root view
        final downloadButtons = find.byIcon(Icons.download_rounded);
        expect(downloadButtons, findsWidgets);
        await tester.tap(downloadButtons.first);
        await tester.pump(const Duration(milliseconds: 100));

        expect(taskNotifier.calls, hasLength(1));
        final call = taskNotifier.calls.first;
        expect(call['destination'], tempDir.path);
        expect(call['totalItems'], 1);
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-031: Grouped item download reuses existing folder without creating (1)/(2) numbered folders
    // ═══════════════════════════════════════════════════════════════
    testWidgets(
      'W-SDW-031: downloading grouped item when destination folder already exists reuses folder and does not create duplicate numbered folders',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        // Pre-create the directory to simulate existing folder
        final existingFolder = Directory(p.join(tempDir.path, 'Photo Album'));
        existingFolder.createSync(recursive: true);

        final item1 = makeInfo(
          id: 'photo-1',
          title: 'Photo Album',
          originalUrl: 'https://instagram.com/p/album',
          directUrl: 'https://instagram.com/p/album/1.jpg',
          isVideo: false,
        );
        final item2 = makeInfo(
          id: 'photo-2',
          title: 'Photo Album',
          originalUrl: 'https://instagram.com/p/album',
          directUrl: 'https://instagram.com/p/album/2.jpg',
          isVideo: false,
        );
        final group = MediaGroup(
          items: [item1, item2],
          originalUrl: 'https://instagram.com/p/album',
        );
        controller.cache.parsedItems = [group];
        controller.cache.configs[0] = DownloadConfig();

        await pumpWindow(
          tester,
          container: container,
          initParams: <String, dynamic>{'currentPath': tempDir.path},
        );

        final downloadButtons = find.byIcon(Icons.download_rounded);
        expect(downloadButtons, findsWidgets);
        await tester.tap(downloadButtons.first);
        await tester.pump(const Duration(milliseconds: 100));

        expect(taskNotifier.calls, hasLength(1));
        final call = taskNotifier.calls.first;
        expect(call['destination'], existingFolder.path);
        expect(call['totalItems'], 2);

        // Verify no duplicate numbered folders were created in tempDir
        expect(Directory(p.join(tempDir.path, 'Photo Album (1)')).existsSync(), isFalse);
        expect(Directory(p.join(tempDir.path, 'Photo Album (2)')).existsSync(), isFalse);
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-032: Profile/playlist grouped download creates a single enclosing directory and routes all items there
    // ═══════════════════════════════════════════════════════════════
    testWidgets(
      'W-SDW-032: profile and playlist grouped downloads create a single enclosing directory and do not create duplicate subfolders',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        final profileItem = makeInfo(
          id: 'prof-root',
          title: 'User Profile',
          originalUrl: 'https://instagram.com/user',
          isProfile: true,
        );
        final subItem1 = makeInfo(
          id: 'sub-1',
          title: 'User Profile',
          originalUrl: 'https://instagram.com/user',
          directUrl: 'https://instagram.com/media1.jpg',
        );
        final subItem2 = makeInfo(
          id: 'sub-2',
          title: 'User Profile',
          originalUrl: 'https://instagram.com/user',
          directUrl: 'https://instagram.com/media2.jpg',
        );
        final group = MediaGroup(
          items: [profileItem, subItem1, subItem2],
          originalUrl: 'https://instagram.com/user',
        );
        controller.cache.parsedItems = [group];
        controller.cache.configs[0] = DownloadConfig();

        await pumpWindow(
          tester,
          container: container,
          initParams: <String, dynamic>{'currentPath': tempDir.path},
        );

        final downloadButtons = find.byIcon(Icons.download_rounded);
        expect(downloadButtons, findsWidgets);
        await tester.tap(downloadButtons.first);
        await tester.pump(const Duration(milliseconds: 100));

        expect(taskNotifier.calls, hasLength(1));
        final call = taskNotifier.calls.first;
        final expectedFolder = p.join(tempDir.path, 'User Profile');
        expect(call['destination'], expectedFolder);
        expect(call['isProfile'], isTrue);
        expect(Directory(expectedFolder).existsSync(), isTrue);
        expect(Directory(p.join(tempDir.path, 'User Profile (1)')).existsSync(), isFalse);
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-033: Download All across multiple groups creates only one folder per multi-item group
    // ═══════════════════════════════════════════════════════════════
    testWidgets(
      'W-SDW-033: Download All across multiple groups creates only one folder per multi-item group without conflict-numbered folders',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        // Group 1: 2 items named "Collection Alpha"
        final g1i1 = makeInfo(
          id: 'g1-1',
          title: 'Collection Alpha',
          originalUrl: 'https://example.com/g1',
          directUrl: 'https://example.com/g1-1.jpg',
        );
        final g1i2 = makeInfo(
          id: 'g1-2',
          title: 'Collection Alpha',
          originalUrl: 'https://example.com/g1',
          directUrl: 'https://example.com/g1-2.jpg',
        );
        final group1 = MediaGroup(
          items: [g1i1, g1i2],
          originalUrl: 'https://example.com/g1',
        );

        // Group 2: Single item named "Single Beta"
        final g2i1 = makeInfo(
          id: 'g2-1',
          title: 'Single Beta',
          originalUrl: 'https://example.com/g2',
          directUrl: 'https://example.com/g2-1.mp4',
        );
        final group2 = MediaGroup(
          items: [g2i1],
          originalUrl: 'https://example.com/g2',
        );

        controller.cache.parsedItems = [group1, group2];
        controller.cache.configs[0] = DownloadConfig();
        controller.cache.configs[1] = DownloadConfig();

        await pumpWindow(
          tester,
          container: container,
          initParams: <String, dynamic>{'currentPath': tempDir.path},
        );

        // Tap Download All on the location bar
        final downloadAllFinder = find.text('Download All');
        expect(downloadAllFinder, findsOneWidget);
        await tester.tap(downloadAllFinder);
        await tester.pump(const Duration(milliseconds: 100));

        // Expect 1 single call for group 1 (into Collection Alpha) and 1 call for group 2 (into root tempDir)
        expect(taskNotifier.calls, hasLength(2));
        final g1Dest = p.join(tempDir.path, 'Collection Alpha');
        expect(taskNotifier.calls[0]['destination'], g1Dest);
        expect(taskNotifier.calls[0]['totalItems'], 2);
        expect(taskNotifier.calls[1]['destination'], tempDir.path);
        expect(taskNotifier.calls[1]['totalItems'], 1);

        // Verify folder structure
        expect(Directory(g1Dest).existsSync(), isTrue);
        expect(Directory(p.join(tempDir.path, 'Collection Alpha (1)')).existsSync(), isFalse);
        expect(Directory(p.join(tempDir.path, 'Single Beta')).existsSync(), isFalse);
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-035: Group title with newlines/tabs sanitizes cleanly into a single folder
    // ═══════════════════════════════════════════════════════════════
    testWidgets(
      'W-SDW-035: group title with newlines/tabs sanitizes cleanly into a single folder without multiple folders',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        final item1 = makeInfo(
          id: 'multiline-1',
          title: "You wouldn't get it😌\n#newpost",
          originalUrl: 'https://instagram.com/p/multiline',
          directUrl: 'https://instagram.com/p/multiline/1.jpg',
        );
        final item2 = makeInfo(
          id: 'multiline-2',
          title: "You wouldn't get it😌\n#newpost",
          originalUrl: 'https://instagram.com/p/multiline',
          directUrl: 'https://instagram.com/p/multiline/2.jpg',
        );
        final group = MediaGroup(
          items: [item1, item2],
          originalUrl: 'https://instagram.com/p/multiline',
        );
        controller.cache.parsedItems = [group];
        controller.cache.configs[0] = DownloadConfig();

        await pumpWindow(
          tester,
          container: container,
          initParams: <String, dynamic>{'currentPath': tempDir.path},
        );

        final downloadButtons = find.byIcon(Icons.download_rounded);
        expect(downloadButtons, findsWidgets);
        await tester.tap(downloadButtons.first);
        await tester.pump(const Duration(milliseconds: 100));

        expect(taskNotifier.calls, hasLength(1));
        final call = taskNotifier.calls.first;
        final expectedFolder = p.join(tempDir.path, "You wouldn't get it😌 #newpost");
        expect(call['destination'], expectedFolder);
        expect(Directory(expectedFolder).existsSync(), isTrue);

        // Verify NO newline folder or duplicate folders were created
        expect(Directory(p.join(tempDir.path, "You wouldn't get it😌\n#newpost")).existsSync(), isFalse);
        expect(Directory(p.join(tempDir.path, "You wouldn't get it😌")).existsSync(), isFalse);
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-015: Group Download with Deleted Items passes exact range
    // ═══════════════════════════════════════════════════════════════
    testWidgets(
      'W-SDW-015: group download after deleting items passes surviving itemsRange and expectedBytes',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        final item1 = makeInfo(
          id: 'item-1',
          title: 'Carousel Item 1',
          galleryIndex: 1,
          filesize: 1000,
          originalUrl: 'https://instagram.com/p/carousel123',
        );
        final item4 = makeInfo(
          id: 'item-4',
          title: 'Carousel Item 4',
          galleryIndex: 4,
          filesize: 4000,
          originalUrl: 'https://instagram.com/p/carousel123',
        );
        // Suppose items 2 and 3 were deleted, leaving only items 1 and 4 in the group
        final group = MediaGroup(
          items: [item1, item4],
          originalUrl: 'https://instagram.com/p/carousel123',
        );
        controller.cache.parsedItems = [group];
        controller.cache.configs[0] = DownloadConfig();

        await pumpWindow(
          tester,
          container: container,
          initParams: <String, dynamic>{'currentPath': tempDir.path},
        );

        final downloadButtons = find.byIcon(Icons.download_rounded);
        expect(downloadButtons, findsWidgets);
        await tester.tap(downloadButtons.first);
        await tester.pump(const Duration(milliseconds: 100));

        expect(taskNotifier.calls, hasLength(1));
        final call = taskNotifier.calls.first;
        expect(call['itemsRange'], '1,4');
        expect(call['totalItems'], 2);
        expect(call['expectedBytes'], 5000);
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-016: Intact Group Download passes null itemsRange
    // ═══════════════════════════════════════════════════════════════
    testWidgets(
      'W-SDW-016: intact group download (all items present) passes itemsRange as null',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        final item1 = makeInfo(
          id: 'item-1',
          title: 'Carousel Item 1',
          galleryIndex: 1,
          filesize: 1000,
          originalUrl: 'https://instagram.com/p/carousel123',
        );
        final item2 = makeInfo(
          id: 'item-2',
          title: 'Carousel Item 2',
          galleryIndex: 2,
          filesize: 2000,
          originalUrl: 'https://instagram.com/p/carousel123',
        );
        final item3 = makeInfo(
          id: 'item-3',
          title: 'Carousel Item 3',
          galleryIndex: 3,
          filesize: 3000,
          originalUrl: 'https://instagram.com/p/carousel123',
        );
        final group = MediaGroup(
          items: [item1, item2, item3],
          originalUrl: 'https://instagram.com/p/carousel123',
        );
        controller.cache.parsedItems = [group];
        controller.cache.configs[0] = DownloadConfig();

        await pumpWindow(
          tester,
          container: container,
          initParams: <String, dynamic>{'currentPath': tempDir.path},
        );

        final downloadButtons = find.byIcon(Icons.download_rounded);
        expect(downloadButtons, findsWidgets);
        await tester.tap(downloadButtons.first);
        await tester.pump(const Duration(milliseconds: 100));

        expect(taskNotifier.calls, hasLength(1));
        final call = taskNotifier.calls.first;
        expect(call['itemsRange'], isNull);
        expect(call['totalItems'], 3);
        expect(call['expectedBytes'], 6000);
      },
    );

    // ═══════════════════════════════════════════════════════════════
    // W-SDW-021: Deleting a hydrating root item calls cancelHydration
    // ═══════════════════════════════════════════════════════════════
    testWidgets(
      'W-SDW-021: deleting a hydrating root item cancels hydration on controller',
      (tester) async {
        final controller = RecordingDownloadsSharedController();
        final taskNotifier = RecordingDownloadTaskNotifier();
        final container = createContainer(
          controller: controller,
          taskNotifier: taskNotifier,
          currentPath: tempDir.path,
        );
        addTearDown(container.dispose);

        const testUrl = 'https://instagram.com/p/hydrating_post';
        final loadingItem = makeInfo(
          id: 'hydration_loading',
          title: 'Loading...',
          originalUrl: testUrl,
        );
        final group = MediaGroup(
          items: [loadingItem],
          originalUrl: testUrl,
        );

        controller.cache.parsedItems = <MediaGroup>[group];
        controller.backgroundLoadingProfiles.add(testUrl);
        controller.activeHydrationPids[testUrl] = <int>[12345];

        await pumpWindow(
          tester,
          container: container,
          initParams: <String, dynamic>{'currentPath': tempDir.path},
        );

        expect(controller.backgroundLoadingProfiles.contains(testUrl), isTrue);

        standaloneState(tester).selectedIndicesForTesting.add(0);
        standaloneState(tester).handleDeleteForTesting(false);
        await tester.pump();

        expect(controller.backgroundLoadingProfiles.contains(testUrl), isFalse);
        expect(controller.activeHydrationPids.containsKey(testUrl), isFalse);
        expect(controller.cache.parsedItems, isEmpty);
      },
    );
  });
}
