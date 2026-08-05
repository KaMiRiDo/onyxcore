import 'package:flutter/foundation.dart';

@immutable
class MediaFormat {
  const MediaFormat({
    required this.formatId,
    required this.extension,
    required this.resolution,
    required this.formatString,
    this.videoCodec,
    this.audioCodec,
    this.filesize,
    this.formatNote,
    this.url,
  });

  factory MediaFormat.fromJson(Map<String, dynamic> json) {
    var parsedFilesize = (json['filesize'] as num?)?.toInt() ??
        (json['filesize_approx'] as num?)?.toInt() ??
        (json['file_size'] as num?)?.toInt() ??
        (json['size'] as num?)?.toInt();

    if (parsedFilesize == null) {
      final tbr = (json['tbr'] as num?)?.toDouble() ??
          (((json['vbr'] as num?)?.toDouble() ?? 0) +
              ((json['abr'] as num?)?.toDouble() ?? 0));
      final duration = (json['duration'] as num?)?.toDouble();
      if (tbr > 0 && duration != null && duration > 0) {
        parsedFilesize = ((tbr * 1000 / 8) * duration).round();
      }
    }

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
      filesize: parsedFilesize,
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

  bool get isAudioOnly =>
      videoCodec == 'none' ||
      (videoCodec == null && resolution == 'audio only');

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

DateTime? _parseUploadDate(Map<String, dynamic> json, [int depth = 0]) {
  if (depth > 3) return null;

  if (json['uploadDate'] != null) {
    if (json['uploadDate'] is DateTime) return json['uploadDate'] as DateTime;
    final dt = DateTime.tryParse(json['uploadDate'].toString());
    if (dt != null) return dt;
  }
  for (final key in [
    'timestamp',
    'release_timestamp',
    'taken_at_timestamp',
    'taken_at',
    'created_utc',
    'created',
    'epoch',
    'date_utc',
    'datetime_utc',
    'post_timestamp',
    'published_timestamp',
    'pubdate_timestamp',
    'timestamp_ms',
    'time',
  ]) {
    if (json[key] != null) {
      final ts = num.tryParse(json[key].toString());
      if (ts != null && ts > 0) {
        final ms = ts > 100000000000 ? ts.toInt() : (ts * 1000).toInt();
        return DateTime.fromMillisecondsSinceEpoch(ms);
      }
    }
  }
  for (final key in [
    'upload_date',
    'datetime',
    'date',
    'created_at',
    'post_date',
    'pubdate',
    'published_at',
    'publish_date',
    'published',
    'release_date',
    'date_taken',
    'modified',
    'updated',
  ]) {
    if (json[key] != null) {
      final parsed = _parseDateString(json[key].toString());
      if (parsed != null) return parsed;
    }
  }

  if (depth < 3) {
    for (final entry in json.entries) {
      if (entry.value is Map<String, dynamic>) {
        final res = _parseUploadDate(entry.value as Map<String, dynamic>, depth + 1);
        if (res != null) return res;
      } else if (entry.value is Map) {
        try {
          final map = Map<String, dynamic>.from(entry.value as Map);
          final res = _parseUploadDate(map, depth + 1);
          if (res != null) return res;
        } catch (_) {}
      }
    }
  }
  return null;
}

DateTime? _parseDateString(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  final numTs = num.tryParse(trimmed);
  if (numTs != null && numTs > 100000000) {
    final ms = numTs > 100000000000 ? numTs.toInt() : (numTs * 1000).toInt();
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  if (RegExp(r'^\d{8}$').hasMatch(trimmed)) {
    final y = int.tryParse(trimmed.substring(0, 4));
    final m = int.tryParse(trimmed.substring(4, 6));
    final d = int.tryParse(trimmed.substring(6, 8));
    if (y != null && m != null && d != null) {
      return DateTime(y, m, d);
    }
  }

  if (RegExp(r'^\d{4}:\d{2}:\d{2}').hasMatch(trimmed)) {
    final formatted = trimmed.replaceRange(4, 5, '-').replaceRange(7, 8, '-');
    final dt = DateTime.tryParse(formatted);
    if (dt != null) return dt;
  }

  final isoDt = DateTime.tryParse(trimmed);
  if (isoDt != null) return isoDt;

  final twitterMatch = RegExp(
    r'^[A-Za-z]{3}\s+([A-Za-z]{3})\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})\s*(?:([+-]\d{4})\s*)?(\d{4})$',
  ).firstMatch(trimmed);
  if (twitterMatch != null) {
    const months = {
      'Jan': 1,
      'Feb': 2,
      'Mar': 3,
      'Apr': 4,
      'May': 5,
      'Jun': 6,
      'Jul': 7,
      'Aug': 8,
      'Sep': 9,
      'Oct': 10,
      'Nov': 11,
      'Dec': 12,
    };
    final monthStr = twitterMatch.group(1);
    final month = months[monthStr];
    final day = int.tryParse(twitterMatch.group(2) ?? '');
    final hour = int.tryParse(twitterMatch.group(3) ?? '');
    final minute = int.tryParse(twitterMatch.group(4) ?? '');
    final second = int.tryParse(twitterMatch.group(5) ?? '');
    final year = int.tryParse(twitterMatch.group(7) ?? '');

    if (year != null &&
        month != null &&
        day != null &&
        hour != null &&
        minute != null &&
        second != null) {
      return DateTime.utc(year, month, day, hour, minute, second);
    }
  }

  return null;
}

@immutable
class MediaInfo {
  const MediaInfo({
    required this.id,
    required this.title,
    required this.originalUrl,
    this.thumbnail,
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
    this.tag,
    this.tagSortOrder,
    this.uploadDate,
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

    int? itemCount;
    if (isPlaylist && json['playlist_count'] != null) {
      itemCount = json['playlist_count'] as int;
    } else if (isPlaylist && json['entries'] is List) {
      itemCount = (json['entries'] as List).length;
    }

    var parsedTitle = json['title']?.toString().trim() ?? '';
    if (parsedTitle.isEmpty && json['description'] != null) {
      final desc = json['description'].toString().trim();
      if (desc.isNotEmpty) {
        parsedTitle = desc;
      }
    }
    if (parsedTitle.isEmpty && originalUrl.isNotEmpty) {
      try {
        final uri = Uri.parse(originalUrl);
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.isNotEmpty) {
          if (originalUrl.contains('reddit.com')) {
            if (segments.length >= 2 && segments[0] == 'r') {
              if (segments.length >= 5 && segments[2] == 'comments') {
                final slug = segments[4].replaceAll('_', ' ').replaceAll('-', ' ').trim();
                if (slug.isNotEmpty) {
                  parsedTitle = slug[0].toUpperCase() + slug.substring(1);
                } else {
                  parsedTitle = 'r/${segments[1]} Post';
                }
              } else {
                parsedTitle = 'r/${segments[1]}';
              }
            } else if (segments.length >= 2 && segments[0] == 'user') {
              parsedTitle = 'u/${segments[1]}';
            } else {
              parsedTitle = segments.first;
            }
          } else {
            parsedTitle = segments.first;
            if (originalUrl.contains('instagram.com') ||
                originalUrl.contains('x.com') ||
                originalUrl.contains('twitter.com')) {
              parsedTitle = '@$parsedTitle';
            }
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
              ? ((json['thumbnails'] as List).last as Map<String, dynamic>)['url']?.toString()
              : null),
      duration: (json['duration'] as num?)?.toInt(),
      filesize: () {
        var size = (json['filesize'] as num?)?.toInt() ??
            (json['filesize_approx'] as num?)?.toInt() ??
            (json['file_size'] as num?)?.toInt() ??
            (json['size'] as num?)?.toInt();

        if (size == null && json['requested_formats'] is List) {
          final rf = json['requested_formats'] as List;
          var sum = 0;
          var hasAny = false;
          for (final f in rf) {
            if (f is Map<String, dynamic>) {
              final s = (f['filesize'] as num?)?.toInt() ??
                  (f['filesize_approx'] as num?)?.toInt() ??
                  (f['file_size'] as num?)?.toInt();
              if (s != null && s > 0) {
                sum += s;
                hasAny = true;
              }
            }
          }
          if (hasAny) size = sum;
        }

        if (size == null && json['requested_downloads'] is List) {
          final rd = json['requested_downloads'] as List;
          var sum = 0;
          var hasAny = false;
          for (final d in rd) {
            if (d is Map<String, dynamic>) {
              final s = (d['filesize'] as num?)?.toInt() ??
                  (d['filesize_approx'] as num?)?.toInt() ??
                  (d['file_size'] as num?)?.toInt();
              if (s != null && s > 0) {
                sum += s;
                hasAny = true;
              }
            }
          }
          if (hasAny) size = sum;
        }

        if (size == null) {
          final tbr = (json['tbr'] as num?)?.toDouble();
          final dur = (json['duration'] as num?)?.toDouble();
          if (tbr != null && tbr > 0 && dur != null && dur > 0) {
            size = ((tbr * 1000 / 8) * dur).round();
          }
        }

        if (size == null && parsedFormats.isNotEmpty) {
          for (final f in parsedFormats) {
            if (f.filesize != null && f.filesize! > 0) {
              size = f.filesize;
              break;
            }
          }
        }

        return size;
      }(),
      extractor: json['extractor']?.toString() ?? json['category']?.toString(),
      engineId: json['engineId']?.toString(),
      formats: parsedFormats,
      isVideo: isVid,
      isPlaylist: isPlaylist,
      itemCount: itemCount,
      galleryIndex: json['galleryIndex'] as int? ??
          json['playlist_index'] as int? ??
          (json['num'] is int
              ? json['num'] as int
              : int.tryParse(json['num']?.toString() ?? '')),
      width: json['width'] as int?,
      height: json['height'] as int?,
      originalUrl: originalUrl.isNotEmpty
          ? originalUrl
          : (json['webpage_url']?.toString() ?? ''),
      directUrl: json['url']?.toString(),
      webpageUrl: json['webpage_url']?.toString(),
      isLive: json['is_live'] == true,
      tag: json['tag']?.toString(),
      tagSortOrder: json['tagSortOrder']?.toString(),
      uploadDate: _parseUploadDate(json),
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
      tag: map['tag']?.toString(),
      tagSortOrder: map['tagSortOrder']?.toString(),
      uploadDate: map['uploadDate'] != null
          ? DateTime.tryParse(map['uploadDate'].toString())
          : null,
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
  final String? tag;
  final String? tagSortOrder;
  final DateTime? uploadDate;

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
    String? tag,
    String? tagSortOrder,
    bool clearTag = false,
    DateTime? uploadDate,
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
      tag: clearTag ? null : (tag ?? this.tag),
      tagSortOrder: clearTag ? null : (tagSortOrder ?? this.tagSortOrder),
      uploadDate: uploadDate ?? this.uploadDate,
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
      if (tag != null) 'tag': tag,
      if (tagSortOrder != null) 'tagSortOrder': tagSortOrder,
      if (uploadDate != null) 'uploadDate': uploadDate!.toIso8601String(),
    };
  }
}

@immutable
class MediaGroup {
  const MediaGroup({
    required this.originalUrl,
    required this.items,
    this.tag,
    this.tagSortOrder,
  });

  factory MediaGroup.fromMap(Map<String, dynamic> map) {
    return MediaGroup(
      originalUrl: map['originalUrl']?.toString() ?? '',
      items:
          (map['items'] as List<dynamic>?)
              ?.map((e) => MediaInfo.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      tag: map['tag']?.toString(),
      tagSortOrder: map['tagSortOrder']?.toString(),
    );
  }
  final String originalUrl;
  final List<MediaInfo> items;
  final String? tag;
  final String? tagSortOrder;

  MediaGroup copyWith({
    String? originalUrl,
    List<MediaInfo>? items,
    String? tag,
    String? tagSortOrder,
    bool clearTag = false,
  }) {
    return MediaGroup(
      originalUrl: originalUrl ?? this.originalUrl,
      items: items ?? this.items,
      tag: clearTag ? null : (tag ?? this.tag),
      tagSortOrder: clearTag ? null : (tagSortOrder ?? this.tagSortOrder),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'originalUrl': originalUrl,
      'items': items.map((e) => e.toMap()).toList(),
      if (tag != null) 'tag': tag,
      if (tagSortOrder != null) 'tagSortOrder': tagSortOrder,
    };
  }

  bool get isSingle => items.length <= 1;
  MediaInfo get first => items.first;
  DateTime? get uploadDate {
    for (final item in items) {
      if (item.uploadDate != null) return item.uploadDate;
    }
    return null;
  }

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
      if (item.isError) continue;
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

  bool get isError => items.isNotEmpty && items.every((i) => i.isError);
}
