import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PersistentViewerManager Tests', () {
    final List<MethodCall> log = [];

    setUp(() {
      log.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('onyxcore/window_manager'), (MethodCall methodCall) async {
        log.add(methodCall);
        if (methodCall.method == 'create_window') {
          return 1; // Return fake window ID
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('onyxcore/window_manager'), null);
    });

    final defaultFile = FileItem(
      name: 'test',
      path: '/test',
      type: FileItemType.other,
      modified: DateTime.now(),
      sizeBytes: 0,
    );

    test('W-PVM-01: openMedia with no initParams uses defaults', () async {
      await PersistentViewerManager.openMedia(WindowParams(
        viewerType: ViewerType.image,
        file: defaultFile,
      ));

      expect(log.length, 1);
      expect(log.first.method, 'create_window');
      expect(log.first.arguments['width'], 800);
      expect(log.first.arguments['height'], 600);
      expect(log.first.arguments['maximize'], false);
    });

    test('W-PVM-02 & W-PVM-03: explicit dimensions and maximize', () async {
      await PersistentViewerManager.openMedia(WindowParams(
        viewerType: ViewerType.markdown,
        file: defaultFile,
        initParams: {'width': 1024, 'height': 768, 'maximize': true},
      ));

      expect(log.last.method, 'create_window');
      expect(log.last.arguments['width'], 1024);
      expect(log.last.arguments['height'], 768);
      expect(log.last.arguments['maximize'], true);
    });

    test('W-PVM-04: ViewerType.downloader auto maximizes', () async {
      await PersistentViewerManager.openMedia(WindowParams(
        viewerType: ViewerType.downloader,
        file: defaultFile,
        initParams: {'maximize': false},
      ));

      expect(log.last.method, 'create_window');
      expect(log.last.arguments['maximize'], true); // overridden
    });

    test('W-PVM-07 & W-PVM-08: closeWindow and minimizeWindow', () async {
      await PersistentViewerManager.closeWindow(42);
      expect(log.last.method, 'close_window');
      expect(log.last.arguments['view_id'], 42);

      await PersistentViewerManager.minimizeWindow(43);
      expect(log.last.method, 'minimize_window');
      expect(log.last.arguments['view_id'], 43);
    });
  });
}
