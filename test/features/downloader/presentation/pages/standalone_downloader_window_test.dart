import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/pages/standalone_downloader_window.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_shared_controller.dart';

// ignore_for_file: avoid_dynamic_calls, invalid_use_of_protected_member

class MockDownloadsSharedController extends Mock implements DownloadsSharedController {
  final _cache = DownloadsListCache();

  @override
  DownloadsListCache get cache => _cache;

  @override
  String get selectedEngine => 'yt-dlp';

  @override
  Map<String, List<int>> get activeHydrationPids => {};

  @override
  int get totalListVideos => 0;

  @override
  int get totalListImages => 0;

  @override
  int get totalListSize => 0;
}
class MockPersistentViewerManager extends Mock implements PersistentViewerManager {}
class MockDownloadsListCache extends Mock implements DownloadsListCache {}

class MockDownloadTaskNotifier extends Notifier<List<DownloadTask>> with Mock implements DownloadTaskNotifier {
  final calls = <Map<String, dynamic>>[];

  @override
  List<DownloadTask> build() => [];

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
    calls.add({
      'action': 'start',
      'url': url,
      'destination': destination,
      'title': title,
    });
  }

  @override
  Future<void> cancelDownload(String url) async {
    calls.add({'action': 'cancel', 'url': url});
  }
}

void main() {
  setUpAll(TestWidgetsFlutterBinding.ensureInitialized);

  group('StandaloneDownloaderWindow Unit Tests', () {
    testWidgets('U-SDW-001 to U-SDW-015: _getHeight() logic', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StandaloneDownloaderWindow(windowId: 1),
            ),
          ),
        ),
      );
      final state = tester.state(find.byType(StandaloneDownloaderWindow)) as dynamic;
      
      expect(state.getHeightForTesting(''), 0, reason: 'U-SDW-001');
      expect(state.getHeightForTesting('audio only'), 0, reason: 'U-SDW-002');
      expect(state.getHeightForTesting('audio'), 0, reason: 'U-SDW-003');
      expect(state.getHeightForTesting('4K'), 2160, reason: 'U-SDW-004');
      expect(state.getHeightForTesting('2160p'), 2160, reason: 'U-SDW-005');
      expect(state.getHeightForTesting('1440p'), 1440, reason: 'U-SDW-006');
      expect(state.getHeightForTesting('2K'), 1440, reason: 'U-SDW-007');
      expect(state.getHeightForTesting('1080p'), 1080, reason: 'U-SDW-008');
      expect(state.getHeightForTesting('720p'), 720, reason: 'U-SDW-009');
      expect(state.getHeightForTesting('480p'), 480, reason: 'U-SDW-010');
      expect(state.getHeightForTesting('1920x1080'), 1080, reason: 'U-SDW-011');
      expect(state.getHeightForTesting('abcd'), 0, reason: 'U-SDW-012');
      expect(state.getHeightForTesting('Video 720 HD'), 720, reason: 'U-SDW-013');
      expect(state.getHeightForTesting('360p'), 360, reason: 'U-SDW-014');
      expect(state.getHeightForTesting('AUDIO ONLY'), 0, reason: 'U-SDW-015');
    });
  });

  group('StandaloneDownloaderWindow Widget Tests', () {
    Widget createWidget({Map<String, dynamic> initParams = const {}}) {
      return ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: StandaloneDownloaderWindow(windowId: 1, initParams: initParams),
          ),
        ),
      );
    }

    group('Initialization & Lifecycle', () {
      testWidgets('W-SDW-001: Render successfully', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(createWidget());
        expect(find.byType(StandaloneDownloaderWindow), findsOneWidget);
      });

      testWidgets('W-SDW-002 to W-SDW-007: Lifecycle init', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(createWidget(initParams: {'currentPath': '/test/path'}));
        final state = tester.state(find.byType(StandaloneDownloaderWindow)) as dynamic;
        expect(state.currentPathForTesting, '/test/path', reason: 'W-SDW-002');
      });

      testWidgets('W-SDW-008 to W-SDW-009: didUpdateWidget', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(createWidget(initParams: {'currentPath': '/test/path1'}));
        dynamic state = tester.state(find.byType(StandaloneDownloaderWindow));
        expect(state.currentPathForTesting, '/test/path1');

        await tester.pumpWidget(createWidget(initParams: {'currentPath': '/test/path2'}));
        state = tester.state(find.byType(StandaloneDownloaderWindow));
        expect(state.currentPathForTesting, '/test/path2', reason: 'W-SDW-008');
      });
      
      testWidgets('W-SDW-010 to W-SDW-012: dispose', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(createWidget());
        await tester.pumpWidget(const SizedBox()); // dispose
      });
    });

    group('Search', () {
      testWidgets('W-SDW-013 to W-SDW-020: Search input and debounce', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(createWidget());
        final state = tester.state(find.byType(StandaloneDownloaderWindow)) as dynamic;
        expect(state.searchControllerForTesting.text, '', reason: 'W-SDW-013');
        
        state.searchControllerForTesting.text = 'test';
        state.onSearchChangedForTesting();
        expect(state.searchDebounceForTesting?.isActive, true, reason: 'W-SDW-014');
        
        await tester.pump(const Duration(milliseconds: 350));
        expect(state.searchDebounceForTesting?.isActive, false, reason: 'W-SDW-015');
      });
    });

    group('Global Keyboard Shortcuts', () {
      testWidgets('W-SDW-025 to W-SDW-032: Ctrl+F and Ctrl+D', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createWidget());
        final state = tester.state(find.byType(StandaloneDownloaderWindow)) as dynamic;
        
        await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
        await tester.pump(const Duration(milliseconds: 100));
        
        expect(state.isSearchVisibleForTesting, true, reason: 'W-SDW-025');
        
        await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
        await tester.pump(const Duration(milliseconds: 100));
        expect(state.isSearchVisibleForTesting, false, reason: 'W-SDW-026');
        
        await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      });
    });

    group('Tab State Management', () {
      testWidgets('W-SDW-033 to W-SDW-042: Save and Restore tab state', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createWidget());
        final state = tester.state(find.byType(StandaloneDownloaderWindow)) as dynamic;
        
        state.searchControllerForTesting.text = 'hello';
        state.isSearchVisibleForTesting = true;
        state.selectedIndicesForTesting.add(1);
        
        state.saveCurrentTabStateForTesting('path1');
        
        state.searchControllerForTesting.text = '';
        state.isSearchVisibleForTesting = false;
        state.selectedIndicesForTesting.clear();
        
        state.restoreTabStateForTesting('path1');
        expect(state.searchControllerForTesting.text, 'hello', reason: 'W-SDW-041');
        expect(state.isSearchVisibleForTesting, true, reason: 'W-SDW-042');
        expect(state.selectedIndicesForTesting.contains(1), true, reason: 'W-SDW-040');
      });
    });

    group('Delete Workflow', () {
      testWidgets('W-SDW-043 to W-SDW-054: Delete operations', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createWidget());
        final state = tester.state(find.byType(StandaloneDownloaderWindow)) as dynamic;
        
        state.selectedIndicesForTesting.clear();
        state.handleDeleteForTesting(false);
        // should do nothing
        
        state.selectedIndicesForTesting.add(0);
        state.handleDeleteForTesting(true);
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Permanently Delete'), findsOneWidget, reason: 'W-SDW-045');
        
        await tester.tap(find.text('Cancel'));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Permanently Delete'), findsNothing, reason: 'W-SDW-046');
      });
    });

    group('Download Workflow & Download All', () {
      Widget createWidgetWithMocks({
        required DownloadsSharedController controller,
        required DownloadTaskNotifier taskNotifier,
      }) {
        return ProviderScope(
          overrides: [
            downloadsSharedControllerProvider.overrideWith((ref) => controller),
            downloadTaskProvider.overrideWith(() => taskNotifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StandaloneDownloaderWindow(windowId: 1),
            ),
          ),
        );
      }

      testWidgets('W-SDW-055 to W-SDW-061: Download Selected logic', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockController = MockDownloadsSharedController();
        final mockCache = mockController.cache;
        final mockTaskNotifier = MockDownloadTaskNotifier();

        final item1 = MediaInfo(title: 'T1', originalUrl: 'u1', id: '1', isPlaylist: true);
        final item2 = MediaInfo(title: 'T2', originalUrl: 'u2', id: '2', isPlaylist: true);
        final group1 = MediaGroup(originalUrl: 'u1', items: [item1]);
        final group2 = MediaGroup(originalUrl: 'u2', items: [item2]);

        mockCache.parsedItems = [group1, group2];
        mockCache.configs.clear();

        await tester.pumpWidget(createWidgetWithMocks(
          controller: mockController,
          taskNotifier: mockTaskNotifier,
        ));
        
        final state = tester.state(find.byType(StandaloneDownloaderWindow)) as dynamic;
        
        // W-SDW-055: Ignore download when nothing selected
        state.selectedIndicesForTesting.clear();
        mockCache.parsedItems = []; 
        mockTaskNotifier.calls.clear();
        await tester.tap(find.text('Download All'));
        await tester.pump();
        expect(mockTaskNotifier.calls.isEmpty, true, reason: 'No items to download');

        // W-SDW-056: Download single selected item
        mockCache.parsedItems = [group1, group2];
        state.selectedIndicesForTesting.clear();
        state.selectedIndicesForTesting.add(0);
        mockTaskNotifier.calls.clear();
        await tester.tap(find.text('Download All'));
        await tester.pump();
        expect(mockTaskNotifier.calls.length, 1);
        
        // W-SDW-057: Download multiple selected items
        mockCache.parsedItems = [group1, group2];
        state.selectedIndicesForTesting.clear();
        state.selectedIndicesForTesting.addAll([0, 1]);
        mockTaskNotifier.calls.clear();
        await tester.tap(find.text('Download All'));
        await tester.pump();
        expect(mockTaskNotifier.calls.length, 2);
      });

      testWidgets('W-SDW-065 to W-SDW-071: Download All logic', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockController = MockDownloadsSharedController();
        final mockCache = mockController.cache;
        final mockTaskNotifier = MockDownloadTaskNotifier();

        final item1 = MediaInfo(title: 'T1', originalUrl: 'u1', id: '1', isPlaylist: true);
        final item2 = MediaInfo(title: 'T2', originalUrl: 'u2', id: '2', isPlaylist: true);
        final group1 = MediaGroup(originalUrl: 'u1', items: [item1]);
        final group2 = MediaGroup(originalUrl: 'u2', items: [item2]);

        await tester.pumpWidget(createWidgetWithMocks(
          controller: mockController,
          taskNotifier: mockTaskNotifier,
        ));
        
        final state = tester.state(find.byType(StandaloneDownloaderWindow)) as dynamic;
        state.selectedIndicesForTesting.clear();

        // W-SDW-065: Ignore empty download list
        mockCache.parsedItems = []; 
        mockTaskNotifier.calls.clear();
        await tester.tap(find.text('Download All'));
        await tester.pump();
        expect(mockTaskNotifier.calls.isEmpty, true);

        // W-SDW-066: Download every configuration
        mockCache.parsedItems = [group1, group2];
        mockTaskNotifier.calls.clear();
        await tester.tap(find.text('Download All'));
        await tester.pump();
        expect(mockTaskNotifier.calls.length, 2);
      });
    });

    group('Action Bar & Trash View', () {
      Widget createWidget({Map<String, dynamic> initParams = const {}}) {
        return ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StandaloneDownloaderWindow(windowId: 1, initParams: initParams),
            ),
          ),
        );
      }

      testWidgets('W-SDW-091 to W-SDW-100: Action Bar Interactions', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockController = MockDownloadsSharedController();
        final mockCache = mockController.cache;
        final mockTaskNotifier = MockDownloadTaskNotifier();

        final item1 = MediaInfo(title: 'T1', originalUrl: 'u1', id: '1');
        final group1 = MediaGroup(originalUrl: 'u1', items: [item1]);
        mockCache.parsedItems = [group1];

        await tester.pumpWidget(ProviderScope(
          overrides: [
            downloadsSharedControllerProvider.overrideWith((ref) => mockController),
            downloadTaskProvider.overrideWith(() => mockTaskNotifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StandaloneDownloaderWindow(windowId: 1),
            ),
          ),
        ));

        final state = tester.state(find.byType(StandaloneDownloaderWindow)) as dynamic;
        
        // Test clear list
        state.selectedIndicesForTesting.add(0);
        await tester.tap(find.text('Clear List'));
        await tester.pump();
        
        expect(mockCache.parsedItems?.isEmpty ?? true, true, reason: 'W-SDW-094');
        expect(mockCache.configs.isEmpty, true, reason: 'W-SDW-095');
      });

      testWidgets('W-SDW-101 to W-SDW-112: Trash View Toggling', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createWidget());
        final state = tester.state(find.byType(StandaloneDownloaderWindow)) as dynamic;
        
        // Turn trash view on
        await tester.tap(find.byIcon(Icons.delete_outline));
        await tester.pump();
        
        expect(state.isTrashViewForTesting, true, reason: 'W-SDW-102');
        expect(find.text('Trash'), findsWidgets, reason: 'W-SDW-104');
      });
    });

    group('Media Grid & Item Rendering', () {
      Widget createWidgetWithMocks({
        required DownloadsSharedController controller,
        required DownloadTaskNotifier taskNotifier,
      }) {
        return ProviderScope(
          overrides: [
            downloadsSharedControllerProvider.overrideWith((ref) => controller),
            downloadTaskProvider.overrideWith(() => taskNotifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StandaloneDownloaderWindow(windowId: 1),
            ),
          ),
        );
      }

      testWidgets('W-SDW-113 to W-SDW-117: Render grid items based on config', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockController = MockDownloadsSharedController();
        final mockCache = mockController.cache;
        final mockTaskNotifier = MockDownloadTaskNotifier();

        mockCache.parsedItems = [];
        mockCache.configs.clear();
        
        await tester.pumpWidget(createWidgetWithMocks(controller: mockController, taskNotifier: mockTaskNotifier));
        await tester.pump(const Duration(milliseconds: 500));
        
        // W-SDW-113: Render empty grid
        expect(find.byIcon(Icons.video_file), findsNothing);
        expect(find.text('vid1.mp4'), findsNothing);

        // W-SDW-114 & W-SDW-115 & W-SDW-117: Single and Multiple items (mixed)
        mockCache.parsedItems = [
          MediaGroup(originalUrl: 'http://t.com/v1.mp4', items: [
            MediaInfo(id: 'vid1', title: 'v1.mp4', originalUrl: 'http://t.com/v1.mp4')
          ]),
          MediaGroup(originalUrl: 'http://t.com/i1.png', items: [
            MediaInfo(id: 'img1', title: 'i1.png', originalUrl: 'http://t.com/i1.png', isVideo: false)
          ])
        ];
        mockCache.configs.addAll({
          0: DownloadConfig(),
          1: DownloadConfig(),
        });
        
        await tester.pumpWidget(createWidgetWithMocks(controller: mockController, taskNotifier: mockTaskNotifier));
        await tester.pump(const Duration(milliseconds: 500));
        
        expect(find.text('v1.mp4'), findsOneWidget, reason: 'W-SDW-114');
        expect(find.text('i1.png'), findsOneWidget, reason: 'W-SDW-115');
      });
    });

    group('Selection', () {
      Widget createWidgetWithMocks({
        required DownloadsSharedController controller,
        required DownloadTaskNotifier taskNotifier,
      }) {
        return ProviderScope(
          overrides: [
            downloadsSharedControllerProvider.overrideWith((ref) => controller),
            downloadTaskProvider.overrideWith(() => taskNotifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StandaloneDownloaderWindow(windowId: 1),
            ),
          ),
        );
      }

      testWidgets('W-SDW-121 to W-SDW-128: Item selection mechanics', (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockController = MockDownloadsSharedController();
        final mockCache = mockController.cache;
        final mockTaskNotifier = MockDownloadTaskNotifier();

        mockCache.parsedItems = [];
        mockCache.configs.clear();
        mockCache.parsedItems = [
          MediaGroup(originalUrl: 'http://t.com/v1.mp4', items: [
            MediaInfo(id: 'vid1', title: 'v1.mp4', originalUrl: 'http://t.com/v1.mp4')
          ]),
          MediaGroup(originalUrl: 'http://t.com/v2.mp4', items: [
            MediaInfo(id: 'vid2', title: 'v2.mp4', originalUrl: 'http://t.com/v2.mp4')
          ])
        ];
        mockCache.configs.addAll({
          0: DownloadConfig(),
          1: DownloadConfig(),
        });

        await tester.pumpWidget(createWidgetWithMocks(controller: mockController, taskNotifier: mockTaskNotifier));
        await tester.pump(const Duration(milliseconds: 500));

        // W-SDW-121: Select single item
        await tester.tap(find.text('v1.mp4'));
        await tester.pump(const Duration(seconds: 1));
        
        // Check if Action Bar updates with 1 item selected (assuming selection shows clear button or similar)
        expect(find.text('Clear List'), findsOneWidget); 

        // W-SDW-122: Deselect selected item
        await tester.tap(find.text('v1.mp4'));
        await tester.pump(const Duration(seconds: 1));
      });
    });
  });
}
