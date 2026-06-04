import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/filter_settings.dart';

class TabState {
  final String id;
  final String currentPath;
  final List<String> history;
  final int historyIndex;
  final Set<String> selectedPaths;
  final String searchQuery;
  final bool isSearchActive;
  final bool isAnalysisActive;
  final bool isLocationEditing;
  final int refreshCount;
  final bool isRefreshing;
  final SortSettings sortSettings;
  final FilterSettings filterSettings;

  TabState({
    required this.id,
    required this.currentPath,
    this.history = const [],
    this.historyIndex = 0,
    this.selectedPaths = const {},
    this.searchQuery = '',
    this.isSearchActive = false,
    this.isAnalysisActive = false,
    this.isLocationEditing = false,
    this.refreshCount = 0,
    this.isRefreshing = false,
    this.sortSettings = const SortSettings(),
    this.filterSettings = const FilterSettings(),
  });

  String get title {
    if (currentPath == '/') return 'Root';
    if (currentPath == Platform.environment['HOME']) return 'Home';
    if (currentPath.endsWith('.local/share/Trash/files') || currentPath == 'trash:///') return 'Trash';
    return p.basename(currentPath);
  }

  bool get canGoBack => historyIndex > 0;
  bool get canGoForward => historyIndex < history.length - 1;

  TabState copyWith({
    String? id,
    String? currentPath,
    List<String>? history,
    int? historyIndex,
    Set<String>? selectedPaths,
    String? searchQuery,
    bool? isSearchActive,
    bool? isAnalysisActive,
    bool? isLocationEditing,
    int? refreshCount,
    bool? isRefreshing,
    SortSettings? sortSettings,
    FilterSettings? filterSettings,
  }) {
    return TabState(
      id: id ?? this.id,
      currentPath: currentPath ?? this.currentPath,
      history: history ?? this.history,
      historyIndex: historyIndex ?? this.historyIndex,
      selectedPaths: selectedPaths ?? this.selectedPaths,
      searchQuery: searchQuery ?? this.searchQuery,
      isSearchActive: isSearchActive ?? this.isSearchActive,
      isAnalysisActive: isAnalysisActive ?? this.isAnalysisActive,
      isLocationEditing: isLocationEditing ?? this.isLocationEditing,
      refreshCount: refreshCount ?? this.refreshCount,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      sortSettings: sortSettings ?? this.sortSettings,
      filterSettings: filterSettings ?? this.filterSettings,
    );
  }
}
