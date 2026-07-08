class MediaFormat {

  const MediaFormat({
    required this.formatId,
    required this.extension,
    required this.resolution,
    required this.formatString, this.videoCodec,
    this.audioCodec,
    this.filesize,
    this.formatNote,
    this.url,
  });

  factory MediaFormat.fromJson(Map<String, dynamic> json) {
    return MediaFormat(
      formatId: json['format_id']?.toString() ?? '',
      extension: json['ext']?.toString() ?? '',
      resolution:
          json['resolution']?.toString() ??
          (json['height'] != null
              ? '${json['width']}x${json['height']}'
              : 'audio only'),
      videoCodec: json['vcodec']?.toString(),
      audioCodec: json['acodec']?.toString(),
      filesize:
          (json['filesize'] as num?)?.toInt() ??
          (json['filesize_approx'] as num?)?.toInt(),
      formatNote: json['format_note']?.toString(),
      formatString: json['format']?.toString() ?? '',
      url: json['url']?.toString(),
    );
  }
  final String formatId;
  final String extension;
  final String resolution;
  final String? videoCodec;
  final String? audioCodec;
  final int? filesize;
  final String? formatNote;
  final String formatString;
  final String? url;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MediaFormat &&
        other.formatId == formatId &&
        other.formatString == formatString;
  }

  @override
  int get hashCode => formatId.hashCode ^ formatString.hashCode;

  Map<String, dynamic> toJson() {
    return {
      'format_id': formatId,
      'ext': extension,
      'resolution': resolution,
      if (videoCodec != null) 'vcodec': videoCodec,
      if (audioCodec != null) 'acodec': audioCodec,
      if (filesize != null) 'filesize': filesize,
      if (formatNote != null) 'format_note': formatNote,
      'format': formatString,
      if (url != null) 'url': url,
    };
  }
}

class MediaInfo {

  const MediaInfo({
    required this.id,
    required this.title,
    required this.originalUrl, this.thumbnail,
    this.duration,
    this.extractor,
    this.engineId,
    this.formats = const [],
    this.isVideo = true,
    this.isPlaylist = false,
    this.isProfile = false,
    this.itemCount,
    this.galleryIndex,
    this.width,
    this.height,
    this.filesize,
    this.directUrl,
    this.webpageUrl,
    this.isError = false,
    this.errorMessage,
    this.fetchLogs,
    this.isLive = false,
  });

  factory MediaInfo.fromJson(
    Map<String, dynamic> json, {
    String originalUrl = '',
  }) {
    final formatsJson = json['formats'] as List<dynamic>?;
    var parsedFormats = <MediaFormat>[];
    if (formatsJson != null) {
      parsedFormats = formatsJson
          .map((e) => MediaFormat.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final type = json['_type']?.toString();
    final isPlaylist = type == 'playlist';
    const isProfile = false; // Will set in backend based on url/extractor

    int? itemCount;
    if (isPlaylist && json['playlist_count'] != null) {
      itemCount = json['playlist_count'] as int;
    } else if (isPlaylist && json['entries'] is List) {
      itemCount = (json['entries'] as List).length;
    }

    var parsedTitle = json['title']?.toString() ?? '';
    if (parsedTitle.isEmpty && originalUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(originalUrl);
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.isNotEmpty) {
          parsedTitle = segments.first;
          if (originalUrl.contains('instagram.com') ||
              originalUrl.contains('x.com') ||
              originalUrl.contains('twitter.com')) {
            parsedTitle = '@$parsedTitle';
          }
        }
      } catch (_) {}
    }
    if (parsedTitle.isEmpty) {
      parsedTitle = isPlaylist ? 'Unknown Playlist' : 'Unknown Title';
    }

    var isVid = false;
    if (json['vcodec'] != null) {
      isVid = json['vcodec'] != 'none';
    } else if (formatsJson != null && formatsJson.isNotEmpty) {
      isVid =
          true; // yt-dlp default assumption if vcodec missing but formats exist
    } else if (json['extension'] != null) {
      isVid = [
        'mp4',
        'webm',
        'mkv',
        'mov',
        'avi',
      ].contains(json['extension'].toString().toLowerCase());
    }

    return MediaInfo(
      id: json['id']?.toString() ?? '',
      title: parsedTitle,
      thumbnail:
          json['thumbnail']?.toString() ??
          (json['thumbnails'] is List && (json['thumbnails'] as List).isNotEmpty
              ? (json['thumbnails'] as List).last['url']?.toString()
              : null),
      duration: (json['duration'] as num?)?.toInt(),
      filesize:
          (json['filesize'] as num?)?.toInt() ??
          (json['filesize_approx'] as num?)?.toInt() ??
          (json['file_size'] as num?)?.toInt() ??
          (json['size'] as num?)?.toInt(),
      extractor: json['extractor']?.toString() ?? json['category']?.toString(),
      engineId: json['engineId']?.toString(),
      formats: parsedFormats,
      isVideo: isVid,
      isPlaylist: isPlaylist,
      itemCount: itemCount,
      galleryIndex: json['galleryIndex'] as int?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      originalUrl: originalUrl.isNotEmpty
          ? originalUrl
          : (json['webpage_url']?.toString() ?? ''),
      directUrl: json['url']?.toString(),
      webpageUrl: json['webpage_url']?.toString(),
      isLive: json['is_live'] == true,
    );
  }

  factory MediaInfo.fromMap(Map<String, dynamic> map) {
    return MediaInfo(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      thumbnail: map['thumbnail']?.toString(),
      duration: map['duration'] as int?,
      extractor: map['extractor']?.toString(),
      formats:
          (map['formats'] as List<dynamic>?)
              ?.map((e) => MediaFormat.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isVideo: map['isVideo'] as bool? ?? true,
      isPlaylist: map['isPlaylist'] as bool? ?? false,
      isProfile: map['isProfile'] as bool? ?? false,
      itemCount: map['itemCount'] as int?,
      galleryIndex: map['galleryIndex'] as int?,
      width: map['width'] as int?,
      height: map['height'] as int?,
      filesize: map['filesize'] as int?,
      originalUrl: map['originalUrl']?.toString() ?? '',
      directUrl: map['directUrl']?.toString(),
      webpageUrl: map['webpageUrl']?.toString(),
      isLive: map['isLive'] as bool? ?? false,
      engineId: map['engineId']?.toString(),
      isError: map['isError'] as bool? ?? false,
      errorMessage: map['errorMessage']?.toString(),
      fetchLogs: map['fetchLogs']?.toString(),
    );
  }
  final String id;
  final String title;
  final String? thumbnail;
  final int? duration;
  final String? extractor; // 'youtube', 'gallery-dl', etc.
  final String? engineId;
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
  final String? directUrl;
  final String? webpageUrl;
  final bool isError;
  final String? errorMessage;
  final String? fetchLogs;
  final bool isLive;

  MediaInfo copyWith({
    String? id,
    bool? isProfile,
    String? thumbnail,
    String? title,
    int? galleryIndex,
    int? filesize,
    bool? isLive,
    String? originalUrl,
    String? directUrl,
    String? webpageUrl,
    String? engineId,
    String? errorMessage,
    String? fetchLogs,
    bool? isVideo,
    List<MediaFormat>? formats,
    int? width,
    int? height,
  }) {
    return MediaInfo(
      id: id ?? this.id,
      title: title ?? this.title,
      thumbnail: thumbnail ?? this.thumbnail,
      duration: duration,
      extractor: extractor,
      formats: formats ?? this.formats,
      isVideo: isVideo ?? this.isVideo,
      isPlaylist: isPlaylist,
      isProfile: isProfile ?? this.isProfile,
      itemCount: itemCount,
      galleryIndex: galleryIndex ?? this.galleryIndex,
      width: width ?? this.width,
      height: height ?? this.height,
      filesize: filesize ?? this.filesize,
      originalUrl: originalUrl ?? this.originalUrl,
      directUrl: directUrl ?? this.directUrl,
      webpageUrl: webpageUrl ?? this.webpageUrl,
      isLive: isLive ?? this.isLive,
      engineId: engineId ?? this.engineId,
      errorMessage: errorMessage ?? this.errorMessage,
      fetchLogs: fetchLogs ?? this.fetchLogs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      if (thumbnail != null) 'thumbnail': thumbnail,
      if (duration != null) 'duration': duration,
      if (extractor != null) 'extractor': extractor,
      'formats': formats.map((e) => e.toJson()).toList(),
      'isVideo': isVideo,
      'isPlaylist': isPlaylist,
      'isProfile': isProfile,
      if (itemCount != null) 'itemCount': itemCount,
      if (galleryIndex != null) 'galleryIndex': galleryIndex,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (filesize != null) 'filesize': filesize,
      'originalUrl': originalUrl,
      if (directUrl != null) 'directUrl': directUrl,
      if (webpageUrl != null) 'webpageUrl': webpageUrl,
      if (isLive) 'isLive': isLive,
      if (engineId != null) 'engineId': engineId,
      'isError': isError,
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (fetchLogs != null) 'fetchLogs': fetchLogs,
    };
  }
}

class MediaGroup {

  const MediaGroup({
    required this.originalUrl,
    required this.items,
  });

  factory MediaGroup.fromMap(Map<String, dynamic> map) {
    return MediaGroup(
      originalUrl: map['originalUrl']?.toString() ?? '',
      items:
          (map['items'] as List<dynamic>?)
              ?.map((e) => MediaInfo.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
  final String originalUrl;
  final List<MediaInfo> items;

  Map<String, dynamic> toMap() {
    return {
      'originalUrl': originalUrl,
      'items': items.map((e) => e.toMap()).toList(),
    };
  }

  bool get isSingle => items.length <= 1;
  MediaInfo get first => items.first;

  int get imageCount => items.where((i) => !i.isVideo).length;
  int get videoCount => items.where((i) => i.isVideo).length;
  int get totalFilesize {
    var totalVideo = 0;
    var videoWithSize = 0;
    var videoWithoutSize = 0;

    var totalImage = 0;
    var imageWithSize = 0;
    var imageWithoutSize = 0;

    for (final item in items) {
      final bytes = item.filesize;
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
        totalVideo += videoWithoutSize * 15 * 1024 * 1024;
      }
    }

    if (imageWithoutSize > 0) {
      if (imageWithSize > 0) {
        totalImage += ((totalImage / imageWithSize) * imageWithoutSize).round();
      } else {
        totalImage += imageWithoutSize * 1 * 1024 * 1024;
      }
    }

    return totalVideo + totalImage;
  }
}
