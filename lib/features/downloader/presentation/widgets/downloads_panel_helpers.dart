import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';

mixin DownloadsPanelHelpersMixin {
  final Map<String, int> _resolvedFileSizes = {};
  final Set<String> _fetchingFileSizes = {};

  String _trimMiddle(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    final partLength = (maxLength - 3) ~/ 2;
    return '${text.substring(0, partLength)}...${text.substring(text.length - partLength)}';
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final remainingSeconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
    } else {
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }
  }

  String _formatResolution(String resolution) {
    if (resolution.isEmpty) return 'Unknown';
    if (resolution.toLowerCase().contains('audio')) return 'Audio Only';

    final parts = resolution.split('x');
    if (parts.length == 2) {
      final height = int.tryParse(parts[1]);
      if (height != null) {
        if (height >= 2160) return '4K';
        if (height >= 1440) return '1440p';
        if (height >= 1080) return '1080p';
        if (height >= 720) return '720p';
        if (height >= 480) return '480p';
        if (height >= 360) return '360p';
        return '${height}p';
      }
    }

    return resolution;
  }

  int _getHeight(String resolution) {
    if (resolution.toLowerCase().contains('audio')) return 0;
    if (resolution.toLowerCase() == '4k') return 2160;

    final parts = resolution.split('x');
    if (parts.length == 2) {
      return int.tryParse(parts[1]) ?? 0;
    }

    final cleaned = resolution.replaceAll(RegExp('[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  MediaFormat? matchTargetFormat(MediaInfo item, MediaFormat? target) {
    if (target == null || item.formats.isEmpty) return null;

    final exactMatch = item.formats.where(
      (f) =>
          f.formatId == target.formatId ||
          (f.resolution == target.resolution &&
              f.videoCodec == target.videoCodec &&
              f.audioCodec == target.audioCodec),
    );
    if (exactMatch.isNotEmpty) return exactMatch.first;

    final isAudio = target.resolution.toLowerCase().contains('audio');
    if (isAudio) {
      final audioFormats = item.formats.where(
        (f) => f.resolution.toLowerCase().contains('audio'),
      );
      if (audioFormats.isNotEmpty) {
        final sorted = audioFormats.toList()
          ..sort((a, b) => (b.filesize ?? 0).compareTo(a.filesize ?? 0));
        return sorted.first;
      }
    }

    final targetHeight = _getHeight(target.resolution);
    final videoFormats = item.formats
        .where((f) => !f.resolution.toLowerCase().contains('audio'))
        .toList();

    if (videoFormats.isNotEmpty) {
      videoFormats.sort((a, b) {
        final heightA = _getHeight(a.resolution);
        final heightB = _getHeight(b.resolution);
        final isUnderOrEqualA = heightA <= targetHeight;
        final isUnderOrEqualB = heightB <= targetHeight;

        if (isUnderOrEqualA && !isUnderOrEqualB) return -1;
        if (!isUnderOrEqualA && isUnderOrEqualB) return 1;

        if (heightA != heightB) {
          return isUnderOrEqualA
              ? heightB.compareTo(heightA)
              : heightA.compareTo(heightB);
        }

        final noAudioA = a.audioCodec == 'none' || a.audioCodec == null;
        final noAudioB = b.audioCodec == 'none' || b.audioCodec == null;
        if (noAudioA && !noAudioB) return -1;
        if (!noAudioA && noAudioB) return 1;

        return (b.filesize ?? 0).compareTo(a.filesize ?? 0);
      });
      return videoFormats.first;
    }

    return null;
  }

  void _fetchLazySize(MediaInfo item) {
    if (item.directUrl == null ||
        _fetchingFileSizes.contains(item.id) ||
        _resolvedFileSizes.containsKey(item.id)) {
      return;
    }

    _fetchingFileSizes.add(item.id);

    Future.microtask(() async {
      try {
        final client = HttpClient();
        final request = await client.headUrl(Uri.parse(item.directUrl!));
        final response = await request.close();
        final contentLength = response.contentLength;

        if (contentLength > 0) {
          _resolvedFileSizes[item.id] = contentLength;
        }
      } catch (_) {
      } finally {
        _fetchingFileSizes.remove(item.id);
      }
    });
  }

  int? getFormatBytes(
    MediaInfo item,
    MediaFormat? format,
    DownloadConfig? config,
  ) {
    if (format == null) return null;

    if (format.filesize != null && format.filesize! > 0) {
      var size = format.filesize!;
      final noAudio = format.audioCodec == 'none' || format.audioCodec == null;
      if (noAudio &&
          !format.resolution.toLowerCase().contains('audio') &&
          config?.mode != DownloadMode.audioOnly) {
        final audioFormats = item.formats.where(
          (f) => f.resolution.toLowerCase().contains('audio'),
        );
        if (audioFormats.isNotEmpty) {
          final sortedAudio = audioFormats.toList()
            ..sort((a, b) => (b.filesize ?? 0).compareTo(a.filesize ?? 0));
          size += sortedAudio.first.filesize ?? 0;
        }
      }
      return size;
    }

    if (_resolvedFileSizes.containsKey(item.id)) {
      return _resolvedFileSizes[item.id];
    }

    if (item.directUrl != null) {
      _fetchLazySize(item);
    }

    if (config?.mode == DownloadMode.audioOnly) {
      final audioFormats = item.formats.where(
        (f) => f.resolution.toLowerCase().contains('audio'),
      );
      if (audioFormats.isNotEmpty) {
        final sortedAudio = audioFormats.toList()
          ..sort((a, b) => (b.filesize ?? 0).compareTo(a.filesize ?? 0));
        if (sortedAudio.first.filesize != null) {
          return sortedAudio.first.filesize;
        }
      }
    }

    return null;
  }

  String _getFileSize(MediaInfo item, DownloadConfig? config) {
    var format = config?.format;
    if (format != null && format.filesize == null && item.formats.isNotEmpty) {
      format = matchTargetFormat(item, format) ?? format;
    }
    final bytes = getFormatBytes(item, format, config);
    if (bytes != null && bytes > 0) {
      return StringUtils.formatBytes(bytes);
    }
    if (item.filesize != null && item.filesize! > 0) {
      return StringUtils.formatBytes(item.filesize!);
    }
    return '';
  }

  int _getGroupBytes(MediaGroup group, DownloadConfig config) {
    if (config.mode == DownloadMode.normal) {
      if (config.groupFilter == GroupDownloadType.images) {
        return group.items
            .where((i) => !i.isVideo && !i.isProfile && !i.isPlaylist)
            .fold(0, (sum, item) => sum + (item.filesize ?? (1024 * 1024)));
      } else if (config.groupFilter == GroupDownloadType.videos) {
        return group.items
            .where((i) => i.isVideo && !i.isProfile && !i.isPlaylist)
            .fold(
              0,
              (sum, item) => sum + (item.filesize ?? (15 * 1024 * 1024)),
            );
      }
    }

    var total = 0;
    var knownVideos = 0;
    var videoSizes = 0;
    var unknownVideos = 0;

    var knownImages = 0;
    var imageSizes = 0;
    var unknownImages = 0;

    for (final item in group.items) {
      if (item.isProfile || item.isPlaylist || item.isError) continue;

      if (item.isVideo) {
        if (item.filesize != null && item.filesize! > 0) {
          knownVideos++;
          videoSizes += item.filesize!;
          total += item.filesize!;
        } else {
          unknownVideos++;
        }
      } else {
        if (item.filesize != null && item.filesize! > 0) {
          knownImages++;
          imageSizes += item.filesize!;
          total += item.filesize!;
        } else {
          unknownImages++;
        }
      }
    }

    if (unknownVideos > 0) {
      final avgVideo = knownVideos > 0
          ? videoSizes ~/ knownVideos
          : (15 * 1024 * 1024);
      total += unknownVideos * avgVideo;
    }

    if (unknownImages > 0) {
      final avgImage = knownImages > 0
          ? imageSizes ~/ knownImages
          : (1024 * 1024);
      total += unknownImages * avgImage;
    }

    return total;
  }

  // Testing helpers
  @visibleForTesting
  String trimMiddleForTesting(String text, int maxLength) =>
      _trimMiddle(text, maxLength);

  @visibleForTesting
  String formatDurationForTesting(int seconds) => _formatDuration(seconds);

  @visibleForTesting
  String formatResolutionForTesting(String res) => _formatResolution(res);

  @visibleForTesting
  int getHeightForTesting(String res) => _getHeight(res);

  @visibleForTesting
  int? getFormatBytesForTesting(
    MediaInfo item,
    MediaFormat format,
    DownloadConfig config,
  ) => getFormatBytes(item, format, config);

  @visibleForTesting
  String getFileSizeForTesting(MediaInfo item, DownloadConfig config) =>
      _getFileSize(item, config);

  @visibleForTesting
  int getGroupBytesForTesting(MediaGroup group, DownloadConfig config) =>
      _getGroupBytes(group, config);

  @visibleForTesting
  Map<String, int> get resolvedFileSizesForTesting => _resolvedFileSizes;

  @visibleForTesting
  Set<String> get fetchingFileSizesForTesting => _fetchingFileSizes;
}
