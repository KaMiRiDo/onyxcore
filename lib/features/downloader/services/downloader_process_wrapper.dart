import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';

/// Thin facade over the engine registry.
///
/// The public API surface (`analyzeUrls`, `startDownload`, `fetchMetadata`)
/// is unchanged — all existing callers continue working without modification.
/// Internally, each call resolves the appropriate engine via [EngineRegistry]
/// and delegates to it.
class MediaDownloaderBackend {
  static Future<List<MediaInfo>> fetchMetadata(
    String url, {
    String engine = 'auto',
    String? browser,
    bool fetchDeep = false,
  }) async {
    final resolved = EngineRegistry.resolveEngine(url, engine);
    return resolved.fetchMetadata(
      url: url,
      browser: browser,
      fetchDeep: fetchDeep,
    );
  }

  static Future<List<MediaInfo>> analyzeUrls(
    List<String> urls, {
    String engine = 'auto',
    String? browser,
    bool fetchDeep = false,
    void Function(MediaInfo info)? onProgress,
    void Function(int pid)? onProcessStarted,
  }) async {
    final results = <MediaInfo>[];
    for (final url in urls) {
      if (url.trim().isEmpty) continue;
      try {
        final resolved = EngineRegistry.resolveEngine(url.trim(), engine);
        final infoList = await resolved.fetchMetadata(
          url: url.trim(),
          browser: browser,
          fetchDeep: fetchDeep,
          onProgress: onProgress,
          onProcessStarted: onProcessStarted,
        );
        results.addAll(infoList);
      } catch (e) {
        debugPrint('Failed to analyze $url: $e');
        results.add(
          MediaInfo(
            id: '',
            title: 'Error loading URL',
            originalUrl: url.trim(),
            isError: true,
            errorMessage: e.toString(),
          ),
        );
      }
    }
    return results;
  }

  static Future<Process> startDownload({
    required String url,
    required String destination,
    String? title,
    MediaFormat? format,
    bool audioOnly = false,
    bool mute = false,
    int? galleryIndex,
    String engine = 'auto',
    bool isPlaylist = false,
    bool isProfile = false,
    String? browser,
    bool isZip = false,
    String? filterType,
    int? totalItems,
  }) async {
    final resolved = EngineRegistry.resolveEngine(url, engine);
    return resolved.startDownload(
      url: url,
      destination: destination,
      title: title,
      format: format,
      audioOnly: audioOnly,
      mute: mute,
      galleryIndex: galleryIndex,
      isPlaylist: isPlaylist,
      isProfile: isProfile,
      browser: browser,
      isZip: isZip,
      filterType: filterType,
      totalItems: totalItems,
    );
  }
}
