import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

class DownloaderUpdateState {
  final bool isUpdating;
  final double progress; // 0.0 to 1.0
  final String? error;

  const DownloaderUpdateState({
    this.isUpdating = false,
    this.progress = 0.0,
    this.error,
  });

  DownloaderUpdateState copyWith({
    bool? isUpdating,
    double? progress,
    String? error,
  }) {
    return DownloaderUpdateState(
      isUpdating: isUpdating ?? this.isUpdating,
      progress: progress ?? this.progress,
      error: error,
    );
  }
}

class DownloaderUpdateNotifier extends Notifier<DownloaderUpdateState> {
  @override
  DownloaderUpdateState build() => const DownloaderUpdateState();

  Future<void> updateBinaries() async {
    if (state.isUpdating) return;

    state = const DownloaderUpdateState(isUpdating: true, progress: 0.0);

    try {
      final binDir = Directory(p.join(
        Platform.environment['HOME'] ?? '',
        '.local',
        'share',
        'onyxcore',
        'bin',
      ));

      if (!await binDir.exists()) {
        await binDir.create(recursive: true);
      }

      // Update yt-dlp
      await _downloadLatestRelease(
        apiUrl: 'https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest',
        assetName: 'yt-dlp_linux',
        savePath: p.join(binDir.path, 'yt-dlp'),
        progressWeight: 0.5,
        progressOffset: 0.0,
      );

      // Update gallery-dl
      await _downloadLatestRelease(
        apiUrl: 'https://codeberg.org/api/v1/repos/mikf/gallery-dl/releases/latest',
        assetName: 'gallery-dl.bin',
        savePath: p.join(binDir.path, 'gallery-dl'),
        progressWeight: 0.5,
        progressOffset: 0.5,
      );

      state = const DownloaderUpdateState(isUpdating: false, progress: 1.0);
    } catch (e) {
      state = DownloaderUpdateState(
          isUpdating: false, progress: 0.0, error: e.toString());
    }
  }

  Future<void> _downloadLatestRelease({
    required String apiUrl,
    required String assetName,
    required String savePath,
    required double progressWeight,
    required double progressOffset,
  }) async {
    final client = HttpClient();

    try {
      final req = await client.getUrl(Uri.parse(apiUrl));
      req.headers.set('User-Agent', 'OnyxCore/1.0.0');
      final res = await req.close();

      if (res.statusCode != 200) {
        throw Exception('Failed to fetch release info: ${res.statusCode}');
      }

      final body = await res.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final assets = json['assets'] as List<dynamic>? ?? [];
      final asset = assets.firstWhere(
        (a) => a['name'] == assetName,
        orElse: () => null,
      );

      if (asset == null) {
        throw Exception('Asset $assetName not found in the latest release');
      }

      final downloadUrl = asset['browser_download_url'] as String;

      final downloadReq = await client.getUrl(Uri.parse(downloadUrl));
      downloadReq.headers.set('User-Agent', 'OnyxCore/1.0.0');
      final downloadRes = await downloadReq.close();

      if (downloadRes.statusCode != 200 && downloadRes.statusCode != 302) {
        throw Exception('Failed to download asset: ${downloadRes.statusCode}');
      }

      final contentLength =
          downloadRes.contentLength > 0 ? downloadRes.contentLength : 1;
      int downloaded = 0;

      final file = File(savePath);
      final sink = file.openWrite();

      await for (final chunk in downloadRes) {
        sink.add(chunk);
        downloaded += chunk.length;

        final subProgress = (downloaded / contentLength).clamp(0.0, 1.0);
        state = state.copyWith(
            progress: progressOffset + (subProgress * progressWeight));
      }

      await sink.flush();
      await sink.close();

      // chmod +x
      final chmodRes = Process.runSync('chmod', ['+x', savePath]);
      if (chmodRes.exitCode != 0) {
        throw Exception('Failed to set executable permissions for $savePath');
      }
    } finally {
      client.close(force: true);
    }
  }
}

final downloaderUpdateProvider =
    NotifierProvider<DownloaderUpdateNotifier, DownloaderUpdateState>(
        DownloaderUpdateNotifier.new);
