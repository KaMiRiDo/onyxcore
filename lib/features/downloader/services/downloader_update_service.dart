import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:path/path.dart' as p;

class DownloaderUpdateState {
  final bool isUpdating;
  final double progress; // 0.0 to 1.0
  final String? error;
  final Map<String, double> engineProgress;
  final Map<String, String> installedVersions;
  final Map<String, String> latestVersions;
  final bool isCheckingForUpdates;

  const DownloaderUpdateState({
    this.isUpdating = false,
    this.progress = 0.0,
    this.error,
    this.engineProgress = const {},
    this.installedVersions = const {},
    this.latestVersions = const {},
    this.isCheckingForUpdates = false,
  });

  DownloaderUpdateState copyWith({
    bool? isUpdating,
    double? progress,
    String? error,
    Map<String, double>? engineProgress,
    Map<String, String>? installedVersions,
    Map<String, String>? latestVersions,
    bool? isCheckingForUpdates,
    bool clearError = false,
  }) {
    return DownloaderUpdateState(
      isUpdating: isUpdating ?? this.isUpdating,
      progress: progress ?? this.progress,
      error: clearError ? null : (error ?? this.error),
      engineProgress: engineProgress ?? this.engineProgress,
      installedVersions: installedVersions ?? this.installedVersions,
      latestVersions: latestVersions ?? this.latestVersions,
      isCheckingForUpdates: isCheckingForUpdates ?? this.isCheckingForUpdates,
    );
  }
}

class DownloaderUpdateNotifier extends Notifier<DownloaderUpdateState> {
  @override
  DownloaderUpdateState build() => const DownloaderUpdateState();

  Future<void> checkForUpdates({bool clearError = true}) async {
    if (state.isCheckingForUpdates) return;
    
    state = state.copyWith(isCheckingForUpdates: true, clearError: clearError);
    
    final installed = Map<String, String>.from(state.installedVersions);
    final latest = Map<String, String>.from(state.latestVersions);

    await Future.wait(EngineRegistry.allEngines.map((engine) async {
      final vInst = await engine.getInstalledVersion();
      if (vInst != null) installed[engine.id] = vInst;
      
      final vLatest = await engine.getLatestVersion();
      if (vLatest != null) latest[engine.id] = vLatest;
    }));

    state = state.copyWith(
      isCheckingForUpdates: false,
      installedVersions: installed,
      latestVersions: latest,
    );
  }

  Future<void> updateAll({bool defaultOnly = false}) async {
    if (state.isUpdating) return;
    state = state.copyWith(isUpdating: true, progress: 0.0, engineProgress: {}, clearError: true);

    final enginesToUpdate = EngineRegistry.allEngines.where((e) {
      final vInst = state.installedVersions[e.id];
      final vLat = state.latestVersions[e.id];
      final isUpdateAvailable = vInst != vLat && e.isInstalled;
      if (!isUpdateAvailable) return false;
      if (defaultOnly && e.isOptional) return false;
      return true;
    }).toList();

    if (enginesToUpdate.isEmpty) {
      state = state.copyWith(isUpdating: false);
      return;
    }

    try {
      final binDir = Directory(
        p.join(Platform.environment['HOME'] ?? '', '.local', 'share', 'onyxcore', 'bin'),
      );
      if (!await binDir.exists()) await binDir.create(recursive: true);

      int completed = 0;
      for (final engine in enginesToUpdate) {
        if (engine.updateInfo != null && engine.binaryPath != null) {
          await _downloadLatestRelease(
            apiUrl: engine.updateInfo!.apiUrl,
            assetName: engine.updateInfo!.assetName,
            checksumAssetName: engine.updateInfo!.checksumAssetName,
            savePath: engine.binaryPath!,
            progressWeight: 1.0 / enginesToUpdate.length,
            progressOffset: completed / enginesToUpdate.length,
            engineId: engine.id,
          );
        } else if (engine.engineType == EngineType.python) {
          final processFuture = engine.install();
          if (processFuture != null) {
            final process = await processFuture;
            await process.exitCode;
          }
        }
        completed++;
      }
    } catch (e) {
      state = state.copyWith(error: 'Global update failed: $e');
    } finally {
      state = state.copyWith(isUpdating: false, engineProgress: {});
      await checkForUpdates(clearError: false);
    }
  }

  Future<void> updateBinaries() async {
    if (state.isUpdating) return;

    state = state.copyWith(isUpdating: true, progress: 0.0, engineProgress: {}, clearError: true);

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

      state = state.copyWith(isUpdating: false, progress: 1.0);
    } catch (e) {
      state = DownloaderUpdateState(
        isUpdating: false,
        progress: 0.0,
        error: e.toString(),
        engineProgress: state.engineProgress,
      );
    }
  }

  /// Update a single engine that has updateInfo or is a python script engine.
  Future<void> updateEngine(DownloadEngine engine) async {
    if (engine.updateInfo == null && engine.engineType != EngineType.python) return;
    
    final newEngineProgress = Map<String, double>.from(state.engineProgress);
    newEngineProgress[engine.id] = -1.0; // Indeterminate progress for python engines initially
    if (engine.updateInfo != null) newEngineProgress[engine.id] = 0.0;
    state = state.copyWith(engineProgress: newEngineProgress, clearError: true);

    try {
      if (engine.updateInfo != null && engine.binaryPath != null) {
        await _downloadLatestRelease(
          apiUrl: engine.updateInfo!.apiUrl,
          assetName: engine.updateInfo!.assetName,
          checksumAssetName: engine.updateInfo!.checksumAssetName,
          savePath: engine.binaryPath!,
          progressWeight: 1.0,
          progressOffset: 0.0,
          engineId: engine.id,
        );
      } else if (engine.engineType == EngineType.python) {
        final processFuture = engine.install();
        if (processFuture != null) {
          final process = await processFuture;
          await process.exitCode;
        }
      }

      // Clean up progress upon completion
      final updatedProgress = Map<String, double>.from(state.engineProgress);
      updatedProgress.remove(engine.id);
      state = state.copyWith(engineProgress: updatedProgress);
      await checkForUpdates(clearError: false);
    } catch (e) {
      final updatedProgress = Map<String, double>.from(state.engineProgress);
      updatedProgress.remove(engine.id);
      state = state.copyWith(error: '${engine.id}:$e', engineProgress: updatedProgress);
    }
  }

  /// Track installation process for engines that use pip or other scripts.
  /// Sets progress to -1 (indeterminate) while running.
  Future<void> installProcessEngine(DownloadEngine engine, Future<Process>? processFuture) async {
    if (processFuture == null) return;

    final newEngineProgress = Map<String, double>.from(state.engineProgress);
    newEngineProgress[engine.id] = -1.0; // -1 represents indeterminate progress
    state = state.copyWith(engineProgress: newEngineProgress, clearError: true);

    try {
      final process = await processFuture;
      final stderrFuture = process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;
      final stderr = await stderrFuture;
      
      final updatedProgress = Map<String, double>.from(state.engineProgress);
      updatedProgress.remove(engine.id);
      
      if (exitCode != 0) {
        state = state.copyWith(error: '${engine.id}:$stderr', engineProgress: updatedProgress);
      } else {
        state = state.copyWith(engineProgress: updatedProgress);
        await checkForUpdates(clearError: false);
      }
    } catch (e) {
      final updatedProgress = Map<String, double>.from(state.engineProgress);
      updatedProgress.remove(engine.id);
      state = state.copyWith(error: '${engine.displayName} installation failed: $e', engineProgress: updatedProgress);
    }
  }

  Future<void> _downloadLatestRelease({
    required String apiUrl,
    required String assetName,
    String? checksumAssetName,
    required String savePath,
    required double progressWeight,
    required double progressOffset,
    String? engineId,
  }) async {
    final client = HttpClient();

    try {
      final req = await client.getUrl(Uri.parse(apiUrl));
      req.headers.set('User-Agent', 'OnyxCore/1.0.0');
      final res = await req.close();

      if (res.statusCode != 200) {
        throw Exception('Failed to fetch release info: ${res.statusCode}');
      }

      final resBody = await res.transform(utf8.decoder).join();
      final json = jsonDecode(resBody);
      final assets = json['assets'] as List<dynamic>?;

      if (assets == null || assets.isEmpty) {
        throw Exception('No assets found in the release');
      }

      // Find the asset that contains the assetName (so 'Linux_x86_64.tar.gz' matches 'lux_1.0_Linux_x86_64.tar.gz')
      final asset = assets.firstWhere(
        (a) => (a['name'] as String).contains(assetName),
        orElse: () => null,
      );

      if (asset == null) {
        throw Exception('Asset $assetName not found in release');
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

      final isTarGz = assetName.endsWith('.tar.gz');
      final targetPath = isTarGz ? '$savePath.tar.gz' : savePath;
      final file = File(targetPath);
      final sink = file.openWrite();

      await for (final chunk in downloadRes) {
        sink.add(chunk);
        downloaded += chunk.length;

        final subProgress = (downloaded / contentLength).clamp(0.0, 1.0);
        
        final currentGlobal = engineId != null ? state.engineProgress[engineId] : null;
        if (engineId != null && currentGlobal != null) {
          final newProgress = progressOffset + (subProgress * progressWeight);
          
          final newEngineProgress = Map<String, double>.from(state.engineProgress);
          newEngineProgress[engineId!] = newProgress;
          state = state.copyWith(
            progress: progressOffset + (subProgress * progressWeight),
            engineProgress: newEngineProgress,
          );
        } else {
          state = state.copyWith(
            progress: progressOffset + (subProgress * progressWeight),
          );
        }
      }

      await sink.flush();
      await sink.close();

      if (isTarGz) {
        final extractDir = p.dirname(targetPath);
        final res = await Process.run('tar', ['-xzf', targetPath, '-C', extractDir]);
        if (res.exitCode != 0) {
          throw Exception('Failed to extract tar.gz: ${res.stderr}');
        }
        await File(targetPath).delete();
      }

      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', savePath]);
      }

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
                final processResult = await Process.run('sha256sum', [savePath]);
                if (processResult.exitCode == 0) {
                  final actualHash = (processResult.stdout as String)
                      .split(' ')
                      .first
                      .trim();
                  if (actualHash != expectedHash) {
                    await File(savePath).delete();
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
      final chmodRes = await Process.run('chmod', ['+x', savePath]);
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
