/// Utility functions for string manipulation.
class StringUtils {
  const StringUtils._();

  /// Truncates a string in the middle, keeping the start and end.
  /// Format: "start_part...end_part"
  static String truncateMiddle(String text, {int maxLength = 24}) {
    if (text.length <= maxLength) return text;

    final int partLen = (maxLength - 3) ~/ 2;
    final String start = text.substring(0, partLen);
    final String end = text.substring(text.length - partLen);

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
