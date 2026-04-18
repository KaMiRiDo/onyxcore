import 'package:path/path.dart' as p;

import 'formatters.dart';

/// Extension methods on [int] for human-readable conversions.
extension IntExtensions on int {
  /// Converts bytes to human-readable string (e.g., "1.5 MB").
  String toHumanReadableSize() => bytesToHumanReadable(this);
}

/// Extension methods on [Duration] for formatted output.
extension DurationExtensions on Duration {
  /// Formats as MM:SS (e.g., "03:45").
  String toMmSs() => formatDuration(this);

  /// Formats as HH:MM:SS.MMM for FFmpeg (e.g., "00:03:45.123").
  String toHhMmSsMss() => formatDurationMs(this);
}

/// Extension methods on [String] for path operations.
extension StringExtensions on String {
  /// Returns the file extension including the dot (e.g., ".pdf").
  String get fileExtension => p.extension(this).toLowerCase();

  /// Returns the basename of a path (e.g., "photo.jpg").
  String get baseName => p.basename(this);
}
