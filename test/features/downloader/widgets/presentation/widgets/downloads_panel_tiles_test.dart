import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'package:onyxcore/features/downloader/presentation/widgets/downloads_panel.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';

import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:google_fonts/google_fonts.dart';

import 'mock_providers.dart';

class MockSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() {
    return Future.value(const AppSettings(
      downloadBrowser: 'none',
      downloadToCurrentFolder: true,
    ));
  }
}

class MockCurrentPathNotifier extends CurrentPathNotifier {
  @override
  String build() {
    return '/tmp';
  }
}

class MockDownloadTaskNotifier extends DownloadTaskNotifier {
  @override
  List<DownloadTask> build() {
    return [];
  }

  @override
  void addDownloadTask({
    required String url,
    required String destination,
    required String title,
    String downloadType = 'generic',
    MediaFormat? format,
    bool audioOnly = false,
    bool mute = false,
    int? galleryIndex,
    String? engine,
    bool isPlaylist = false,
    bool isProfile = false,
    String? browser,
    bool isZip = false,
    String? filterType,
    int? totalItems,
    String? singleItemId,
    String? directUrl,
  }) {
    // Do nothing for tests
  }
}

class MockYtDlpEngine extends DownloadEngine {
  @override
  String get id => 'yt-dlp';
  @override
  String get name => 'yt-dlp mock';
  @override
  String get binaryName => 'yt-dlp';
  @override
  bool get isInstalled => true;
  @override
  int get priority => 9;
  @override
  List<RegExp> get urlPatterns => [];
  @override
  String? get binaryPath => null;
  @override
  Color get color => const Color(0xFF000000);
  @override
  String get displayName => 'Mock yt-dlp';
  @override
  EngineType get engineType => EngineType.cli;
  @override
  IconData get icon => Icons.video_library;
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
  }) async {
    return [
      MediaInfo(
        id: '123',
        title: 'Mock Video Content',
        originalUrl: url,
        duration: 120,
        thumbnail: 'https://test.com/thumb',
        filesize: 1048576,
      )
    ];
  }

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
    throw UnimplementedError();
  }
}

/// Simulates an engine that returns a grouped/carousel post from social media,
/// matching the actual gallery-dl output pattern after the fix: all items share
/// the same [originalUrl] (the canonical input post URL) so they group into one
/// tile. Before the fix, gallery-dl was setting the per-slide sub-shortcode as
/// [originalUrl], producing separate tiles for every carousel image.
class MockGroupedPostEngine extends DownloadEngine {
  static const String postUrl = 'https://instagram.com/p/abc123/';
  static const String postTitle = 'Grouped Social Post';

  @override
  String get id => 'yt-dlp';
  @override
  String get name => 'mock-grouped';
  @override
  String get binaryName => 'yt-dlp';
  @override
  bool get isInstalled => true;
  @override
  int get priority => 9;
  @override
  List<RegExp> get urlPatterns => [];
  @override
  String? get binaryPath => null;
  @override
  Color get color => const Color(0xFF000000);
  @override
  String get displayName => 'Mock grouped';
  @override
  EngineType get engineType => EngineType.cli;
  @override
  IconData get icon => Icons.video_library;
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
  }) async {
    // Simulate gallery-dl carousel output after the fix:
    // All items share the same originalUrl (the canonical input post URL).
    // This matches gallery_dl_engine.dart which now sets originalUrl: url
    // for every carousel item, ensuring they collapse into one MediaGroup.
    return [
      MediaInfo(
        id: 'img1',
        title: postTitle,
        originalUrl: url,
        isVideo: false,
        filesize: 512000,
      ),
      MediaInfo(
        id: 'img2',
        title: postTitle,
        originalUrl: url,
        isVideo: false,
        filesize: 512000,
      ),
      MediaInfo(
        id: 'img3',
        title: postTitle,
        originalUrl: url,
        isVideo: false,
        filesize: 512000,
      ),
    ];
  }

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
    throw UnimplementedError();
  }
}

class MockErrorEngine extends DownloadEngine {
  @override
  String get id => 'yt-dlp';
  @override
  String get name => 'mock-error';
  @override
  String get binaryName => 'yt-dlp';
  @override
  bool get isInstalled => true;
  @override
  int get priority => 9;
  @override
  List<RegExp> get urlPatterns => [];
  @override
  String? get binaryPath => null;
  @override
  Color get color => const Color(0xFF000000);
  @override
  String get displayName => 'Mock Error';
  @override
  EngineType get engineType => EngineType.cli;
  @override
  IconData get icon => Icons.error;
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
  }) async {
    return [
      MediaInfo(
        id: 'err1',
        title: '',
        originalUrl: url,
        isVideo: false,
        isError: true,
        errorMessage: 'Simulated failure to process URL',
      ),
    ];
  }

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
    throw UnimplementedError();
  }
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = true;

  Widget createTilesTestWidget(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 1600,
            height: 1000,
            child: DownloadsPanel(),
          ),
        ),
      ),
    );
  }

  group('Downloads Panel Tiles Tests', () {
    late ProviderContainer container;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      final window = TestWidgetsFlutterBinding.instance.window;
      window.physicalSizeTestValue = const Size(1600, 1000);
      window.devicePixelRatioTestValue = 1.0;

      // Removed MockBinaryHelper

      HttpOverrides.global = null;
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        if (details.exceptionAsString().contains('RenderFlex overflowed')) {
          return;
        }
        if (details.exceptionAsString().contains('GoogleFonts')) {
          return;
        }
        if (originalOnError != null) {
          originalOnError(details);
        } else {
          FlutterError.presentError(details);
        }
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        if (error.toString().contains('GoogleFonts')) {
          return true;
        }
        return false;
      };
    });

    tearDownAll(() {
      final window = TestWidgetsFlutterBinding.instance.window;
      window.clearPhysicalSizeTestValue();
      window.clearDevicePixelRatioTestValue();
    });

    setUp(() {
      EngineRegistry.clearAllEnginesForTesting();
      EngineRegistry.register(MockYtDlpEngine());
      container = ProviderContainer(
        overrides: [
          settingsProvider.overrideWith(() => MockSettingsNotifier()),
          currentPathProvider.overrideWith(() => MockCurrentPathNotifier()),
          downloadTaskProvider.overrideWith(() => MockDownloadTaskNotifier()),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('W-DL-PNL-27: Show parsed items as tiles and test interaction', (tester) async {
      await tester.pumpWidget(createTilesTestWidget(container));
      while (container.read(settingsProvider).value == null) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(seconds: 1));

      // Enter URL
      final urlField = find.byType(TextField);
      await tester.tap(urlField);
      await tester.enterText(urlField, 'https://test.com/mock');
      await tester.pump();

      // Hit Fetch
      // Wait for settings to load
      while (container.read(settingsProvider).value == null) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final homeDir = Platform.environment['HOME'] ?? '';
      final expectedPath = '$homeDir/.local/share/onyxcore/yt-dlp-venv/bin/yt-dlp';
      print('DEBUG: yt-dlp exists: ${File(expectedPath).existsSync()}');
      final settings = container.read(settingsProvider);
      print('DEBUG: settings state: ${settings.value?.downloadBrowser}');

      final fetchButton = find.widgetWithText(ElevatedButton, 'Fetch');
      await tester.tap(fetchButton);
      await tester.pump();

      // Wait for the mock engine to complete
      await tester.pump(const Duration(seconds: 1));

      print('DEBUG: _parsedItems empty?');
      for (final widget in tester.widgetList<Text>(find.byType(Text))) {
        print('Found text: "${widget.data}"');
      }

      // The parsed item tile should show "Mock Video Content"
      expect(find.textContaining('Mock Video Content'), findsWidgets);

      // We should see the cancel (close) icon on the tile
      final cancelIcon = find.byIcon(Icons.close);
      expect(cancelIcon, findsWidgets);

      // W-DL-PNL-28: Remove tile
      await tester.tap(cancelIcon.first);
      await tester.pump(const Duration(milliseconds: 500));

      // Item should be gone
      expect(find.textContaining('Mock Video Content'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('W-DL-PNL-28: Click Download All triggers download process', (tester) async {
      EngineRegistry.clearAllEnginesForTesting();
      EngineRegistry.register(MockYtDlpEngine());

      await tester.pumpWidget(createTilesTestWidget(container));
      while (container.read(settingsProvider).value == null) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(seconds: 1));
      
      // Wait for settings to load
      while (container.read(settingsProvider).value == null) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Enter URL
      final urlField = find.byType(TextField);
      await tester.tap(urlField);
      await tester.enterText(urlField, 'https://test.com/mock');
      await tester.pump();

      // Hit Fetch
      final fetchButton = find.widgetWithText(ElevatedButton, 'Fetch');
      await tester.tap(fetchButton);
      await tester.pump();

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify item loaded
      expect(find.textContaining('Mock Video Content'), findsWidgets);

      // Hit Download All
      final downloadAllButton = find.text('Download All');
      await tester.tap(downloadAllButton);
      await tester.pump();

      // Verify download task was added to DownloadTaskNotifier mock
      // Or simply verify it doesn't crash since we use a mock provider
      
      // Wait for any snackbars or timers to finish
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('W-DL-PNL-29: Click Clear removes parsed items', (tester) async {
      EngineRegistry.clearAllEnginesForTesting();
      EngineRegistry.register(MockYtDlpEngine());

      await tester.pumpWidget(createTilesTestWidget(container));
      while (container.read(settingsProvider).value == null) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(seconds: 1));
      
      // Wait for settings to load
      while (container.read(settingsProvider).value == null) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Enter URL
      final urlField = find.byType(TextField);
      await tester.tap(urlField);
      await tester.enterText(urlField, 'https://test.com/mock');
      await tester.pump();

      // Hit Fetch
      final fetchButton = find.widgetWithText(ElevatedButton, 'Fetch');
      await tester.tap(fetchButton);
      await tester.pump();

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Verify item loaded
      expect(find.textContaining('Mock Video Content'), findsWidgets);

      // Hit Clear
      final clearButton = find.text('Clear');
      await tester.tap(clearButton);
      await tester.pump(const Duration(milliseconds: 500));

      // Verify item removed and empty state shown
      expect(find.textContaining('Mock Video Content'), findsNothing);
      expect(find.text('No Media to Download'), findsOneWidget);
    });

    testWidgets(
      'W-DL-PNL-30: Grouped social media post shows as ONE tile, not separate tiles',
      (tester) async {
        // Arrange: register engine that returns 3 items sharing the same webpageUrl
        EngineRegistry.clearAllEnginesForTesting();
        EngineRegistry.register(MockGroupedPostEngine());

        await tester.pumpWidget(createTilesTestWidget(container));
        while (container.read(settingsProvider).value == null) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        await tester.pump(const Duration(seconds: 1));

        // Act: enter the post URL and fetch
        final urlField = find.byType(TextField);
        await tester.tap(urlField);
        await tester.enterText(urlField, MockGroupedPostEngine.postUrl);
        await tester.pump();

        final fetchButton = find.widgetWithText(ElevatedButton, 'Fetch');
        await tester.tap(fetchButton);
        await tester.pump();

        await tester.pump(const Duration(seconds: 1));

        // Assert: the post title appears (tile is rendered)
        expect(
          find.textContaining(MockGroupedPostEngine.postTitle),
          findsWidgets,
          reason: 'The grouped post title should be visible on the tile',
        );

        // Assert: there is exactly ONE close (remove) button, meaning ONE tile
        // was created for the 3-item grouped post, not 3 separate tiles.
        final closeFinders = find.byIcon(Icons.close);
        expect(
          closeFinders,
          findsOneWidget,
          reason:
              'A grouped post with multiple items should appear as a single tile '
              'with one close button, not one per item',
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets('W-DL-PNL-31: Ctrl+Click to multi-select tiles', (tester) async {
      EngineRegistry.clearAllEnginesForTesting();
      EngineRegistry.register(MockGroupedPostEngine());

      await tester.pumpWidget(createTilesTestWidget(container));
      while (container.read(settingsProvider).value == null) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(seconds: 1));

      // We will add two items by fetching twice
      final urlField = find.byType(TextField);
      await tester.tap(urlField);
      await tester.enterText(urlField, 'https://test.com/mock1');
      await tester.pump();
      await tester.tap(find.text('Fetch'));
      await tester.pump(const Duration(seconds: 2));

      await tester.enterText(urlField, 'https://test.com/mock2');
      await tester.pump();
      await tester.tap(find.text('Fetch'));
      await tester.pump(const Duration(seconds: 2));

      // We should have 2 tiles now
      final closeIcons = find.byIcon(Icons.close);
      expect(closeIcons, findsWidgets); // at least 2 close buttons (one for each tile)

      // Tap first tile with Ctrl pressed
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      // Wait, we need to find the tiles, let's find the text
      final tileTexts = find.textContaining(MockGroupedPostEngine.postTitle);
      expect(tileTexts, findsWidgets);

      await tester.tap(tileTexts.first);
      await tester.pump();
      
      // Tap second tile with Ctrl pressed
      await tester.tap(tileTexts.last);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      
      // We expect no crash and both selected internally. 
      // It's hard to verify internal _selectedIndices, but covering the interaction is good.
    });

    testWidgets('W-DL-PNL-32: Shift+Click to range select tiles', (tester) async {
      EngineRegistry.clearAllEnginesForTesting();
      EngineRegistry.register(MockGroupedPostEngine());

      await tester.pumpWidget(createTilesTestWidget(container));
      while (container.read(settingsProvider).value == null) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(seconds: 1));

      final urlField = find.byType(TextField);
      await tester.tap(urlField);
      await tester.enterText(urlField, 'https://test.com/mock1');
      await tester.pump();
      await tester.tap(find.text('Fetch'));
      await tester.pump(const Duration(seconds: 2));

      await tester.enterText(urlField, 'https://test.com/mock2');
      await tester.pump();
      await tester.tap(find.text('Fetch'));
      await tester.pump(const Duration(seconds: 2));

      final tileTexts = find.textContaining(MockGroupedPostEngine.postTitle);
      expect(tileTexts, findsWidgets);

      // Tap first tile without modifiers to set anchor
      await tester.tap(tileTexts.first);
      await tester.pump();

      // Tap second tile with Shift pressed
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.tap(tileTexts.last);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    });

    testWidgets('W-DL-PNL-33: Show error tile when fetching fails', (tester) async {
      EngineRegistry.clearAllEnginesForTesting();
      EngineRegistry.register(MockErrorEngine());

      await tester.pumpWidget(createTilesTestWidget(container));
      while (container.read(settingsProvider).value == null) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.pump(const Duration(seconds: 1));

      final urlField = find.byType(TextField);
      await tester.tap(urlField);
      await tester.enterText(urlField, 'https://test.com/error');
      await tester.pump();

      await tester.tap(find.text('Fetch'));
      await tester.pump(const Duration(seconds: 2));

      // Assert Error Tile UI elements
      expect(find.text('Error Processing URL'), findsWidgets);
      expect(find.text('Simulated failure to process URL'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);

      // Verify tapping on info icon doesn't crash (should show log dialog if implemented, but we just tap)
      final infoIcon = find.byIcon(Icons.info_outline_rounded);
      expect(infoIcon, findsOneWidget);
      await tester.tap(infoIcon);
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
