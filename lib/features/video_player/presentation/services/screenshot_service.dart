import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

/// Service for capturing and saving screenshots from the video player.
class ScreenshotService {
  const ScreenshotService._();

  /// Captures a frame from the [player] and saves it to a 'Snapshots' directory
  /// next to the original [videoPath].
  static Future<void> captureAndSave({
    required Player player,
    required String videoPath,
  }) async {
    try {
      final bytes = await player.screenshot();
      if (bytes == null) return;

      final file = File(videoPath);
      final snapshotsDir = Directory(p.join(file.parent.path, 'Snapshots'));

      if (!snapshotsDir.existsSync()) {
        snapshotsDir.createSync(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          '${p.basenameWithoutExtension(videoPath)}_$timestamp.png';
      final screenshotFile = File(p.join(snapshotsDir.path, fileName));

      await screenshotFile.writeAsBytes(bytes);
      debugPrint('[VideoPlayer] Screenshot saved: ${screenshotFile.path}');
    } catch (e) {
      debugPrint('[VideoPlayer] Error taking screenshot: $e');
    }
  }
}
