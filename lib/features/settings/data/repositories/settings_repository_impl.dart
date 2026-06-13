import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';

/// SharedPreferences-based implementation of [SettingsRepository].
///
/// Android-specific settings (biometric auth, vault, singleTapPlayPause)
/// have been removed. Only Linux-relevant settings are persisted.
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._prefs);

  final SharedPreferences _prefs;

  // In-memory state
  Map<String, String> _gallerySortSettings = {};
  List<String> _pinnedFolders = [];

  @override
  Future<AppSettings> load() async {
    // Load sort settings
    final sortStr = _prefs.getString('gallerySortSettings');
    if (sortStr != null && sortStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(sortStr) as Map<String, dynamic>;
        _gallerySortSettings = Map<String, String>.from(decoded);
      } catch (_) {}
    }

    // Load pinned folders
    _pinnedFolders = _prefs.getStringList('pinnedFolders') ?? [];

    // Load global sort option
    final globalSortStr = _prefs.getString('globalSortOption');
    final globalSort = SortOption.values.firstWhere(
      (e) => e.name == globalSortStr,
      orElse: () => SortOption.aToZ,
    );

    return AppSettings(
      autoPlayNext: _prefs.getBool('autoPlayNext') ?? true,
      showHiddenFiles: _prefs.getBool('showHiddenFiles') ?? false,
      showHiddenAudioFiles: _prefs.getBool('showHiddenAudioFiles') ?? false,
      snapshotPrefix: _prefs.getString('snapshotPrefix') ?? 'snapshot',
      doubleTapSeekSeconds: _prefs.getInt('doubleTapSeekSeconds') ?? 10,
      pinnedFolders: List<String>.from(_pinnedFolders),
      gallerySortSettings: Map<String, String>.from(_gallerySortSettings),
      maxConcurrentTasks: _prefs.getInt('maxConcurrentTasks') ?? 3,
      globalSortOption: globalSort,
      resumePlayback: _prefs.getBool('resumePlayback') ?? true,
      audioSeekSeconds: _prefs.getInt('audioSeekSeconds') ?? 5,
      selectedHwDec: _prefs.getString('selectedHwDec') ?? 'auto',
      cachedResolvedHwDec: _prefs.getString('cachedResolvedHwDec'),
      trackpadSpeedControl: SpeedControlOption.values.firstWhere(
        (e) => e.name == _prefs.getString('trackpad_speed_control'),
        orElse: () => SpeedControlOption.off,
      ),
      filePickerWidth: _prefs.getDouble('filePickerWidth') ?? 1000.0,
      filePickerHeight: _prefs.getDouble('filePickerHeight') ?? 650.0,
      settingsWidth: _prefs.getDouble('settingsWidth') ?? 760.0,
      settingsHeight: _prefs.getDouble('settingsHeight') ?? 560.0,
      downloaderWidth: _prefs.getDouble('downloaderWidth') ?? 750.0,
      downloaderHeight: _prefs.getDouble('downloaderHeight') ?? 560.0,
      confirmDeleteImage: _prefs.getBool('confirmDeleteImage') ?? true,
      confirmDeleteVideo: _prefs.getBool('confirmDeleteVideo') ?? true,
      confirmDeleteDocument: _prefs.getBool('confirmDeleteDocument') ?? true,
      confirmDeleteAudio: _prefs.getBool('confirmDeleteAudio') ?? true,
      downloadBrowser: _prefs.getString('downloadBrowser'),
      downloadToCurrentFolder: _prefs.getBool('downloadToCurrentFolder') ?? true,
      maxConcurrentDownloads: _prefs.getInt('maxConcurrentDownloads') ?? 3,
      maxLiveRecordingMinutes: _prefs.getInt('maxLiveRecordingMinutes') ?? 0,
      documentSearchCaseSensitive: _prefs.getBool('documentSearchCaseSensitive') ?? false,
      documentSearchUseRegex: _prefs.getBool('documentSearchUseRegex') ?? false,
    );

  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setBool('autoPlayNext', settings.autoPlayNext);
    await _prefs.setBool('showHiddenFiles', settings.showHiddenFiles);
    await _prefs.setBool('showHiddenAudioFiles', settings.showHiddenAudioFiles);
    await _prefs.setString('snapshotPrefix', settings.snapshotPrefix);
    await _prefs.setInt('doubleTapSeekSeconds', settings.doubleTapSeekSeconds);
    await _prefs.setInt('maxConcurrentTasks', settings.maxConcurrentTasks);
    await _prefs.setString('globalSortOption', settings.globalSortOption.name);
    await _prefs.setBool('resumePlayback', settings.resumePlayback);
    await _prefs.setInt('audioSeekSeconds', settings.audioSeekSeconds);
    await _prefs.setString('selectedHwDec', settings.selectedHwDec);
    if (settings.cachedResolvedHwDec != null) {
      await _prefs.setString('cachedResolvedHwDec', settings.cachedResolvedHwDec!);
    } else {
      await _prefs.remove('cachedResolvedHwDec');
    }
    await _prefs.setString('trackpad_speed_control', settings.trackpadSpeedControl.name);
    await _prefs.setDouble('filePickerWidth', settings.filePickerWidth);
    await _prefs.setDouble('filePickerHeight', settings.filePickerHeight);
    await _prefs.setDouble('settingsWidth', settings.settingsWidth);
    await _prefs.setDouble('settingsHeight', settings.settingsHeight);
    await _prefs.setDouble('downloaderWidth', settings.downloaderWidth);
    await _prefs.setDouble('downloaderHeight', settings.downloaderHeight);
    await _prefs.setBool('confirmDeleteImage', settings.confirmDeleteImage);
    await _prefs.setBool('confirmDeleteVideo', settings.confirmDeleteVideo);
    await _prefs.setBool('confirmDeleteDocument', settings.confirmDeleteDocument);
    await _prefs.setBool('confirmDeleteAudio', settings.confirmDeleteAudio);
    
    if (settings.downloadBrowser != null) {
      await _prefs.setString('downloadBrowser', settings.downloadBrowser!);
    } else {
      await _prefs.remove('downloadBrowser');
    }
    
    await _prefs.setBool('downloadToCurrentFolder', settings.downloadToCurrentFolder);
    await _prefs.setInt('maxConcurrentDownloads', settings.maxConcurrentDownloads);
    await _prefs.setInt('maxLiveRecordingMinutes', settings.maxLiveRecordingMinutes);
    await _prefs.setBool('documentSearchCaseSensitive', settings.documentSearchCaseSensitive);
    await _prefs.setBool('documentSearchUseRegex', settings.documentSearchUseRegex);
  }

  @override
  Future<void> setAutoPlayNext({required bool value}) async {
    await _prefs.setBool('autoPlayNext', value);
  }

  @override
  Future<void> setShowHiddenFiles({required bool value}) async {
    await _prefs.setBool('showHiddenFiles', value);
  }

  @override
  Future<void> setShowHiddenAudioFiles({required bool value}) async {
    await _prefs.setBool('showHiddenAudioFiles', value);
  }


  @override
  Future<void> setSnapshotPrefix(String value) async {
    await _prefs.setString('snapshotPrefix', value);
  }

  @override
  Future<void> setDoubleTapSeekSeconds(int value) async {
    await _prefs.setInt('doubleTapSeekSeconds', value);
  }

  @override
  Future<void> setResumePlayback({required bool value}) async {
    await _prefs.setBool('resumePlayback', value);
  }

  @override
  Future<void> setAudioSeekSeconds(int value) async {
    await _prefs.setInt('audioSeekSeconds', value);
  }

  @override
  Future<void> setSelectedHwDec(String value) async {
    await _prefs.setString('selectedHwDec', value);
  }

  @override
  Future<void> setCachedResolvedHwDec(String? value) async {
    if (value != null) {
      await _prefs.setString('cachedResolvedHwDec', value);
    } else {
      await _prefs.remove('cachedResolvedHwDec');
    }
  }

  @override
  Future<void> setTrackpadSpeedControl({required SpeedControlOption value}) async {
    await _prefs.setString('trackpad_speed_control', value.name);
  }

  @override
  Future<void> setFilePickerDimensions(double width, double height) async {
    await _prefs.setDouble('filePickerWidth', width);
    await _prefs.setDouble('filePickerHeight', height);
  }

  @override
  Future<void> setSettingsDimensions(double width, double height) async {
    await _prefs.setDouble('settingsWidth', width);
    await _prefs.setDouble('settingsHeight', height);
  }

  @override
  Future<void> setDownloaderDimensions(double width, double height) async {
    await _prefs.setDouble('downloaderWidth', width);
    await _prefs.setDouble('downloaderHeight', height);
  }

  @override
  Future<void> setDownloadBrowser(String? browser) async {
    if (browser != null) {
      await _prefs.setString('downloadBrowser', browser);
    } else {
      await _prefs.remove('downloadBrowser');
    }
  }

  @override
  Future<void> setDownloadToCurrentFolder({required bool value}) async {
    await _prefs.setBool('downloadToCurrentFolder', value);
  }

  // ——— Gallery Sorting ———

  @override
  SortOption getFolderSort(String path, SortOption globalDefault) {
    final name = _gallerySortSettings[path];
    if (name == null) return globalDefault;
    return SortOption.values.firstWhere(
      (e) => e.name == name,
      orElse: () => globalDefault,
    );
  }

  @override
  Future<void> setFolderSort(String path, SortOption option) async {
    _gallerySortSettings[path] = option.name;
    await _prefs.setString(
      'gallerySortSettings',
      jsonEncode(_gallerySortSettings),
    );
  }

  // ——— Gallery Pinning ———

  @override
  List<String> get pinnedFolders => List<String>.from(_pinnedFolders);

  @override
  bool isFolderPinned(String path) => _pinnedFolders.contains(path);

  @override
  Future<void> togglePinFolders(List<String> paths) async {
    for (final path in paths) {
      if (_pinnedFolders.contains(path)) {
        _pinnedFolders.remove(path);
      } else {
        _pinnedFolders.add(path);
      }
    }
    await _prefs.setStringList('pinnedFolders', _pinnedFolders);
  }

  @override
  Future<void> movePinUp(String path) async {
    final index = _pinnedFolders.indexOf(path);
    if (index > 0) {
      _pinnedFolders
        ..removeAt(index)
        ..insert(index - 1, path);
      await _prefs.setStringList('pinnedFolders', _pinnedFolders);
    }
  }

  @override
  Future<void> movePinDown(String path) async {
    final index = _pinnedFolders.indexOf(path);
    if (index >= 0 && index < _pinnedFolders.length - 1) {
      _pinnedFolders
        ..removeAt(index)
        ..insert(index + 1, path);
      await _prefs.setStringList('pinnedFolders', _pinnedFolders);
    }
  }

  @override
  Future<void> removeMissingPinnedFolders(
    String currentPath,
    List<String> validFolders,
  ) async {
    var changed = false;
    for (final path in List<String>.from(_pinnedFolders)) {
      final expectedParent = path.contains('/')
          ? path.substring(0, path.lastIndexOf('/'))
          : '';

      if (expectedParent == currentPath && !validFolders.contains(path)) {
        _pinnedFolders.remove(path);
        changed = true;
      }
    }
    if (changed) {
      await _prefs.setStringList('pinnedFolders', _pinnedFolders);
    }
  }

  // ——— Thumbnail Management ———

  @override
  String getThumbnailPath(String videoPath) {
    final hash = videoPath.hashCode.toString();
    final fileName = p.basename(videoPath);
    final cacheDir =
        "${Platform.environment['HOME']}/.cache/onyxcore/thumbnails";
    return '$cacheDir/${hash}_$fileName.jpg';
  }
}
