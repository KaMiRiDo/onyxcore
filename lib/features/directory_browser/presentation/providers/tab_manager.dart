import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tab_state.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/filter_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

class TabManagerState {
  final List<TabState> tabs;
  final int activeTabIndex;

  TabManagerState({
    required this.tabs,
    required this.activeTabIndex,
  });

  TabState get activeTab => tabs[activeTabIndex];

  TabManagerState copyWith({
    List<TabState>? tabs,
    int? activeTabIndex,
  }) {
    return TabManagerState(
      tabs: tabs ?? this.tabs,
      activeTabIndex: activeTabIndex ?? this.activeTabIndex,
    );
  }
}

class TabManager extends Notifier<TabManagerState> {
  @override
  TabManagerState build() {
    final home = Platform.environment['HOME'] ?? '/';
    return TabManagerState(
      tabs: [
        TabState(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          currentPath: home,
          history: [home],
          historyIndex: 0,
          sortSettings: SortSettings(
            option: ref
                .read(settingsRepositoryProvider)
                .getFolderSort(
                  home,
                  SortOption.aToZ, // Fallback during initial build
                ),
          ),
        ),
      ],
      activeTabIndex: 0,
    );
  }

  void addTab({String? path, List<String>? history, int? historyIndex}) {
    final home = Platform.environment['HOME'] ?? '/';
    final newPath = path ?? home;
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final globalSort =
        ref.read(settingsProvider).value?.globalSortOption ?? SortOption.aToZ;
    final folderSort = settingsRepo.getFolderSort(newPath, globalSort);

    final newTab = TabState(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      currentPath: newPath,
      history: history != null ? List<String>.from(history) : [newPath],
      historyIndex: historyIndex ?? 0,
      sortSettings: SortSettings(option: folderSort),
    );

    state = state.copyWith(
      tabs: [...state.tabs, newTab],
      activeTabIndex: state.tabs.length,
    );
  }

  void closeTab(String id) {
    if (state.tabs.length <= 1) {
      // Don't close the last tab to prevent application exit.
      // Application exit should only happen via Alt+F4 or system menus.
      return;
    }

    final index = state.tabs.indexWhere((t) => t.id == id);
    if (index == -1) return;

    final newTabs = List<TabState>.from(state.tabs)..removeAt(index);
    int newActiveIndex = state.activeTabIndex;

    if (index <= state.activeTabIndex) {
      newActiveIndex = (state.activeTabIndex - 1).clamp(0, newTabs.length - 1);
    }

    state = state.copyWith(
      tabs: newTabs,
      activeTabIndex: newActiveIndex,
    );
  }

  void switchTab(int index) {
    if (index >= 0 && index < state.tabs.length) {
      state = state.copyWith(activeTabIndex: index);
    }
  }

  void switchToNextTab() {
    final nextIndex = (state.activeTabIndex + 1) % state.tabs.length;
    state = state.copyWith(activeTabIndex: nextIndex);
  }

  void switchToPreviousTab() {
    final prevIndex =
        (state.activeTabIndex - 1 + state.tabs.length) % state.tabs.length;
    state = state.copyWith(activeTabIndex: prevIndex);
  }

  void updateTabPath(String tabId, String newPath) {
    final index = state.tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    final tab = state.tabs[index];
    if (tab.currentPath == newPath) return;

    final history = List<String>.from(tab.history);
    var historyIndex = tab.historyIndex;

    // Clear forward history and add new path
    if (historyIndex < history.length - 1) {
      history.removeRange(historyIndex + 1, history.length);
    }
    history.add(newPath);
    historyIndex = history.length - 1;

    // Load folder-specific sort settings
    final settingsRepo = ref.read(settingsRepositoryProvider);
    final globalSort =
        ref.read(settingsProvider).value?.globalSortOption ?? SortOption.aToZ;
    final folderSort = settingsRepo.getFolderSort(newPath, globalSort);

    final updatedTab = tab.copyWith(
      currentPath: newPath,
      history: history,
      historyIndex: historyIndex,
      selectedPaths: {}, // Clear selection on navigate
      sortSettings: SortSettings(option: folderSort),
      filterSettings: const FilterSettings(), // Reset filter on navigate?
      isAnalysisActive: false, // Reset analysis on navigate
      // Usually users want filters cleared when moving between folders.
    );

    final newTabs = List<TabState>.from(state.tabs)..[index] = updatedTab;
    state = state.copyWith(tabs: newTabs);
  }

  void navigateBack(String tabId) {
    final index = state.tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    final tab = state.tabs[index];
    if (!tab.canGoBack) return;

    final newPath = tab.history[tab.historyIndex - 1];

    final settingsRepo = ref.read(settingsRepositoryProvider);
    final globalSort =
        ref.read(settingsProvider).value?.globalSortOption ?? SortOption.aToZ;
    final folderSort = settingsRepo.getFolderSort(newPath, globalSort);

    final updatedTab = tab.copyWith(
      historyIndex: tab.historyIndex - 1,
      currentPath: newPath,
      selectedPaths: {},
      sortSettings: SortSettings(option: folderSort),
    );

    final newTabs = List<TabState>.from(state.tabs)..[index] = updatedTab;
    state = state.copyWith(tabs: newTabs);
  }

  void navigateForward(String tabId) {
    final index = state.tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    final tab = state.tabs[index];
    if (!tab.canGoForward) return;

    final newPath = tab.history[tab.historyIndex + 1];

    final settingsRepo = ref.read(settingsRepositoryProvider);
    final globalSort =
        ref.read(settingsProvider).value?.globalSortOption ?? SortOption.aToZ;
    final folderSort = settingsRepo.getFolderSort(newPath, globalSort);

    final updatedTab = tab.copyWith(
      historyIndex: tab.historyIndex + 1,
      currentPath: newPath,
      selectedPaths: {},
      sortSettings: SortSettings(option: folderSort),
    );

    final newTabs = List<TabState>.from(state.tabs)..[index] = updatedTab;
    state = state.copyWith(tabs: newTabs);
  }

  void updateSelection(String tabId, Set<String> selection) {
    final index = state.tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    final updatedTab = state.tabs[index].copyWith(selectedPaths: selection);
    final newTabs = List<TabState>.from(state.tabs)..[index] = updatedTab;
    state = state.copyWith(tabs: newTabs);
  }

  void updateSearchQuery(String tabId, String query) {
    final index = state.tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    final updatedTab = state.tabs[index].copyWith(searchQuery: query);
    final newTabs = List<TabState>.from(state.tabs)..[index] = updatedTab;
    state = state.copyWith(tabs: newTabs);
  }

  void setSearchActive(String tabId, bool active) {
    final index = state.tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    final updatedTab = state.tabs[index].copyWith(
      isSearchActive: active,
      searchQuery: active ? null : '',
    );
    final newTabs = List<TabState>.from(state.tabs)..[index] = updatedTab;
    state = state.copyWith(tabs: newTabs);
  }

  void setAnalysisActive(String tabId, bool active) {
    final index = state.tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    final updatedTab = state.tabs[index].copyWith(isAnalysisActive: active);
    final newTabs = List<TabState>.from(state.tabs)..[index] = updatedTab;
    state = state.copyWith(tabs: newTabs);
  }

  void setLocationEditing(String tabId, bool active) {
    final index = state.tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    final updatedTab = state.tabs[index].copyWith(isLocationEditing: active);
    final newTabs = List<TabState>.from(state.tabs)..[index] = updatedTab;
    state = state.copyWith(tabs: newTabs);
  }

  void setRefreshing(String tabId, bool refreshing) {
    final index = state.tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    final updatedTab = state.tabs[index].copyWith(isRefreshing: refreshing);
    final newTabs = List<TabState>.from(state.tabs)..[index] = updatedTab;
    state = state.copyWith(tabs: newTabs);
  }

  void incrementRefreshCount(String tabId) {
    final index = state.tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    final updatedTab = state.tabs[index].copyWith(
      refreshCount: state.tabs[index].refreshCount + 1,
    );
    final newTabs = List<TabState>.from(state.tabs)..[index] = updatedTab;
    state = state.copyWith(tabs: newTabs);
  }

  void updateSortSettings(String tabId, SortSettings sort) {
    final index = state.tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    final tab = state.tabs[index];
    final updatedTab = tab.copyWith(sortSettings: sort);
    final newTabs = List<TabState>.from(state.tabs)..[index] = updatedTab;
    state = state.copyWith(tabs: newTabs);

    // Persist folder-specific sort
    final settingsRepo = ref.read(settingsRepositoryProvider);
    settingsRepo.setFolderSort(tab.currentPath, sort.option);

    // Also notify settings provider that something changed (if needed)
    // ref.invalidate(settingsProvider); // Optional
  }

  void updateFilterSettings(String tabId, FilterSettings filter) {
    final index = state.tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    final updatedTab = state.tabs[index].copyWith(filterSettings: filter);
    final newTabs = List<TabState>.from(state.tabs)..[index] = updatedTab;
    state = state.copyWith(tabs: newTabs);
  }
}

final tabManagerProvider = NotifierProvider<TabManager, TabManagerState>(
  TabManager.new,
);

final activeTabIdProvider = Provider<String>((ref) {
  final state = ref.watch(tabManagerProvider);
  return state.activeTab.id;
});

final tabIdProvider = Provider<String>((ref) {
  // By default, it points to the active tab if not overridden
  return ref.watch(activeTabIdProvider);
});
