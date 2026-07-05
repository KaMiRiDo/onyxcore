import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/domain/repositories/settings_repository.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async => AppSettings();
}

void main() {
  setUpAll(() {
    registerFallbackValue(SortOption.aToZ);
  });

  group('TabManager Tests', () {
    late ProviderContainer container;
    late MockSettingsRepository mockSettingsRepository;

    setUp(() {
      mockSettingsRepository = MockSettingsRepository();
      when(() => mockSettingsRepository.load()).thenAnswer((_) async => AppSettings());
      when(() => mockSettingsRepository.getFolderSort(any(), any())).thenReturn(SortOption.aToZ);
      when(() => mockSettingsRepository.setFolderSort(any(), any())).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockSettingsRepository),
          settingsProvider.overrideWith(MockSettingsNotifier.new),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('Initial state has one tab', () {
      final state = container.read(tabManagerProvider);
      expect(state.tabs.length, 1);
      expect(state.activeTabIndex, 0);
    });

    test('addTab creates a new tab and makes it active', () {
      final tabManager = container.read(tabManagerProvider.notifier);
      tabManager.addTab(path: '/test/path');

      final state = container.read(tabManagerProvider);
      expect(state.tabs.length, 2);
      expect(state.activeTabIndex, 1);
      expect(state.activeTab.currentPath, '/test/path');
      expect(state.activeTab.history, ['/test/path']);
    });

    test('closeTab removes a tab and updates active index', () {
      final tabManager = container.read(tabManagerProvider.notifier);
      tabManager.addTab(path: '/test/path1');
      tabManager.addTab(path: '/test/path2');

      var state = container.read(tabManagerProvider);
      expect(state.tabs.length, 3);
      final idToClose = state.tabs[1].id;

      tabManager.closeTab(idToClose);

      state = container.read(tabManagerProvider);
      expect(state.tabs.length, 2);
      expect(state.activeTabIndex, 1); // should shift from 2 to 1
    });

    test('closeTab does not remove the last tab', () {
      final tabManager = container.read(tabManagerProvider.notifier);
      final state = container.read(tabManagerProvider);
      
      tabManager.closeTab(state.tabs[0].id);
      
      final newState = container.read(tabManagerProvider);
      expect(newState.tabs.length, 1);
    });

    test('switchTab changes active tab', () {
      final tabManager = container.read(tabManagerProvider.notifier);
      tabManager.addTab(path: '/test/path1');
      
      tabManager.switchTab(0);
      expect(container.read(tabManagerProvider).activeTabIndex, 0);
      
      tabManager.switchTab(1);
      expect(container.read(tabManagerProvider).activeTabIndex, 1);
    });

    test('switchToNextTab and switchToPreviousTab wrap around properly', () {
      final tabManager = container.read(tabManagerProvider.notifier);
      tabManager.addTab();
      tabManager.addTab(); // 3 tabs total

      tabManager.switchTab(0);
      tabManager.switchToPreviousTab();
      expect(container.read(tabManagerProvider).activeTabIndex, 2);

      tabManager.switchToNextTab();
      expect(container.read(tabManagerProvider).activeTabIndex, 0);
    });

    test('updateTabPath updates path and clears forward history', () {
      final tabManager = container.read(tabManagerProvider.notifier);
      final tabId = container.read(tabManagerProvider).activeTab.id;

      tabManager.updateTabPath(tabId, '/new/path');
      
      var state = container.read(tabManagerProvider);
      expect(state.activeTab.currentPath, '/new/path');
      expect(state.activeTab.history.length, 2);
      expect(state.activeTab.historyIndex, 1);

      tabManager.navigateBack(tabId);
      
      tabManager.updateTabPath(tabId, '/another/path');
      state = container.read(tabManagerProvider);
      expect(state.activeTab.history.length, 2); // Overwrote forward history
      expect(state.activeTab.currentPath, '/another/path');
    });

    test('navigateBack and navigateForward work correctly', () {
      final tabManager = container.read(tabManagerProvider.notifier);
      final tabId = container.read(tabManagerProvider).activeTab.id;

      tabManager.updateTabPath(tabId, '/path2');
      tabManager.updateTabPath(tabId, '/path3');

      tabManager.navigateBack(tabId);
      expect(container.read(tabManagerProvider).activeTab.currentPath, '/path2');

      tabManager.navigateBack(tabId);
      // Depending on initial path, it goes back
      
      tabManager.navigateForward(tabId);
      expect(container.read(tabManagerProvider).activeTab.currentPath, '/path2');
    });

    test('Property update methods update tab state', () {
      final tabManager = container.read(tabManagerProvider.notifier);
      final tabId = container.read(tabManagerProvider).activeTab.id;

      tabManager.setSearchActive(tabId, true);
      expect(container.read(tabManagerProvider).activeTab.isSearchActive, true);

      tabManager.updateSearchQuery(tabId, 'query');
      expect(container.read(tabManagerProvider).activeTab.searchQuery, 'query');

      tabManager.setAnalysisActive(tabId, true);
      expect(container.read(tabManagerProvider).activeTab.isAnalysisActive, true);

      tabManager.setLocationEditing(tabId, true);
      expect(container.read(tabManagerProvider).activeTab.isLocationEditing, true);

      tabManager.setRefreshing(tabId, true);
      expect(container.read(tabManagerProvider).activeTab.isRefreshing, true);

      final initialCount = container.read(tabManagerProvider).activeTab.refreshCount;
      tabManager.incrementRefreshCount(tabId);
      expect(container.read(tabManagerProvider).activeTab.refreshCount, initialCount + 1);
    });
  });
}
