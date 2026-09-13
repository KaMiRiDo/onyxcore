import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/settings/data/repositories/settings_repository_impl.dart';

enum DownloadsPanelView {
  tasks,
  history,
  historyDetail,
}

final downloadsPanelOpenProvider = StateProvider<bool>((ref) => false);
final downloadsPanelViewProvider = StateProvider<DownloadsPanelView>(
  (ref) => DownloadsPanelView.tasks,
);
final selectedDownloadHistoryIdProvider = StateProvider<String?>((ref) => null);
final isDownloadsPanelFocusedProvider = StateProvider<bool>((ref) => false);

class DownloadsPanelWidthNotifier extends AsyncNotifier<double> {
  @override
  Future<double> build() async {
    final db = ref.read(databaseProvider);
    final repo = SettingsRepositoryImpl(db);
    return repo.getDownloadsPanelWidth();
  }

  Future<void> updateWidth(double newWidth) async {
    state = AsyncValue.data(newWidth);
    final db = ref.read(databaseProvider);
    final repo = SettingsRepositoryImpl(db);
    await repo.setDownloadsPanelWidth(newWidth);
  }
}

final downloadsPanelWidthProvider =
    AsyncNotifierProvider<DownloadsPanelWidthNotifier, double>(
      DownloadsPanelWidthNotifier.new,
    );

final isDownloadsPanelDraggingProvider = StateProvider<bool>((ref) => false);

class _CacheState {
  List<MediaGroup>? parsedItems;
  final Map<int, DownloadConfig> configs = {};
  String? importedListName;
  String? importedListPath;
  bool isListChanged = false;
  bool isLocked = false;
  String? currentPassword;
}

class CustomListInfo {
  CustomListInfo({required this.path, required this.name, this.hasPassword = false, this.isLocked = false});
  final String path;
  final String name;
  final bool hasPassword;
  final bool isLocked;
}

class DownloadsListCache extends ChangeNotifier {
  final Map<String, _CacheState> _states = {};
  String _activePath = 'default';

  _CacheState get _activeState {
    return _states.putIfAbsent(_activePath, _CacheState.new);
  }

  void switchList(String? path) {
    _activePath = path ?? 'default';
    notifyListeners();
  }
  
  bool hasCache(String path) {
    return _states.containsKey(path);
  }
  
  bool isCacheChanged(String path) {
    return _states[path]?.isListChanged ?? false;
  }
  
  void invalidateCache(String path) {
    _states.remove(path);
    if (_activePath == path) {
      _activePath = 'default';
      notifyListeners();
    }
  }

  List<MediaGroup>? get parsedItems => _activeState.parsedItems;
  set parsedItems(List<MediaGroup>? value) {
    _activeState.parsedItems = value;
    notifyListeners();
  }

  Map<int, DownloadConfig> get configs => _activeState.configs;

  String? get importedListName => _activeState.importedListName;
  set importedListName(String? value) {
    _activeState.importedListName = value;
    notifyListeners();
  }

  String? get importedListPath => _activeState.importedListPath;
  set importedListPath(String? value) {
    _activeState.importedListPath = value;
    notifyListeners();
  }

  bool get isListChanged => _activeState.isListChanged;
  set isListChanged(bool value) {
    _activeState.isListChanged = value;
    notifyListeners();
  }

  bool get isLocked => _activeState.isLocked;
  set isLocked(bool value) {
    _activeState.isLocked = value;
    notifyListeners();
  }

  String? get currentPassword => _activeState.currentPassword;
  set currentPassword(String? value) {
    _activeState.currentPassword = value;
    notifyListeners();
  }

  List<CustomListInfo> get customLists {
    final lists = <CustomListInfo>[];
    for (final entry in _states.entries) {
      if (entry.key != 'default' && entry.value.importedListPath != null && entry.value.importedListName != null) {
        lists.add(CustomListInfo(
          path: entry.value.importedListPath!,
          name: entry.value.importedListName!,
          hasPassword: entry.value.isLocked || (entry.value.currentPassword != null && entry.value.currentPassword!.isNotEmpty),
          isLocked: entry.value.isLocked,
        ));
      }
    }
    return lists;
  }

  void notify() {
    notifyListeners();
  }

  void clear() {
    _activeState.parsedItems = null;
    _activeState.configs.clear();
    _activeState.importedListName = null;
    _activeState.importedListPath = null;
    _activeState.isListChanged = false;
    _activeState.isLocked = false;
    _activeState.currentPassword = null;
    notifyListeners();
  }

  List<MediaGroup>? getItemsForPath(String path) {
    return _states[path]?.parsedItems;
  }

  void setCacheChanged(String path, {required bool changed}) {
    if (_states.containsKey(path)) {
      _states[path]!.isListChanged = changed;
      notifyListeners();
    }
  }

  bool isLockedForPath(String path) {
    return _states[path]?.isLocked ?? false;
  }

  void lockPath(String path) {
    if (_states.containsKey(path)) {
      _states[path]!.isLocked = true;
      _states[path]!.parsedItems = null;
      _states[path]!.currentPassword = null;
      notifyListeners();
    }
  }

  bool hasPasswordForPath(String path) {
    final state = _states[path];
    if (state == null) return false;
    return state.isLocked || (state.currentPassword != null && state.currentPassword!.isNotEmpty);
  }

  String? getPasswordForPath(String path) {
    return _states[path]?.currentPassword;
  }

  void removePasswordForPath(String path) {
    if (_states.containsKey(path)) {
      _states[path]!.isLocked = false;
      _states[path]!.currentPassword = null;
      notifyListeners();
    }
  }
}

final downloadsListCacheProvider = ChangeNotifierProvider<DownloadsListCache>(
  (ref) => DownloadsListCache(),
);
