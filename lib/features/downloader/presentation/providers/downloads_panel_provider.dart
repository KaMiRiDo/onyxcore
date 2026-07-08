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
final isDownloadInputFocusedProvider = StateProvider<bool>((ref) => false);
final isDownloadsPanelFocusedProvider = StateProvider<bool>((ref) => false);
final downloadUrlFocusRequestProvider = StateProvider<int>((ref) => 0);

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

  void notify() {
    notifyListeners();
  }

  void clear() {
    _activeState.parsedItems = null;
    _activeState.configs.clear();
    _activeState.importedListName = null;
    _activeState.importedListPath = null;
    _activeState.isListChanged = false;
    notifyListeners();
  }
}

final downloadsListCacheProvider = ChangeNotifierProvider<DownloadsListCache>(
  (ref) => DownloadsListCache(),
);
