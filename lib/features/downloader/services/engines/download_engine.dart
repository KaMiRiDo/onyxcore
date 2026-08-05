import 'dart:io';
import 'package:flutter/material.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/downloader_process_wrapper.dart' show MediaDownloaderBackend;

/// The type of download engine — determines how processes are spawned.
enum EngineType {
  /// Single native binary (yt-dlp, gallery-dl, lux, aria2c).
  cli,

  /// Python-based CLI tool (you-get, streamlink, playwright).
  python,

  /// Script-based pipeline (playwright → ffmpeg/aria2c).
  script,

  /// Future: API-based engines.
  api,
}

/// Information needed to download/update an engine binary from a GitHub release.
class EngineUpdateInfo {

  const EngineUpdateInfo({
    required this.apiUrl,
    required this.assetName,
    this.checksumAssetName,
  });
  final String apiUrl;
  final String assetName;
  final String? checksumAssetName;
}

/// Exception thrown when an engine fetches some metadata but times out before finishing.
class PartialMetadataException implements Exception {

  const PartialMetadataException({
    required this.partialInfos,
    required this.message,
  });
  final List<MediaInfo> partialInfos;
  final String message;

  @override
  String toString() => message;
}

/// Abstract interface for a download engine.
///
/// Concrete implementations extract all CLI-specific logic (argument building,
/// JSON parsing, streaming) so that adding a new engine (CLI tool, Python
/// script, web scraper) never requires touching the [MediaDownloaderBackend]
/// facade.
abstract class DownloadEngine {
  /// Unique engine identifier (e.g., 'yt-dlp', 'gallery-dl').
  String get id;

  /// Human-readable display name.
  String get displayName;

  /// Icon for UI rendering.
  IconData get icon;

  /// Color for UI rendering.
  Color get color;

  /// Type of engine — determines how processes are spawned.
  EngineType get engineType;

  /// Path to the engine binary/script (null for API-based engines).
  String? get binaryPath;

  /// URL patterns this engine can handle (regex list for auto-detection).
  List<RegExp> get urlPatterns;

  /// Priority for auto-detection (higher = preferred when multiple match).
  int get priority;

  /// System dependencies required by this engine (e.g., 'python3', 'ffmpeg').
  /// Used by the missing binaries view to show granular dependency info.
  List<String> get systemDependencies => [];

  /// Whether this engine is optional (can be installed/deleted from Settings).
  /// Required engines (yt-dlp, gallery-dl) block the panel if missing.
  /// Optional engines (you-get, lux, streamlink, playwright) are managed freely.
  bool get isOptional => false;

  /// Fetch metadata for a URL.
  Future<List<MediaInfo>> fetchMetadata({
    required String url,
    String? browser,
    bool fetchDeep = false,
    bool isPlaylist = false,
    void Function(MediaInfo info)? onProgress,
    void Function(int pid)? onProcessStarted,
  });

  /// Start a download process.
  Future<Process> startDownload({
    required String url,
    required String destination,
    String? title,
    MediaFormat? format,
    bool audioOnly = false,
    bool mute = false,
    int? galleryIndex,
    bool isPlaylist = false,
    bool isProfile = false,
    String? browser,
    bool isZip = false,
    String? filterType,
    int? totalItems,
    String? singleItemId,
    String? directUrl,
    String? itemsRange,
  });

  /// Whether the engine binary is installed and ready to use.
  bool get isInstalled;

  /// Update info — where to download and verify the binary.
  EngineUpdateInfo? get updateInfo;

  /// Install this engine. Override for engines with custom install flows.
  /// Returns the install process for progress tracking in the UI.
  Future<Process>? install() => null;

  /// Uninstall this engine. Override for engines with custom uninstall flows.
  /// Returns the uninstall process for progress tracking in the UI.
  Future<Process>? uninstall() => null;

  /// Get the currently installed version of the engine (e.g., '2024.04.09').
  /// Returns null if not installed or version cannot be determined.
  Future<String?> getInstalledVersion() async => null;

  /// Get the latest available version from remote APIs (GitHub/PyPI).
  /// Returns null if it cannot be fetched or there's no update mechanism.
  Future<String?> getLatestVersion() async => null;
}
