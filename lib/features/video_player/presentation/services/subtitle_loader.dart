import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

/// Service for automatically discovering and loading external subtitle files.
class SubtitleLoader {
  /// Scans the directory of the video file for matching subtitles and loads them.
  /// Supported extensions: .srt, .vtt, .ass
  static Future<void> autoLoadExternalSubtitles({
    required Player player,
    required String videoPath,
  }) async {
    try {
      final file = File(videoPath);
      final dir = file.parent;
      final baseName = p.basenameWithoutExtension(videoPath);
      const extensions = ['.srt', '.vtt', '.ass'];

      for (final ext in extensions) {
        final subPath = p.join(dir.path, '$baseName$ext');
        if (await File(subPath).exists()) {
          debugPrint('[VideoPlayer] Auto-loading subtitle: $subPath');
          player.setSubtitleTrack(SubtitleTrack.uri(subPath));
          break;
        }
      }
    } catch (e) {
      debugPrint('[VideoPlayer] Error auto-loading subtitles: $e');
    }
  }
}
