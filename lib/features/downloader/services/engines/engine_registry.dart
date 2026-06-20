import 'package:flutter/foundation.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/gallery_dl_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/lux_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/playwright_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/streamlink_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/youget_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/ytdlp_engine.dart';

/// Central registry for download engines.
///
/// Provides auto-detection based on URL patterns, manual engine lookup by ID,
/// and a registration mechanism for future plugin engines.
///
/// Engines are classified as **required** or **optional**:
/// - Required engines (yt-dlp, gallery-dl) block the download panel if missing.
/// - Optional engines (you-get, lux, streamlink, playwright) can be installed
///   and deleted from Settings → Downloads → Installed Engines.
class EngineRegistry {
  /// Required engines — must be installed for the downloader to function.
  /// If missing, show blocking error dialog when user tries to download.
  static final List<DownloadEngine> _requiredEngines = [
    GalleryDlEngine(), // priority 10 — images/galleries
    YtDlpEngine(), // priority 9 — videos/audio (primary)
  ];

  /// Optional engines — can be installed/deleted from Settings.
  /// Never block the panel; greyed out with "Install" badge if missing.
  static final List<DownloadEngine> _optionalEngines = [
    StreamlinkEngine(), // priority 7 — live streams
    LuxEngine(), // priority 4 — fast Go binary
    YouGetEngine(), // priority 3 — Asian platform fallback
    PlaywrightEngine(), // priority 0 — manual URL interceptor
  ];

  /// All registered engines (required + optional).
  static final List<DownloadEngine> _engines = [
    ..._requiredEngines,
    ..._optionalEngines,
  ];

  /// Register a new engine (for future plugins).
  static void register(DownloadEngine engine) {
    _engines.add(engine);
  }

  @visibleForTesting
  static void clearRegisteredEngines() {
    _engines.clear();
    _engines.addAll([
      ..._requiredEngines,
      ..._optionalEngines,
    ]);
  }

  @visibleForTesting
  static void clearAllEnginesForTesting() {
    _engines.clear();
  }

  /// Resolve engine by preference or auto-detect from URL.
  ///
  /// If [preference] is 'auto', finds the highest-priority engine whose
  /// [DownloadEngine.urlPatterns] match the URL. Falls back to the last
  /// required engine (yt-dlp) if no patterns match.
  ///
  /// Only installed engines participate in auto-detection. Uninstalled
  /// optional engines are skipped silently.
  static DownloadEngine resolveEngine(String url, String preference) {
    if (preference != 'auto') {
      return _engines.firstWhere(
        (e) => e.id == preference,
        orElse: () => requiredEngines.last,
      );
    }
    // Auto: find highest-priority INSTALLED engine whose urlPatterns match
    final matching = _engines.where(
      (e) => e.isInstalled && e.urlPatterns.any((p) => p.hasMatch(url)),
    );
    if (matching.isNotEmpty) {
      return matching.reduce((a, b) => a.priority > b.priority ? a : b);
    }
    return requiredEngines.last; // fallback to yt-dlp
  }

  /// Resolve an ordered sequence of engines to try.
  /// If [preference] is 'auto', returns all installed engines sorted by:
  /// 1. Pattern matchers (highest priority first)
  /// 2. Non-matchers (highest priority first)
  /// If [preference] is specific, returns only that engine.
  static List<DownloadEngine> resolveEngineSequence(
    String url,
    String preference,
  ) {
    if (preference != 'auto') {
      final specific = findById(preference);
      if (specific != null) return [specific];
      return [requiredEngines.last];
    }

    final installed = _engines.where((e) => e.isInstalled).toList();

    final matching = installed
        .where((e) => e.urlPatterns.any((p) => p.hasMatch(url)))
        .toList();
    matching.sort((a, b) => b.priority.compareTo(a.priority));

    final others = installed.where((e) => !matching.contains(e)).toList();
    others.sort((a, b) => b.priority.compareTo(a.priority));

    final sequence = [...matching, ...others];
    if (sequence.isEmpty) {
      return [requiredEngines.last];
    }
    return sequence;
  }

  /// All registered engines (unmodifiable).
  static List<DownloadEngine> get allEngines => List.unmodifiable(_engines);

  /// Whether all REQUIRED engines have their binaries installed.
  static bool get requiredInstalled =>
      requiredEngines.every((e) => e.isInstalled);

  /// Whether ALL registered engines (required + optional) are installed.
  static bool get allInstalled => _engines.every((e) => e.isInstalled);

  /// Required engines only.
  static List<DownloadEngine> get requiredEngines {
    final required = _engines.where((e) => !e.isOptional).toList();
    required.sort((a, b) => b.priority.compareTo(a.priority));
    return List.unmodifiable(required);
  }

  /// Optional engines only.
  static List<DownloadEngine> get optionalEngines {
    final optional = _engines.where((e) => e.isOptional).toList();
    optional.sort((a, b) => b.priority.compareTo(a.priority));
    return List.unmodifiable(optional);
  }

  /// Missing required engines.
  static List<DownloadEngine> get missingRequired =>
      requiredEngines.where((e) => !e.isInstalled).toList();

  /// Find an engine by ID.
  static DownloadEngine? findById(String id) {
    try {
      return _engines.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}
