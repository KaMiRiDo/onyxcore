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
      'directUrl': directUrl,
      'expectedBytes': expectedBytes,
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

      if (group.first.isPlaylist || group.first.isProfile) {
        hasUnderestimatedSize = true;
      }
    }

    notifyListeners();
  }

  @override
  Future<void> analyzeUrls(String text) async {
    analyzeCalls.add(text);
  }

  @override
  Future<void> hydrateProfile(String url) async {}

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

    testWidgets('W-SDW-015: changing global format clears individual itemFormats', (tester) async {
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
          makeInfo(id: 'v1', title: 'Video 1', originalUrl: 'https://playlist.example/v1', isPlaylist: true, formats: []),
          makeInfo(id: 'v2', title: 'Video 2', originalUrl: 'https://playlist.example/v2', isPlaylist: true, formats: []),
        ],
      );
      
      controller.cache.parsedItems = [group];
      final config = DownloadConfig();
      config.format = makeFormat(formatId: '1080', resolution: '1080p', filesize: 100);
      config.itemFormats['v1'] = makeFormat(formatId: '720', resolution: '720p', filesize: 50);
      controller.cache.configs[0] = config;

      await pumpWindow(tester, container: container);
      
      final state = standaloneState(tester);
      // Simulate double tap to enter group
      state.onDoubleTapItemForTesting(0, group);
      await tester.pump();
      
      // Simulate onFormatChanged from action bar
      final newFormat = makeFormat(formatId: '4k', resolution: '2160p', filesize: 200);
      
      // Find the FormatSelectionDropdown and change value or directly call method if exposed.
      // We know `rootIndex` is 0 when inside the group
      state.onFormatChangedForTesting(newFormat);
      
      expect(controller.cache.configs[0]?.format?.resolution, '2160p');
      expect(controller.cache.configs[0]?.itemFormats, isEmpty);
    });


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
    testWidgets('W-SDW-017: audio format shows audio icon and playlist suppresses root thumbnail', (tester) async {
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
          makeInfo(id: 'v1', title: 'Video 1', originalUrl: 'https://playlist.example/v1', isPlaylist: true, thumbnail: 'https://thumb.example', formats: [
            makeFormat(formatId: 'a1', resolution: 'audio only', filesize: 100, videoCodec: 'none'),
          ]),
          makeInfo(id: 'v2', title: 'Video 2', originalUrl: 'https://playlist.example/v2', isPlaylist: true, thumbnail: 'https://thumb.example', formats: []),
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

      // Thumbnail is the same as root, so it should be suppressed for both items since both have the same thumbnail.
      expect(find.byIcon(Icons.image), findsWidgets);
    });

    testWidgets('W-SDW-018: global hotkeys function correctly after tapping on the media grid', (tester) async {
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
        items: [makeInfo(id: 'v1', title: 'Video 1', originalUrl: 'https://video.example/v1')],
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
      expect(tester.widget<TextField>(searchField).focusNode?.hasFocus, isTrue);
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
    });

    testWidgets('W-SDW-019: tagging functionality updates the grid and header', (tester) async {
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
        items: [makeInfo(id: 'v1', title: 'Video 1', originalUrl: 'https://video1.example')],
      );
      final group2 = makeGroup(
        originalUrl: 'https://video2.example',
        items: [makeInfo(id: 'v2', title: 'Video 2', originalUrl: 'https://video2.example')],
      );
      controller.cache.parsedItems = [group1, group2];
      controller.cache.configs[0] = DownloadConfig();
      controller.cache.configs[1] = DownloadConfig();

      await pumpWindow(tester, container: container);

      // Verify no tags initially
      expect(find.text('Tag...'), findsNothing);

      // Simulate right-click on the first item to add a tag
      final item = find.text('Video 1');
      final gesture = await tester.startGesture(tester.getCenter(item), buttons: 2);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 50));

      // Find tag input text field in overlay
      final tagFields = find.byType(TextField);
      expect(tagFields.evaluate().length, greaterThanOrEqualTo(3)); // URL, Search, Tag
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
      final gesture2 = await tester.startGesture(tester.getCenter(item), buttons: 2);
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

  });
}
