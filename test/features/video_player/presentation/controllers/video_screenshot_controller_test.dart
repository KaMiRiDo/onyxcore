import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/features/video_player/presentation/controllers/video_screenshot_controller.dart';

class MockPlayer extends Mock implements Player {}

void main() {
  group('VideoScreenshotController', () {
    late MockPlayer mockPlayer;
    late bool mounted;
    late bool showFlash;
    late bool showSnapshotToast;
    Timer? snapshotToastTimer;

    late VideoScreenshotCallbacks callbacks;
    late VideoScreenshotController controller;

    setUp(() {
      mockPlayer = MockPlayer();
      mounted = true;
      showFlash = false;
      showSnapshotToast = false;
      snapshotToastTimer = null;

      callbacks = VideoScreenshotCallbacks(
        getMounted: () => mounted,
        setShowFlash: (v) => showFlash = v,
        setShowSnapshotToast: (v) => showSnapshotToast = v,
        getSnapshotToastTimer: () => snapshotToastTimer,
        setSnapshotToastTimer: (t) => snapshotToastTimer = t,
      );

      controller = VideoScreenshotController(callbacks);
    });

    testWidgets('takeScreenshot shows flash and toast immediately', (tester) async {
      await tester.pumpWidget(const SizedBox()); // Provide basic test environment

      // Call takeScreenshot
      // It will throw an exception internally in ScreenshotService because path_provider is not mocked,
      // but the controller catches it, so the test will pass if the UI state is correct.
      await controller.takeScreenshot(
        player: mockPlayer,
        videoPath: '/dummy/path.mp4',
        setStateCallback: (cb) => cb(),
      );

      // Flash and toast should be visible immediately
      expect(showFlash, isTrue);
      expect(showSnapshotToast, isTrue);
      expect(snapshotToastTimer, isNotNull);
      expect(snapshotToastTimer!.isActive, isTrue);

      // Flash should fade after 50ms
      await tester.pump(const Duration(milliseconds: 50));
      expect(showFlash, isFalse);
      expect(showSnapshotToast, isTrue); // Toast still visible

      // Toast should hide after 3 seconds
      await tester.pump(const Duration(seconds: 3));
      expect(showSnapshotToast, isFalse);
    });
  });
}
