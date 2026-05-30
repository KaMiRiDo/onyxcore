class MediaFormat {
  final String formatId;
  final String extension;
  final String resolution;
  final String? videoCodec;
  final String? audioCodec;
  final int? filesize;
  final String? formatNote;
  final String formatString;

  const MediaFormat({
    required this.formatId,
    required this.extension,
    required this.resolution,
    this.videoCodec,
    this.audioCodec,
    this.filesize,
    this.formatNote,
    required this.formatString,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaFormat &&
        other.formatId == formatId &&
        other.formatString == formatString;
  }

  @override
  int get hashCode => formatId.hashCode ^ formatString.hashCode;

  factory MediaFormat.fromJson(Map<String, dynamic> json) {
    return MediaFormat(
      formatId: json['format_id']?.toString() ?? '',
      extension: json['ext']?.toString() ?? '',
      resolution: json['resolution']?.toString() ??
          (json['height'] != null
              ? '${json['width']}x${json['height']}'
              : 'audio only'),
      videoCodec: json['vcodec']?.toString(),
      audioCodec: json['acodec']?.toString(),
      filesize: json['filesize'] as int?,
      formatNote: json['format_note']?.toString(),
      formatString: json['format']?.toString() ?? '',
    );
  }
}

class MediaInfo {
  final String id;
  final String title;
  final String? thumbnail;
  final int? duration;
  final String? extractor; // 'youtube', 'gallery-dl', etc.
  final List<MediaFormat> formats;
  final bool isVideo;
  final bool isPlaylist;
  final bool isProfile;
  final int? itemCount;
  final int? galleryIndex;
  final int? width;
  final int? height;
  final int? filesize;
  final String originalUrl;

  const MediaInfo({
    required this.id,
    required this.title,
    this.thumbnail,
    this.duration,
    this.extractor,
    this.formats = const [],
    this.isVideo = true,
    this.isPlaylist = false,
    this.isProfile = false,
    this.itemCount,
    this.galleryIndex,
    this.width,
    this.height,
    this.filesize,
    this.originalUrl = '',
  });

  factory MediaInfo.fromJson(Map<String, dynamic> json, {String originalUrl = ''}) {
    var formatsJson = json['formats'] as List<dynamic>?;
    List<MediaFormat> parsedFormats = [];
    if (formatsJson != null) {
      parsedFormats = formatsJson
          .map((e) => MediaFormat.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final type = json['_type']?.toString();
    final isPlaylist = type == 'playlist';
    final isProfile = false; // Will set in backend based on url/extractor
    
    int? itemCount;
    if (isPlaylist && json['playlist_count'] != null) {
       itemCount = json['playlist_count'] as int;
    } else if (isPlaylist && json['entries'] is List) {
       itemCount = (json['entries'] as List).length;
    }

    String parsedTitle = json['title']?.toString() ?? '';
    if (parsedTitle.isEmpty && originalUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(originalUrl);
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.isNotEmpty) {
          parsedTitle = segments.first;
          if (originalUrl.contains('instagram.com') || originalUrl.contains('x.com') || originalUrl.contains('twitter.com')) {
            parsedTitle = '@$parsedTitle';
          }
        }
      } catch (_) {}
    }
    if (parsedTitle.isEmpty) {
      parsedTitle = isPlaylist ? 'Unknown Playlist' : 'Unknown Title';
    }

    bool isVid = false;
    if (json['vcodec'] != null) {
      isVid = json['vcodec'] != 'none';
    } else if (formatsJson != null && formatsJson.isNotEmpty) {
      isVid = true; // yt-dlp default assumption if vcodec missing but formats exist
    } else if (json['extension'] != null) {
      isVid = ['mp4', 'webm', 'mkv', 'mov', 'avi'].contains(json['extension'].toString().toLowerCase());
    }

    return MediaInfo(
      id: json['id']?.toString() ?? '',
      title: parsedTitle,
      thumbnail: json['thumbnail']?.toString() ?? (json['thumbnails'] is List && (json['thumbnails'] as List).isNotEmpty ? (json['thumbnails'] as List).last['url']?.toString() : null),
      duration: json['duration'] as int?,
      filesize: json['filesize'] as int? ?? json['file_size'] as int? ?? json['size'] as int?,
      extractor: json['extractor']?.toString() ?? json['category']?.toString(),
      formats: parsedFormats,
      isVideo: isVid,
      isPlaylist: isPlaylist,
      isProfile: isProfile,
      itemCount: itemCount,
      galleryIndex: json['galleryIndex'] as int?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      originalUrl: originalUrl,
    );
  }

  MediaInfo copyWith({bool? isProfile, String? thumbnail, String? title, int? galleryIndex, int? filesize}) {
    return MediaInfo(
      id: id,
      title: title ?? this.title,
      thumbnail: thumbnail ?? this.thumbnail,
      duration: duration,
      extractor: extractor,
      formats: formats,
      isVideo: isVideo,
      isPlaylist: isPlaylist,
      isProfile: isProfile ?? this.isProfile,
      itemCount: itemCount,
      galleryIndex: galleryIndex ?? this.galleryIndex,
      width: width,
      height: height,
      filesize: filesize ?? this.filesize,
      originalUrl: originalUrl,
    );
  }
}

class MediaGroup {
  final String originalUrl;
  final List<MediaInfo> items;
  
  const MediaGroup({
    required this.originalUrl,
    required this.items,
  });

  bool get isSingle => items.length <= 1;
  MediaInfo get first => items.first;

  int get imageCount => items.where((i) => !i.isVideo).length;
  int get videoCount => items.where((i) => i.isVideo).length;
  int get totalFilesize => items.fold<int>(0, (sum, i) => sum + (i.filesize ?? 0));
}
