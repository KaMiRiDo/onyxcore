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

  /// Parses a human-readable speed string (e.g. "1.5 MB/s", "500 KB/s", "2 GiB/s")
  /// into bytes per second. Returns 0 if the string cannot be parsed.
  static double parseBytesPerSecond(String speed) {
    if (speed.isEmpty) return 0;
    // Match patterns like "1.5 MB/s", "500KB/s", "2 GiB/s", "1024 B/s"
    final regex = RegExp(
      r'([\d.]+)\s*(B|KB|KiB|MB|MiB|GB|GiB|TB|TiB)\s*/\s*s',
      caseSensitive: false,
    );
    final m = regex.firstMatch(speed);
    if (m == null) return 0;
    final value = double.tryParse(m.group(1)!) ?? 0;
    final unit = m.group(2)!.toLowerCase();
    const multipliers = <String, double>{
      'b': 1,
      'kb': 1024,
      'kib': 1024,
      'mb': 1024 * 1024,
      'mib': 1024 * 1024,
      'gb': 1024 * 1024 * 1024,
      'gib': 1024 * 1024 * 1024,
      'tb': 1024.0 * 1024 * 1024 * 1024,
      'tib': 1024.0 * 1024 * 1024 * 1024,
    };
    return value * (multipliers[unit] ?? 0);
  }
}
