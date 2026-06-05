import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:onyxcore/core/utils/browser_detector.dart';
import 'package:onyxcore/core/utils/process_utils.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
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
  EngineType get engineType => EngineType.cli;

  @override
  String? get binaryPath => p.join(
    Platform.environment['HOME'] ?? '',
    '.local',
    'share',
    'onyxcore',
    'bin',
    'yt-dlp',
  );

  @override
  List<RegExp> get urlPatterns => [
    RegExp(r'.*'), // Fallback — matches everything
  ];

  @override
  int get priority => 1; // Low priority — gallery-dl wins for matching URLs

  @override
  bool get isInstalled => binaryPath != null && File(binaryPath!).existsSync();

  @override
  EngineUpdateInfo? get updateInfo => const EngineUpdateInfo(
    apiUrl: 'https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest',
    assetName: 'yt-dlp_linux',
    checksumAssetName: 'SHA2-256SUMS',
  );

  static bool? _aria2cAvailable;
  static bool _hasAria2c() {
    if (_aria2cAvailable != null) return _aria2cAvailable!;
    try {
      final res = Process.runSync('which', ['aria2c']);
      _aria2cAvailable = res.exitCode == 0;
      return _aria2cAvailable!;
    } catch (_) {
      _aria2cAvailable = false;
      return false;
    }
  }

  @override
  Future<List<MediaInfo>> fetchMetadata({
    required String url,
    String? browser,
    bool fetchDeep = false,
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

    if (url.contains('instagram.com')) {
      args.addAll(['--sleep-interval', '3', '--max-sleep-interval', '5']);
    }

    if (fetchDeep) {
      args.addAll([
        '-j',
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

      if (!fetchDeep) {
        final rawOutput = await process.stdout.transform(utf8.decoder).join();
        final exitCode = await process.exitCode;

        if (exitCode != 0 && rawOutput.trim().isEmpty) {
          final stderrStr = await process.stderr.transform(utf8.decoder).join();
          throw Exception('Failed to fetch metadata: $stderrStr');
        }

        if (rawOutput.isEmpty) {
          throw Exception('Received empty metadata from yt-dlp');
        }

        final jsonStartIndex = rawOutput.indexOf(RegExp(r'[\{\[]'));
        if (jsonStartIndex == -1) {
          throw Exception('Could not find JSON in output');
        }
        final jsonString = rawOutput.substring(jsonStartIndex);
        final json = jsonDecode(jsonString);
        final info = MediaInfo.fromJson(
          json as Map<String, dynamic>,
          originalUrl: url,
        );
        parsedInfos.add(info);
        onProgress?.call(info);
        return parsedInfos;
      } else {
        await for (final line
            in process.stdout
                .transform(utf8.decoder)
                .transform(const LineSplitter())) {
          if (line.trim().startsWith('{')) {
            try {
              final json = jsonDecode(line);
              final info = MediaInfo.fromJson(
                json as Map<String, dynamic>,
                originalUrl: url,
              );
              parsedInfos.add(info);
              onProgress?.call(info);
            } catch (e) {
              debugPrint('Failed to parse yt-dlp deep json line: $e');
            }
          }
        }
        final exitCode = await process.exitCode;
        if (exitCode != 0 && parsedInfos.isEmpty) {
          final stderrStr = await process.stderr.transform(utf8.decoder).join();
          throw Exception('Failed to fetch deep metadata: $stderrStr');
        }
        return parsedInfos;
      }
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
      args.addAll(['--sleep-interval', '3', '--max-sleep-interval', '5']);
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
      args.addAll(['-o', p.join(destination, '%(title)s.%(ext)s')]);
      args.addAll(['--trim-filenames', '80']);
    }

    if (_hasAria2c()) {
      args.addAll([
        '--external-downloader',
        'aria2c',
        '--downloader-args',
        'aria2c:-x 16 -s 16 -k 1M',
      ]);
    }

    args.add(url);

    return Process.start(
      binaryPath!,
      args,
      environment: {'PYTHONUNBUFFERED': '1'},
    );
  }
}
