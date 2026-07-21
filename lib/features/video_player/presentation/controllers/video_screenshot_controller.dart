import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/features/video_player/presentation/services/screenshot_service.dart';

/// Typed callback bundle for [VideoScreenshotController].
class VideoScreenshotCallbacks {
  const VideoScreenshotCallbacks({
    required this.getMounted,
    required this.setShowFlash,
    required this.setShowSnapshotToast,
    required this.getSnapshotToastTimer,
    required this.setSnapshotToastTimer,
  });

  final bool Function() getMounted;
  final void Function(bool) setShowFlash;
  final void Function(bool) setShowSnapshotToast;
  final Timer? Function() getSnapshotToastTimer;
  final void Function(Timer?) setSnapshotToastTimer;
}

/// Handles the UI flash, toast notifications, and delegates saving logic
/// when taking a screenshot.
class VideoScreenshotController {
  const VideoScreenshotController(this.c);

  final VideoScreenshotCallbacks c;

  Future<void> takeScreenshot({
    required Player player,
    required String videoPath,
    required void Function(void Function()) setStateCallback,
  }) async {
    // Show flash and toast immediately for instant feedback
    if (c.getMounted()) {
      setStateCallback(() {
        c.setShowFlash(true);
        c.setShowSnapshotToast(true);
      });

      // Subtle flash fade
      Future.delayed(const Duration(milliseconds: 50), () {
        if (c.getMounted()) {
          setStateCallback(() => c.setShowFlash(false));
        }
      });

      // Notification timer
      c.getSnapshotToastTimer()?.cancel();
      c.setSnapshotToastTimer(
        Timer(const Duration(seconds: 3), () {
          if (c.getMounted()) {
            setStateCallback(() => c.setShowSnapshotToast(false));
          }
        }),
      );
    }

    try {
      // Capture the frame as soon as possible after visual trigger
      await ScreenshotService.captureAndSave(
        player: player,
        videoPath: videoPath,
      );
    } catch (e) {
      debugPrint('[VideoPlayer] Error taking screenshot: $e');
    }
  }
}
