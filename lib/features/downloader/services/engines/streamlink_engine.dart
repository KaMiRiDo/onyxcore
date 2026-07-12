import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:onyxcore/core/utils/process_utils.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/downloader_process_wrapper.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';

/// Concrete [DownloadEngine] implementation for Streamlink.
///
/// Streamlink is a Python CLI utility that extracts live video streams from
/// web interfaces and pipes them to disk. Built to hook into live HLS/DASH
/// streams on platforms like Twitch, Kick, and YouTube Live.
///
/// **Key differences from other engines:**
/// - Live streams have no definitive end — process termination requires
///   SIGINT (not SIGTERM) for clean container closure.
/// - Progress is tracked by file size growth, not percentage.
/// - Max recording duration is configurable in Settings.
///
/// Install via: `pip install streamlink`
class StreamlinkEngine extends DownloadEngine {
  @override
  String get id => 'streamlink';

  @override
  String get displayName => 'Streamlink';

  @override
  IconData get icon => Icons.sensors_rounded;

  @override
  Color get color => const Color(0xFFFF6B6B); // Coral red

  @override
  EngineType get engineType => EngineType.python;

  @override
  int get priority => 7; // Wins for live stream URLs

  @override
  bool get isOptional => true;

  @override
  List<String> get systemDependencies => ['python3'];

  String? _cachedBinaryPath;

  @override
  String? get binaryPath {
    if (_cachedBinaryPath != null) return _cachedBinaryPath;
    final commonPaths = [
      '/usr/bin/streamlink',
      '/usr/local/bin/streamlink',
      '${Platform.environment['HOME']}/.local/bin/streamlink',
    ];
    for (final path in commonPaths) {
      if (File(path).existsSync()) {
        _cachedBinaryPath = path;
        return path;
      }
    }
    try {
      final res = Process.runSync('which', ['streamlink']);
      if (res.exitCode == 0) {
        return _cachedBinaryPath = (res.stdout as String).trim();
      }
    } catch (_) {}
    return null;
  }

  @override
  List<RegExp> get urlPatterns => [
    RegExp(r'twitch\.tv/\w+$'), // Twitch live (not VOD clips)
    RegExp(r'kick\.com/\w+$'), // Kick live
    RegExp(r'youtube\.com/.*live'), // YouTube Live
    RegExp(r'youtube\.com/@\w+/live'), // YouTube Live channel
    RegExp(r'crunchyroll\.com'),
    RegExp(r'dailymotion\.com/video'),
  ];

  @override
  bool get isInstalled => binaryPath != null && File(binaryPath!).existsSync();

  @override
  EngineUpdateInfo? get updateInfo => null; // Installed via pip

  @override
  Future<Process>? install() {
    return Process.start('bash', [
      '-c',
      'pip3 install streamlink --break-system-packages',
    ]);
  }

  @override
  Future<Process>? uninstall() {
    return Process.start('bash', [
      '-c',
      'pip3 uninstall streamlink -y --break-system-packages',
    ]);
  }

  @override
  Future<String?> getInstalledVersion() async {
    if (!isInstalled) return null;
    try {
      final res = await Process.run('streamlink', ['--version']);
      if (res.exitCode == 0) {
        final out = (res.stdout as String).trim();
        // streamlink 6.7.3 -> 6.7.3
        final parts = out.split(' ');
        return parts.last;
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<String?> getLatestVersion() async {
    try {
      final res = await Process.run('curl', [
        '-s',
        'https://pypi.org/pypi/streamlink/json',
      ]);
      if (res.exitCode == 0) {
        final json = jsonDecode(res.stdout as String) as Map<String, dynamic>;
        return (json['info'] as Map<String, dynamic>?)?['version']?.toString();
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

    final process = await Process.start(binaryPath!, args);
    if (onProcessStarted != null) {
      onProcessStarted(process.pid);
    }

    final parsedInfos = <MediaInfo>[];

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
        throw Exception('Streamlink failed: $stderrStr');
      }

      if (rawOutput.trim().isEmpty) {
        throw Exception('No stream data from Streamlink');
      }

      final jsonStartIndex = rawOutput.indexOf('{');
      if (jsonStartIndex == -1) {
        throw Exception('Could not find JSON in Streamlink output');
      }

      final jsonString = rawOutput.substring(jsonStartIndex);
      final json = jsonDecode(jsonString) as Map<String, dynamic>;

      if (json.containsKey('error')) {
        throw Exception(json['error'].toString());
      }

      // Parse Streamlink JSON format
      final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
      final title =
          metadata['title']?.toString() ??
          metadata['author']?.toString() ??
          'Live Stream';
      final category = metadata['category']?.toString();

      final streams = json['streams'] as Map<String, dynamic>? ?? {};

      final formats = <MediaFormat>[];
      for (final entry in streams.entries) {
        final quality =
            entry.key; // e.g., "720p", "1080p60", "best", "audio_only"
        final stream = entry.value as Map<String, dynamic>? ?? {};
        final type = stream['type']?.toString() ?? 'hls';

        formats.add(
          MediaFormat(
            formatId: quality,
            extension: 'ts',
            resolution: quality,
            formatString: '$quality ($type)',
          ),
        );
      }

      // Extract stream title for display
      var displayTitle = title;
      if (category != null && category.isNotEmpty) {
        displayTitle = '$title — $category';
      }

      // Determine the platform name
      String? extractor;
      if (url.contains('twitch.tv')) {
        extractor = 'Twitch';
      } else if (url.contains('kick.com')) {
        extractor = 'Kick';
      } else if (url.contains('youtube.com')) {
        extractor = 'YouTube Live';
      } else {
        extractor = json['plugin']?.toString() ?? 'streamlink';
      }

      final info = MediaInfo(
        id: url.hashCode.toString(),
        title: displayTitle,
        extractor: extractor,
        formats: formats,
        isLive: true,
        originalUrl: url,
      );

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
        currentLogs += '\n\n--- Streamlink Raw Logs ---\n$formattedErrors';
      }
      final finalInfo = info.copyWith(fetchLogs: currentLogs.trim());

      parsedInfos.add(finalInfo);
      onProgress?.call(finalInfo);
    }

    try {
      await processOutput().timeout(const Duration(minutes: 10));
      return parsedInfos;
    } on TimeoutException {
      ProcessUtils.killProcessTreeSync(process.pid);
      if (parsedInfos.isEmpty) {
        throw Exception('Streamlink metadata fetch timed out');
      }
      throw PartialMetadataException(
        partialInfos: parsedInfos,
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
    final safeTitle =
        title?.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_') ??
        'live_recording_${DateTime.now().millisecondsSinceEpoch}';

    final outputPath = '$destination/$safeTitle.ts';

    final quality = format?.formatId ?? 'best';

    final args = <String>[
      '--output',
      outputPath,
      '--force', // Overwrite existing files
      url,
      quality,
    ];

    return Process.start(
      binaryPath!,
      args,
      environment: {'PYTHONUNBUFFERED': '1'},
    );
  }

  /// Gracefully stop a live stream recording.
  ///
  /// Sends SIGINT first (allows Streamlink to close the TS container cleanly),
  /// waits 3 seconds, then force-kills if still running.
  static Future<void> stopGracefully(Process process) async {
    process.kill(ProcessSignal.sigint);
    await Future<void>.delayed(const Duration(seconds: 3));
    // Check if process exited
    try {
      final exitCode = await process.exitCode.timeout(
        const Duration(seconds: 1),
      );
      debugPrint('Streamlink exited cleanly with code $exitCode');
    } on TimeoutException {
      // Still running — force kill
      debugPrint('Streamlink still running, force killing...');
      await ProcessUtils.killProcessTree(process.pid);
    }
  }
}
