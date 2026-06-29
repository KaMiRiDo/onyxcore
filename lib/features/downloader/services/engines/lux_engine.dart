import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:onyxcore/core/utils/process_utils.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:onyxcore/features/downloader/services/downloader_process_wrapper.dart';
import 'package:path/path.dart' as p;

/// Concrete [DownloadEngine] implementation for Lux (formerly Annie).
///
/// Lux is a fast, dependency-free command-line video downloader written in Go.
/// It compiles to a single statically-linked binary with virtually zero memory
/// footprint compared to Python-based tools.
///
/// Auto-downloadable from GitHub Releases: `iawia002/lux`
class LuxEngine extends DownloadEngine {
  @override
  String get id => 'lux';

  @override
  String get displayName => 'Lux';

  @override
  IconData get icon => Icons.bolt_rounded;

  @override
  Color get color => Colors.orangeAccent;

  @override
  EngineType get engineType => EngineType.cli;

  @override
  int get priority => 4;

  @override
  bool get isOptional => true;

  @override
  String? get binaryPath => p.join(
    Platform.environment['HOME'] ?? '',
    '.local',
    'share',
    'onyxcore',
    'bin',
    'lux',
  );

  @override
  List<RegExp> get urlPatterns => [
    RegExp(r'bilibili\.com'),
    RegExp(r'bilibili\.tv'),
    RegExp(r'youku\.com'),
    RegExp(r'iqiyi\.com'),
    RegExp(r'douyin\.com'), // TikTok China
    RegExp(r'weibo\.com'),
    RegExp(r'tumblr\.com'),
  ];

  @override
  bool get isInstalled => binaryPath != null && File(binaryPath!).existsSync();

  @override
  EngineUpdateInfo? get updateInfo => const EngineUpdateInfo(
    apiUrl: 'https://api.github.com/repos/iawia002/lux/releases/latest',
    assetName: 'Linux_x86_64.tar.gz',
  );

  @override
  Future<String?> getInstalledVersion() async {
    if (!isInstalled) return null;
    try {
      final res = await Process.run(binaryPath!, ['-v']);
      if (res.exitCode == 0) {
        final out = (res.stdout as String).trim();
        // lux: version 0.23.0, A fast and simple video downloader. -> 0.23.0
        final parts = out.split('version ');
        if (parts.length > 1) {
          final verString = parts[1].trim();
          return verString.split(',').first.trim().split(' ').first.trim();
        }
        return out.split(',').first.trim().split(' ').first.trim();
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<String?> getLatestVersion() async {
    try {
      final res = await Process.run('curl', [
        '-s',
        'https://api.github.com/repos/iawia002/lux/releases/latest',
      ]);
      if (res.exitCode == 0) {
        final json = jsonDecode(res.stdout as String);
        return json['tag_name']?.toString().replaceFirst('v', '');
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
    final args = <String>['-j', url];

    final process = await Process.start(binaryPath!, args);
    if (onProcessStarted != null) {
      onProcessStarted(process.pid);
    }

    final results = <MediaInfo>[];

    Future<void> processOutput() async {
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

      final rawOutput = await process.stdout.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;

      if (exitCode != 0 && rawOutput.trim().isEmpty) {
        final stderrStr = stderrBuffer.toString();
        throw Exception('Lux failed: $stderrStr');
      }

      if (rawOutput.trim().isEmpty) {
        throw Exception('Received empty metadata from Lux');
      }

      final jsonStartIndex = rawOutput.indexOf(RegExp(r'[\{\[]'));
      if (jsonStartIndex == -1) {
        final errorMsg = rawOutput.trim();
        throw Exception(
          errorMsg.isNotEmpty ? errorMsg : 'Could not find JSON in Lux output',
        );
      }

      final jsonString = rawOutput.substring(jsonStartIndex);
      final parsed = jsonDecode(jsonString);

      // Lux can return a list or a single object
      final List<dynamic> items = parsed is List ? parsed : [parsed];

      for (final json in items) {
        if (json is! Map<String, dynamic>) continue;

        final title = json['title']?.toString() ?? 'Unknown Title';
        final site = json['site']?.toString();
        final streams = json['streams'] as Map<String, dynamic>? ?? {};

        final formats = <MediaFormat>[];
        for (final entry in streams.entries) {
          final stream = entry.value as Map<String, dynamic>;
          final quality = stream['quality']?.toString() ?? entry.key;
          final size = stream['size'] as int?;
          // Lux stream parts
          final parts = stream['parts'] as List<dynamic>?;
          final ext = parts != null && parts.isNotEmpty
              ? (parts.first as Map<String, dynamic>)['ext']?.toString() ??
                    'mp4'
              : 'mp4';

          formats.add(
            MediaFormat(
              formatId: entry.key,
              extension: ext,
              resolution: quality,
              filesize: size,
              formatString: '$quality ($ext)',
            ),
          );
        }

        // Get size from the best stream
        int? totalSize;
        if (streams.isNotEmpty) {
          final bestStream = streams.values.first as Map<String, dynamic>;
          totalSize = bestStream['size'] as int?;
        }

        final info = MediaInfo(
          id:
              json['url']?.toString().hashCode.toString() ??
              url.hashCode.toString(),
          title: title,
          extractor: site ?? 'lux',
          formats: formats,
          isVideo: true,
          filesize: totalSize,
          originalUrl: json['url']?.toString() ?? url,
        );

        hydrationLogsBuffer.writeln(
          'Successfully fetched metadata for: "${info.title}"\n',
        );
        String currentLogs = hydrationLogsBuffer.toString();
        if (stderrBuffer.isNotEmpty) {
          final formattedErrors = stderrBuffer
              .toString()
              .trim()
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .join('\n\n');
          currentLogs += '\n\n--- lux Raw Logs ---\n$formattedErrors';
        }
        final infoWithLogs = info.copyWith(fetchLogs: currentLogs.trim());

        results.add(infoWithLogs);
        onProgress?.call(infoWithLogs);
      }

      if (results.isEmpty) {
        throw Exception('Lux returned no parseable results');
      }

      // Update all results with final combined logs
      String combinedLogs = hydrationLogsBuffer.toString();
      if (stderrBuffer.isNotEmpty) {
        final formattedErrors = stderrBuffer
            .toString()
            .trim()
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .join('\n\n');
        combinedLogs += '\n\n--- lux Raw Logs ---\n$formattedErrors';
      }
      for (int i = 0; i < results.length; i++) {
        results[i] = results[i].copyWith(fetchLogs: combinedLogs.trim());
      }
    }

    try {
      await processOutput().timeout(const Duration(minutes: 10));
      return results;
    } on TimeoutException {
      ProcessUtils.killProcessTreeSync(process.pid);
      if (results.isEmpty) {
        throw Exception('Lux metadata fetch timed out');
      }
      throw PartialMetadataException(
        partialInfos: results,
        message:
            'Hydration timed out after 10 minutes. Showing partial results.',
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
    final args = <String>[
      '-o',
      destination,
    ];

    if (title != null) {
      final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      args.addAll(['-O', safeTitle]);
    }

    if (format != null) {
      args.addAll(['-f', format.formatId]);
    }

    // Lux supports multi-threading internally
    args.addAll(['-n', '16']);

    args.add(url);

    return Process.start(binaryPath!, args);
  }
}
