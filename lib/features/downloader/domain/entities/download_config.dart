import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';

enum DownloadMode { normal, mute, audioOnly }
enum GroupDownloadType { all, images, videos }

class DownloadConfig {
  MediaFormat? format;
  Map<String, MediaFormat?> itemFormats;
  DownloadMode mode;
  GroupDownloadType groupFilter;

  DownloadConfig({
    this.format,
    this.mode = DownloadMode.normal,
    this.groupFilter = GroupDownloadType.all,
    Map<String, MediaFormat?>? itemFormats,
  }) : itemFormats = itemFormats ?? {};
}
