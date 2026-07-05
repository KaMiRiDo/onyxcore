import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onyxcore/core/cache/metadata_cache.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/domain/repositories/settings_repository.dart';

/// Provider for the SettingsRepository implementation.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SettingsRepositoryImpl(db);
});

/// Provider for MetadataCache (image aspect ratio cache).
final metadataCacheProvider = Provider<MetadataCache>((ref) {
  final db = ref.watch(databaseProvider);
  final cache = MetadataCache(db);
  // Fire-and-forget: load runs in background via Drift's background isolate.
  // The in-memory map starts empty and fills in as the async query resolves.
  cache.load();
  return cache;
});

/// Notifier for app settings state.
///
/// Uses Drift's [watchAllSettings] stream for truly reactive updates —
/// any write to the Settings table automatically pushes a new [AppSettings]
/// to all listeners without requiring [ref.invalidateSelf].
class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final repo = ref.watch(settingsRepositoryProvider);

    // Subscribe to the Drift watch stream so we rebuild when any setting row changes.
    final db = ref.watch(databaseProvider);
    bool isFirst = true;
    final sub = db.watchAllSettings().listen((_) {
      if (isFirst) {
        isFirst = false;
        return;
      }
      ref.invalidateSelf();
    });
    ref.onDispose(sub.cancel);

    return repo.load();
  }

  Future<void> setAutoPlayNext({required bool value}) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setAutoPlayNext(value: value);
  }

  Future<void> setShowHiddenFiles({required bool value}) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setShowHiddenFiles(value: value);
  }

  Future<void> setShowHiddenAudioFiles({required bool value}) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setShowHiddenAudioFiles(value: value);
  }

  Future<void> setSnapshotPrefix(String value) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setSnapshotPrefix(value);
  }

  Future<void> setDoubleTapSeekSeconds(int value) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setDoubleTapSeekSeconds(value);
  }

  Future<void> setResumePlayback({required bool value}) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setResumePlayback(value: value);
  }

  Future<void> setSelectedHwDec(String value) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setSelectedHwDec(value);
  }

  Future<void> setCachedResolvedHwDec(String? value) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setCachedResolvedHwDec(value);
  }

  Future<void> setTrackpadSpeedControl({
    required SpeedControlOption value,
  }) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setTrackpadSpeedControl(value: value);
  }

  Future<void> setFilePickerDimensions(double width, double height) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setFilePickerDimensions(width, height);
  }

  Future<void> setSettingsDimensions(double width, double height) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setSettingsDimensions(width, height);
  }

  Future<void> setDownloaderDimensions(double width, double height) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setDownloaderDimensions(width, height);
  }

  Future<void> setDownloadBrowser(String? browser) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setDownloadBrowser(browser);
  }

  Future<void> setDownloadToCurrentFolder({required bool value}) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setDownloadToCurrentFolder(value: value);
  }

  Future<void> setFolderSort(String path, SortOption option) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setFolderSort(path, option);
    
    // Update local state since watchAllSettings only covers the generic Settings table.
    if (state.hasValue && state.value != null) {
      final newSorts = Map<String, String>.from(state.value!.gallerySortSettings);
      newSorts[path] = option.name;
      state = AsyncValue.data(state.value!.copyWith(gallerySortSettings: newSorts));
    }
  }

  Future<void> cleanupFolderSorts(List<String> paths) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.removeFolderSorts(paths);

    // Update local state by removing matching paths
    if (state.hasValue && state.value != null) {
      final newSorts = Map<String, String>.from(state.value!.gallerySortSettings);
      bool changed = false;
      for (final path in paths) {
        final toRemove = newSorts.keys.where((k) => k == path || k.startsWith('$path/')).toList();
        for (final k in toRemove) {
          newSorts.remove(k);
          changed = true;
        }
      }
      if (changed) {
        state = AsyncValue.data(state.value!.copyWith(gallerySortSettings: newSorts));
      }
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveSettings(settings);
  }
}

/// Provider for app settings with async loading.
final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
