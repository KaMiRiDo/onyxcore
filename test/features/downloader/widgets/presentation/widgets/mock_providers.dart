import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:path/path.dart' as p;

class MockSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() {
    return Future.value(const AppSettings(
      downloadBrowser: 'None',
      downloadToCurrentFolder: true,
    ));
  }
}

class MockCurrentPathNotifier extends CurrentPathNotifier {
  @override
  String build() {
    return '/tmp';
  }
}

class MockDownloadTaskNotifier extends DownloadTaskNotifier {
  @override
  List<DownloadTask> build() {
    return [];
  }

  @override
  void addDownloadTask({
    required String url,
    required String destination,
    required String title,
    String downloadType = 'generic',
    MediaFormat? format,
    bool audioOnly = false,
    bool mute = false,
    int? galleryIndex,
    String? engine,
    bool isPlaylist = false,
    bool isProfile = false,
    String? browser,
    bool isZip = false,
    String? filterType,
    int? totalItems,
    String? singleItemId,
    String? directUrl,
  }) {
    // Do nothing for tests
  }

  @override
  void startListening(WidgetRef ref) {}

  @override
  void addDownload(MediaInfo info) {
    // Empty
  }

  @override
  void updateProgress(String id, double progress, String speed, String eta) {}
}

class MockBinaryHelper {
  static void setupMockBinaries() {
    final homeDir = Platform.environment['HOME'] ?? '';
    final ytdlpPath = p.join(homeDir, '.local', 'share', 'onyxcore', 'yt-dlp-venv', 'bin', 'yt-dlp');
    final galleryDlPath = p.join(homeDir, '.local', 'share', 'onyxcore', 'bin', 'gallery-dl');
    
    for (final path in [ytdlpPath, galleryDlPath]) {
      final file = File(path);
      if (!file.existsSync()) {
        file.createSync(recursive: true);
      }
    }
  }

  static void cleanupMockBinaries() {
    final homeDir = Platform.environment['HOME'] ?? '';
    final onyxcoreDir = Directory(p.join(homeDir, '.local', 'share', 'onyxcore'));
    if (onyxcoreDir.existsSync()) {
      try {
        onyxcoreDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  }
}

class MockYtDlpEngine extends DownloadEngine {
  @override
  String get id => 'yt-dlp';
  @override
  String get name => 'yt-dlp mock';
  @override
  String get binaryName => 'yt-dlp';
  @override
  bool get isInstalled => true;
  @override
  int get priority => 9;
  @override
  List<RegExp> get urlPatterns => [];
  @override
  String? get binaryPath => null;
  @override
  Color get color => const Color(0xFF000000);
  @override
  String get displayName => 'Mock yt-dlp';
  @override
  EngineType get engineType => EngineType.cli;
  @override
  IconData get icon => Icons.video_library;
  @override
  EngineUpdateInfo? get updateInfo => null;
  
  @override
  Future<List<MediaInfo>> fetchMetadata({
    required String url,
    String? browser,
    bool fetchDeep = false,
    bool isPlaylist = false,
    void Function(MediaInfo info)? onProgress,
    void Function(int pid)? onProcessStarted,
  }) async {
    return [
      MediaInfo(
        id: '123',
        title: 'Mock Video Content',
        originalUrl: url,
        duration: 120,
        thumbnail: 'https://test.com/thumb',
        filesize: 1048576,
      )
    ];
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
    throw UnimplementedError();
  }
}
