import 'dart:io';
import 'package:flutter/foundation.dart';
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
    void Function(MediaInfo info)? onProgress,
    void Function(int pid)? onProcessStarted,
  }) async {
    final results = <MediaInfo>[];
    
    for (final url in urls) {
      if (url.trim().isEmpty) continue;
      final sequence = EngineRegistry.resolveEngineSequence(url.trim(), engine);
      bool success = false;
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
            onProgress: onProgress != null ? (info) {
              var modifiedInfo = info.copyWith(engineId: resolved.id);
              if (modifiedInfo.fetchLogs != null && modifiedInfo.fetchLogs!.isNotEmpty) {
                modifiedInfo = modifiedInfo.copyWith(
                  fetchLogs: '[${resolved.id}]:\n${modifiedInfo.fetchLogs}',
                );
              }
              onProgress(modifiedInfo);
            } : null,
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
          final engineId = successfulInfos[i].engineId ?? successfulEngineId ?? 'yt-dlp';
          final currentLogs = successfulInfos[i].fetchLogs ?? 'Fetch completed successfully.';

          final formattedSuccessLogs = pipelineLogs.toString() + '[$engineId]:\n$currentLogs';
          
          if (successfulInfos[i].engineId == null) {
            successfulInfos[i] = MediaInfo(
              id: successfulInfos[i].id,
              title: successfulInfos[i].title,
              thumbnail: successfulInfos[i].thumbnail,
              duration: successfulInfos[i].duration,
              filesize: successfulInfos[i].filesize,
              extractor: successfulInfos[i].extractor,
              engineId: successfulEngineId,
              formats: successfulInfos[i].formats,
              isVideo: successfulInfos[i].isVideo,
              isPlaylist: successfulInfos[i].isPlaylist,
              isProfile: successfulInfos[i].isProfile,
              itemCount: successfulInfos[i].itemCount,
              galleryIndex: successfulInfos[i].galleryIndex,
              width: successfulInfos[i].width,
              height: successfulInfos[i].height,
              originalUrl: successfulInfos[i].originalUrl,
              directUrl: successfulInfos[i].directUrl,
              isError: successfulInfos[i].isError,
              isLive: successfulInfos[i].isLive,
              errorMessage: successfulInfos[i].errorMessage ?? (engineErrors.isNotEmpty ? engineErrors.values.first : null),
              fetchLogs: formattedSuccessLogs,
            );
          } else {
            successfulInfos[i] = successfulInfos[i].copyWith(
              errorMessage: successfulInfos[i].errorMessage ?? (engineErrors.isNotEmpty ? engineErrors.values.first : null),
              fetchLogs: formattedSuccessLogs,
            );
          }
        }
        results.addAll(successfulInfos);
      } else {
        final errorMsg = engineErrors.entries.map((e) => '${e.key}: ${e.value}').join('\n');
        
        final pipelineLogs = StringBuffer();
        var idx = 0;
        for (final entry in engineErrors.entries) {
          pipelineLogs.writeln('[${entry.key}]:\n${entry.value}');
          if (idx < engineErrors.length - 1) {
            pipelineLogs.writeln('======================================');
          }
          idx++;
        }
        
        results.add(MediaInfo(
          id: '',
          title: url,
          originalUrl: url,
          isError: true,
          errorMessage: errorMsg.isNotEmpty ? errorMsg : 'All available engines failed to analyze this URL.',
          fetchLogs: pipelineLogs.toString(),
        ));
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
    String? singleItemId,
    String? directUrl,
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
    );
  }
}
