import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/filter_settings.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/tab_state.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:uuid/uuid.dart';

class TabManagerState {

  TabManagerState({
    required this.tabs,
    required this.activeTabIndex,
  });
  final List<TabState> tabs;
  final int activeTabIndex;

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

    ref.listen(settingsProvider, (previous, next) {
      if (previous?.hasValue != true && next.hasValue && next.value != null) {
        final currentTabs = state.tabs;
        final newTabs = currentTabs.map((tab) {
          return tab.copyWith(
            sortSettings: SortSettings(option: _getFolderSort(tab.currentPath)),
          );
        }).toList();
        state = state.copyWith(tabs: newTabs);
      }
    });

    return TabManagerState(
      tabs: [
        TabState(
          id: const Uuid().v4(),
          currentPath: home,
          history: [home],
          sortSettings: SortSettings(
            option: _getFolderSort(home),
          ),
        ),
      ],
      activeTabIndex: 0,
    );
  }

  SortOption _getFolderSort(String path) {
    final settingsState = ref.read(settingsProvider).value;
    final globalSort = settingsState?.globalSortOption ?? SortOption.aToZ;
    
    if (settingsState != null) {
      final savedSortStr = settingsState.gallerySortSettings[path];
      if (savedSortStr != null) {
        return SortOption.values.firstWhere(
          (e) => e.name == savedSortStr,
          orElse: () => globalSort,
        );
      }
    }
    return globalSort;
  }

  void addTab({String? path, List<String>? history, int? historyIndex}) {
    final home = Platform.environment['HOME'] ?? '/';
    final newPath = path ?? home;
    final folderSort = _getFolderSort(newPath);

    final newTab = TabState(
      id: const Uuid().v4(),
      currentPath: newPath,
      history: history != null ? List<String>.from(history) : [newPath],
      historyIndex: historyIndex ?? 0,
      refreshCount: 1,
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
    var newActiveIndex = state.activeTabIndex;

    if (index <= state.activeTabIndex) {
      newActiveIndex = (state.activeTabIndex - 1).clamp(0, newTabs.length - 1);
    }

    if (newTabs.isNotEmpty && newActiveIndex < newTabs.length) {
      newTabs[newActiveIndex] = newTabs[newActiveIndex].copyWith(
        refreshCount: newTabs[newActiveIndex].refreshCount + 1,
      );
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
    final folderSort = _getFolderSort(newPath);

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

    final folderSort = _getFolderSort(newPath);

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

    final folderSort = _getFolderSort(newPath);

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

  void setSearchActive(String tabId, {required bool active}) {
    final index = state.tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    final updatedTab = state.tabs[index].copyWith(
      isSearchActive: active,
      searchQuery: active ? null : '',
    );
    final newTabs = List<TabState>.from(state.tabs)..[index] = updatedTab;
    state = state.copyWith(tabs: newTabs);
  }

  void setAnalysisActive(String tabId, {required bool active}) {
    final index = state.tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    final updatedTab = state.tabs[index].copyWith(isAnalysisActive: active);
    final newTabs = List<TabState>.from(state.tabs)..[index] = updatedTab;
    state = state.copyWith(tabs: newTabs);
  }

  void setLocationEditing(String tabId, {required bool active}) {
    final index = state.tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    final updatedTab = state.tabs[index].copyWith(isLocationEditing: active);
    final newTabs = List<TabState>.from(state.tabs)..[index] = updatedTab;
    state = state.copyWith(tabs: newTabs);
  }

  void setRefreshing(String tabId, {required bool refreshing}) {
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
    ref.read(settingsProvider.notifier).setFolderSort(tab.currentPath, sort.option);
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
  return ref.watch(tabManagerProvider.select((state) => state.activeTab.id));
});

final tabIdProvider = Provider<String>((ref) {
  // By default, it points to the active tab if not overridden
  return ref.watch(activeTabIdProvider);
});
