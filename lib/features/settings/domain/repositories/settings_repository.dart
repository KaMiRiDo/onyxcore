import '../entities/app_settings.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';

/// Abstract interface for settings persistence.
///
/// Data layer implements this with SharedPreferences.
abstract class SettingsRepository {
  /// Load all settings from persistent storage.
  Future<AppSettings> load();

  /// Save all settings in a single batch.
  Future<void> saveSettings(AppSettings settings);

  /// Update the auto-play-next setting.
  Future<void> setAutoPlayNext({required bool value});

  /// Update the show-hidden-files setting.
  Future<void> setShowHiddenFiles({required bool value});

  /// Update the snapshot filename prefix.
  Future<void> setSnapshotPrefix(String value);

  /// Update the double-tap seek seconds.
  Future<void> setDoubleTapSeekSeconds(int value);

  /// Update the resume playback setting.
  Future<void> setResumePlayback({required bool value});

  /// Update the audio seek seconds.
  Future<void> setAudioSeekSeconds(int value);

  /// Update the user-selected hardware decoder driver.
  Future<void> setSelectedHwDec(String value);

  /// Update the cached resolved hardware decoder driver from the engine.
  Future<void> setCachedResolvedHwDec(String? value);

  /// Update the trackpad speed control setting.
  Future<void> setTrackpadSpeedControl({required SpeedControlOption value});

  /// Update the file picker dimensions.
  Future<void> setFilePickerDimensions(double width, double height);

  // ——— Gallery Sorting ———

  /// Get the sort key for a specific folder path.
  SortOption getFolderSort(String path, SortOption globalDefault);

  /// Set the sort key for a specific folder path.
  Future<void> setFolderSort(String path, SortOption option);

  // ——— Gallery Pinning ———

  /// Get the list of pinned folder paths (ordered).
  List<String> get pinnedFolders;

  /// Check if a folder is pinned.
  bool isFolderPinned(String path);

  /// Toggle pin state for multiple folders.
  Future<void> togglePinFolders(List<String> paths);

  /// Move a pinned folder up in the order.
  Future<void> movePinUp(String path);

  /// Move a pinned folder down in the order.
  Future<void> movePinDown(String path);

  /// Remove pinned folders that no longer exist at their expected path.
  Future<void> removeMissingPinnedFolders(
    String currentPath,
    List<String> validFolders,
  );

  // ——— Thumbnail Management ———

  /// Generate the deterministic cache path for a video thumbnail.
  String getThumbnailPath(String videoPath);
}
