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
      autoPlayNext: _prefs.getBool('autoPlayNext') ?? false,
      showHiddenFiles: _prefs.getBool('showHiddenFiles') ?? false,
      snapshotPrefix: _prefs.getString('snapshotPrefix') ?? 'snapshot',
      doubleTapSeekSeconds: _prefs.getInt('doubleTapSeekSeconds') ?? 10,
      pinnedFolders: List<String>.from(_pinnedFolders),
      gallerySortSettings: Map<String, String>.from(_gallerySortSettings),
      maxConcurrentTasks: _prefs.getInt('maxConcurrentTasks') ?? 3,
      globalSortOption: globalSort,
    );

  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    await _prefs.setBool('autoPlayNext', settings.autoPlayNext);
    await _prefs.setBool('showHiddenFiles', settings.showHiddenFiles);
    await _prefs.setString('snapshotPrefix', settings.snapshotPrefix);
    await _prefs.setInt('doubleTapSeekSeconds', settings.doubleTapSeekSeconds);
    await _prefs.setInt('maxConcurrentTasks', settings.maxConcurrentTasks);
    await _prefs.setString('globalSortOption', settings.globalSortOption.name);
    // pinnedFolders and gallerySortSettings are currently managed via specific methods,
    // but we can include them here for a full sync if needed.
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
  Future<void> setSnapshotPrefix(String value) async {
    await _prefs.setString('snapshotPrefix', value);
  }

  @override
  Future<void> setDoubleTapSeekSeconds(int value) async {
    await _prefs.setInt('doubleTapSeekSeconds', value);
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
