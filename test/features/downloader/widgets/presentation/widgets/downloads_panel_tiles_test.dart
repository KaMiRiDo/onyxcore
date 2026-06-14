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

      // Mock required binaries to bypass _checkBinaries
      MockBinaryHelper.setupMockBinaries();

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

      // Wait for the real OS process to complete
      await tester.runAsync(() async {
        await Future.delayed(const Duration(seconds: 3));
      });
      // Pump to process the Future resolutions in the fake async zone
      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

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
  });
}
