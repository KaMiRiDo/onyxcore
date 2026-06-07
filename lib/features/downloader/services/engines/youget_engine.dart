import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:onyxcore/core/utils/process_utils.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/aria2_accelerator.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';

/// Concrete [DownloadEngine] implementation for You-Get.
///
/// You-Get is a Python-based command-line utility that excels at scraping
/// Asian streaming platforms (Bilibili, Tencent, Youku) and acts as an
/// excellent fallback when yt-dlp breaks on certain sites.
///
/// Since it's Python-based, it relies on the system's Python environment.
/// Install via: `pip install you-get`
class YouGetEngine extends DownloadEngine {
  @override
  String get id => 'you-get';

  @override
  String get displayName => 'You-Get';

  @override
  IconData get icon => Icons.download_for_offline_rounded;

  @override
  Color get color => Colors.tealAccent;

  @override
  EngineType get engineType => EngineType.python;

  @override
  int get priority => 3; // Low — yt-dlp handles most of these better

  @override
  bool get isOptional => true;

  @override
  List<String> get systemDependencies => ['python3'];

  String? _cachedBinaryPath;

  @override
  String? get binaryPath {
    if (_cachedBinaryPath != null) return _cachedBinaryPath;
    final commonPaths = [
      '/usr/bin/you-get',
      '/usr/local/bin/you-get',
      '${Platform.environment['HOME']}/.local/bin/you-get',
    ];
    for (final path in commonPaths) {
      if (File(path).existsSync()) {
        _cachedBinaryPath = path;
        return path;
      }
    }
    // Fallback to which
    try {
      final res = Process.runSync('which', ['you-get']);
      if (res.exitCode == 0) {
        _cachedBinaryPath = (res.stdout as String).trim();
        return _cachedBinaryPath;
      }
    } catch (_) {}
    return null;
  }

  @override
  List<RegExp> get urlPatterns => [
    RegExp(r'bilibili\.com'),
    RegExp(r'bilibili\.tv'),
    RegExp(r'youku\.com'),
    RegExp(r'iqiyi\.com'),
    RegExp(r'qq\.com/x'), // Tencent Video
    RegExp(r'tudou\.com'),
    RegExp(r'acfun\.cn'),
    RegExp(r'nicovideo\.jp'),
  ];

  @override
  bool get isInstalled => binaryPath != null && File(binaryPath!).existsSync();

  @override
  EngineUpdateInfo? get updateInfo => null; // Installed via pip

  @override
  Future<Process>? install() {
    return Process.start('bash', ['-c', 'pip3 install you-get --break-system-packages']);
  }

  @override
  Future<Process>? uninstall() {
    return Process.start('bash', ['-c', 'pip3 uninstall you-get -y --break-system-packages']);
  }

  @override
  Future<String?> getInstalledVersion() async {
    if (!isInstalled) return null;
    try {
      final res = await Process.run('you-get', ['--version']);
      if (res.exitCode == 0) {
        final rawOut = res.stdout as String;
        final rawErr = res.stderr as String;
        final out = rawOut.isNotEmpty ? rawOut.trim() : rawErr.trim();
        // you-get: version 0.4.1743, a tiny downloader that scrapes the web.
        final parts = out.split('version ');
        if (parts.length > 1) {
          return parts[1].split(',').first.trim();
        }
        return out;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<String?> getLatestVersion() async {
    try {
      final res = await Process.run('curl', ['-s', 'https://pypi.org/pypi/you-get/json']);
      if (res.exitCode == 0) {
        final json = jsonDecode(res.stdout as String);
        return json['info']?['version']?.toString();
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
    final args = <String>['--json', url];

    final process = await Process.start('you-get', args);
    if (onProcessStarted != null) {
      onProcessStarted(process.pid);
    }

    final parsedInfos = <MediaInfo>[];

    Future<void> processOutput() async {
      final rawOutput = await process.stdout.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;

      if (exitCode != 0 && rawOutput.trim().isEmpty) {
        final stderrStr = await process.stderr.transform(utf8.decoder).join();
        throw Exception('You-Get failed: $stderrStr');
      }

      if (rawOutput.trim().isEmpty) {
        throw Exception('Received empty metadata from You-Get');
      }

      // Find JSON start
      final jsonStartIndex = rawOutput.indexOf(RegExp(r'[\{\[]'));
      if (jsonStartIndex == -1) {
        throw Exception('Could not find JSON in You-Get output');
      }

      final jsonString = rawOutput.substring(jsonStartIndex);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      // Parse You-Get JSON format
      final title = json['title']?.toString() ?? 'Unknown Title';
      final site = json['site']?.toString();
      final streams = json['streams'] as Map<String, dynamic>? ?? {};

      final formats = <MediaFormat>[];
      for (final entry in streams.entries) {
        final stream = entry.value as Map<String, dynamic>;
        final quality = stream['quality']?.toString() ?? entry.key;
        final container = stream['container']?.toString() ?? 'mp4';
        final size = stream['size'] as int?;

        formats.add(MediaFormat(
          formatId: entry.key,
          extension: container,
          resolution: quality,
          filesize: size,
          formatString: '$quality ($container)',
        ));
      }

      // Determine total filesize from the best stream
      int? totalSize;
      if (streams.isNotEmpty) {
        final bestStream =
            streams.values.first as Map<String, dynamic>;
        totalSize = bestStream['size'] as int?;
      }

      final info = MediaInfo(
        id: url.hashCode.toString(),
        title: title,
        extractor: site ?? 'you-get',
        formats: formats,
        isVideo: true,
        filesize: totalSize,
        originalUrl: url,
      );

      parsedInfos.add(info);
      onProgress?.call(info);
    }

    try {
      await processOutput().timeout(const Duration(minutes: 10));
      return parsedInfos;
    } on TimeoutException {
      ProcessUtils.killProcessTreeSync(process.pid);
      if (parsedInfos.isEmpty) {
        throw Exception('You-Get metadata fetch timed out');
      }
      throw PartialMetadataException(
        partialInfos: parsedInfos,
        message: 'Hydration timed out after 10 minutes. Showing partial results.',
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
    // You-Get doesn't natively support aria2c as an external downloader,
    // so we use a two-phase approach if aria2 is available:
    // 1. Extract direct URL via --json
    // 2. Download via aria2c
    // For simplicity in the initial implementation, we use you-get directly.

    final args = <String>[
      '-o',
      destination,
    ];

    if (title != null) {
      final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      args.addAll(['-O', safeTitle]);
    }

    if (format != null) {
      args.addAll(['--format=${ format.formatId}']);
    }

    args.add(url);

    return Process.start(
      'you-get',
      args,
      environment: {'PYTHONUNBUFFERED': '1'},
    );
  }
}
