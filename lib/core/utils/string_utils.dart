/// Utility functions for string manipulation.
library;
import 'package:flutter/widgets.dart';

class StringUtils {
  const StringUtils._();

  /// Truncates a string in the middle, keeping the start and end.
  /// Format: "start_part...end_part"
  static String truncateMiddle(String text, {int maxLength = 24}) {
    if (text.characters.length <= maxLength) return text;

    final partLen = (maxLength - 3) ~/ 2;
    final start = text.characters.take(partLen).toString();
    final end = text.characters.takeLast(partLen).toString();

    return '$start...$end';
  }

  /// Formats a byte count into a human-readable string.
  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    var count = bytes.toDouble();
    while (count >= 1024 && i < suffixes.length - 1) {
      count /= 1024;
      i++;
    }
    return '${count.toStringAsFixed(1)} ${suffixes[i]}';
  }
}
