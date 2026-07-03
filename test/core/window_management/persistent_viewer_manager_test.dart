import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';

import 'package:onyxcore/features/video_player/presentation/widgets/video_preview_widget.dart';
import 'package:onyxcore/features/audio_player/presentation/pages/audio_player_view.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_preview_widget.dart';
import 'package:onyxcore/features/document_viewer/presentation/widgets/markdown_preview_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late Directory tempDir;
  const MethodChannel channel = MethodChannel('onyxcore/window_manager');
  final List<MethodCall> log = [];
  bool shouldThrow = false;

  setUpAll(() {
    MediaKit.ensureInitialized();
    tempDir = Directory.systemTemp.createTempSync('persistent_viewer_manager_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    try {
      await Hive.close();
    } catch (_) {}
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() {
    log.clear();
    shouldThrow = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
      log.add(methodCall);
      if (shouldThrow) {
        throw PlatformException(code: 'TEST_ERROR', message: 'Test error');
      }
      if (methodCall.method == 'create_window') {
        return WidgetsBinding.instance.platformDispatcher.views.first.viewId;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('PersistentViewerManager Tests', () {
    test('init sets up channel handler and increments focus trigger on focus event', () async {
      PersistentViewerManager.init();

      final viewId = WidgetsBinding.instance.platformDispatcher.views.first.viewId;
      final params = WindowParams(
        viewerType: ViewerType.video,
        file: FileItem(path: '/test/vid.mp4', name: 'vid.mp4', type: FileItemType.video, modified: DateTime.now()),
      );
      await PersistentViewerManager.openMedia(params);

      final trigger = PersistentViewerManager.getFocusTrigger(viewId);

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'onyxcore/window_manager',
        const StandardMethodCodec().encodeMethodCall(
          MethodCall('on_window_focus', {'view_id': viewId}),
        ),
        (ByteData? data) {},
      );

      await Future<void>.delayed(Duration.zero);
      expect(trigger.value, 1);
    });

    testWidgets('init clears primary focus when untracked window regains focus', (WidgetTester tester) async {
      PersistentViewerManager.init();
      
      final focusNode = FocusNode();
      // Initialize the widget tree with an actively focused node
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Focus(
              focusNode: focusNode,
              autofocus: true,
              child: const SizedBox(),
            ),
          ),
        ),
      );
      
      expect(focusNode.hasFocus, true);
      
      // We send on_window_focus with an untracked view_id (e.g., 999 for main window)
      // This should trigger FocusManager.instance.primaryFocus?.unfocus(),
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'onyxcore/window_manager',
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('on_window_focus', {'view_id': 999}),
        ),
        (ByteData? data) {},
      );
      
      // Pump to ensure the async callback is processed
      await tester.pump();
      
      // The focus should have been cleared
      expect(focusNode.hasFocus, false);
    });

    test('presentWindow invokes method channel and increments focus trigger', () async {
      final trigger = PersistentViewerManager.getFocusTrigger(101);
      final initialValue = trigger.value;

      await PersistentViewerManager.presentWindow(101);

      expect(
        log,
        contains(
          isA<MethodCall>().having((call) => call.method, 'method', 'present_window')
                           .having((call) => call.arguments['view_id'], 'view_id', 101),
        ),
      );

      expect(trigger.value, initialValue + 1);
    });
    
    test('presentWindow handles platform exceptions gracefully', () async {
      shouldThrow = true;
      // Should not throw
      await PersistentViewerManager.presentWindow(101);
    });

    test('openMedia handles new window creation and subsequent reuse', () async {
      final params = WindowParams(
        viewerType: ViewerType.image,
        file: FileItem(path: '/test/image.jpg', name: 'image.jpg', type: FileItemType.image, modified: DateTime.now()),
      );

      await PersistentViewerManager.openMedia(params);
      
      expect(
        log,
        contains(
          isA<MethodCall>().having((call) => call.method, 'method', 'create_window'),
        ),
      );
      
      log.clear();

      final params2 = WindowParams(
        viewerType: ViewerType.image,
        file: FileItem(path: '/test/image2.jpg', name: 'image2.jpg', type: FileItemType.image, modified: DateTime.now()),
      );
      await PersistentViewerManager.openMedia(params2);
      
      final validViewId = WidgetsBinding.instance.platformDispatcher.views.first.viewId;
      expect(
        log,
        contains(
          isA<MethodCall>().having((call) => call.method, 'method', 'present_window')
                           .having((call) => call.arguments['view_id'], 'view_id', validViewId),
        ),
      );
    });
    
    test('openMedia handles platform exceptions gracefully', () async {
      final params = WindowParams(
        viewerType: ViewerType.audio, // Use different type to force create_window
        file: FileItem(path: '/test/audio.mp3', name: 'audio.mp3', type: FileItemType.audio, modified: DateTime.now()),
      );
      shouldThrow = true;
      // Should not throw
      await PersistentViewerManager.openMedia(params);
    });

    test('setFullScreen invokes method channel correctly', () async {
      await PersistentViewerManager.setFullScreen(102, true);

      expect(
        log,
        contains(
          isA<MethodCall>().having((call) => call.method, 'method', 'set_fullscreen')
                           .having((call) => call.arguments['view_id'], 'view_id', 102)
                           .having((call) => call.arguments['is_fullscreen'], 'is_fullscreen', true),
        ),
      );
    });
    
    test('setFullScreen handles platform exceptions gracefully', () async {
      shouldThrow = true;
      // Should not throw
      await PersistentViewerManager.setFullScreen(102, true);
    });

    testWidgets('buildView initially returns Waiting for media', (WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));
      
      final widget = PersistentViewerManager.buildView(999) as ValueListenableBuilder<WindowParams?>;
      final built = widget.builder(context, null, null) as MaterialApp;
      final scaffold = built.home as Scaffold;
      final center = scaffold.body as Center;
      final text = center.child as Text;
      expect(text.data, 'Waiting for media...');
    });

    testWidgets('buildView renders VideoPreviewWidget for video type (no initParams)', (WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));

      final params = WindowParams(
        viewerType: ViewerType.video,
        file: FileItem(path: '/test/video.mp4', name: 'video.mp4', type: FileItemType.video, modified: DateTime.now()),
      );
      final widget = PersistentViewerManager.buildView(1001) as ValueListenableBuilder<WindowParams?>;
      final built = widget.builder(context, params, null) as ProviderScope;
      final app = built.child as MaterialApp;
      final scaffold = app.home as Scaffold;
      
      final previewWidget = scaffold.body as VideoPreviewWidget;
      expect(previewWidget.initialPosition, isNull);
    });

    testWidgets('buildView renders VideoPreviewWidget for video type (with initParams)', (WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));

      final params = WindowParams(
        viewerType: ViewerType.video,
        file: FileItem(path: '/test/video.mp4', name: 'video.mp4', type: FileItemType.video, modified: DateTime.now()),
        initParams: {'startPositionMs': 12345, 'playbackRate': 1.5, 'audioTrackId': 'aud1', 'subtitleTrackId': 'sub1'},
      );
      final widget = PersistentViewerManager.buildView(1001) as ValueListenableBuilder<WindowParams?>;
      final built = widget.builder(context, params, null) as ProviderScope;
      final app = built.child as MaterialApp;
      final scaffold = app.home as Scaffold;
      
      final previewWidget = scaffold.body as VideoPreviewWidget;
      expect(previewWidget.initialPosition, const Duration(milliseconds: 12345));
      expect(previewWidget.initialRate, 1.5);
      expect(previewWidget.initialAudioTrackId, 'aud1');
      expect(previewWidget.initialSubtitleTrackId, 'sub1');
    });

    testWidgets('buildView renders ImagePreviewWidget for image type', (WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));

      final params = WindowParams(
        viewerType: ViewerType.image,
        file: FileItem(path: '/test/image.jpg', name: 'image.jpg', type: FileItemType.image, modified: DateTime.now()),
      );
      final widget = PersistentViewerManager.buildView(1002) as ValueListenableBuilder<WindowParams?>;
      final built = widget.builder(context, params, null) as ProviderScope;
      final app = built.child as MaterialApp;
      final scaffold = app.home as Scaffold;
      expect(scaffold.body, isA<ImagePreviewWidget>());
    });

    testWidgets('buildView renders AudioPlayerView for audio type', (WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));

      final params = WindowParams(
        viewerType: ViewerType.audio,
        file: FileItem(path: '/test/audio.mp3', name: 'audio.mp3', type: FileItemType.audio, modified: DateTime.now()),
      );
      final widget = PersistentViewerManager.buildView(1003) as ValueListenableBuilder<WindowParams?>;
      final built = widget.builder(context, params, null) as ProviderScope;
      final app = built.child as MaterialApp;
      final scaffold = app.home as Scaffold;
      expect(scaffold.body, isA<AudioPlayerView>());
    });

    testWidgets('buildView renders MarkdownPreviewWidget for markdown type', (WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));

      final params = WindowParams(
        viewerType: ViewerType.markdown,
        file: FileItem(path: '/test/doc.md', name: 'doc.md', type: FileItemType.document, modified: DateTime.now()),
      );
      final widget = PersistentViewerManager.buildView(1004) as ValueListenableBuilder<WindowParams?>;
      final built = widget.builder(context, params, null) as ProviderScope;
      final app = built.child as MaterialApp;
      final scaffold = app.home as Scaffold;
      expect(scaffold.body, isA<MarkdownPreviewWidget>());
    });

    testWidgets('buildView renders unsupported text for unsupported type', (WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));

      final params = WindowParams(
        viewerType: ViewerType.unsupported,
        file: FileItem(path: '/test/unknown.xyz', name: 'unknown.xyz', type: FileItemType.other, modified: DateTime.now()),
      );
      final widget = PersistentViewerManager.buildView(1005) as ValueListenableBuilder<WindowParams?>;
      final built = widget.builder(context, params, null) as ProviderScope;
      final app = built.child as MaterialApp;
      final scaffold = app.home as Scaffold;
      final center = scaffold.body as Center;
      final text = center.child as Text;
      expect(text.data, 'Unsupported preview type for unknown.xyz');
    });

    testWidgets('buildView overrides previewFileProvider correctly', (WidgetTester tester) async {
      final params = WindowParams(
        viewerType: ViewerType.image,
        file: FileItem(path: '/test/image.jpg', name: 'image.jpg', type: FileItemType.image, modified: DateTime.now()),
      );
      final widget = PersistentViewerManager.buildView(1006) as ValueListenableBuilder<WindowParams?>;
      
      await tester.pumpWidget(const SizedBox());
      final context = tester.element(find.byType(SizedBox));
      
      final built = widget.builder(context, params, null) as ProviderScope;
      
      // Pump the ProviderScope so we can read the provider
      await tester.pumpWidget(built);
      await tester.pump(const Duration(seconds: 3));
      
      final container = ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
      final file = container.read(previewFileProvider);
      
      expect(file, params.file);
    });
  });
}
