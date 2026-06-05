import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/gallery_dl_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/ytdlp_engine.dart';

/// Central registry for download engines.
///
/// Provides auto-detection based on URL patterns, manual engine lookup by ID,
/// and a registration mechanism for future plugin engines.
class EngineRegistry {
  static final List<DownloadEngine> _engines = [
    GalleryDlEngine(),
    YtDlpEngine(),
  ];

  /// Register a new engine (for future plugins).
  static void register(DownloadEngine engine) {
    _engines.add(engine);
  }

  /// Resolve engine by preference or auto-detect from URL.
  ///
  /// If [preference] is 'auto', finds the highest-priority engine whose
  /// [DownloadEngine.urlPatterns] match the URL. Falls back to the last
  /// registered engine (yt-dlp) if no patterns match.
  static DownloadEngine resolveEngine(String url, String preference) {
    if (preference != 'auto') {
      return _engines.firstWhere(
        (e) => e.id == preference,
        orElse: () => _engines.last,
      );
    }
    // Auto: find highest-priority engine whose urlPatterns match
    final matching = _engines.where(
      (e) => e.urlPatterns.any((p) => p.hasMatch(url)),
    );
    if (matching.isNotEmpty) {
      return matching.reduce((a, b) => a.priority > b.priority ? a : b);
    }
    return _engines.last; // fallback to yt-dlp
  }

  /// All registered engines (unmodifiable).
  static List<DownloadEngine> get allEngines => List.unmodifiable(_engines);

  /// Whether all registered engines have their binaries installed.
  static bool get allInstalled => _engines.every((e) => e.isInstalled);
}
