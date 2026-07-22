/// Shared utility helpers for the video player presentation layer.
///
/// These are pure functions with no Flutter or provider dependencies,
/// intentionally kept here so every split widget can import without
/// circular references.
library;

class VideoPlayerUtils {
  /// Formats a [Duration] as `mm:ss` or `hh:mm:ss` for the player OSD.
  ///
  /// Identical to the original `_formatDuration` in `_VideoPreviewWidgetState`.
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final mn = twoDigits(duration.inMinutes.remainder(60));
    final sc = twoDigits(duration.inSeconds.remainder(60));
    if (duration.inHours > 0) {
      return '${twoDigits(duration.inHours)}:$mn:$sc';
    }
    return '$mn:$sc';
  }
}
