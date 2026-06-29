import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';
import 'package:hive/hive.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';

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

class DownloadsPanelWidthNotifier extends Notifier<double> {
  static const String _boxName = 'ui_settings';
  static const String _key = 'side_panel_width_pixels';

  @override
  double build() {
    final box = Hive.box<dynamic>(_boxName);
    return box.get(_key, defaultValue: 320.0) as double;
  }

  void updateWidth(double newWidth) {
    state = newWidth;
    Hive.box<dynamic>(_boxName).put(_key, newWidth);
  }
}

final downloadsPanelWidthProvider =
    NotifierProvider<DownloadsPanelWidthNotifier, double>(
      DownloadsPanelWidthNotifier.new,
    );

final isDownloadsPanelDraggingProvider = StateProvider<bool>((ref) => false);

class DownloadsListCache {
  List<MediaGroup>? parsedItems;
  final Map<int, DownloadConfig> configs = {};
  String? importedListName;
  String? importedListPath;
  bool isListChanged = false;

  void clear() {
    parsedItems = null;
    configs.clear();
    importedListName = null;
    importedListPath = null;
    isListChanged = false;
  }
}

final downloadsListCacheProvider = Provider<DownloadsListCache>(
  (ref) => DownloadsListCache(),
);
