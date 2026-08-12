import 'dart:io';

import 'package:flutter/material.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:path/path.dart' as p;

class DenoRuntime extends DownloadEngine {
  DenoRuntime._internal();
  static final DenoRuntime instance = DenoRuntime._internal();

  /// Pinned stable version to ensure deterministic behavior.
  static const String pinnedVersion = 'v2.9.5';

  @override
  String get id => 'deno';

  @override
  String get displayName => 'Deno Runtime';

  @override
  IconData get icon => Icons.javascript_rounded;

  @override
  Color get color => Colors.blueAccent;

  @override
  EngineType get engineType => EngineType.cli;

  @override
  int get priority => 0;

  @override
  bool get isOptional => false;

  /// Deterministic path to the managed Deno binary.
  static String get managedPath => p.join(
    Platform.environment['HOME'] ?? '',
    '.local',
    'share',
    'onyxcore',
    'bin',
    'deno',
  );

  @override
  String? get binaryPath => DenoRuntime.managedPath;

  @override
  List<RegExp> get urlPatterns => const [];

  @override
  EngineUpdateInfo? get updateInfo => EngineUpdateInfo(
    apiUrl: 'https://api.github.com/repos/denoland/deno/releases/tags/$pinnedVersion',
    assetName: 'deno-x86_64-unknown-linux-gnu.zip',
  );

  @override
  bool get isInstalled {
    final file = File(managedPath);
    if (!file.existsSync()) return false;
    // Check if it's executable
    final stat = file.statSync();
    return (stat.mode & 0x49) != 0; // Check executable bits
  }

  @override
  Future<String?> getInstalledVersion() async {
    if (!isInstalled) return null;
    try {
      final res = await Process.run(managedPath, ['--version']);
      if (res.exitCode == 0) {
        final text = res.stdout.toString();
        // deno 2.1.2
        final match = RegExp(r'deno (\d+\.\d+\.\d+)').firstMatch(text);
        if (match != null) {
          return 'v${match.group(1)}';
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Future<String?> getLatestVersion() async {
    return pinnedVersion; // We don't fetch latest, we return pinned.
  }

  @override
  Future<List<MediaInfo>> fetchMetadata({
    required String url,
    String? browser,
    bool fetchDeep = false,
    bool isPlaylist = false,
    void Function(MediaInfo info)? onProgress,
    void Function(int pid)? onProcessStarted,
  }) {
    throw UnimplementedError('Deno is a runtime, not a download engine');
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
    String? itemsRange,
  }) {
    throw UnimplementedError('Deno is a runtime, not a download engine');
  }
}
