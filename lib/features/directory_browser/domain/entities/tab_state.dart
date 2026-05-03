import 'package:path/path.dart' as p;

class TabState {
  final String id;
  final String currentPath;
  final List<String> history;
  final int historyIndex;
  final Set<String> selectedPaths;
  final String searchQuery;
  final bool isSearchActive;
  final bool isLocationEditing;
  final int refreshCount;
  final bool isRefreshing;

  TabState({
    required this.id,
    required this.currentPath,
    this.history = const [],
    this.historyIndex = 0,
    this.selectedPaths = const {},
    this.searchQuery = '',
    this.isSearchActive = false,
    this.isLocationEditing = false,
    this.refreshCount = 0,
    this.isRefreshing = false,
  });

  String get title => currentPath == '/' ? 'Root' : p.basename(currentPath);

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
    bool? isLocationEditing,
    int? refreshCount,
    bool? isRefreshing,
  }) {
    return TabState(
      id: id ?? this.id,
      currentPath: currentPath ?? this.currentPath,
      history: history ?? this.history,
      historyIndex: historyIndex ?? this.historyIndex,
      selectedPaths: selectedPaths ?? this.selectedPaths,
      searchQuery: searchQuery ?? this.searchQuery,
      isSearchActive: isSearchActive ?? this.isSearchActive,
      isLocationEditing: isLocationEditing ?? this.isLocationEditing,
      refreshCount: refreshCount ?? this.refreshCount,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}
