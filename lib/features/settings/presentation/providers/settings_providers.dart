import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:onyxcore/core/cache/metadata_cache.dart';
import 'package:onyxcore/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/domain/repositories/settings_repository.dart';

/// Provider for SharedPreferences instance.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Must be overridden in ProviderScope');
});

/// Provider for the SettingsRepository implementation.
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsRepositoryImpl(prefs);
});

/// Provider for MetadataCache (image aspect ratio cache).
final metadataCacheProvider = Provider<MetadataCache>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final cache = MetadataCache(prefs)..load();
  return cache;
});

/// Notifier for app settings state.
class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final repo = ref.watch(settingsRepositoryProvider);
    return repo.load();
  }

  Future<void> setAutoPlayNext({required bool value}) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setAutoPlayNext(value: value);
    ref.invalidateSelf();
  }

  Future<void> setShowHiddenFiles({required bool value}) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setShowHiddenFiles(value: value);
    ref.invalidateSelf();
  }

  Future<void> setSnapshotPrefix(String value) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setSnapshotPrefix(value);
    ref.invalidateSelf();
  }

  Future<void> setDoubleTapSeekSeconds(int value) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setDoubleTapSeekSeconds(value);
    ref.invalidateSelf();
  }

  Future<void> setResumePlayback({required bool value}) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.setResumePlayback(value: value);
    ref.invalidateSelf();
  }

  Future<void> saveSettings(AppSettings settings) async {
    final repo = ref.read(settingsRepositoryProvider);
    await repo.saveSettings(settings);
    ref.invalidateSelf();
  }
}

/// Provider for app settings with async loading.
final settingsProvider =
    AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
