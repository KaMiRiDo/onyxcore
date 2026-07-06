import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/settings_codec.dart';

import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';

/// Drift-backed implementation of [SettingsRepository].
///
/// All AppSettings fields are stored as individual rows in the [Settings] Drift
/// table (key → JSON-encoded value). Structured data (folder sorts, pinned
/// folders) has dedicated tables.
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._db);

  final AppDatabase _db;

  // ── Keys for the Settings table ──────────────────────────────────────────
  static const _autoPlayNext = 'autoPlayNext';
  static const _audioAutoPlayNext = 'audioAutoPlayNext';
  static const _showHiddenFiles = 'showHiddenFiles';
  static const _showHiddenAudioFiles = 'showHiddenAudioFiles';
  static const _snapshotPrefix = 'snapshotPrefix';
  static const _doubleTapSeekSeconds = 'doubleTapSeekSeconds';
  static const _maxConcurrentTasks = 'maxConcurrentTasks';
  static const _globalSortOption = 'globalSortOption';
  static const _resumePlayback = 'resumePlayback';
  static const _audioSeekSeconds = 'audioSeekSeconds';
  static const _selectedHwDec = 'selectedHwDec';
  static const _cachedResolvedHwDec = 'cachedResolvedHwDec';
  static const _trackpadSpeedControl = 'trackpad_speed_control';
  static const _filePickerWidth = 'filePickerWidth';
  static const _filePickerHeight = 'filePickerHeight';
  static const _settingsWidth = 'settingsWidth';
  static const _settingsHeight = 'settingsHeight';
  static const _downloaderWidth = 'downloaderWidth';
  static const _downloaderHeight = 'downloaderHeight';
  static const _confirmDeleteImage = 'confirmDeleteImage';
  static const _confirmDeleteVideo = 'confirmDeleteVideo';
  static const _confirmDeleteDocument = 'confirmDeleteDocument';
  static const _confirmDeleteAudio = 'confirmDeleteAudio';
  static const _downloadBrowser = 'downloadBrowser';
  static const _downloadToCurrentFolder = 'downloadToCurrentFolder';
  static const _maxConcurrentDownloads = 'maxConcurrentDownloads';
  static const _maxLiveRecordingMinutes = 'maxLiveRecordingMinutes';
  static const _documentSearchCaseSensitive = 'documentSearchCaseSensitive';
  static const _documentSearchUseRegex = 'documentSearchUseRegex';
  static const _audioPlayerVolume = 'audioPlayerVolume';
  static const _videoPlayerVolume = 'videoPlayerVolume';
  static const _openWithDialogWidth = 'open_with_dialog_width';
  static const _openWithDialogHeight = 'open_with_dialog_height';
  static const _sidePanelWidthPixels = 'side_panel_width_pixels';

  // Helper to read multiple settings at once (minimizes async round trips)
  Future<Map<String, String?>> _readAll(List<String> keys) async {
    final result = <String, String?>{};
    for (final key in keys) {
      result[key] = await _db.getSetting(key);
    }
    return result;
  }

  @override
  Future<AppSettings> load() async {
    final keys = [
      _autoPlayNext, _audioAutoPlayNext, _showHiddenFiles, _showHiddenAudioFiles,
      _snapshotPrefix, _doubleTapSeekSeconds, _maxConcurrentTasks,
      _globalSortOption, _resumePlayback, _audioSeekSeconds, _selectedHwDec,
      _cachedResolvedHwDec, _trackpadSpeedControl, _filePickerWidth,
      _filePickerHeight, _settingsWidth, _settingsHeight, _downloaderWidth,
      _downloaderHeight, _confirmDeleteImage, _confirmDeleteVideo,
      _confirmDeleteDocument, _confirmDeleteAudio, _downloadBrowser,
      _downloadToCurrentFolder, _maxConcurrentDownloads, _maxLiveRecordingMinutes,
      _documentSearchCaseSensitive, _documentSearchUseRegex,
      _audioPlayerVolume, _videoPlayerVolume,
    ];

    final vals = await _readAll(keys);

    final globalSortStr = vals[_globalSortOption];
    final globalSort = SortOption.values.firstWhere(
      (e) => e.name == globalSortStr,
      orElse: () => SortOption.aToZ,
    );

    // Load pinned folders from dedicated table
    final pinnedFolders = await _db.getOrderedPinnedFolders();

    return AppSettings(
      autoPlayNext: SettingsCodec.decodeBool(vals[_autoPlayNext], fallback: true),
      audioAutoPlayNext: SettingsCodec.decodeBool(vals[_audioAutoPlayNext], fallback: true),
      showHiddenFiles: SettingsCodec.decodeBool(vals[_showHiddenFiles], fallback: false),
      showHiddenAudioFiles: SettingsCodec.decodeBool(vals[_showHiddenAudioFiles], fallback: false),
      snapshotPrefix: SettingsCodec.decodeString(vals[_snapshotPrefix], fallback: 'snapshot'),
      doubleTapSeekSeconds: SettingsCodec.decodeInt(vals[_doubleTapSeekSeconds], fallback: 10),
      pinnedFolders: pinnedFolders,
      gallerySortSettings: await _loadGallerySortSettings(),
      maxConcurrentTasks: SettingsCodec.decodeInt(vals[_maxConcurrentTasks], fallback: 3),
      globalSortOption: globalSort,
      resumePlayback: SettingsCodec.decodeBool(vals[_resumePlayback], fallback: true),
      audioSeekSeconds: SettingsCodec.decodeInt(vals[_audioSeekSeconds], fallback: 5),
      selectedHwDec: SettingsCodec.decodeString(vals[_selectedHwDec], fallback: 'auto'),
      cachedResolvedHwDec: SettingsCodec.decodeNullableString(vals[_cachedResolvedHwDec]),
      trackpadSpeedControl: SpeedControlOption.values.firstWhere(
        (e) => e.name == vals[_trackpadSpeedControl],
        orElse: () => SpeedControlOption.off,
      ),
      filePickerWidth: SettingsCodec.decodeDouble(vals[_filePickerWidth], fallback: 1000.0),
      filePickerHeight: SettingsCodec.decodeDouble(vals[_filePickerHeight], fallback: 650.0),
      settingsWidth: SettingsCodec.decodeDouble(vals[_settingsWidth], fallback: 760.0),
      settingsHeight: SettingsCodec.decodeDouble(vals[_settingsHeight], fallback: 560.0),
      downloaderWidth: SettingsCodec.decodeDouble(vals[_downloaderWidth], fallback: 750.0),
      downloaderHeight: SettingsCodec.decodeDouble(vals[_downloaderHeight], fallback: 560.0),
      confirmDeleteImage: SettingsCodec.decodeBool(vals[_confirmDeleteImage], fallback: true),
      confirmDeleteVideo: SettingsCodec.decodeBool(vals[_confirmDeleteVideo], fallback: true),
      confirmDeleteDocument: SettingsCodec.decodeBool(vals[_confirmDeleteDocument], fallback: true),
      confirmDeleteAudio: SettingsCodec.decodeBool(vals[_confirmDeleteAudio], fallback: true),
      downloadBrowser: SettingsCodec.decodeNullableString(vals[_downloadBrowser]),
      downloadToCurrentFolder: SettingsCodec.decodeBool(vals[_downloadToCurrentFolder], fallback: true),
      maxConcurrentDownloads: SettingsCodec.decodeInt(vals[_maxConcurrentDownloads], fallback: 3),
      maxLiveRecordingMinutes: SettingsCodec.decodeInt(vals[_maxLiveRecordingMinutes], fallback: 0),
      documentSearchCaseSensitive: SettingsCodec.decodeBool(vals[_documentSearchCaseSensitive], fallback: false),
      documentSearchUseRegex: SettingsCodec.decodeBool(vals[_documentSearchUseRegex], fallback: false),
      audioPlayerVolume: SettingsCodec.decodeDouble(vals[_audioPlayerVolume], fallback: 100.0),
      videoPlayerVolume: SettingsCodec.decodeDouble(vals[_videoPlayerVolume], fallback: 100.0),
    );
  }

  Future<Map<String, String>> _loadGallerySortSettings() async {
    return _db.getAllFolderSorts();
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    // Save all scalar settings
    await Future.wait([
      _db.setSetting(_autoPlayNext, SettingsCodec.encodeBool(settings.autoPlayNext)),
      _db.setSetting(_audioAutoPlayNext, SettingsCodec.encodeBool(settings.audioAutoPlayNext)),
      _db.setSetting(_showHiddenFiles, SettingsCodec.encodeBool(settings.showHiddenFiles)),
      _db.setSetting(_showHiddenAudioFiles, SettingsCodec.encodeBool(settings.showHiddenAudioFiles)),
      _db.setSetting(_snapshotPrefix, SettingsCodec.encodeString(settings.snapshotPrefix)),
      _db.setSetting(_doubleTapSeekSeconds, SettingsCodec.encodeInt(settings.doubleTapSeekSeconds)),
      _db.setSetting(_maxConcurrentTasks, SettingsCodec.encodeInt(settings.maxConcurrentTasks)),
      _db.setSetting(_globalSortOption, settings.globalSortOption.name),
      _db.setSetting(_resumePlayback, SettingsCodec.encodeBool(settings.resumePlayback)),
      _db.setSetting(_audioSeekSeconds, SettingsCodec.encodeInt(settings.audioSeekSeconds)),
      _db.setSetting(_selectedHwDec, SettingsCodec.encodeString(settings.selectedHwDec)),
      _db.setSetting(_trackpadSpeedControl, settings.trackpadSpeedControl.name),
      _db.setSetting(_filePickerWidth, SettingsCodec.encodeDouble(settings.filePickerWidth)),
      _db.setSetting(_filePickerHeight, SettingsCodec.encodeDouble(settings.filePickerHeight)),
      _db.setSetting(_settingsWidth, SettingsCodec.encodeDouble(settings.settingsWidth)),
      _db.setSetting(_settingsHeight, SettingsCodec.encodeDouble(settings.settingsHeight)),
      _db.setSetting(_downloaderWidth, SettingsCodec.encodeDouble(settings.downloaderWidth)),
      _db.setSetting(_downloaderHeight, SettingsCodec.encodeDouble(settings.downloaderHeight)),
      _db.setSetting(_confirmDeleteImage, SettingsCodec.encodeBool(settings.confirmDeleteImage)),
      _db.setSetting(_confirmDeleteVideo, SettingsCodec.encodeBool(settings.confirmDeleteVideo)),
      _db.setSetting(_confirmDeleteDocument, SettingsCodec.encodeBool(settings.confirmDeleteDocument)),
      _db.setSetting(_confirmDeleteAudio, SettingsCodec.encodeBool(settings.confirmDeleteAudio)),
      _db.setSetting(_downloadToCurrentFolder, SettingsCodec.encodeBool(settings.downloadToCurrentFolder)),
      _db.setSetting(_maxConcurrentDownloads, SettingsCodec.encodeInt(settings.maxConcurrentDownloads)),
      _db.setSetting(_maxLiveRecordingMinutes, SettingsCodec.encodeInt(settings.maxLiveRecordingMinutes)),
      _db.setSetting(_documentSearchCaseSensitive, SettingsCodec.encodeBool(settings.documentSearchCaseSensitive)),
      _db.setSetting(_documentSearchUseRegex, SettingsCodec.encodeBool(settings.documentSearchUseRegex)),
      _db.setSetting(_audioPlayerVolume, SettingsCodec.encodeDouble(settings.audioPlayerVolume)),
      _db.setSetting(_videoPlayerVolume, SettingsCodec.encodeDouble(settings.videoPlayerVolume)),
      // Nullable
      settings.cachedResolvedHwDec != null
          ? _db.setSetting(_cachedResolvedHwDec, settings.cachedResolvedHwDec!)
          : _db.removeSetting(_cachedResolvedHwDec),
      settings.downloadBrowser != null
          ? _db.setSetting(_downloadBrowser, settings.downloadBrowser!)
          : _db.removeSetting(_downloadBrowser),
      // Pinned folders
      _db.savePinnedFolders(settings.pinnedFolders),
    ]);
  }

  @override
  Future<void> setAutoPlayNext({required bool value}) =>
      _db.setSetting(_autoPlayNext, SettingsCodec.encodeBool(value));

  @override
  Future<void> setShowHiddenFiles({required bool value}) =>
      _db.setSetting(_showHiddenFiles, SettingsCodec.encodeBool(value));

  @override
  Future<void> setShowHiddenAudioFiles({required bool value}) =>
      _db.setSetting(_showHiddenAudioFiles, SettingsCodec.encodeBool(value));

  @override
  Future<void> setSnapshotPrefix(String value) =>
      _db.setSetting(_snapshotPrefix, SettingsCodec.encodeString(value));

  @override
  Future<void> setDoubleTapSeekSeconds(int value) =>
      _db.setSetting(_doubleTapSeekSeconds, SettingsCodec.encodeInt(value));

  @override
  Future<void> setResumePlayback({required bool value}) =>
      _db.setSetting(_resumePlayback, SettingsCodec.encodeBool(value));

  @override
  Future<void> setAudioSeekSeconds(int value) =>
      _db.setSetting(_audioSeekSeconds, SettingsCodec.encodeInt(value));

  @override
  Future<void> setSelectedHwDec(String value) =>
      _db.setSetting(_selectedHwDec, SettingsCodec.encodeString(value));

  @override
  Future<void> setCachedResolvedHwDec(String? value) async {
    if (value != null) {
      await _db.setSetting(_cachedResolvedHwDec, value);
    } else {
      await _db.removeSetting(_cachedResolvedHwDec);
    }
  }

  @override
  Future<void> setTrackpadSpeedControl({required SpeedControlOption value}) =>
      _db.setSetting(_trackpadSpeedControl, value.name);

  @override
  Future<void> setFilePickerDimensions(double width, double height) =>
      Future.wait([
        _db.setSetting(_filePickerWidth, SettingsCodec.encodeDouble(width)),
        _db.setSetting(_filePickerHeight, SettingsCodec.encodeDouble(height)),
      ]);

  @override
  Future<void> setSettingsDimensions(double width, double height) =>
      Future.wait([
        _db.setSetting(_settingsWidth, SettingsCodec.encodeDouble(width)),
        _db.setSetting(_settingsHeight, SettingsCodec.encodeDouble(height)),
      ]);

  @override
  Future<void> setDownloaderDimensions(double width, double height) =>
      Future.wait([
        _db.setSetting(_downloaderWidth, SettingsCodec.encodeDouble(width)),
        _db.setSetting(_downloaderHeight, SettingsCodec.encodeDouble(height)),
      ]);

  @override
  Future<void> setDownloadBrowser(String? browser) async {
    if (browser != null) {
      await _db.setSetting(_downloadBrowser, browser);
    } else {
      await _db.removeSetting(_downloadBrowser);
    }
  }

  @override
  Future<void> setDownloadToCurrentFolder({required bool value}) =>
      _db.setSetting(_downloadToCurrentFolder, SettingsCodec.encodeBool(value));

  // ── Open With Dialog geometry ─────────────────────────────────────────────

  Future<(double width, double height)> getOpenWithDialogSize() async {
    final w = SettingsCodec.decodeDouble(
      await _db.getSetting(_openWithDialogWidth),
      fallback: 500.0,
    );
    final h = SettingsCodec.decodeDouble(
      await _db.getSetting(_openWithDialogHeight),
      fallback: 650.0,
    );
    return (w, h);
  }

  Future<void> setOpenWithDialogSize(double width, double height) =>
      Future.wait([
        _db.setSetting(_openWithDialogWidth, SettingsCodec.encodeDouble(width)),
        _db.setSetting(_openWithDialogHeight, SettingsCodec.encodeDouble(height)),
      ]);

  // ── Downloader panel width ────────────────────────────────────────────────

  Future<double> getDownloadsPanelWidth() async {
    return SettingsCodec.decodeDouble(
      await _db.getSetting(_sidePanelWidthPixels),
      fallback: 320.0,
    );
  }

  Future<void> setDownloadsPanelWidth(double width) =>
      _db.setSetting(_sidePanelWidthPixels, SettingsCodec.encodeDouble(width));

  // ——— Gallery Sorting ———

  @override
  Future<void> setFolderSort(String path, SortOption option) =>
      _db.setFolderSort(path, option.name);

  @override
  Future<void> removeFolderSorts(List<String> paths) =>
      _db.removeFolderSorts(paths);

  // ——— Gallery Pinning ———

  // In-memory cache of pinned folders (loaded on startup via load())
  List<String> _pinnedFolders = [];

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
    await _db.savePinnedFolders(_pinnedFolders);
  }

  @override
  Future<void> movePinUp(String path) async {
    final index = _pinnedFolders.indexOf(path);
    if (index > 0) {
      _pinnedFolders
        ..removeAt(index)
        ..insert(index - 1, path);
      await _db.savePinnedFolders(_pinnedFolders);
    }
  }

  @override
  Future<void> movePinDown(String path) async {
    final index = _pinnedFolders.indexOf(path);
    if (index >= 0 && index < _pinnedFolders.length - 1) {
      _pinnedFolders
        ..removeAt(index)
        ..insert(index + 1, path);
      await _db.savePinnedFolders(_pinnedFolders);
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
      await _db.savePinnedFolders(_pinnedFolders);
    }
  }
}
