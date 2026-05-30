import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:onyxcore/core/utils/browser_detector.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';

class MediaDownloaderBackend {
  static String? _cachedCookies;

  static String get _binPath {
    return p.join(
      Platform.environment['HOME'] ?? '',
      '.local',
      'share',
      'onyxcore',
      'bin',
    );
  }

  static String get _ytdlpPath => p.join(_binPath, 'yt-dlp');
  static String get _galleryDlPath => p.join(_binPath, 'gallery-dl');

  static bool _hasAria2c() {
    try {
      final res = Process.runSync('which', ['aria2c']);
      return res.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  static Future<List<MediaInfo>> fetchMetadata(String url, {String engine = 'auto', String? browser}) async {
    return _fetchMetadataAsync(url, engine, browser);
  }

  static Future<List<MediaInfo>> analyzeUrls(List<String> urls, {String engine = 'auto', String? browser}) async {
    final results = <MediaInfo>[];
    for (final url in urls) {
      if (url.trim().isEmpty) continue;
      try {
        final infoList = await fetchMetadata(url.trim(), engine: engine, browser: browser);
        results.addAll(infoList);
      } catch (e) {
        debugPrint('Failed to analyze $url: $e');
      }
    }
    return results;
  }

  static Future<String?> _extractCookies(String? browser) async {
    if (browser == null || browser == 'None' || browser.isEmpty) return null;
    
    // We only support manual sqlite extraction for Firefox-based browsers currently
    // since Chromium-based browsers encrypt their cookies on Linux.
    if (!browser.toLowerCase().contains('firefox') && !browser.toLowerCase().contains('librewolf') && !browser.toLowerCase().contains('waterfox')) {
        return null;
    }

    if (_cachedCookies != null) {
        return _cachedCookies;
    }

    final home = Platform.environment['HOME'] ?? '';
    final possiblePaths = [
      p.join(home, '.mozilla', 'firefox'),
      p.join(home, 'snap', 'firefox', 'common', '.mozilla', 'firefox'),
      p.join(home, '.var', 'app', 'org.mozilla.firefox', '.mozilla', 'firefox'),
      p.join(home, '.librewolf'),
      p.join(home, '.waterfox'),
    ];

    File? cookieDb;

    for (final base in possiblePaths) {
      final dir = Directory(base);
      if (dir.existsSync()) {
        final profiles = dir.listSync().whereType<Directory>();
        for (final profile in profiles) {
          final dbFile = File(p.join(profile.path, 'cookies.sqlite'));
          if (dbFile.existsSync()) {
            cookieDb = dbFile;
            break;
          }
        }
      }
      if (cookieDb != null) break;
    }

    if (cookieDb == null) return null;

    final tmpFile = File(p.join(Directory.systemTemp.path, 'onyx_cookies_${DateTime.now().millisecondsSinceEpoch}.sqlite'));
    try {
      await cookieDb.copy(tmpFile.path);
      final db = sqlite3.open(tmpFile.path);
      
      final rows = db.select("SELECT name, value FROM moz_cookies WHERE host LIKE '%instagram%' OR host LIKE '%cdninstagram%' OR host LIKE '%fbcdn%'");
      
      final cookies = <String>[];
      for (final row in rows) {
        cookies.add('${row['name']}=${row['value']}');
      }
      
      db.dispose();
      await tmpFile.delete();
      
      _cachedCookies = cookies.join('; ');
      return _cachedCookies;
    } catch (e) {
      debugPrint('[SizeProbe] Cookie extraction failed: $e');
      if (tmpFile.existsSync()) {
        await tmpFile.delete();
      }
      return null;
    }
  }

  static Future<List<MediaInfo>> _fetchMetadataAsync(String url, String engine, String? browser) async {
    bool isGallery = url.contains('instagram.com') ||
        url.contains('twitter.com') ||
        url.contains('x.com') ||
        url.contains('reddit.com/gallery');

    if (engine == 'gallery-dl') {
      isGallery = true;
    } else if (engine == 'yt-dlp') {
      isGallery = false;
    }

    final isSocialProfile = engine == 'auto' && isGallery && (!url.contains('/p/') && !url.contains('/reel/') && !url.contains('/status/'));

    if (url.contains('instagram.com') && isSocialProfile) {
      try {
        final profile = await _fetchInstagramProfile(url, browser);
        if (profile != null) return [profile];
      } catch (e) {
        debugPrint('Instagram API fallback failed: $e, trying gallery-dl...');
      }
    }

    final executable = isGallery ? _galleryDlPath : _ytdlpPath;
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
      if (isGallery) {
        args.addAll(['--sleep', '3-5']);
      } else {
        args.addAll(['--sleep-interval', '3', '--max-sleep-interval', '5']);
      }
    }

    if (isGallery) {
      args.addAll(['-j', url]);
    } else {
      args.addAll(['-J', '--flat-playlist', url]);
    }

    final result = await Process.run(executable, args);

    if (result.exitCode != 0 && result.stdout.toString().trim().isEmpty) {
      throw Exception('Failed to fetch metadata: ${result.stderr}');
    }

    final rawOutput = result.stdout.toString().trim();
    if (rawOutput.isEmpty) {
      throw Exception('Received empty metadata from $executable');
    }

    if (isGallery) {
      final jsonBlocks = <String>[];
      int braceCount = 0;
      int bracketCount = 0;
      bool inString = false;
      bool escape = false;
      int startIndex = -1;

      for (int i = 0; i < rawOutput.length; i++) {
        final c = rawOutput[i];
        if (escape) {
          escape = false;
          continue;
        }
        if (c == '\\') {
          escape = true;
          continue;
        }
        if (c == '"') {
          inString = !inString;
          continue;
        }
        if (!inString) {
          if (c == '{' || c == '[') {
            if (braceCount == 0 && bracketCount == 0) startIndex = i;
            if (c == '{') braceCount++;
            if (c == '[') bracketCount++;
          } else if (c == '}' || c == ']') {
            if (c == '}') braceCount--;
            if (c == ']') bracketCount--;
            if (braceCount == 0 && bracketCount == 0 && startIndex != -1) {
              jsonBlocks.add(rawOutput.substring(startIndex, i + 1));
              startIndex = -1;
            }
          }
        }
      }

      if (jsonBlocks.isEmpty) {
        throw Exception('Could not find JSON in gallery-dl output');
      }

      final parsedInfos = <MediaInfo>[];
      for (int index = 0; index < jsonBlocks.length; index++) {
        final block = jsonBlocks[index];
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
                  sharedMeta.addAll(Map<String, dynamic>.from(event[metaIndex] as Map));
                }
                
                if (eventType == 3) {
                  fileCount++;
                  String? fileUrl;
                  if (sharedMeta['video_versions'] is List && (sharedMeta['video_versions'] as List).isNotEmpty) {
                    final versions = List<Map<dynamic, dynamic>>.from((sharedMeta['video_versions'] as List).where((e) => e is Map));
                    if (versions.isNotEmpty) {
                      versions.sort((a, b) {
                        final widthA = int.tryParse(a['width']?.toString() ?? '0') ?? 0;
                        final heightA = int.tryParse(a['height']?.toString() ?? '0') ?? 0;
                        final widthB = int.tryParse(b['width']?.toString() ?? '0') ?? 0;
                        final heightB = int.tryParse(b['height']?.toString() ?? '0') ?? 0;
                        return (widthB * heightB).compareTo(widthA * heightA);
                      });
                      final highest = versions.first;
                      if (highest['url'] != null) fileUrl = highest['url'].toString();
                    }
                  }
                  
                  if (fileUrl == null && sharedMeta['video_url'] != null && sharedMeta['video_url'].toString().startsWith('http')) {
                    fileUrl = sharedMeta['video_url'] as String;
                  } else if (fileUrl == null) {
                    final urlIndex = event.indexWhere((e) => e is String && e.startsWith('http'));
                    if (urlIndex != -1) {
                      fileUrl = event[urlIndex] as String;
                    }
                  }
                  
                  String? title = sharedMeta['title']?.toString() ?? sharedMeta['description']?.toString();
                  if (title == null || title.isEmpty) title = 'Item';
                  
                  final info = MediaInfo.fromJson(sharedMeta, originalUrl: url).copyWith(
                    isProfile: isSocialProfile,
                    thumbnail: sharedMeta['thumbnail']?.toString() ?? sharedMeta['display_url']?.toString() ?? fileUrl,
                    title: title,
                    galleryIndex: fileCount,
                  );
                  if (fileUrl != null) {
                    info.formats.add(MediaFormat(
                      formatId: 'original',
                      extension: fileUrl.split('?').first.split('.').last,
                      resolution: 'original',
                      formatString: fileUrl,
                    ));
                  }
                  parsedInfos.add(info);
                }
              }
            }
            
            if (fileCount == 0 && sharedMeta.isNotEmpty) {
               if (sharedMeta.containsKey('error')) {
                 throw Exception('Extraction Error: ${sharedMeta['message'] ?? sharedMeta['error']}');
               }
               String? title = sharedMeta['title']?.toString() ?? sharedMeta['description']?.toString();
               if (title == null || title.isEmpty) title = 'Item';
               
               final info = MediaInfo.fromJson(sharedMeta, originalUrl: url).copyWith(
                  isProfile: isSocialProfile,
                  thumbnail: sharedMeta['thumbnail']?.toString() ?? sharedMeta['display_url']?.toString(),
                  title: title,
               );
               parsedInfos.add(info);
            }
          }
        } catch (e) {
          debugPrint('Error parsing block: $e');
        }
      }
      
      if (parsedInfos.length > 1) {
         for (int i = 0; i < parsedInfos.length; i++) {
            final oldInfo = parsedInfos[i];
            parsedInfos[i] = oldInfo.copyWith(title: '${oldInfo.title} (${i + 1})');
         }
      }

      if (parsedInfos.isEmpty) {
        throw Exception('Failed to parse gallery-dl JSON blocks');
      }
      
      for (int i = 0; i < parsedInfos.length; i++) {
        var info = parsedInfos[i];
        final fileUrlFormat = info.formats.where((f) => f.formatId == 'original').firstOrNull;
        final urlForSize = fileUrlFormat?.formatString ?? info.thumbnail;

        bool needsSize = info.filesize == null;
        if (info.isVideo && info.filesize != null && info.filesize! < 1024 * 1024 && info.extractor?.contains('instagram') == true) {
          needsSize = true;
          info = info.copyWith(filesize: null);
          parsedInfos[i] = info;
        }

        if (needsSize && urlForSize != null && urlForSize.startsWith('http')) {
          final isInstagram = info.extractor?.contains('instagram') == true || urlForSize.contains('cdninstagram.com') || urlForSize.contains('fbcdn.net');
          
          if (isInstagram && browser != null && browser != 'None') {
            try {
              final cookies = await _extractCookies(browser);
              
              final client = HttpClient();
              client.connectionTimeout = const Duration(seconds: 5);
              final req = await client.headUrl(Uri.parse(urlForSize));
              req.headers.set('User-Agent', 'Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0');
              req.headers.set('Referer', 'https://www.instagram.com/');
              if (cookies != null && cookies.isNotEmpty) {
                  req.headers.set('Cookie', cookies);
              }
              
              final res = await req.close();
              if (res.contentLength > 0 && res.contentLength > 500 * 1024) {
                 parsedInfos[i] = info.copyWith(filesize: res.contentLength);
              } else {
                 // Try GET request with Range if HEAD is blocked or returns small length
                 final client2 = HttpClient();
                 client2.connectionTimeout = const Duration(seconds: 5);
                 final req2 = await client2.getUrl(Uri.parse(urlForSize));
                 req2.headers.set('User-Agent', 'Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0');
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
              }
            } catch (e) {
              debugPrint('[SizeProbe] Exception: $e');
            }
          } else {
            try {
              final client = HttpClient();
              client.connectionTimeout = const Duration(seconds: 3);
              final req = await client.headUrl(Uri.parse(urlForSize));
              final res = await req.close();
              if (res.contentLength > 0) {
                parsedInfos[i] = info.copyWith(filesize: res.contentLength);
              }
            } catch (_) {}
          }
        }
      }
      
      return parsedInfos;
    } else {
      final jsonStartIndex = rawOutput.indexOf(RegExp(r'[\{\[]'));
      if (jsonStartIndex == -1) {
        throw Exception('Could not find JSON in output');
      }
      final jsonString = rawOutput.substring(jsonStartIndex);
      final json = jsonDecode(jsonString);
      return [MediaInfo.fromJson(json as Map<String, dynamic>, originalUrl: url)];
    }
  }

  static Future<MediaInfo?> _fetchInstagramProfile(String url, String? browser) async {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty) throw Exception('Could not extract username from URL');
    final username = segments.first;

    final cookies = await _extractCookies(browser);
    if (cookies == null || cookies.isEmpty) {
        return null; // fallback to gallery-dl if no cookies
    }

    try {
        final client = HttpClient();
        client.connectionTimeout = const Duration(seconds: 8);
        final req = await client.getUrl(Uri.parse('https://www.instagram.com/api/v1/users/web_profile_info/?username=$username'));
        req.headers.set('Cookie', cookies);
        req.headers.set('User-Agent', 'Mozilla/5.0 (X11; Linux x86_64; rv:133.0) Gecko/20100101 Firefox/133.0');
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
        
        final fullName = user['full_name']?.toString() ?? '';
        final uname = user['username']?.toString() ?? username;
        final title = fullName.isNotEmpty ? '$fullName (@$uname)' : '@$uname';

        return MediaInfo(
          id: uname,
          title: title,
          thumbnail: user['profile_pic_url_hd']?.toString() ?? user['profile_pic_url']?.toString(),
          extractor: 'instagram',
          isProfile: true,
          itemCount: user['edge_owner_to_timeline_media']?['count'] as int? ?? 0,
          originalUrl: url,
        );
    } catch (e) {
        debugPrint('Insta Profile Error: $e');
        return null;
    }
  }

  static Future<Process> startDownload({
    required String url,
    required String destination,
    String? title,
    MediaFormat? format,
    bool audioOnly = false,
    bool mute = false,
    int? galleryIndex,
    String engine = 'auto',
    bool isPlaylist = false,
    String? browser,
  }) async {
    bool isGallery = url.contains('instagram.com') ||
        url.contains('twitter.com') ||
        url.contains('reddit.com/gallery');

    if (engine == 'gallery-dl') {
      isGallery = true;
    } else if (engine == 'yt-dlp') {
      isGallery = false;
    }

    final executable = isGallery ? _galleryDlPath : _ytdlpPath;
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
      if (isGallery) {
        args.addAll(['--sleep', '3-5']);
      } else {
        args.addAll(['--sleep-interval', '3', '--max-sleep-interval', '5']);
      }
    }

    if (!isGallery) {
      if (audioOnly) {
        args.addAll(['-x', '--audio-format', 'best']);
      } else if (mute) {
        if (format != null && format.resolution != 'audio only') {
          args.addAll(['-f', '${format.formatId}']);
        } else {
          args.addAll(['-f', 'bestvideo']);
        }
      } else if (format != null) {
        if (format.resolution == 'audio only') {
             args.addAll(['-f', format.formatId]);
        } else {
             args.addAll(['-f', '${format.formatId}+bestaudio/best']);
        }
      }

      if (title != null && !isPlaylist) {
        final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        args.addAll(['-o', p.join(destination, '$safeTitle.%(ext)s')]);
      } else {
        args.addAll(['-o', p.join(destination, '%(title)s.%(ext)s')]);
        args.addAll(['--trim-filenames', '80']);
      }

      if (_hasAria2c()) {
        args.addAll([
          '--external-downloader',
          'aria2c',
          '--downloader-args',
          'aria2c:-x 16 -s 16 -k 1M'
        ]);
      }
    } else {
      args.addAll(['-D', destination]);
      if (galleryIndex != null && title != null) {
        final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|\{\}]'), '_');
        args.addAll(['--filename', '$safeTitle.{extension}']);
        args.addAll(['--range', galleryIndex.toString()]);
      }
    }

    args.add(url);

    return Process.start(executable, args);
  }
}
