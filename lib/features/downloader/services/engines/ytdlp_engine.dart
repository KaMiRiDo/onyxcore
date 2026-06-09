import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:onyxcore/core/utils/browser_detector.dart';
import 'package:onyxcore/core/utils/process_utils.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/aria2_accelerator.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:onyxcore/features/downloader/services/downloader_process_wrapper.dart';
import 'package:path/path.dart' as p;
import 'dart:async';

/// Concrete [DownloadEngine] implementation for yt-dlp.
///
/// Handles YouTube, Vimeo, and most general video/audio platforms.
/// Acts as the fallback engine when no higher-priority engine matches.
class YtDlpEngine extends DownloadEngine {
  @override
  String get id => 'yt-dlp';

  @override
  String get displayName => 'yt-dlp';

  @override
  IconData get icon => Icons.video_library_rounded;

  @override
  Color get color => Colors.redAccent;

  @override
  EngineType get engineType => EngineType.python;

  @override
  List<String> get systemDependencies => ['python3', 'python3-venv'];

  @override
  String? get binaryPath => p.join(
    Platform.environment['HOME'] ?? '',
    '.local',
    'share',
    'onyxcore',
    'yt-dlp-venv',
    'bin',
    'yt-dlp',
  );

  @override
  List<RegExp> get urlPatterns => [
    RegExp(r'.*'), // Fallback — matches everything
  ];

  @override
  int get priority => 9; // Primary video/audio engine — gallery-dl wins for matching image URLs

  @override
  bool get isInstalled => binaryPath != null && File(binaryPath!).existsSync();

  @override
  EngineUpdateInfo? get updateInfo => null;

  @override
  Future<Process>? install() {
    final venvPath = p.join(Platform.environment['HOME'] ?? '', '.local', 'share', 'onyxcore', 'yt-dlp-venv');
    return Process.start('bash', [
      '-c',
      'python3 -m venv "$venvPath" && "$venvPath/bin/pip" install --upgrade "yt-dlp[default,curl-cffi]"'
    ]);
  }

  @override
  Future<Process>? uninstall() {
    final venvPath = p.join(Platform.environment['HOME'] ?? '', '.local', 'share', 'onyxcore', 'yt-dlp-venv');
    return Process.start('bash', ['-c', 'rm -rf "$venvPath"']);
  }

  @override
  Future<String?> getInstalledVersion() async {
    if (!isInstalled) return null;
    try {
      final res = await Process.run(binaryPath!, ['--version']);
      if (res.exitCode == 0) return (res.stdout as String).trim();
    } catch (_) {}
    return null;
  }

  @override
  Future<String?> getLatestVersion() async {
    try {
      final res = await Process.run('curl', ['-s', 'https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest']);
      if (res.exitCode == 0) {
        final json = jsonDecode(res.stdout as String);
        return json['tag_name']?.toString();
      }
    } catch (_) {}
    return null;
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
    final args = <String>[];

    String? actualBrowser = browser;
    if (actualBrowser == null) {
      final defaultBrowser = await BrowserDetector.getDefaultBrowser();
      if (defaultBrowser != null) actualBrowser = defaultBrowser;
    }

    if (actualBrowser != null && actualBrowser.toLowerCase() != 'none') {
      args.addAll(['--cookies-from-browser', actualBrowser]);
    }

    // Bypass Cloudflare TLS fingerprinting
    args.addAll(['--impersonate', 'chrome']);

    if (url.contains('instagram.com')) {
      args.addAll(['--sleep-interval', '3', '--max-sleep-interval', '5']);
    }

    if (fetchDeep) {
      args.addAll([
        '-j',
        '--compat-options',
        'no-youtube-unavailable-videos',
        '--ignore-errors',
        '--no-warnings',
        '--no-check-certificates',
        url,
      ]);
    } else {
      args.addAll([
        '-J',
        '--flat-playlist',
        '--no-warnings',
        '--no-check-certificates',
        url,
      ]);
    }
    // Fix C1: No duplicate --no-warnings

    final customEnv = {
      'PYTHONUNBUFFERED': '1',
      'PATH': '${Platform.environment['PATH'] ?? ''}:${Platform.environment['HOME']}/.deno/bin:/usr/local/bin:/opt/homebrew/bin',
    };

    final process = await Process.start(
      binaryPath!,
      args,
      environment: customEnv,
    );
    if (onProcessStarted != null) {
      onProcessStarted(process.pid);
    }

    final parsedInfos = <MediaInfo>[];
    final stderrBuffer = StringBuffer();
    final hydrationLogsBuffer = StringBuffer();
    process.stderr.transform(utf8.decoder).listen((data) {
      stderrBuffer.write(data);
      MediaDownloaderBackend.activeLogs[url] = stderrBuffer.toString();
    });

    if (onProgress != null) {
      onProgress(MediaInfo(
        id: 'hydration_loading',
        title: 'Fetching...',
        originalUrl: url,
        fetchLogs: 'Waiting for output...',
        isVideo: false,
      ));
    }

    Future<void> processOutput() async {
      if (!fetchDeep) {
        final rawOutput = await process.stdout.transform(utf8.decoder).join();
        final exitCode = await process.exitCode;

        if (exitCode != 0 && rawOutput.trim().isEmpty) {
          final stderrStr = stderrBuffer.toString();
          throw Exception('Failed to fetch metadata: $stderrStr');
        }

        if (rawOutput.isEmpty) {
          throw Exception('Received empty metadata from yt-dlp');
        }

        final jsonStartIndex = rawOutput.indexOf(RegExp(r'[\{\[]'));
        if (jsonStartIndex == -1) {
          final stderrStr = stderrBuffer.toString();
          if (stderrStr.contains('Sign in to confirm')) {
            throw Exception('YouTube bot protection triggered. Please select your active browser in Settings > Download Browser to pass cookies, or install Node.js/Deno on your system.');
          } else if (stderrStr.contains('Requested format is not available') || stderrStr.contains('n challenge solving failed')) {
            throw Exception('YouTube stream decryption failed (n-challenge). A JavaScript runtime is required. Please install Node.js or Deno on your system to download YouTube videos.');
          } else {
            throw Exception('Could not find JSON in output.\nError: $stderrStr\nOutput: $rawOutput');
          }
        }
        final jsonString = rawOutput.substring(jsonStartIndex);
        final json = jsonDecode(jsonString);
        var info = MediaInfo.fromJson(
          json as Map<String, dynamic>,
          originalUrl: url,
        );
        info = await _probeSize(json as Map<String, dynamic>, info);
        parsedInfos.add(info);
        hydrationLogsBuffer.writeln('Successfully fetched metadata for: "${info.title}"\n');
        
        String currentLogs = hydrationLogsBuffer.toString();
        if (stderrBuffer.isNotEmpty) {
          final formattedErrors = stderrBuffer.toString().trim().split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).join('\n\n');
          currentLogs += '\n\n--- yt-dlp Raw Logs ---\n$formattedErrors';
        }
        info = info.copyWith(fetchLogs: currentLogs.trim());
        
        onProgress?.call(info);
      } else {
        hydrationLogsBuffer.writeln('Hydration started for playlist...');
        await for (final line
            in process.stdout
                .transform(utf8.decoder)
                .transform(const LineSplitter())) {
          if (line.trim().startsWith('{')) {
            try {
              final json = jsonDecode(line);
              var info = MediaInfo.fromJson(
                json as Map<String, dynamic>,
                originalUrl: url,
              );
              info = await _probeSize(json as Map<String, dynamic>, info);
              parsedInfos.add(info);
              hydrationLogsBuffer.writeln('Successfully fetched metadata for: "${info.title}"\n');
              
              String currentLogs = hydrationLogsBuffer.toString();
              if (stderrBuffer.isNotEmpty) {
                final formattedErrors = stderrBuffer.toString().trim().split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).join('\n\n');
                currentLogs += '\n\n--- yt-dlp Raw Logs ---\n$formattedErrors';
              }
              info = info.copyWith(fetchLogs: currentLogs.trim());
              
              onProgress?.call(info);
            } catch (e) {
              debugPrint('Failed to parse yt-dlp deep json line: $e');
              hydrationLogsBuffer.writeln('Error parsing metadata for a video: $e\n');
            }
          }
        }
        final exitCode = await process.exitCode;
        if (exitCode != 0 && parsedInfos.isEmpty) {
          final stderrStr = stderrBuffer.toString();
          if (stderrStr.contains('Sign in to confirm')) {
            throw Exception('YouTube bot protection triggered. Please select your active browser in Settings > Download Browser to pass cookies, or install Node.js/Deno on your system.');
          } else if (stderrStr.contains('Requested format is not available') || stderrStr.contains('n challenge solving failed')) {
            throw Exception('YouTube stream decryption failed (n-challenge). A JavaScript runtime is required. Please install Node.js or Deno on your system to download YouTube videos.');
          } else {
            throw Exception('Failed to fetch deep metadata: $stderrStr');
          }
        }
      }
    }

    try {
      final timeoutDuration = fetchDeep ? const Duration(minutes: 10) : const Duration(minutes: 3);
      await processOutput().timeout(timeoutDuration);
      
      String combinedLogs = hydrationLogsBuffer.toString();
      if (stderrBuffer.isNotEmpty) {
        final formattedErrors = stderrBuffer.toString().trim().split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).join('\n\n');
        combinedLogs += '\n\n--- yt-dlp Raw Logs ---\n$formattedErrors';
      }
      
      return parsedInfos.map((i) => i.copyWith(fetchLogs: combinedLogs.trim())).toList();
    } on TimeoutException {
      ProcessUtils.killProcessTreeSync(process.pid);
      hydrationLogsBuffer.writeln('!!! Hydration timed out after 10 minutes !!!');
      
      String combinedLogs = hydrationLogsBuffer.toString();
      if (stderrBuffer.isNotEmpty) {
        final formattedErrors = stderrBuffer.toString().trim().split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).join('\n\n');
        combinedLogs += '\n\n--- yt-dlp Raw Logs ---\n$formattedErrors';
      }

      if (parsedInfos.isEmpty) {
        throw Exception('Metadata fetch timed out. Logs:\n$combinedLogs');
      }
      throw PartialMetadataException(
        partialInfos: parsedInfos.map((i) => i.copyWith(fetchLogs: combinedLogs.trim())).toList(),
        message: 'Hydration timed out after 10 minutes. Showing partial results.',
      );
    }
  }

  Future<MediaInfo> _probeSize(Map<String, dynamic> json, MediaInfo info) async {
    if (info.filesize != null) return info;
    
    final directUrl = json['url']?.toString();
    if (directUrl == null || directUrl.isEmpty) return info;

    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 3);
      final req = await client.headUrl(Uri.parse(directUrl));
      
      final headers = json['http_headers'] as Map<String, dynamic>?;
      if (headers != null) {
        headers.forEach((k, v) {
          req.headers.set(k, v.toString());
        });
      }
      
      final cookies = json['cookies']?.toString();
      if (cookies != null && cookies.isNotEmpty) {
        req.headers.set('Cookie', cookies);
      }
      
      final res = await req.close();
      if (res.contentLength > 0) {
        client.close(force: true);
        return info.copyWith(filesize: res.contentLength);
      }
      client.close(force: true);
    } catch (_) {}
    
    return info;
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
    final args = <String>[
      '--newline',
      '--compat-options',
      'no-external-downloader-progress',
    ];

    String? actualBrowser = browser;
    if (actualBrowser == null) {
      final defaultBrowser = await BrowserDetector.getDefaultBrowser();
      if (defaultBrowser != null) actualBrowser = defaultBrowser;
    }

    if (actualBrowser != null && actualBrowser.toLowerCase() != 'none') {
      args.addAll(['--cookies-from-browser', actualBrowser]);
    }

    // Bypass Cloudflare TLS fingerprinting
    args.addAll(['--impersonate', 'chrome']);

    if (url.contains('instagram.com')) {
      args.addAll(['--sleep-interval', '3', '--max-sleep-interval', '5']);
    }

    String downloadTarget = url;
    final fallbackDirectUrl = (format?.url?.isNotEmpty == true) ? format!.url! : directUrl;
    
    if (singleItemId != null && fallbackDirectUrl != null && fallbackDirectUrl.isNotEmpty && fallbackDirectUrl != url) {
      // Use direct media URL for single item downloads to bypass dynamic webpage scraping
      downloadTarget = fallbackDirectUrl;
      args.addAll(['--add-header', 'Referer:$url']);
    } else if (singleItemId != null && singleItemId.isNotEmpty) {
      args.addAll(['--match-filter', 'id = $singleItemId']);
    } else if (galleryIndex != null) {
      args.addAll(['--playlist-items', galleryIndex.toString()]);
    } else if (!isPlaylist) {
      args.addAll(['--no-playlist']);
    }

    if (audioOnly) {
      args.addAll(['-x', '--audio-format', 'best']);
    } else if (mute) {
      if (format != null && format.resolution != 'audio only') {
        args.addAll(['-f', format.formatId]);
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
      args.addAll(['-o', p.join(destination, '%(playlist_index)03d - %(title)s.%(ext)s')]);
      args.addAll(['--trim-filenames', '80']);
    }

    if (Aria2Accelerator.isAvailable) {
      args.addAll([
        '--external-downloader',
        Aria2Accelerator.executable,
        '--downloader-args',
        Aria2Accelerator.downloaderArgs,
      ]);
    }

    args.add(downloadTarget);

    final customEnv = {
      'PYTHONUNBUFFERED': '1',
      'PATH': '${Platform.environment['PATH'] ?? ''}:${Platform.environment['HOME']}/.deno/bin:/usr/local/bin:/opt/homebrew/bin',
    };

    return Process.start(
      binaryPath!,
      args,
      environment: customEnv,
    );
  }
}
