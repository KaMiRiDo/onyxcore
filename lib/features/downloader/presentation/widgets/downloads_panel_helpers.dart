part of 'downloads_panel.dart';

mixin DownloadsPanelHelpersMixin<T extends StatefulWidget> on State<T> {
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

  String? _getFileSize(MediaInfo item, DownloadConfig config) {
    int? bytes;
    final currentFormat = config.itemFormats[item.id] ?? config.format;

    if (config.mode == DownloadMode.mute ||
        config.mode == DownloadMode.normal) {
      final formatId = currentFormat?.formatId;
      if (formatId != null) {
        final format = item.formats
            .where((f) => f.formatId == formatId)
            .firstOrNull;
        bytes = format?.filesize;
      }
    } else if (config.mode == DownloadMode.audioOnly) {
      final audioFormat = item.formats
          .where((f) => f.resolution == 'audio only')
          .firstOrNull;
      bytes = audioFormat?.filesize;
    }

    bytes ??= item.filesize;

    if (bytes != null && bytes > 0) {
      return StringUtils.formatBytes(bytes);
    }
    return null;
  }

  int _getGroupBytes(MediaGroup group, DownloadConfig config) {
    int total = 0;
    for (final item in group.items) {
      if (item.isProfile || item.isPlaylist) continue;
      if (config.groupFilter == GroupDownloadType.images && item.isVideo)
        continue;
      if (config.groupFilter == GroupDownloadType.videos && !item.isVideo)
        continue;

      int? bytes;
      final currentFormat = config.itemFormats[item.id] ?? config.format;

      if (config.mode == DownloadMode.mute ||
          config.mode == DownloadMode.normal) {
        final formatId = currentFormat?.formatId;
        if (formatId != null) {
          final format = item.formats
              .where((f) => f.formatId == formatId)
              .firstOrNull;
          bytes = format?.filesize;
        }
      } else if (config.mode == DownloadMode.audioOnly) {
        final audioFormat = item.formats
            .where((f) => f.resolution == 'audio only')
            .firstOrNull;
        bytes = audioFormat?.filesize;
      }

      bytes ??= item.filesize;
      total += bytes ?? 0;
    }
    return total;
  }

  String _formatBytes(int bytes) => StringUtils.formatBytes(bytes);
}
