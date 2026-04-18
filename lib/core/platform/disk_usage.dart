import 'dart:io';

/// Result of a disk usage query.
class DiskUsage {
  const DiskUsage({
    required this.totalBytes,
    required this.usedBytes,
    required this.availableBytes,
  });

  final int totalBytes;
  final int usedBytes;
  final int availableBytes;

  /// Usage as a fraction (0.0 to 1.0).
  double get usageFraction =>
      totalBytes > 0 ? usedBytes / totalBytes : 0;

  /// Usage as a percentage string (e.g., "60%").
  String get usagePercent => '${(usageFraction * 100).round()}%';

  /// Total size as a human-readable string.
  String get totalHuman => _bytesToHuman(totalBytes);

  /// Used size as a human-readable string.
  String get usedHuman => _bytesToHuman(usedBytes);

  static String _bytesToHuman(int bytes) {
    if (bytes >= 1024 * 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024 * 1024)).toStringAsFixed(1)} TB';
    } else if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } else if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
}

/// Queries real disk usage for a given path using the Linux `df` command.
///
/// Returns [DiskUsage] with total, used, and available bytes,
/// or `null` if the command fails.
Future<DiskUsage?> getDiskUsage(String path) async {
  try {
    final result = await Process.run(
      'df',
      ['-B1', '--output=size,used,avail', path],
    );

    if (result.exitCode != 0) return null;

    final lines = (result.stdout as String).trim().split('\n');
    if (lines.length < 2) return null;

    // Second line has the values: "total used available"
    final parts = lines[1].trim().split(RegExp(r'\s+'));
    if (parts.length < 3) return null;

    return DiskUsage(
      totalBytes: int.tryParse(parts[0]) ?? 0,
      usedBytes: int.tryParse(parts[1]) ?? 0,
      availableBytes: int.tryParse(parts[2]) ?? 0,
    );
  } catch (_) {
    return null;
  }
}
