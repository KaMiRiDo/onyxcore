/// Formatting utilities used across the application.
library;
import 'package:flutter/widgets.dart';

/// Formats a [Duration] as MM:SS.
String formatDuration(Duration d) {
  final minutes = d.inMinutes.toString().padLeft(2, '0');
  final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Formats a [Duration] as HH:MM:SS.MMM (for FFmpeg commands).
String formatDurationMs(Duration d) {
  final hh = d.inHours.toString().padLeft(2, '0');
  final mm = (d.inMinutes % 60).toString().padLeft(2, '0');
  final ss = (d.inSeconds % 60).toString().padLeft(2, '0');
  final ms = (d.inMilliseconds % 1000).toString().padLeft(3, '0');
  return '$hh:$mm:$ss.$ms';
}

/// Converts bytes to a human-readable size string (B, KB, MB, GB).
String bytesToHumanReadable(int bytes) {
  if (bytes > 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  } else if (bytes > 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  } else if (bytes > 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '$bytes B';
}

/// Truncates a filename in the middle, preserving the file extension.
///
/// Example: "very_long_filename_here.pdf" → "very_long_fil...pdf"
String truncateMiddle(String title, {int maxLength = 50}) {
  if (title.characters.length <= maxLength) return title;

  final extIndex = title.lastIndexOf('.');
  var ext = '';
  var base = title;

  // Preserve extension if it's reasonably short (e.g. .pdf, .docx)
  if (extIndex != -1 && (title.length - extIndex) <= 8) {
    ext = title.substring(extIndex);
    base = title.substring(0, extIndex);
  }

  final startChars = maxLength - ext.characters.length - 3; // 3 for '...'
  if (startChars <= 10) return '${title.characters.take(maxLength - 3)}...';

  return '${base.characters.take(startChars)}...$ext';
}
