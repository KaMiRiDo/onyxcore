// ignore_for_file: avoid_dynamic_calls
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PersistentViewerManager', () {
    const channel = MethodChannel('onyxcore/window_manager');
    final log = <MethodCall>[];

    setUp(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        log.add(methodCall);
        if (methodCall.method == 'create_window') {
          return WidgetsBinding.instance.platformDispatcher.views.first.viewId;
        }
        return null;
      });
      PersistentViewerManager.init();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('init sets method call handler', () async {
      final result = await TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'onyxcore/window_manager',
        const StandardMethodCodec().encodeMethodCall(
            const MethodCall('on_window_focus', {'view_id': 100})),
        (ByteData? data) {},
      );
      expect(result, isNotNull);
    });

    test('on_window_focus triggers focus notifier for tracked window', () async {
      final file = FileItem(path: '/focus.ext', name: 'focus.ext', type: FileItemType.other, modified: DateTime.now(), sizeBytes: 100);
      final params = WindowParams(viewerType: ViewerType.markdown, file: file, initParams: {});
      await PersistentViewerManager.openMedia(params);
      
      final viewId = WidgetsBinding.instance.platformDispatcher.views.first.viewId;
      final trigger = PersistentViewerManager.getFocusTrigger(viewId);
      final initialVal = trigger.value;

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .handlePlatformMessage(
        'onyxcore/window_manager',
        const StandardMethodCodec().encodeMethodCall(
            MethodCall('on_window_focus', {'view_id': viewId})),
        (ByteData? data) {},
      );
      
      expect(trigger.value, initialVal + 1);
    });

    test('setFullScreen invokes set_fullscreen', () async {
      await PersistentViewerManager.setFullScreen(WidgetsBinding.instance.platformDispatcher.views.first.viewId, true);
      expect(
          log.any((call) =>
              call.method == 'set_fullscreen' &&
              call.arguments['view_id'] == WidgetsBinding.instance.platformDispatcher.views.first.viewId &&
              call.arguments['is_fullscreen'] == true),
          isTrue);
    });

    test('closeWindow invokes close_window', () async {
      await PersistentViewerManager.closeWindow(WidgetsBinding.instance.platformDispatcher.views.first.viewId);
      expect(
          log.any((call) =>
              call.method == 'close_window' &&
              call.arguments['view_id'] == WidgetsBinding.instance.platformDispatcher.views.first.viewId),
          isTrue);
    });

    test('minimizeWindow invokes minimize_window', () async {
      await PersistentViewerManager.minimizeWindow(WidgetsBinding.instance.platformDispatcher.views.first.viewId);
      expect(
          log.any((call) =>
              call.method == 'minimize_window' &&
              call.arguments['view_id'] == WidgetsBinding.instance.platformDispatcher.views.first.viewId),
          isTrue);
    });

    test('presentWindow invokes present_window', () async {
      await PersistentViewerManager.presentWindow(WidgetsBinding.instance.platformDispatcher.views.first.viewId);
      expect(
          log.any((call) =>
              call.method == 'present_window' &&
              call.arguments['view_id'] == WidgetsBinding.instance.platformDispatcher.views.first.viewId),
          isTrue);
    });

    testWidgets('buildView returns empty waiting scaffold when params is null',
        (tester) async {
      final widget = PersistentViewerManager.buildView(999);
      await tester.pumpWidget(widget);
      expect(find.text('Waiting for media...'), findsOneWidget);
    });

    testWidgets('openMedia creates new window and sets params', (tester) async {
      final file = FileItem(path: '/test.mp4', name: 'test.mp4', type: FileItemType.video, modified: DateTime.now(), sizeBytes: 100);
      final params = WindowParams(
        viewerType: ViewerType.video,
        file: file,
        initParams: {'width': 1200, 'height': 800, 'maximize': true},
      );

      await PersistentViewerManager.openMedia(params);

      // Verify create_window was called with correct params
      expect(
        log.any((call) =>
            call.method == 'create_window' &&
            call.arguments['width'] == 1200 &&
            call.arguments['height'] == 800 &&
            call.arguments['maximize'] == true),
        isTrue,
      );

      // Verify buildView now returns the widget content instead of waiting scaffold
      // Since it's VideoPreviewWidget, which we shouldn't fully pump due to dependencies,
      // we can just check the type by building it with an override
      // Actually we can't fully pump it without providing database and riverpod overrides.
    });

    test('openMedia reuses existing window if type already open', () async {
      final file1 = FileItem(path: '/test1.mp4', name: 'test1.mp4', type: FileItemType.video, modified: DateTime.now(), sizeBytes: 100);
      final params1 = WindowParams(viewerType: ViewerType.video, file: file1);

      await PersistentViewerManager.openMedia(params1);
      final viewId = WidgetsBinding.instance.platformDispatcher.views.first.viewId;
      log.clear();

      final file2 = FileItem(path: '/test2.mp4', name: 'test2.mp4', type: FileItemType.video, modified: DateTime.now(), sizeBytes: 100);
      final params2 = WindowParams(viewerType: ViewerType.video, file: file2);

      await PersistentViewerManager.openMedia(params2);

      // Should call present_window on the existing viewId, NOT create_window
      expect(log.any((call) => call.method == 'create_window'), isFalse);
      expect(
        log.any((call) =>
            call.method == 'present_window' &&
            call.arguments['view_id'] == viewId),
        isTrue,
      );
    });

    test('getFocusTrigger returns ValueNotifier', () {
      final trigger = PersistentViewerManager.getFocusTrigger(123);
      expect(trigger, isNotNull);
      expect(trigger.value, 0);
    });

    testWidgets('buildView branches', (tester) async {
      await tester.pumpWidget(Container());
      final ctx = tester.element(find.byType(Container));

      final viewId = WidgetsBinding.instance.platformDispatcher.views.first.viewId;
      
      for (final type in ViewerType.values) {
        final file = FileItem(path: '/test.ext', name: 'test.ext', type: FileItemType.video, modified: DateTime.now(), sizeBytes: 100);
        final params = WindowParams(
          viewerType: type,
          file: file,
          initParams: {
            'startPositionMs': 1000,
            'playbackRate': 1.0,
            'audioTrackId': '1',
            'subtitleTrackId': '2',
          },
        );

        await PersistentViewerManager.openMedia(params);
        final widget = PersistentViewerManager.buildView(viewId) as ValueListenableBuilder<WindowParams?>;
        
        // Call the builder directly to evaluate the switch statement without mounting the complex widgets
        widget.builder(ctx, params, null);
      }
    });

    test('error handling', () async {
      // Mock platform channel to throw exception
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (methodCall) async {
        throw PlatformException(code: 'error');
      });

      // These should not crash
      await PersistentViewerManager.openMedia(WindowParams(viewerType: ViewerType.image, file: FileItem(path: '', name: '', type: FileItemType.image, modified: DateTime.now(), sizeBytes: 0)));
      await PersistentViewerManager.setFullScreen(1, true);
      await PersistentViewerManager.closeWindow(1);
      await PersistentViewerManager.minimizeWindow(1);
      await PersistentViewerManager.presentWindow(1);
    });
  });
}
