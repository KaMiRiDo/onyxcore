import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:onyxcore/core/utils/browser_detector.dart';
import 'package:onyxcore/core/utils/process_utils.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:onyxcore/features/downloader/services/cookie_helper.dart';
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
    RegExp(r'reddit\.com/gallery'),
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

  /// Detect if the URL is a social profile (not a single post).
  bool _isSocialProfile(String url) {
    return !url.contains('/p/') &&
        !url.contains('/reel/') &&
        !url.contains('/status/');
  }

  @override
  Future<List<MediaInfo>> fetchMetadata({
    required String url,
    String? browser,
    bool fetchDeep = false,
    void Function(MediaInfo info)? onProgress,
    void Function(int pid)? onProcessStarted,
  }) async {
    final isSocialProfile = _isSocialProfile(url);

    // Try Instagram API shortcut for profiles (non-deep fetch)
    if (url.contains('instagram.com') && isSocialProfile && !fetchDeep) {
      try {
        final profileInfos = await _fetchInstagramProfile(url, browser);
        if (profileInfos != null) return profileInfos;
      } catch (e) {
        debugPrint('Instagram API fallback failed: $e, trying gallery-dl...');
      }
    }

    final args = <String>[];

    String? actualBrowser = browser;
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

    args.add('-q'); // Suppress logs in stdout to prevent JSON parser corruption
    if (isSocialProfile) {
      if (fetchDeep) {
        args.addAll(['-J', url]);
      } else {
        args.addAll(['-J', '--range', '1-1', url]);
      }
    } else {
      args.addAll(['-j', url]);
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

      // Streaming JSON state machine for gallery-dl output
      int braceCount = 0;
      int bracketCount = 0;
      bool inString = false;
      bool escape = false;

      bool isOuterArray = false;
      bool initialized = false;
      bool tracking = false;
      StringBuffer currentBlock = StringBuffer();

      await for (var chunk in process.stdout.transform(utf8.decoder)) {
        for (int i = 0; i < chunk.length; i++) {
          final c = chunk[i];

          if (!initialized) {
            if (c.trim().isEmpty) continue;
            if (c == '[') {
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
            if (tracking) currentBlock.write(c);
            continue;
          }
          if (c == '\\') {
            escape = true;
            if (tracking) currentBlock.write(c);
            continue;
          }
          if (c == '"') {
            inString = !inString;
            if (tracking) currentBlock.write(c);
            continue;
          }
          if (!inString) {
            if (c == '{' || c == '[') {
              if (!tracking) {
                if ((isOuterArray && bracketCount == 1 && braceCount == 0) ||
                    (!isOuterArray && bracketCount == 0 && braceCount == 0)) {
                  tracking = true;
                  currentBlock.clear();
                }
              }
              if (c == '{') braceCount++;
              if (c == '[') bracketCount++;
            } else if (c == '}' || c == ']') {
              if (c == '}') braceCount--;
              if (c == ']') bracketCount--;
            }
          }

          if (tracking) {
            currentBlock.write(c);
            bool blockComplete = false;
            if (isOuterArray) {
              blockComplete =
                  (braceCount == 0 && bracketCount == 1 && !inString);
            } else {
              blockComplete =
                  (braceCount == 0 && bracketCount == 0 && !inString);
            }

            if (blockComplete) {
              final blockStr = currentBlock.toString();
              tracking = false;
              currentBlock.clear();

              final infos = <MediaInfo>[];
              try {
                infos.addAll(
                  await _parseGalleryDlJsonBlock(
                    blockStr,
                    url,
                    isSocialProfile,
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
                if (parsedInfos.isNotEmpty || infos.length > 1) {
                  info = info.copyWith(
                    title: '${info.title} (${parsedInfos.length + 1})',
                  );
                }
                info = info.copyWith(
                  id: '${info.id}_${parsedInfos.length + 1}',
                );
                parsedInfos.add(info);
                onProgress?.call(info);
              }
            }
          }
        }
      }

      final exitCode = await process.exitCode;
      if (exitCode != 0 && parsedInfos.isEmpty) {
        final stderrStr = await process.stderr.transform(utf8.decoder).join();
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

      if (!fetchDeep && isSocialProfile) {
        parsedInfos.removeWhere((info) => !info.isProfile);
      }
      return parsedInfos;
    }

    try {
      return await processOutput().timeout(const Duration(minutes: 3));
    } on TimeoutException {
      ProcessUtils.killProcessTreeSync(process.pid);
      throw Exception('Metadata fetch timed out after 3 minutes');
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
  }) async {
    final args = <String>[];

    String? actualBrowser = browser;
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

  Future<List<MediaInfo>?> _fetchInstagramProfile(
    String url,
    String? browser,
  ) async {
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
        final user = data['data']?['user'] as Map<String, dynamic>? ?? {};

        if (user.isEmpty) {
          return null;
        }

        final fullName = user['full_name']?.toString() ?? '';
        final uname = user['username']?.toString() ?? username;
        final title = fullName.isNotEmpty ? '$fullName (@$uname)' : '@$uname';

        final profileInfo = MediaInfo(
          id: uname,
          title: title,
          thumbnail:
              user['profile_pic_url_hd']?.toString() ??
              user['profile_pic_url']?.toString(),
          extractor: 'instagram',
          isProfile: true,
          itemCount:
              user['edge_owner_to_timeline_media']?['count'] as int? ?? 0,
          originalUrl: url,
        );

        return [profileInfo];
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Insta Profile Error: $e');
      return null;
    }
  }

  Future<List<MediaInfo>> _parseGalleryDlJsonBlock(
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
        bool isListOfEvents = json.isNotEmpty && json.first is List;
        List<dynamic> events = isListOfEvents ? json : [json];

        Map<String, dynamic> sharedMeta = {};
        int fileCount = 0;

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
                  (sharedMeta['video_versions'] as List).where((e) => e is Map),
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

              if (fileUrl == null &&
                  sharedMeta['video_url'] != null &&
                  sharedMeta['video_url'].toString().startsWith('http')) {
                fileUrl = sharedMeta['video_url'] as String;
              } else if (fileUrl == null) {
                final urlIndex = event.indexWhere(
                  (e) => e is String && e.startsWith('http'),
                );
                if (urlIndex != -1) {
                  fileUrl = event[urlIndex] as String;
                }
              }

              String? title =
                  sharedMeta['title']?.toString() ??
                  sharedMeta['description']?.toString();
              if (title == null || title.isEmpty) title = 'Item';

              final info = MediaInfo.fromJson(sharedMeta, originalUrl: url)
                  .copyWith(
                    isProfile: false,
                    thumbnail:
                        sharedMeta['thumbnail']?.toString() ??
                        sharedMeta['display_url']?.toString() ??
                        fileUrl,
                    title: title,
                    galleryIndex: fileCount,
                  );
              if (fileUrl != null) {
                final ext = fileUrl.split('?').first.split('.').last;
                if (!ext.contains('/')) {
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
        }

        if (isSocialProfile && sharedMeta.isNotEmpty && existingCount == 0) {
          String title = '';
          String? profilePic;
          final userMeta = sharedMeta['user'] as Map<String, dynamic>?;
          if (userMeta != null) {
            final fn = userMeta['full_name']?.toString() ?? '';
            final un = userMeta['username']?.toString() ?? '';
            if (un.isNotEmpty) {
              title = fn.isNotEmpty ? '$fn (@$un)' : '@$un';
            }
            profilePic =
                userMeta['profile_pic_url_hd']?.toString() ??
                userMeta['profile_pic_url']?.toString();
          }
          if (title.isEmpty) {
            title =
                sharedMeta['fullname']?.toString() ??
                sharedMeta['title']?.toString() ??
                sharedMeta['description']?.toString() ??
                'Item';
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
    for (int i = 0; i < parsedInfos.length; i++) {
      var info = parsedInfos[i];
      final fileUrlFormat = info.formats
          .where((f) => f.formatId == 'original')
          .firstOrNull;
      final urlForSize = fileUrlFormat?.formatString ?? info.thumbnail;

      bool needsSize = info.filesize == null;
      if (info.isVideo &&
          info.filesize != null &&
          info.filesize! < 1024 * 1024 &&
          info.extractor?.contains('instagram') == true) {
        needsSize = true;
        info = info.copyWith(filesize: null);
        parsedInfos[i] = info;
      }

      if (needsSize && urlForSize != null && urlForSize.startsWith('http')) {
        final isInstagram =
            info.extractor?.contains('instagram') == true ||
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
