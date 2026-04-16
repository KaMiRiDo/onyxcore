import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  late SharedPreferences _prefs;

  // Video playback settings
  bool _singleTapPlayPause = false;
  bool _autoPlayNext = false;
  String _snapshotPrefix = "snapshot";
  int _doubleTapSeekSeconds = 10;

  // Privacy Settings
  bool _isPrivacyLockEnabled = false;
  String _privacyPassphrase = "";

  // Settings Cache for Aspect Ratio
  Map<String, double> _imageAspectRatioCache = {};
  
  // Gallery Sort Settings (path -> sortKey)
  Map<String, String> _gallerySortSettings = {};
  
  // Pinned Folders
  List<String> _pinnedFolders = [];
  bool _isVaultUnlocked = false;

  bool get singleTapPlayPause => _singleTapPlayPause;
  bool get autoPlayNext => _autoPlayNext;
  String get snapshotPrefix => _snapshotPrefix;
  int get doubleTapSeekSeconds => _doubleTapSeekSeconds;

  // Privacy
  bool get isPrivacyLockEnabled => _isPrivacyLockEnabled;
  String get privacyPassphrase => _privacyPassphrase;

  // Aspect Ratio Cache
  Map<String, double> get imageAspectRatioCache => _imageAspectRatioCache;
  bool get isVaultUnlocked => _isVaultUnlocked;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    
    _singleTapPlayPause = _prefs.getBool('singleTapPlayPause') ?? false;
    _autoPlayNext = _prefs.getBool('autoPlayNext') ?? false;
    _snapshotPrefix = _prefs.getString('snapshotPrefix') ?? "snapshot";
    _doubleTapSeekSeconds = _prefs.getInt('doubleTapSeekSeconds') ?? 10;

    _isPrivacyLockEnabled = _prefs.getBool('isPrivacyLockEnabled') ?? false;
    _privacyPassphrase = _prefs.getString('privacyPassphrase') ?? "";

    String? cacheStr = _prefs.getString('imageAspectRatioCache');
    if (cacheStr != null && cacheStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(cacheStr) as Map<String, dynamic>;
        _imageAspectRatioCache = decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
      } catch (_) {}
    }

    String? sortStr = _prefs.getString('gallerySortSettings');
    if (sortStr != null && sortStr.isNotEmpty) {
      try {
        final decoded = jsonDecode(sortStr) as Map<String, dynamic>;
        _gallerySortSettings = Map<String, String>.from(decoded);
      } catch (_) {}
    }

    _pinnedFolders = _prefs.getStringList('pinnedFolders') ?? [];

    notifyListeners();
  }

  Future<void> setSingleTapPlayPause(bool value) async {
    _singleTapPlayPause = value;
    await _prefs.setBool('singleTapPlayPause', value);
    notifyListeners();
  }

  Future<void> setAutoPlayNext(bool value) async {
    _autoPlayNext = value;
    await _prefs.setBool('autoPlayNext', value);
    notifyListeners();
  }

  Future<void> setSnapshotPrefix(String value) async {
    _snapshotPrefix = value;
    await _prefs.setString('snapshotPrefix', value);
    notifyListeners();
  }

  Future<void> setDoubleTapSeekSeconds(int value) async {
    _doubleTapSeekSeconds = value;
    await _prefs.setInt('doubleTapSeekSeconds', value);
    notifyListeners();
  }

  Future<void> setPrivacyLockEnabled(bool value) async {
    _isPrivacyLockEnabled = value;
    await _prefs.setBool('isPrivacyLockEnabled', value);
    notifyListeners();
  }

  Future<void> setPrivacyPassphrase(String value) async {
    _privacyPassphrase = value;
    await _prefs.setString('privacyPassphrase', value);
    notifyListeners();
  }

  Future<void> saveImageAspectRatio(String key, double ratio) async {
    _imageAspectRatioCache[key] = ratio;
    final String encoded = await compute(_serializeCache, _imageAspectRatioCache);
    await _prefs.setString('imageAspectRatioCache', encoded);
  }

  Future<void> saveImageAspectRatioBatch(Map<String, double> ratios) async {
    _imageAspectRatioCache.addAll(ratios);
    final String encoded = await compute(_serializeCache, _imageAspectRatioCache);
    await _prefs.setString('imageAspectRatioCache', encoded);
  }

  Future<void> removeImageAspectRatio(String path) async {
    if (_imageAspectRatioCache.containsKey(path)) {
      _imageAspectRatioCache.remove(path);
      final String encoded = await compute(_serializeCache, _imageAspectRatioCache);
      await _prefs.setString('imageAspectRatioCache', encoded);
    }
  }

  Future<void> removeImageAspectRatioBatch(List<String> paths) async {
    bool changed = false;
    for (var path in paths) {
      if (_imageAspectRatioCache.containsKey(path)) {
        _imageAspectRatioCache.remove(path);
        changed = true;
      }
    }
    if (changed) {
      final String encoded = await compute(_serializeCache, _imageAspectRatioCache);
      await _prefs.setString('imageAspectRatioCache', encoded);
    }
  }

  Future<void> removeImageAspectRatioForFolder(String folderPath) async {
    bool changed = false;
    final keysToRemove = _imageAspectRatioCache.keys.where((k) => k.startsWith(folderPath)).toList();
    for (var key in keysToRemove) {
      _imageAspectRatioCache.remove(key);
      changed = true;
    }
    if (changed) {
      final String encoded = await compute(_serializeCache, _imageAspectRatioCache);
      await _prefs.setString('imageAspectRatioCache', encoded);
    }
  }

  // ——— Gallery Sorting ———
  String getFolderSort(String path) {
    return _gallerySortSettings[path] ?? 'date_desc';
  }

  Future<void> setFolderSort(String path, String sortKey) async {
    _gallerySortSettings[path] = sortKey;
    await _prefs.setString('gallerySortSettings', jsonEncode(_gallerySortSettings));
    notifyListeners();
  }

  // ——— Gallery Pinning ———
  List<String> get pinnedFolders => _pinnedFolders;

  bool isFolderPinned(String path) {
    return _pinnedFolders.contains(path);
  }

  Future<void> togglePinFolders(List<String> paths) async {
    for (String path in paths) {
      if (_pinnedFolders.contains(path)) {
        _pinnedFolders.remove(path);
      } else {
        _pinnedFolders.remove(path);
        _pinnedFolders.add(path); // First pinned first
      }
    }
    await _prefs.setStringList('pinnedFolders', _pinnedFolders);
    notifyListeners();
  }

  Future<void> movePinUp(String path) async {
    int index = _pinnedFolders.indexOf(path);
    if (index > 0) {
      _pinnedFolders.removeAt(index);
      _pinnedFolders.insert(index - 1, path);
      await _prefs.setStringList('pinnedFolders', _pinnedFolders);
      notifyListeners();
    }
  }

  Future<void> movePinDown(String path) async {
    int index = _pinnedFolders.indexOf(path);
    if (index >= 0 && index < _pinnedFolders.length - 1) {
      _pinnedFolders.removeAt(index);
      _pinnedFolders.insert(index + 1, path);
      await _prefs.setStringList('pinnedFolders', _pinnedFolders);
      notifyListeners();
    }
  }

  Future<void> reorderPin(String sourcePath, String targetPath) async {
    if (sourcePath == targetPath) return;
    int sourceIndex = _pinnedFolders.indexOf(sourcePath);
    int targetIndex = _pinnedFolders.indexOf(targetPath);
    if (sourceIndex != -1 && targetIndex != -1) {
      _pinnedFolders.removeAt(sourceIndex);
      int insertIndex = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex;
      _pinnedFolders.insert(insertIndex, sourcePath);
      await _prefs.setStringList('pinnedFolders', _pinnedFolders);
      notifyListeners();
    }
  }

  Future<void> removeMissingPinnedFoldersInPath(String currentPath, List<String> currentValidFoldersInPath) async {
    bool changed = false;
    for (String path in List.from(_pinnedFolders)) {
      final String expectedParent;
      if (path.contains('/')) {
        expectedParent = path.substring(0, path.lastIndexOf('/'));
      } else {
        expectedParent = "";
      }
      
      if (expectedParent == currentPath && !currentValidFoldersInPath.contains(path)) {
        _pinnedFolders.remove(path);
        changed = true;
      }
    }
    if (changed) {
      await _prefs.setStringList('pinnedFolders', _pinnedFolders);
      notifyListeners();
    }
  }

  void setVaultUnlocked(bool value) {
    _isVaultUnlocked = value;
    notifyListeners();
  }

  // Use a dedicated static helper for Isolate serialization
  static String _serializeCache(Map<String, double> cache) => jsonEncode(cache);
}
