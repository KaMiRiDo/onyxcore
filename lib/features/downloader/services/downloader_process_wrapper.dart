import 'dart:io';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';

/// Thin facade over the engine registry.
///
/// The public API surface (`analyzeUrls`, `startDownload`, `fetchMetadata`)
/// is unchanged — all existing callers continue working without modification.
/// Internally, each call resolves the appropriate engine via [EngineRegistry]
/// and delegates to it.
class MediaDownloaderBackend {
  static final Map<String, String> activeLogs = {};

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
    bool isPlaylist = false,
    bool fallbackToDirectLink = false,
    void Function(MediaInfo info)? onProgress,
    void Function(int pid)? onProcessStarted,
  }) async {
    final results = <MediaInfo>[];

    for (final url in urls) {
      if (url.trim().isEmpty) continue;
      final sequence = EngineRegistry.resolveEngineSequence(url.trim(), engine);
      var success = false;
      final engineErrors = <String, String>{};
      List<MediaInfo>? successfulInfos;
      String? successfulEngineId;

      for (final resolved in sequence) {
        try {
          final infoList = await resolved.fetchMetadata(
            url: url.trim(),
            browser: browser,
            fetchDeep: fetchDeep,
            isPlaylist: isPlaylist,
            onProgress: onProgress != null
                ? (info) {
                    var modifiedInfo = info.copyWith(engineId: resolved.id);
                    if (modifiedInfo.fetchLogs != null &&
                        modifiedInfo.fetchLogs!.isNotEmpty) {
                      modifiedInfo = modifiedInfo.copyWith(
                        fetchLogs:
                            '[${resolved.id}]:\n${modifiedInfo.fetchLogs}',
                      );
                    }
                    onProgress(modifiedInfo);
                  }
                : null,
            onProcessStarted: onProcessStarted,
          );
          if (infoList.isNotEmpty) {
            successfulInfos = infoList;
            successfulEngineId = resolved.id;
            success = true;
            break;
          }
        } on PartialMetadataException catch (e) {
          if (e.partialInfos.isNotEmpty) {
            successfulInfos = e.partialInfos;
            successfulEngineId = resolved.id;
            success = true;
            engineErrors[resolved.id] = e.message;
            break;
          } else {
            engineErrors[resolved.id] = e.message;
          }
        } catch (e) {
          engineErrors[resolved.id] = e.toString();
        }
      }

      if (success && successfulInfos != null) {
        final pipelineLogs = StringBuffer();
        var idx = 0;
        for (final entry in engineErrors.entries) {
          pipelineLogs.writeln('[${entry.key}]:\n${entry.value}');
          if (idx < engineErrors.length || successfulInfos.isNotEmpty) {
            pipelineLogs.writeln('======================================');
          }
          idx++;
        }

        for (var i = 0; i < successfulInfos.length; i++) {
          final engineId =
              successfulInfos[i].engineId ?? successfulEngineId ?? 'yt-dlp';
          final currentLogs =
              successfulInfos[i].fetchLogs ?? 'Fetch completed successfully.';

          final formattedSuccessLogs =
              '$pipelineLogs[$engineId]:\n$currentLogs';

          successfulInfos[i] = successfulInfos[i].copyWith(
            id: successfulInfos[i].id.isEmpty ? 'item_${url.hashCode}_$i' : successfulInfos[i].id,
            engineId: successfulInfos[i].engineId ?? successfulEngineId,
            errorMessage: successfulInfos[i].errorMessage,
            fetchLogs: formattedSuccessLogs,
          );
          if (onProgress != null) onProgress(successfulInfos[i]);
        }
        results.addAll(successfulInfos);
      } else {
        final errorMsg = engineErrors.entries
            .map((e) => '${e.key}: ${e.value}')
            .join('\n');

        final pipelineLogs = StringBuffer();
        var idx = 0;
        for (final entry in engineErrors.entries) {
          pipelineLogs.writeln('[${entry.key}]:\n${entry.value}');
          if (idx < engineErrors.length - 1) {
            pipelineLogs.writeln('======================================');
          }
          idx++;
        }

        if (fallbackToDirectLink &&
            (url.startsWith('http://') || url.startsWith('https://'))) {
          var fallbackTitle = url;
          try {
            final uri = Uri.parse(url);
            if (uri.pathSegments.isNotEmpty) {
              fallbackTitle = uri.pathSegments.last;
            }
          } catch (_) {}
          
          final probedSize = await _probeFallbackSize(url);
          
          final fallbackInfo = MediaInfo(
            id: 'fallback_${url.hashCode}',
            title: fallbackTitle,
            originalUrl: url,
            directUrl: url,
            thumbnail: url,
            isVideo: false,
            filesize: probedSize,
            fetchLogs: pipelineLogs.toString(),
          );
          if (onProgress != null) onProgress(fallbackInfo);
          results.add(fallbackInfo);
        } else {
          final errInfo = MediaInfo(
            id: 'err_${url.hashCode}',
            title: url,
            originalUrl: url,
            isError: true,
            errorMessage: errorMsg.isNotEmpty
                ? errorMsg
                : 'All available engines failed to analyze this URL.',
            fetchLogs: pipelineLogs.toString(),
          );
          if (onProgress != null) onProgress(errInfo);
          results.add(errInfo);
        }
      }
    }

    return results;
  }

  static Future<int?> _probeFallbackSize(String url) async {
    try {
      final client = HttpClient()..connectionTimeout = const Duration(seconds: 3);
      final req = await client.headUrl(Uri.parse(url));
      final res = await req.close();
      if (res.contentLength > 0) {
        client.close(force: true);
        return res.contentLength;
      }
      client.close(force: true);
    } catch (_) {}
    return null;
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
    String? singleItemId,
    String? directUrl,
    String? itemsRange,
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
      singleItemId: singleItemId,
      directUrl: directUrl,
      itemsRange: itemsRange,
    );
  }
}
