import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';

enum DownloadMode { normal, mute, audioOnly }

enum GroupDownloadType { all, images, videos }

class DownloadConfig {

  DownloadConfig({
    this.format,
    this.mode = DownloadMode.normal,
    this.groupFilter = GroupDownloadType.all,
    this.engine = 'auto',
    Map<String, MediaFormat?>? itemFormats,
  }) : itemFormats = itemFormats ?? {};
  MediaFormat? format;
  Map<String, MediaFormat?> itemFormats;
  DownloadMode mode;
  GroupDownloadType groupFilter;

  /// Captured at fetch time — ensures downloads use the engine that was
  /// active when the URL was analyzed, even if the user switches engines
  /// afterwards. Fixes C3.
  String engine;
}
