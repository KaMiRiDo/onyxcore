import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';
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
      final binDir = Directory(
        p.join(
          Platform.environment['HOME'] ?? '',
          '.local',
          'share',
          'onyxcore',
          'bin',
        ),
      );

      if (!await binDir.exists()) {
        await binDir.create(recursive: true);
      }

      // Iterate over all registered engines with update info
      final engines = EngineRegistry.allEngines.where((e) => e.updateInfo != null).toList();
      if (engines.isEmpty) {
        state = const DownloaderUpdateState(isUpdating: false, progress: 1.0);
        return;
      }
      final progressPerEngine = 1.0 / engines.length;

      for (int i = 0; i < engines.length; i++) {
        final engine = engines[i];
        await _downloadLatestRelease(
          apiUrl: engine.updateInfo!.apiUrl,
          assetName: engine.updateInfo!.assetName,
          checksumAssetName: engine.updateInfo!.checksumAssetName,
          savePath: engine.binaryPath!,
          progressWeight: progressPerEngine,
          progressOffset: i * progressPerEngine,
        );
      }

      state = const DownloaderUpdateState(isUpdating: false, progress: 1.0);
    } catch (e) {
      state = DownloaderUpdateState(
        isUpdating: false,
        progress: 0.0,
        error: e.toString(),
      );
    }
  }

  Future<void> _downloadLatestRelease({
    required String apiUrl,
    required String assetName,
    String? checksumAssetName,
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

      final contentLength = downloadRes.contentLength > 0
          ? downloadRes.contentLength
          : 1;
      int downloaded = 0;

      final file = File(savePath);
      final sink = file.openWrite();

      await for (final chunk in downloadRes) {
        sink.add(chunk);
        downloaded += chunk.length;

        final subProgress = (downloaded / contentLength).clamp(0.0, 1.0);
        state = state.copyWith(
          progress: progressOffset + (subProgress * progressWeight),
        );
      }

      await sink.flush();
      await sink.close();

      if (checksumAssetName != null) {
        final checksumAsset = assets.firstWhere(
          (a) => a['name'] == checksumAssetName,
          orElse: () => null,
        );
        if (checksumAsset != null) {
          final checksumUrl = checksumAsset['browser_download_url'] as String;
          final checksumReq = await client.getUrl(Uri.parse(checksumUrl));
          final checksumRes = await checksumReq.close();
          if (checksumRes.statusCode == 200 || checksumRes.statusCode == 302) {
            final sumsBody = await checksumRes.transform(utf8.decoder).join();
            for (final line in sumsBody.split('\n')) {
              if (line.contains(assetName)) {
                final expectedHash = line.split(' ').first.trim();
                final processResult = Process.runSync('sha256sum', [savePath]);
                if (processResult.exitCode == 0) {
                  final actualHash = (processResult.stdout as String)
                      .split(' ')
                      .first
                      .trim();
                  if (actualHash != expectedHash) {
                    File(savePath).deleteSync();
                    throw Exception(
                      'Integrity verification failed for $assetName! Expected $expectedHash, got $actualHash',
                    );
                  }
                }
                break;
              }
            }
          }
        }
      }

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
      DownloaderUpdateNotifier.new,
    );
