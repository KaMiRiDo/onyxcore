import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/tab_state.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/filter_settings.dart';

void main() {
  group('TabState', () {
    test('default constructor sets up correct defaults', () {
      final state = TabState(id: 'tab1', currentPath: '/opt');
      
      expect(state.id, 'tab1');
      expect(state.currentPath, '/opt');
      expect(state.history, isEmpty);
      expect(state.historyIndex, 0);
      expect(state.selectedPaths, isEmpty);
      expect(state.searchQuery, isEmpty);
      expect(state.isSearchActive, isFalse);
      expect(state.isAnalysisActive, isFalse);
      expect(state.isLocationEditing, isFalse);
      expect(state.refreshCount, 0);
      expect(state.isRefreshing, isFalse);
      expect(state.sortSettings, const SortSettings());
      expect(state.filterSettings, const FilterSettings());
    });

    test('title returns correct display names based on currentPath', () {
      expect(TabState(id: '1', currentPath: '/').title, 'Root');
      
      final homePath = Platform.environment['HOME'] ?? '/home/user';
      expect(TabState(id: '2', currentPath: homePath).title, 'Home');

      expect(TabState(id: '3', currentPath: '.local/share/Trash/files').title, 'Trash');
      expect(TabState(id: '4', currentPath: 'trash:///').title, 'Trash');

      expect(TabState(id: '5', currentPath: '/some/nested/folder').title, 'folder');
    });

    test('canGoBack is true only when historyIndex > 0', () {
      expect(TabState(id: '1', currentPath: '/', historyIndex: 0).canGoBack, isFalse);
      expect(TabState(id: '1', currentPath: '/', historyIndex: 1).canGoBack, isTrue);
    });

    test('canGoForward is true only when historyIndex < history.length - 1', () {
      expect(
        TabState(id: '1', currentPath: '/', history: ['/a', '/b'], historyIndex: 1).canGoForward, 
        isFalse
      );
      expect(
        TabState(id: '1', currentPath: '/', history: ['/a', '/b', '/c'], historyIndex: 1).canGoForward, 
        isTrue
      );
    });

    test('copyWith updates fields correctly', () {
      final state = TabState(id: 'tab1', currentPath: '/opt');
      
      final updated = state.copyWith(
        id: 'tab2',
        currentPath: '/home',
        history: ['/opt', '/home'],
        historyIndex: 1,
        selectedPaths: {'/home/file.txt'},
        searchQuery: 'txt',
        isSearchActive: true,
        isAnalysisActive: true,
        isLocationEditing: true,
        refreshCount: 1,
        isRefreshing: true,
        sortSettings: const SortSettings(option: SortOption.lastModified),
        filterSettings: const FilterSettings(foldersOnly: true),
      );

      expect(updated.id, 'tab2');
      expect(updated.currentPath, '/home');
      expect(updated.history, ['/opt', '/home']);
      expect(updated.historyIndex, 1);
      expect(updated.selectedPaths, {'/home/file.txt'});
      expect(updated.searchQuery, 'txt');
      expect(updated.isSearchActive, isTrue);
      expect(updated.isAnalysisActive, isTrue);
      expect(updated.isLocationEditing, isTrue);
      expect(updated.refreshCount, 1);
      expect(updated.isRefreshing, isTrue);
      expect(updated.sortSettings.option, SortOption.lastModified);
      expect(updated.filterSettings.foldersOnly, isTrue);
    });

    test('copyWith retains old fields when null is passed', () {
      final state = TabState(
        id: 'tab2',
        currentPath: '/home',
        history: ['/opt', '/home'],
        historyIndex: 1,
        selectedPaths: {'/home/file.txt'},
        searchQuery: 'txt',
        isSearchActive: true,
        isAnalysisActive: true,
        isLocationEditing: true,
        refreshCount: 1,
        isRefreshing: true,
        sortSettings: const SortSettings(option: SortOption.lastModified),
        filterSettings: const FilterSettings(foldersOnly: true),
      );
      
      final updated = state.copyWith();

      expect(updated.id, state.id);
      expect(updated.currentPath, state.currentPath);
      expect(updated.history, state.history);
      expect(updated.historyIndex, state.historyIndex);
      expect(updated.selectedPaths, state.selectedPaths);
      expect(updated.searchQuery, state.searchQuery);
      expect(updated.isSearchActive, state.isSearchActive);
      expect(updated.isAnalysisActive, state.isAnalysisActive);
      expect(updated.isLocationEditing, state.isLocationEditing);
      expect(updated.refreshCount, state.refreshCount);
      expect(updated.isRefreshing, state.isRefreshing);
      expect(updated.sortSettings, state.sortSettings);
      expect(updated.filterSettings, state.filterSettings);
    });
  });
}
