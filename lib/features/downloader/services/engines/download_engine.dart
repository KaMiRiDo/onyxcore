import 'dart:io';
import 'package:flutter/material.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';

/// The type of download engine — determines how processes are spawned.
enum EngineType { cli, python, api }

/// Information needed to download/update an engine binary from a GitHub release.
class EngineUpdateInfo {
  final String apiUrl;
  final String assetName;
  final String? checksumAssetName;

  const EngineUpdateInfo({
    required this.apiUrl,
    required this.assetName,
    this.checksumAssetName,
  });
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

  /// Fetch metadata for a URL.
  Future<List<MediaInfo>> fetchMetadata({
    required String url,
    String? browser,
    bool fetchDeep = false,
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
  });

  /// Whether the engine binary is installed and ready to use.
  bool get isInstalled;

  /// Update info — where to download and verify the binary.
  EngineUpdateInfo? get updateInfo;
}
