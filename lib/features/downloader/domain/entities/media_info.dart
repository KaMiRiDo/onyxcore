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
      filesize: json['filesize'] as int? ?? json['filesize_approx'] as int?,
      formatNote: json['format_note']?.toString(),
      formatString: json['format']?.toString() ?? '',
    );
  }

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
    };
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
  final bool isError;
  final String? errorMessage;

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
    this.isError = false,
    this.errorMessage,
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
      filesize: json['filesize'] as int? ?? json['filesize_approx'] as int? ?? json['file_size'] as int? ?? json['size'] as int?,
      extractor: json['extractor']?.toString() ?? json['category']?.toString(),
      formats: parsedFormats,
      isVideo: isVid,
      isPlaylist: isPlaylist,
      isProfile: isProfile,
      itemCount: itemCount,
      galleryIndex: json['galleryIndex'] as int?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      originalUrl: json['webpage_url']?.toString() ?? originalUrl,
    );
  }

  MediaInfo copyWith({String? id, bool? isProfile, String? thumbnail, String? title, int? galleryIndex, int? filesize}) {
    return MediaInfo(
      id: id ?? this.id,
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

  factory MediaInfo.fromMap(Map<String, dynamic> map) {
    return MediaInfo(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      thumbnail: map['thumbnail']?.toString(),
      duration: map['duration'] as int?,
      extractor: map['extractor']?.toString(),
      formats: (map['formats'] as List<dynamic>?)
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
    };
  }
}

class MediaGroup {
  final String originalUrl;
  final List<MediaInfo> items;
  
  const MediaGroup({
    required this.originalUrl,
    required this.items,
  });

  factory MediaGroup.fromMap(Map<String, dynamic> map) {
    return MediaGroup(
      originalUrl: map['originalUrl']?.toString() ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => MediaInfo.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

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
  int get totalFilesize => items.fold<int>(0, (sum, i) => sum + (i.filesize ?? 0));
}
