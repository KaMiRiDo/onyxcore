// ignore_for_file: cascade_invocations
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/downloader_filter_settings.dart';

class DownloaderViewPreferences {
  final Map<String, ({String sort, DownloaderFilterSettings filter})> _prefs = {};

  ({String sort, DownloaderFilterSettings filter}) getPrefs(String viewKey) {
    return _prefs[viewKey] ?? (sort: 'added_desc', filter: const DownloaderFilterSettings());
  }

  void updateSort(String viewKey, String sort) {
    final current = getPrefs(viewKey);
    _prefs[viewKey] = (sort: sort, filter: current.filter);
  }

  void updateFilter(String viewKey, DownloaderFilterSettings filter) {
    final current = getPrefs(viewKey);
    _prefs[viewKey] = (sort: current.sort, filter: filter);
  }

  void clear() {
    _prefs.clear();
  }
}

void main() {
  group('Per-View Filter & Sort Isolation Unit Tests', () {
    test('root filters do not affect sublist and previous preferences are restored upon return', () {
      final manager = DownloaderViewPreferences();

      const rootKey = 'root';
      const sublistKey = 'https://example.com/post/123';

      // 1. Initial root state should be default
      final rootInitial = manager.getPrefs(rootKey);
      expect(rootInitial.sort, 'added_desc');
      expect(rootInitial.filter.isDefault, isTrue);

      // 2. User filters & sorts in root
      const rootFilter = DownloaderFilterSettings(selectedTypes: {DownloaderItemType.image});
      manager.updateSort(rootKey, 'size_desc');
      manager.updateFilter(rootKey, rootFilter);

      expect(manager.getPrefs(rootKey).sort, 'size_desc');
      expect(manager.getPrefs(rootKey).filter.selectedTypes, {DownloaderItemType.image});

      // 3. User navigates to sublist -> sublist should be default
      final sublistInitial = manager.getPrefs(sublistKey);
      expect(sublistInitial.sort, 'added_desc');
      expect(sublistInitial.filter.isDefault, isTrue);

      // 4. User changes sublist sort to added_asc
      manager.updateSort(sublistKey, 'added_asc');
      expect(manager.getPrefs(sublistKey).sort, 'added_asc');

      // 5. User navigates back to root -> root sort & filter remain intact
      final rootRestored = manager.getPrefs(rootKey);
      expect(rootRestored.sort, 'size_desc');
      expect(rootRestored.filter.selectedTypes, {DownloaderItemType.image});

      // 6. User navigates back to sublist -> sublist sort remains intact
      final sublistRestored = manager.getPrefs(sublistKey);
      expect(sublistRestored.sort, 'added_asc');

      // 7. On clear (app close), temporary preferences are wiped
      manager.clear();
      expect(manager.getPrefs(rootKey).sort, 'added_desc');
      expect(manager.getPrefs(rootKey).filter.isDefault, isTrue);
    });
  });
}
