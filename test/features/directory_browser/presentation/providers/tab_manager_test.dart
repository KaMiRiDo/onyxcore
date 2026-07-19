// ignore_for_file: join_return_with_assignment, cascade_invocations, inference_failure_on_instance_creation
import 'dart:async';
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
  Completer<AppSettings> completer = Completer<AppSettings>();

  @override
  Future<AppSettings> build() => completer.future;

  void finishInitialLoad(AppSettings settings) {
    if (!completer.isCompleted) {
      completer.complete(settings);
    } else {
      state = AsyncValue.data(settings);
    }
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(SortOption.aToZ);
  });

  group('TabManager Tests', () {
    late ProviderContainer container;
    late MockSettingsRepository mockSettingsRepository;
    late MockSettingsNotifier mockSettingsNotifier;

    setUp(() {
      mockSettingsRepository = MockSettingsRepository();
      when(() => mockSettingsRepository.load()).thenAnswer((_) async => AppSettings());
      when(() => mockSettingsRepository.setFolderSort(any(), any())).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(mockSettingsRepository),
          settingsProvider.overrideWith(() {
            mockSettingsNotifier = MockSettingsNotifier();
            return mockSettingsNotifier;
          }),
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
      mockSettingsNotifier.finishInitialLoad(AppSettings());
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
      mockSettingsNotifier.finishInitialLoad(AppSettings());
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

    test('updateSortSettings sets sort order and updates settingsProvider', () async {
      mockSettingsNotifier.finishInitialLoad(AppSettings());
      final tabManager = container.read(tabManagerProvider.notifier);
      final tabId = container.read(tabManagerProvider).activeTab.id;

      tabManager.updateSortSettings(tabId, const SortSettings(option: SortOption.lastModified));
      
      final state = container.read(tabManagerProvider);
      expect(state.activeTab.sortSettings.option, SortOption.lastModified);

      verify(() => mockSettingsRepository.setFolderSort(any(), SortOption.lastModified)).called(1);
    });

    test('TabManager listens to settingsProvider and automatically updates initial sort', () async {
      // 1. Initially, TabManager assigns the fallback aToZ since settingsProvider is still loading.
      expect(container.read(tabManagerProvider).activeTab.sortSettings.option, SortOption.aToZ);
      
      // 2. We simulate the settingsProvider finally finishing its async load.
      // We pass an AppSettings where the initial path has a saved sort preference of 'size'.
      final initialPath = container.read(tabManagerProvider).activeTab.currentPath;
      final newSettings = AppSettings(
        gallerySortSettings: {initialPath: SortOption.sizeSmallToLarge.name},
      );
      
      mockSettingsNotifier.finishInitialLoad(newSettings);
      
      // Wait briefly for Riverpod listeners to trigger.
      await Future.delayed(Duration.zero);
      
      // 3. The TabManager should have caught the transition and updated its tabs automatically.
      expect(container.read(tabManagerProvider).activeTab.sortSettings.option, SortOption.sizeSmallToLarge);
    });
  });
}
