import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/settings/data/repositories/settings_repository_impl.dart';
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
