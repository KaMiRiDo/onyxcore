import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:onyxcore/core/utils/browser_detector.dart';
import 'package:onyxcore/core/utils/process_utils.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/cookie_helper.dart';
import 'package:onyxcore/features/downloader/services/downloader_process_wrapper.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:path/path.dart' as p;

/// Concrete [DownloadEngine] implementation for gallery-dl.
///
/// Handles Instagram, Twitter/X, and Reddit gallery URLs. Uses a streaming
/// JSON state machine to parse gallery-dl's event-based output format.
class GalleryDlEngine extends DownloadEngine {
  @override
  String get id => 'gallery-dl';

  @override
  String get displayName => 'gallery-dl';

  @override
  IconData get icon => Icons.photo_library_rounded;

  @override
  Color get color => Colors.blueAccent;

  @override
  EngineType get engineType => EngineType.cli;

  @override
  String? get binaryPath => p.join(
    Platform.environment['HOME'] ?? '',
    '.local',
    'share',
    'onyxcore',
    'bin',
    'gallery-dl',
  );

  @override
  List<RegExp> get urlPatterns => [
    RegExp(r'instagram\.com'),
    RegExp(r'twitter\.com'),
    RegExp(r'x\.com'),
    RegExp(r'reddit\.com'),
    RegExp(r'facebook\.com'),
    RegExp(r'threads\.net'),
  ];

  @override
  int get priority => 10; // Higher than yt-dlp — wins for matching URLs

  @override
  bool get isInstalled => binaryPath != null && File(binaryPath!).existsSync();

  @override
  EngineUpdateInfo? get updateInfo => const EngineUpdateInfo(
    apiUrl: 'https://codeberg.org/api/v1/repos/mikf/gallery-dl/releases/latest',
    assetName: 'gallery-dl.bin',
  );

  @override
  Future<String?> getInstalledVersion() async {
    if (!isInstalled) return null;
    try {
      final res = await Process.run(binaryPath!, ['--version']);
      if (res.exitCode == 0) {
        return (res.stdout as String).trim();
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<String?> getLatestVersion() async {
    try {
      final res = await Process.run('curl', [
        '-s',
        'https://codeberg.org/api/v1/repos/mikf/gallery-dl/releases/latest',
      ]);
      if (res.exitCode == 0) {
        final json = jsonDecode(res.stdout as String);
        return json['tag_name']?.toString().replaceFirst('v', '');
      }
    } catch (_) {}
    return null;
  }

  /// Detect if the URL is a social profile (not a single post).
  @visibleForTesting
  bool isSocialProfile(String url) {
    if (url.contains('instagram.com')) {
      return !url.contains('/p/') &&
          !url.contains('/reel/') &&
          !url.contains('/tv/');
    }
    if (url.contains('twitter.com') || url.contains('x.com')) {
      return !url.contains('/status/');
    }
    if (url.contains('reddit.com')) {
      return !url.contains('/comments/') && !url.contains('/gallery/');
    }
    if (url.contains('facebook.com')) {
      return !url.contains('/posts/') &&
          !url.contains('/videos/') &&
          !url.contains('/watch/');
    }
    if (url.contains('threads.net')) {
      return !url.contains('/post/');
    }
    if (url.contains('pinterest.com')) {
      return !url.contains('/pin/');
    }
    if (url.contains('tumblr.com')) {
      return !url.contains('/post/');
    }
    if (url.contains('tiktok.com')) {
      return !url.contains('/video/');
    }
    if (url.contains('artstation.com')) {
      return !url.contains('/artwork/');
    }
    if (url.contains('deviantart.com')) {
      return !url.contains('/art/');
    }
    return false;
  }

  @override
  Future<List<MediaInfo>> fetchMetadata({
    required String url,
    String? browser,
    bool fetchDeep = false,
    bool isPlaylist = false,
    void Function(MediaInfo info)? onProgress,
    void Function(int pid)? onProcessStarted,
  }) async {
    if ((url.contains('twitter.com') || url.contains('x.com')) &&
        isSocialProfile(url)) {
      final uri = Uri.tryParse(url);
      if (uri != null &&
          uri.pathSegments.isNotEmpty &&
          uri.pathSegments.length == 1) {
        url = url.endsWith('/') ? '${url}media' : '$url/media';
      }
    }

    final isSocialProfileVar = isSocialProfile(url);

    var actualBrowser = browser;
    if (actualBrowser == null) {
      final defaultBrowser = await BrowserDetector.getDefaultBrowser();
      if (defaultBrowser != null) actualBrowser = defaultBrowser;
    }

    // Try Instagram API shortcut for profiles (only if not deep fetching)
    if (url.contains('instagram.com') && isSocialProfileVar && !fetchDeep) {
      try {
        final profileInfos = await fetchInstagramProfile(
          url,
          actualBrowser,
          fetchDeep: fetchDeep,
        );
        if (profileInfos != null) return profileInfos;
      } catch (e) {
        debugPrint('Instagram API fallback failed: $e, trying gallery-dl...');
      }
    }

    final args = <String>[];

    if (actualBrowser != null && actualBrowser.toLowerCase() != 'none') {
      args.addAll(['--cookies-from-browser', actualBrowser]);
    }

    if (url.contains('instagram.com')) {
      args.addAll(['--sleep', '3-5']);
    }

    args.add('-q'); // Suppress logs in stdout to prevent JSON parser corruption

    if (isSocialProfileVar) {
      if (fetchDeep) {
        args.addAll(['-J', url]);
      } else {
        args.addAll(['-J', '--range', '1-1', url]);
      }
    } else {
      args.addAll(['-J', url]);
    }

    final process = await Process.start(
      binaryPath!,
      args,
      environment: {'PYTHONUNBUFFERED': '1'},
    );
    if (onProcessStarted != null) {
      onProcessStarted(process.pid);
    }

    Future<List<MediaInfo>> processOutput() async {
      final parsedInfos = <MediaInfo>[];
      final extractionErrors = <String>[];

      final stderrBuffer = StringBuffer();
      final hydrationLogsBuffer = StringBuffer();
      process.stderr.transform(utf8.decoder).listen((data) {
        stderrBuffer.write(data);
        MediaDownloaderBackend.activeLogs[url] = stderrBuffer.toString();
      });

      if (onProgress != null) {
        onProgress(
          MediaInfo(
            id: 'hydration_loading',
            title: 'Fetching...',
            originalUrl: url,
            fetchLogs: 'Waiting for output...',
            isVideo: false,
          ),
        );
      }

      // Streaming JSON state machine for gallery-dl output
      var braceCount = 0;
      var bracketCount = 0;
      var inString = false;
      var escape = false;

      var isOuterArray = false;
      var initialized = false;
      var tracking = false;
      final currentBlock = StringBuffer();

      await for (final chunk in process.stdout.transform(utf8.decoder)) {
        final codeUnits = chunk.codeUnits;
        for (var i = 0; i < codeUnits.length; i++) {
          final c = codeUnits[i];

          if (!initialized) {
            // 32 = space, 9 = tab, 10 = LF, 13 = CR
            if (c == 32 || c == 9 || c == 10 || c == 13) continue;
            if (c == 91) {
              // '['
              isOuterArray = true;
              bracketCount = 1;
              initialized = true;
              continue; // skip the outer bracket
            } else {
              initialized = true; // not an outer array
            }
          }

          if (escape) {
            escape = false;
            if (tracking) currentBlock.writeCharCode(c);
            continue;
          }
          if (c == 92) {
            // '\'
            escape = true;
            if (tracking) currentBlock.writeCharCode(c);
            continue;
          }
          if (c == 34) {
            // '"'
            inString = !inString;
            if (tracking) currentBlock.writeCharCode(c);
            continue;
          }
          if (!inString) {
            if (c == 123 || c == 91) {
              // '{' or '['
              if (!tracking) {
                if ((isOuterArray && bracketCount == 1 && braceCount == 0) ||
                    (!isOuterArray && bracketCount == 0 && braceCount == 0)) {
                  tracking = true;
                  currentBlock.clear();
                }
              }
              if (c == 123) braceCount++;
              if (c == 91) bracketCount++;
            } else if (c == 125 || c == 93) {
              // '}' or ']'
              if (c == 125) braceCount--;
              if (c == 93) bracketCount--;
            }
          }

          if (tracking) {
            currentBlock.writeCharCode(c);
            var blockComplete = false;
            if (isOuterArray) {
              blockComplete =
                  braceCount == 0 && bracketCount == 1 && !inString;
            } else {
              blockComplete =
                  braceCount == 0 && bracketCount == 0 && !inString;
            }

            if (blockComplete) {
              final blockStr = currentBlock.toString();
              tracking = false;
              currentBlock.clear();

              final infos = <MediaInfo>[];
              try {
                infos.addAll(
                  await parseGalleryDlJsonBlock(
                    blockStr,
                    url,
                    isSocialProfileVar,
                    browser,
                    parsedInfos.length,
                    fetchDeep,
                  ),
                );
              } catch (e) {
                if (e is Exception &&
                    e.toString().contains('Extraction Error:')) {
                  extractionErrors.add(
                    e.toString().replaceAll(
                      'Exception: Extraction Error: ',
                      '',
                    ),
                  );
                }
              }

              for (var info in infos) {
                final fileUrlFormat = info.formats
                    .where((f) => f.formatId == 'original')
                    .firstOrNull;
                final currentFileUrl = fileUrlFormat?.formatString;

                var isDuplicate = false;
                if (currentFileUrl != null) {
                  for (final existing in parsedInfos) {
                    final existingUrlFormat = existing.formats
                        .where((f) => f.formatId == 'original')
                        .firstOrNull;
                    if (existingUrlFormat?.formatString == currentFileUrl) {
                      isDuplicate = true;
                      break;
                    }
                  }
                }

                if (isDuplicate) continue;

                if (!info.isProfile) {
                  if (parsedInfos.isNotEmpty || infos.length > 1) {
                    info = info.copyWith(
                      title: '${info.title} (${parsedInfos.length + 1})',
                    );
                  }
                  info = info.copyWith(
                    id: '${info.id}_${parsedInfos.length + 1}',
                  );
                }

                hydrationLogsBuffer.writeln(
                  'Successfully fetched metadata for: "${info.title}"\n',
                );
                var currentLogs = hydrationLogsBuffer.toString();
                if (stderrBuffer.isNotEmpty) {
                  final formattedErrors = stderrBuffer
                      .toString()
                      .trim()
                      .split('\n')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .join('\n\n');
                  currentLogs +=
                      '\n\n--- gallery-dl Raw Logs ---\n$formattedErrors';
                }
                info = info.copyWith(fetchLogs: currentLogs.trim());

                parsedInfos.add(info);
                onProgress?.call(info);
              }
            }
          }
        }
      }

      final exitCode = await process.exitCode;
      if (exitCode != 0 && parsedInfos.isEmpty) {
        final stderrStr = stderrBuffer.toString();
        if (stderrStr.trim().isNotEmpty) {
          throw Exception('Failed to fetch metadata: $stderrStr');
        }
      }

      if (parsedInfos.isEmpty) {
        if (extractionErrors.isNotEmpty) {
          throw Exception(extractionErrors.first);
        }
        throw Exception('Failed to parse gallery-dl JSON blocks');
      }

      if (!fetchDeep && isSocialProfileVar) {
        parsedInfos.removeWhere((info) => !info.isProfile);
      }

      var combinedLogs = hydrationLogsBuffer.toString();
      if (stderrBuffer.isNotEmpty) {
        final formattedErrors = stderrBuffer
            .toString()
            .trim()
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .join('\n\n');
        combinedLogs += '\n\n--- gallery-dl Raw Logs ---\n$formattedErrors';
      }
      return parsedInfos
          .map((i) => i.copyWith(fetchLogs: combinedLogs.trim()))
          .toList();
    }

    try {
      final timeoutDuration = fetchDeep
          ? const Duration(minutes: 30)
          : const Duration(minutes: 3);
      return await processOutput().timeout(timeoutDuration);
    } on TimeoutException {
      ProcessUtils.killProcessTreeSync(process.pid);
      throw PartialMetadataException(
        partialInfos: [],
        message: 'Hydration timed out after ${fetchDeep ? 30 : 3} minutes.',
      );
    }
  }

  @override
  Future<Process> startDownload({
    required String url,
    required String destination,
    String? title,
    MediaFormat? format,
    bool audioOnly = false,
    bool mute = false,
    int? galleryIndex,
    bool isPlaylist = false,
    bool isProfile = false,
    String? browser,
    bool isZip = false,
    String? filterType,
    int? totalItems,
    String? singleItemId,
    String? directUrl,
  }) async {
    if ((url.contains('twitter.com') || url.contains('x.com')) &&
        isSocialProfile(url)) {
      final uri = Uri.tryParse(url);
      if (uri != null &&
          uri.pathSegments.isNotEmpty &&
          uri.pathSegments.length == 1) {
        url = url.endsWith('/') ? '${url}media' : '$url/media';
      }
    }

    final args = <String>[];

    var actualBrowser = browser;
    if (actualBrowser == null) {
      final defaultBrowser = await BrowserDetector.getDefaultBrowser();
      if (defaultBrowser != null) actualBrowser = defaultBrowser;
    }

    if (actualBrowser != null && actualBrowser.toLowerCase() != 'none') {
      args.addAll(['--cookies-from-browser', actualBrowser]);
    }

    if (url.contains('instagram.com')) {
      args.addAll(['--sleep', '3-5']);
    }

    args.addAll(['-D', destination]);
    if (title != null) {
      final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|\{\}]'), '_');
      if (galleryIndex != null) {
        args.addAll(['--filename', '$safeTitle.{extension}']);
        args.addAll(['--range', galleryIndex.toString()]);
      } else if (!isProfile) {
        if (totalItems == 1) {
          args.addAll(['--filename', '$safeTitle.{extension}']);
        } else {
          args.addAll(['--filename', '${safeTitle}_{num}.{extension}']);
        }
      }
      args.addAll(['-o', 'directory=[]']);
    } else {
      // All items will download directly to the base profile folder as requested
      args.addAll(['-o', 'directory=[]']);
    }

    if (filterType == 'images') {
      args.addAll([
        '--filter',
        "extension not in ('mp4', 'webm', 'mov', 'mkv')",
      ]);
    } else if (filterType == 'videos') {
      args.addAll(['--filter', "extension in ('mp4', 'webm', 'mov', 'mkv')"]);
    }

    args.add(url);

    return Process.start(
      binaryPath!,
      args,
      environment: {'PYTHONUNBUFFERED': '1'},
    );
  }

  // ——— Private helpers ———

  @visibleForTesting
  Future<List<MediaInfo>?> fetchInstagramProfile(
    String url,
    String? browser, {
    bool fetchDeep = false,
  }) async {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) {
      throw Exception('Could not extract username from URL');
    }
    final username = segments.first;

    final cookies = await CookieHelper.extractCookies(browser);

    try {
      final client = HttpClient();
      try {
        client.connectionTimeout = const Duration(seconds: 8);
        final req = await client.getUrl(
          Uri.parse(
            'https://www.instagram.com/api/v1/users/web_profile_info/?username=$username',
          ),
        );
        if (cookies != null && cookies.isNotEmpty) {
          req.headers.set('Cookie', cookies);
        }
        req.headers.set(
          'User-Agent',
          'Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0',
        );
        req.headers.set('X-IG-App-ID', '936619743392459');
        req.headers.set('X-Requested-With', 'XMLHttpRequest');
        req.headers.set('Referer', 'https://www.instagram.com/');

        final res = await req.close();
        if (res.statusCode != 200) {
          return null;
        }

        final output = await res.transform(utf8.decoder).join();
        final data = jsonDecode(output) as Map<String, dynamic>;
        final user = (data['data'] as Map?)?['user'] as Map<String, dynamic>? ?? {};

        if (user.isEmpty) {
          return null;
        }

        final fullName = user['full_name']?.toString() ?? '';
        final uname = user['username']?.toString() ?? username;
        final title = fullName.isNotEmpty ? '$fullName (@$uname)' : '@$uname';

        final profileInfo = MediaInfo(
          id: 'profile_${url.hashCode}',
          title: title,
          thumbnail:
              user['profile_pic_url_hd']?.toString() ??
              user['profile_pic_url']?.toString(),
          extractor: 'instagram',
          isProfile: true,
          itemCount:
              (user['edge_owner_to_timeline_media'] as Map?)?['count'] as int? ?? 0,
          originalUrl: url,
        );

        final results = <MediaInfo>[profileInfo];

        if (fetchDeep) {
          final edges =
              (user['edge_owner_to_timeline_media'] as Map?)?['edges']
                  as List<dynamic>? ??
              [];
          for (final edge in edges) {
            final node = edge['node'] as Map<String, dynamic>?;
            if (node == null) continue;

            final isVideo = node['is_video'] == true;
            final shortcode = node['shortcode']?.toString() ?? '';
            final itemUrl = shortcode.isNotEmpty
                ? 'https://www.instagram.com/p/$shortcode/'
                : url;

            var itemTitle = title; // default to profile title
            final captionEdges =
                (node['edge_media_to_caption'] as Map?)?['edges'] as List<dynamic>? ?? [];
            if (captionEdges.isNotEmpty) {
              itemTitle =
                  ((captionEdges.first as Map?)?['node'] as Map?)?['text']?.toString() ?? itemTitle;
            }

            results.add(
              MediaInfo(
                id: node['id']?.toString() ?? shortcode,
                title: itemTitle,
                thumbnail:
                    node['display_url']?.toString() ??
                    node['thumbnail_src']?.toString(),
                extractor: 'instagram',
                isVideo: isVideo,
                originalUrl: itemUrl,
                directUrl:
                    node['video_url']?.toString() ??
                    node['display_url']?.toString(),
                width: (node['dimensions'] as Map?)?['width'] as int?,
                height: (node['dimensions'] as Map?)?['height'] as int?,
                duration: node['video_duration'] != null
                    ? (node['video_duration'] as num).toInt()
                    : null,
              ),
            );
          }
        }

        return results;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Insta Profile Error: $e');
      return null;
    }
  }

  @visibleForTesting
  Future<List<MediaInfo>> parseGalleryDlJsonBlock(
    String block,
    String url,
    bool isSocialProfile,
    String? browser,
    int existingCount,
    bool fetchDeep,
  ) async {
    final parsedInfos = <MediaInfo>[];
    try {
      final json = jsonDecode(block);

      if (json is List) {
        final isListOfEvents = json.isNotEmpty && json.first is List;
        final events = isListOfEvents ? json : [json];

        final sharedMeta = <String, dynamic>{};
        var fileCount = 0;

        for (final event in events) {
          if (event is List && event.isNotEmpty) {
            final eventType = event[0];

            final metaIndex = event.indexWhere((e) => e is Map);
            if (metaIndex != -1) {
              sharedMeta.addAll(
                Map<String, dynamic>.from(event[metaIndex] as Map),
              );
            }

            if (eventType == 3) {
              fileCount++;
              String? fileUrl;
              if (sharedMeta['video_versions'] is List &&
                  (sharedMeta['video_versions'] as List).isNotEmpty) {
                final versions = List<Map<dynamic, dynamic>>.from(
                  (sharedMeta['video_versions'] as List).whereType<Map<dynamic, dynamic>>(),
                );
                if (versions.isNotEmpty) {
                  versions.sort((a, b) {
                    final widthA =
                        int.tryParse(a['width']?.toString() ?? '0') ?? 0;
                    final heightA =
                        int.tryParse(a['height']?.toString() ?? '0') ?? 0;
                    final widthB =
                        int.tryParse(b['width']?.toString() ?? '0') ?? 0;
                    final heightB =
                        int.tryParse(b['height']?.toString() ?? '0') ?? 0;
                    return (widthB * heightB).compareTo(widthA * heightA);
                  });
                  final highest = versions.first;
                  if (highest['url'] != null) {
                    fileUrl = highest['url'].toString();
                  }
                }
              }

              // Try to extract Reddit fallback_url for videos to avoid m3u8/dash playlists
              final mediaMap = sharedMeta['media'] as Map?;
              final redditVideoMediaMap = mediaMap?['reddit_video'] as Map?;
              final secureMediaMap = sharedMeta['secure_media'] as Map?;
              final redditVideoSecureMediaMap = secureMediaMap?['reddit_video'] as Map?;
              final previewMap = sharedMeta['preview'] as Map?;
              final redditVideoPreviewMap = previewMap?['reddit_video_preview'] as Map?;

              if (redditVideoMediaMap?['fallback_url'] != null) {
                fileUrl = redditVideoMediaMap!['fallback_url'].toString();
              } else if (redditVideoSecureMediaMap?['fallback_url'] != null) {
                fileUrl = redditVideoSecureMediaMap!['fallback_url'].toString();
              } else if (redditVideoPreviewMap?['fallback_url'] != null) {
                fileUrl = redditVideoPreviewMap!['fallback_url'].toString();
              }

              if (fileUrl == null &&
                  sharedMeta['video_url'] != null &&
                  (sharedMeta['video_url'].toString().startsWith('http') ||
                      sharedMeta['video_url'].toString().startsWith('ytdl:'))) {
                fileUrl = sharedMeta['video_url'] as String;
              } else if (fileUrl == null) {
                final urlIndex = event.indexWhere(
                  (e) =>
                      e is String &&
                      (e.startsWith('http') || e.startsWith('ytdl:')),
                );
                if (urlIndex != -1) {
                  fileUrl = event[urlIndex] as String;
                }
              }

              if (fileUrl != null && fileUrl.startsWith('ytdl:')) {
                fileUrl = fileUrl.replaceFirst('ytdl:', '');
              }

              if (fileUrl == null &&
                  sharedMeta['url'] != null &&
                  sharedMeta['url'].toString().startsWith('http')) {
                fileUrl = sharedMeta['url'] as String;
              }

              String? title;
              if (sharedMeta['subreddit'] != null) {
                final sub = sharedMeta['subreddit'].toString();
                final author = sharedMeta['author']?.toString() ?? 'unknown';
                final postTitle =
                    sharedMeta['title']?.toString() ??
                    sharedMeta['description']?.toString() ??
                    'Post';
                title = 'r/$sub - $postTitle (@$author)';
              } else {
                title =
                    sharedMeta['title']?.toString() ??
                    sharedMeta['description']?.toString();
              }
              if (title == null || title.isEmpty) title = 'Item';

              String? itemUrl;
              if (sharedMeta['shortcode'] != null) {
                itemUrl =
                    'https://www.instagram.com/p/${sharedMeta['shortcode']}/';
                if (!isSocialProfile && fileCount > 0) {
                  itemUrl += '?img_index=$fileCount';
                }
              } else if (sharedMeta['tweet_id'] != null) {
                final author =
                    (sharedMeta['user'] is Map
                        ? (sharedMeta['user'] as Map)['screen_name']
                        : null) ??
                    (sharedMeta['author'] is Map
                        ? (sharedMeta['author'] as Map)['name']
                        : null) ??
                    sharedMeta['author']?.toString() ??
                    'i';
                itemUrl =
                    'https://x.com/$author/status/${sharedMeta['tweet_id']}';
              } else if (sharedMeta['permalink'] != null &&
                  sharedMeta['permalink'].toString().startsWith('/r/')) {
                itemUrl = 'https://www.reddit.com${sharedMeta['permalink']}';
              } else if (sharedMeta['post_url'] != null) {
                itemUrl = sharedMeta['post_url'].toString();
              }

              var thumb = sharedMeta['thumbnail']?.toString();
              if (thumb != null && !thumb.startsWith('http')) {
                thumb =
                    null; // Ignore invalid thumbnails like "self", "default", "nsfw"
              }
              if (thumb == null && sharedMeta['preview'] is Map) {
                try {
                  final images = (sharedMeta['preview'] as Map)['images'] as List;
                  if (images.isNotEmpty) {
                    thumb = (images.first as Map)['source']['url'].toString().replaceAll(
                      '&amp;',
                      '&',
                    );
                  }
                } catch (_) {}
              }
              thumb ??= sharedMeta['display_url']?.toString();
              if (thumb == null &&
                  fileUrl != null &&
                  !fileUrl.contains('.mp4') &&
                  !fileUrl.contains('.webm') &&
                  !fileUrl.contains('.mkv')) {
                thumb = fileUrl;
              }

              var isVid = false;
              if (sharedMeta['is_video'] == true ||
                  sharedMeta['is_video'] == 'true' ||
                  sharedMeta['video'] == true ||
                  sharedMeta['video'] == 'true' ||
                  sharedMeta['type'] == 'video' ||
                  sharedMeta['vcodec'] != null ||
                  sharedMeta['video_url'] != null ||
                  ((sharedMeta['media'] as Map?)?['reddit_video'] != null) ||
                  ((sharedMeta['preview'] as Map?)?['reddit_video_preview'] != null) ||
                  ((sharedMeta['secure_media'] as Map?)?['reddit_video'] != null)) {
                isVid = true;
              }
              if (fileUrl != null) {
                final ext = fileUrl
                    .split('?')
                    .first
                    .split('.')
                    .last
                    .toLowerCase();
                if ([
                  'mp4',
                  'webm',
                  'mkv',
                  'mov',
                  'avi',
                  'm3u8',
                  'mpd',
                  'gifv',
                  'ts',
                ].contains(ext)) {
                  isVid = true;
                }
                if (fileUrl.contains('v.redd.it')) {
                  isVid = true;
                }
              }

              final parsedJsonInfo = MediaInfo.fromJson(
                sharedMeta,
                originalUrl: url,
              );

              // Determine the canonical originalUrl for grouping:
              // - Instagram carousels: always use the base input `url` (stripped
              //   of query params like ?img_index=N) so all slides share one key.
              //   Per-slide sub-shortcodes can make itemUrl unique per slide,
              //   which was the root cause of each slide becoming a separate tile.
              // - Twitter/X and Reddit: keep itemUrl — tweet_id / permalink are
              //   post-level identifiers, already the same for all items in a
              //   multi-image post, so grouping works without normalisation.
              final String canonicalUrl;
              if (sharedMeta['shortcode'] != null) {
                // Instagram: strip query params (e.g. ?img_index=1) from input url
                final uri = Uri.tryParse(url);
                canonicalUrl = uri != null
                    ? uri.replace(queryParameters: {}).toString()
                    : url;
              } else {
                canonicalUrl = itemUrl ?? url;
              }

              final info = parsedJsonInfo.copyWith(
                isProfile: false,
                thumbnail: thumb,
                title: title,
                galleryIndex: fileCount,
                originalUrl: canonicalUrl,
                webpageUrl: itemUrl ?? parsedJsonInfo.webpageUrl,
                isVideo: isVid || parsedJsonInfo.isVideo,
              );
              if (fileUrl != null) {
                var ext = fileUrl.split('?').first.split('.').last;
                if (ext.contains('/')) {
                  ext = isVid ? 'mp4' : 'jpg'; // fallback extension
                }
                info.formats.add(
                  MediaFormat(
                    formatId: 'original',
                    extension: ext,
                    resolution: 'original',
                    formatString: fileUrl,
                  ),
                );
                parsedInfos.add(info);
              }
            }
          }
        }

        final hasProfileData =
            sharedMeta.containsKey('user') ||
            sharedMeta.containsKey('username') ||
            (sharedMeta['subcategory'] == 'user' &&
                sharedMeta['category'] == 'instagram');
        if (isSocialProfile &&
            sharedMeta.isNotEmpty &&
            existingCount == 0 &&
            (fileCount > 0 || hasProfileData)) {
          var title = '';
          String? profilePic;
          final userMeta = sharedMeta['user'] as Map<String, dynamic>?;
          if (userMeta != null) {
            final fn =
                userMeta['full_name']?.toString() ??
                userMeta['nick']?.toString() ??
                '';
            final un =
                userMeta['username']?.toString() ??
                userMeta['name']?.toString() ??
                '';
            if (un.isNotEmpty) {
              title = fn.isNotEmpty ? '$fn (@$un)' : '@$un';
            }
            profilePic =
                userMeta['profile_pic_url_hd']?.toString() ??
                userMeta['profile_pic_url']?.toString() ??
                userMeta['profile_image']?.toString();
          }
          if (title.isEmpty) {
            if (url.contains('reddit.com/user/')) {
              final uri = Uri.tryParse(url);
              if (uri != null &&
                  uri.pathSegments.length >= 2 &&
                  uri.pathSegments[0] == 'user') {
                title = '@${uri.pathSegments[1]}';
              }
            } else if (url.contains('reddit.com/r/')) {
              final uri = Uri.tryParse(url);
              if (uri != null &&
                  uri.pathSegments.length >= 2 &&
                  uri.pathSegments[0] == 'r') {
                title = 'r/${uri.pathSegments[1]}';
              }
            } else if (url.contains('instagram.com/')) {
              final uri = Uri.tryParse(url);
              if (uri != null && uri.pathSegments.isNotEmpty) {
                title = '@${uri.pathSegments.first}';
              }
            }
            if (title.isEmpty && sharedMeta['author'] != null) {
              final author = sharedMeta['author'];
              if (author is Map) {
                final fn =
                    author['full_name']?.toString() ??
                    author['nick']?.toString() ??
                    '';
                final un =
                    author['username']?.toString() ??
                    author['name']?.toString() ??
                    '';
                if (un.isNotEmpty) {
                  title = fn.isNotEmpty ? '$fn (@$un)' : '@$un';
                }
                profilePic ??=
                    author['profile_pic_url_hd']?.toString() ??
                    author['profile_pic_url']?.toString() ??
                    author['profile_image']?.toString();
              } else {
                title = '@$author';
              }
            }
            if (title.isEmpty) {
              title =
                  sharedMeta['fullname']?.toString() ??
                  sharedMeta['title']?.toString() ??
                  sharedMeta['description']?.toString() ??
                  'Item';
            }
          }
          if (profilePic == null || profilePic.isEmpty) {
            profilePic =
                sharedMeta['thumbnail']?.toString() ??
                sharedMeta['display_url']?.toString();
          }

          final info = MediaInfo.fromJson(sharedMeta, originalUrl: url)
              .copyWith(
                isProfile: true,
                thumbnail: profilePic,
                title: title,
                id: 'profile_${url.hashCode}',
              );
          if (!fetchDeep) {
            return [info];
          }
          parsedInfos.insert(0, info);
        } else if (fileCount == 0 && sharedMeta.isNotEmpty) {
          if (sharedMeta.containsKey('error')) {
            throw Exception(
              'Extraction Error: ${sharedMeta['message'] ?? sharedMeta['error']}',
            );
          }
          // Structural parent node — intentionally not added to parsedInfos
        }
      }
    } catch (e) {
      debugPrint('Error parsing block: $e');
      if (e is Exception && e.toString().contains('Extraction Error:')) {
        rethrow;
      }
    }

    // Size probing for parsed items
    for (var i = 0; i < parsedInfos.length; i++) {
      var info = parsedInfos[i];
      final fileUrlFormat = info.formats
          .where((f) => f.formatId == 'original')
          .firstOrNull;
      final urlForSize = fileUrlFormat?.formatString ?? info.thumbnail;

      var needsSize = info.filesize == null;
      if (info.isVideo &&
          info.filesize != null &&
          info.filesize! < 1024 * 1024 &&
          (info.extractor?.contains('instagram') ?? false)) {
        needsSize = true;
        info = info.copyWith();
        parsedInfos[i] = info;
      }

      if (needsSize && urlForSize != null && urlForSize.startsWith('http')) {
        final isInstagram =
            (info.extractor?.contains('instagram') ?? false) ||
            urlForSize.contains('cdninstagram.com') ||
            urlForSize.contains('fbcdn.net');

        if (isInstagram && browser != null && browser != 'None') {
          try {
            final cookies = await CookieHelper.extractCookies(browser);

            final client = HttpClient();
            try {
              client.connectionTimeout = const Duration(seconds: 5);
              final req = await client.headUrl(Uri.parse(urlForSize));
              req.headers.set(
                'User-Agent',
                'Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0',
              );
              req.headers.set('Referer', 'https://www.instagram.com/');
              if (cookies != null && cookies.isNotEmpty) {
                req.headers.set('Cookie', cookies);
              }

              final res = await req.close();
              if (res.contentLength > 0 && res.contentLength > 500 * 1024) {
                parsedInfos[i] = info.copyWith(filesize: res.contentLength);
              } else {
                final client2 = HttpClient();
                try {
                  client2.connectionTimeout = const Duration(seconds: 5);
                  final req2 = await client2.getUrl(Uri.parse(urlForSize));
                  req2.headers.set(
                    'User-Agent',
                    'Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0',
                  );
                  req2.headers.set('Referer', 'https://www.instagram.com/');
                  req2.headers.set('Range', 'bytes=0-0');
                  if (cookies != null && cookies.isNotEmpty) {
                    req2.headers.set('Cookie', cookies);
                  }

                  final res2 = await req2.close();
                  final contentRange = res2.headers.value('content-range');
                  if (contentRange != null && contentRange.contains('/')) {
                    final totalStr = contentRange.split('/').last.trim();
                    final total = int.tryParse(totalStr);
                    if (total != null && total > 500 * 1024) {
                      parsedInfos[i] = info.copyWith(filesize: total);
                    }
                  }
                } finally {
                  client2.close();
                }
              }
            } finally {
              client.close();
            }
          } catch (e) {
            debugPrint('[SizeProbe] Exception: $e');
          }
        } else {
          try {
            final client = HttpClient();
            try {
              client.connectionTimeout = const Duration(seconds: 3);
              final req = await client.headUrl(Uri.parse(urlForSize));
              final res = await req.close();
              if (res.contentLength > 0) {
                parsedInfos[i] = info.copyWith(filesize: res.contentLength);
              }
            } finally {
              client.close();
            }
          } catch (_) {}
        }
      }
    }
    return parsedInfos;
  }
}
