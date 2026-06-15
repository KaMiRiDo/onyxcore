import 'dart:io';
import 'package:path/path.dart' as p;

/// Centralized aria2 download accelerator utility.
///
/// aria2 is NOT a download engine — it does not extract media URLs. Instead, it
/// accelerates the transfer of already-resolved direct URLs by splitting the
/// download into multiple connections (up to 16 by default).
///
/// All engines should use this helper where applicable:
/// - yt-dlp: via `--external-downloader aria2c`
/// - gallery-dl: via `--downloader aria2c`
/// - you-get: two-phase (extract URL → aria2c download)
/// - lux: optional handoff for direct MP4 URLs
/// - playwright: direct handoff of intercepted URLs
/// - streamlink: NOT applicable (live streams are continuous byte pipes)
class Aria2Accelerator {
  static bool? _available;

  /// Path to the bundled aria2c binary.
  static String get binaryPath => p.join(
    Platform.environment['HOME'] ?? '',
    '.local',
    'share',
    'onyxcore',
    'bin',
    'aria2c',
  );

  /// Check if aria2c is available (bundled or system-installed).
  static bool get isAvailable {
    if (_available != null) return _available!;
    if (File(binaryPath).existsSync()) {
      _available = true;
      return true;
    }
    // Fallback: check system aria2c
    try {
      final res = Process.runSync('which', ['aria2c']);
      _available = res.exitCode == 0;
      return _available!;
    } catch (_) {
      _available = false;
      return false;
    }
  }

  /// Resolve the aria2c executable path (prefer bundled, then system).
  static String get executable {
    if (File(binaryPath).existsSync()) return binaryPath;
    return 'aria2c'; // system fallback
  }

  /// Reset cached availability (e.g., after install).
  static void resetCache() => _available = null;

  /// Start a direct download via aria2c with multi-connection acceleration.
  ///
  /// [url] — the direct download URL.
  /// [destination] — output directory.
  /// [filename] — output filename (optional; aria2c infers from URL if null).
  /// [connections] — number of connections per server (default 16).
  /// [splits] — number of splits (default 16).
  /// [minSplitSize] — minimum split size (default '1M').
  static Future<Process> download({
    required String url,
    required String destination,
    String? filename,
    int connections = 16,
    int splits = 16,
    String minSplitSize = '1M',
  }) {
    return Process.start(executable, [
      '-x',
      '$connections',
      '-s',
      '$splits',
      '-k',
      minSplitSize,
      '-d',
      destination,
      if (filename != null) ...['--out', filename],
      '--summary-interval=1',
      '--console-log-level=notice',
      url,
    ]);
  }

  /// Build aria2c downloader args string for engines that support
  /// `--external-downloader` or `--downloader` flags.
  ///
  /// Returns the args string: `aria2c:-x 16 -s 16 -k 1M`
  static String get downloaderArgs =>
      'aria2c:-x 16 -s 16 -k 1M --summary-interval=1';
}
