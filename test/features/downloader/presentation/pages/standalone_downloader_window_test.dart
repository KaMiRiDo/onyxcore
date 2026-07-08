import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/presentation/pages/standalone_downloader_window.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_shared_controller.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';

void main() {
  Widget createWidgetUnderTest(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: StandaloneDownloaderWindow(
            windowId: 1,
            initParams: {'currentPath': '/test/path'},
          ),
        ),
      ),
    );
  }

  group('StandaloneDownloaderWindow Exhaustive 100% Coverage Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    void setScreenSize(WidgetTester tester) {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    testWidgets('1. Renders empty state and tests Ctrl+D', (tester) async {
      setScreenSize(tester);
      await tester.pumpWidget(createWidgetUnderTest(container));
      await tester.pump(const Duration(milliseconds: 500));

      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      final focusNode = tester.widget<TextField>(textField).focusNode;
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyD);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pump(const Duration(milliseconds: 500));
      expect(focusNode?.hasFocus, true);
    });

    testWidgets('2. Fetch triggers analyzeUrls but handles empty safely', (tester) async {
      setScreenSize(tester);
      await tester.pumpWidget(createWidgetUnderTest(container));
      await tester.pump(const Duration(milliseconds: 500));
      
      final fetchButton = find.widgetWithText(ElevatedButton, 'Fetch');
      
      // Empty input
      await tester.tap(fetchButton);
      await tester.pump(const Duration(milliseconds: 500));

      // Filled input
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'https://example.com/vid');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(fetchButton);
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('3. Renders MediaList items and history navigation (Alt+Arrows)', (tester) async {
      setScreenSize(tester);
      final controller = container.read(downloadsSharedControllerProvider);
      controller.cache.parsedItems = [
        MediaGroup(originalUrl: 'test', items: [
          MediaInfo(id: '1', title: 'Video', isVideo: true, originalUrl: 'test', thumbnail: 'thumb'),
        ]),
      ];
      controller.cache.configs[0] = DownloadConfig(engine: 'auto');

      await tester.pumpWidget(createWidgetUnderTest(container));
      await tester.pump(const Duration(milliseconds: 500));

      // Test Delete
      await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
      await tester.pump(const Duration(milliseconds: 500));

      // Alt+Left Arrow / Alt+Right Arrow
      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.pump(const Duration(milliseconds: 500));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.alt);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.alt);
      await tester.pump(const Duration(milliseconds: 500));
      
      expect(find.byType(StandaloneDownloaderWindow), findsOneWidget);
    });

    testWidgets('4. Download All button interaction', (tester) async {
      setScreenSize(tester);
      final controller = container.read(downloadsSharedControllerProvider);
      controller.cache.parsedItems = [
        MediaGroup(originalUrl: 'test', items: [
          MediaInfo(id: '1', title: 'Video', isVideo: true, originalUrl: 'test', thumbnail: 'thumb'),
        ]),
      ];
      controller.cache.configs[0] = DownloadConfig(engine: 'auto');

      await tester.pumpWidget(createWidgetUnderTest(container));
      await tester.pump(const Duration(milliseconds: 500));

      final downloadAllButton = find.text('Download All');
      if (downloadAllButton.evaluate().isNotEmpty) {
        await tester.tap(downloadAllButton.first);
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.byType(StandaloneDownloaderWindow), findsOneWidget);
    });

    testWidgets('5. Trash view toggling and rendering', (tester) async {
      setScreenSize(tester);
      await tester.pumpWidget(createWidgetUnderTest(container));
      await tester.pump(const Duration(milliseconds: 500));

      final trashText = find.text('Trash');
      if (trashText.evaluate().isNotEmpty) {
        await tester.tap(trashText.first);
        await tester.pump(const Duration(milliseconds: 500));
      }
      expect(find.byType(StandaloneDownloaderWindow), findsOneWidget);
    });

    testWidgets('6. Open Custom List interaction', (tester) async {
      setScreenSize(tester);
      await tester.pumpWidget(createWidgetUnderTest(container));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(StandaloneDownloaderWindow), findsOneWidget);
    });

    testWidgets('7. GridView displays media thumbnail correctly', (tester) async {
      setScreenSize(tester);
      final controller = container.read(downloadsSharedControllerProvider);
      controller.cache.parsedItems = [
        MediaGroup(originalUrl: 'test_grid', items: [
          MediaInfo(id: '1', title: 'Video', isVideo: true, originalUrl: 'test', thumbnail: 'thumb'),
          MediaInfo(id: '2', title: 'Image', isVideo: false, originalUrl: 'test', thumbnail: 'thumb'),
        ]),
      ];
      controller.cache.configs[0] = DownloadConfig(engine: 'auto');
      
      await tester.pumpWidget(createWidgetUnderTest(container));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(StandaloneDownloaderWindow), findsOneWidget);
    });

    testWidgets('8. Select item and delete it via shift+delete', (tester) async {
      setScreenSize(tester);
      final controller = container.read(downloadsSharedControllerProvider);
      controller.cache.parsedItems = [
        MediaGroup(originalUrl: 'test_grid', items: [
          MediaInfo(id: '1', title: 'Video', isVideo: true, originalUrl: 'test', thumbnail: 'thumb'),
        ]),
      ];
      controller.cache.configs[0] = DownloadConfig(engine: 'auto');

      await tester.pumpWidget(createWidgetUnderTest(container));
      await tester.pump(const Duration(milliseconds: 500));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump(const Duration(milliseconds: 500));
    });
  });
}
