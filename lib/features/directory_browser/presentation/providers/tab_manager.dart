import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tab_state.dart';

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
        ),
      ],
      activeTabIndex: 0,
    );
  }

  void addTab({String? path, List<String>? history, int? historyIndex}) {
    final home = Platform.environment['HOME'] ?? '/';
    final newPath = path ?? home;
    final newTab = TabState(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      currentPath: newPath,
      history: history != null ? List<String>.from(history) : [newPath],
      historyIndex: historyIndex ?? 0,
    );
    
    state = state.copyWith(
      tabs: [...state.tabs, newTab],
      activeTabIndex: state.tabs.length,
    );
  }

  void closeTab(String id) {
    if (state.tabs.length <= 1) {
      // Close window logic handled in app.dart usually, 
      // but here we just keep at least one tab or let the UI handle exit.
      exit(0);
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
    final prevIndex = (state.activeTabIndex - 1 + state.tabs.length) % state.tabs.length;
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

    final updatedTab = tab.copyWith(
      currentPath: newPath,
      history: history,
      historyIndex: historyIndex,
      selectedPaths: {}, // Clear selection on navigate
    );

    final newTabs = List<TabState>.from(state.tabs)..[index] = updatedTab;
    state = state.copyWith(tabs: newTabs);
  }

  void navigateBack(String tabId) {
    final index = state.tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    final tab = state.tabs[index];
    if (!tab.canGoBack) return;

    final updatedTab = tab.copyWith(
      historyIndex: tab.historyIndex - 1,
      currentPath: tab.history[tab.historyIndex - 1],
      selectedPaths: {},
    );

    final newTabs = List<TabState>.from(state.tabs)..[index] = updatedTab;
    state = state.copyWith(tabs: newTabs);
  }

  void navigateForward(String tabId) {
    final index = state.tabs.indexWhere((t) => t.id == tabId);
    if (index == -1) return;

    final tab = state.tabs[index];
    if (!tab.canGoForward) return;

    final updatedTab = tab.copyWith(
      historyIndex: tab.historyIndex + 1,
      currentPath: tab.history[tab.historyIndex + 1],
      selectedPaths: {},
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
      refreshCount: state.tabs[index].refreshCount + 1
    );
    final newTabs = List<TabState>.from(state.tabs)..[index] = updatedTab;
    state = state.copyWith(tabs: newTabs);
  }
}

final tabManagerProvider = NotifierProvider<TabManager, TabManagerState>(TabManager.new);

final activeTabIdProvider = Provider<String>((ref) {
  final state = ref.watch(tabManagerProvider);
  return state.activeTab.id;
});

final tabIdProvider = Provider<String>((ref) {
  // By default, it points to the active tab if not overridden
  return ref.watch(activeTabIdProvider);
});
