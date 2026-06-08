part of 'downloads_panel.dart';

mixin DownloadsPanelHelpersMixin<T extends StatefulWidget> on State<T> {
  final Map<String, int> _resolvedFileSizes = {};
  final Set<String> _fetchingFileSizes = {};

  Future<void> _fetchLazySize(String id, String url) async {
    try {
      final req = await HttpClient().headUrl(Uri.parse(url));
      final res = await req.close();
      if (res.statusCode == 200 && res.contentLength > 0) {
        if (mounted) {
          setState(() {
            _resolvedFileSizes[id] = res.contentLength;
          });
        }
      }
    } catch (_) {}
  }

  String _trimMiddle(String text, int maxLength) {
    if (text.characters.length <= maxLength) return text;
    final half = (maxLength - 3) ~/ 2;
    final chars = text.characters;
    return '${chars.take(half)}...${chars.takeLast(half)}';
  }

  String _formatResolution(String res) {
    if (res.isEmpty) return 'Unknown';
    if (res == 'audio only' || res.toLowerCase() == 'audio')
      return 'Audio Only';

    final parts = res.toLowerCase().split('x');
    if (parts.length == 2) {
      final height = int.tryParse(parts[1]);
      if (height != null) {
        if (height >= 2160) return '4K';
        if (height >= 1440) return '1440p';
        return '${height}p';
      }
    } else {
      final height = int.tryParse(res.replaceAll(RegExp(r'[^0-9]'), ''));
      if (height != null) {
        if (height >= 2160) return '4K';
        if (height >= 1440) return '1440p';
        return '${height}p';
      }
    }
    return res;
  }

  int _getHeight(String res) {
    if (res.isEmpty || res == 'audio only' || res.toLowerCase() == 'audio')
      return 0;
    final parts = res.toLowerCase().split('x');
    if (parts.length == 2) {
      return int.tryParse(parts[1]) ?? 0;
    } else {
      return int.tryParse(res.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '0:${seconds.toString().padLeft(2, '0')}';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes < 60) {
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '$hours:${remainingMinutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  int? _getFormatBytes(MediaInfo item, MediaFormat? format, DownloadConfig config) {
    if (format == null) {
      final size = item.filesize ?? _resolvedFileSizes[item.id];
      if (size == null && item.directUrl != null && !_fetchingFileSizes.contains(item.id)) {
        _fetchingFileSizes.add(item.id);
        _fetchLazySize(item.id, item.directUrl!);
      }
      return size;
    }

    int? bytes = format.filesize ?? _resolvedFileSizes[item.id];

    if (config.mode == DownloadMode.normal && 
        format.resolution != 'audio only' && 
        format.resolution.toLowerCase() != 'audio') {
      
      final bool noAudio = format.audioCodec == 'none' || format.audioCodec == null || format.audioCodec!.isEmpty;
      if (noAudio) {
        final audioFormats = item.formats
            .where((f) => (f.resolution == 'audio only' || f.resolution.toLowerCase() == 'audio') && f.filesize != null)
            .toList();
            
        if (audioFormats.isNotEmpty) {
          audioFormats.sort((a, b) => b.filesize!.compareTo(a.filesize!));
          if (bytes != null) {
            bytes += audioFormats.first.filesize!;
          }
        }
      }
    } else if (config.mode == DownloadMode.audioOnly) {
       final audioFormats = item.formats
            .where((f) => (f.resolution == 'audio only' || f.resolution.toLowerCase() == 'audio') && f.filesize != null)
            .toList();
        if (audioFormats.isNotEmpty) {
           audioFormats.sort((a, b) => b.filesize!.compareTo(a.filesize!));
           return audioFormats.first.filesize;
        }
    }
    
    // Only fallback to item.filesize if we are selecting the absolute best format 
    // or if the item only has one format anyway.
    if (bytes == null) {
        final bestVideo = item.formats.where((f) => f.videoCodec != null && f.videoCodec != 'none').toList();
        if (bestVideo.isNotEmpty) {
            bestVideo.sort((a, b) => _getHeight(b.resolution).compareTo(_getHeight(a.resolution)));
            if (format.formatId == bestVideo.first.formatId) {
                bytes = item.filesize;
            }
        } else {
            bytes = item.filesize;
        }
    }

    if (bytes == null && item.directUrl != null && !_fetchingFileSizes.contains(item.id)) {
      _fetchingFileSizes.add(item.id);
      _fetchLazySize(item.id, item.directUrl!);
    }

    return bytes;
  }

  String? _getFileSize(MediaInfo item, DownloadConfig config) {
    final currentFormat = config.itemFormats[item.id] ?? config.format;
    final bytes = _getFormatBytes(item, currentFormat, config);

    if (bytes != null && bytes > 0) {
      return StringUtils.formatBytes(bytes);
    }
    return null;
  }

  int _getGroupBytes(MediaGroup group, DownloadConfig config) {
    int totalVideo = 0;
    int videoWithSize = 0;
    int videoWithoutSize = 0;

    int totalImage = 0;
    int imageWithSize = 0;
    int imageWithoutSize = 0;

    for (final item in group.items) {
      if (item.isProfile || item.isPlaylist) continue;
      if (config.groupFilter == GroupDownloadType.images && item.isVideo) continue;
      if (config.groupFilter == GroupDownloadType.videos && !item.isVideo) continue;

      final currentFormat = config.itemFormats[item.id] ?? config.format;
      final bytes = _getFormatBytes(item, currentFormat, config);

      if (item.isVideo) {
        if (bytes != null && bytes > 0) {
          totalVideo += bytes;
          videoWithSize++;
        } else {
          videoWithoutSize++;
        }
      } else {
        if (bytes != null && bytes > 0) {
          totalImage += bytes;
          imageWithSize++;
        } else {
          imageWithoutSize++;
        }
      }
    }

    if (videoWithoutSize > 0) {
      if (videoWithSize > 0) {
        totalVideo += ((totalVideo / videoWithSize) * videoWithoutSize).round();
      } else {
        totalVideo += videoWithoutSize * 15 * 1024 * 1024; // 15MB fallback
      }
    }

    if (imageWithoutSize > 0) {
      if (imageWithSize > 0) {
        totalImage += ((totalImage / imageWithSize) * imageWithoutSize).round();
      } else {
        totalImage += imageWithoutSize * 1 * 1024 * 1024; // 1MB fallback
      }
    }

    return totalVideo + totalImage;
  }

  String _formatBytes(int bytes) => StringUtils.formatBytes(bytes);
}
