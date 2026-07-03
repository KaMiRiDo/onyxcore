import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/video_preview_widget.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() {
    MediaKit.ensureInitialized();
    tempDir = Directory.systemTemp.createTempSync('video_player_focus_test_');
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

  testWidgets('VideoPreviewWidget requests focus and triggers presentWindow when standalone', (WidgetTester tester) async {
    final List<MethodCall> windowLogs = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('onyxcore/window_manager'),
      (MethodCall methodCall) async {
        windowLogs.add(methodCall);
        return null;
      },
    );

    final fileItem = FileItem(
      path: '${tempDir.path}/test_video.mp4',
      name: 'test_video.mp4',
      type: FileItemType.video,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: VideoPreviewWidget(
            item: fileItem,
            isStandalone: true,
            windowId: '300',
          ),
        ),
      ),
    ));

    // Wait for the widget to build and the async Future.delayed(300ms) to fire
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));

    expect(
      windowLogs,
      contains(
        isA<MethodCall>().having((call) => call.method, 'method', 'present_window')
                         .having((call) => call.arguments['view_id'], 'view_id', 300),
      ),
    );

    // Verify focus is acquired
    expect(FocusManager.instance.primaryFocus, isNotNull);

    // Cleanup and swallow unmount exceptions from mocked native dependencies
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    while (tester.takeException() != null) {}
  });
}
