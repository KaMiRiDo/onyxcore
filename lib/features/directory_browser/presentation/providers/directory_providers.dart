import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';

import 'package:onyxcore/core/cache/directory_cache.dart';
import 'package:onyxcore/core/cache/metadata_cache.dart';
import 'package:onyxcore/core/platform/directory_watcher.dart';
import 'package:onyxcore/core/utils/file_type_utils.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/directory_browser/data/datasources/local_file_datasource.dart';
import 'package:onyxcore/features/directory_browser/data/datasources/media_metadata_datasource.dart';
import 'package:onyxcore/features/directory_browser/data/repositories/directory_repository_impl.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/repositories/directory_repository.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/filter_settings.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/pinned_items_provider.dart';

// ——— Infrastructure Providers ———

final directoryWatcherProvider = Provider<DirectoryWatcher>((ref) {
  final watcher = DirectoryWatcher();
  ref.onDispose(watcher.dispose);
  return watcher;
});

final directoryCacheProvider = Provider<DirectoryCache<List<FileItem>>>((ref) {
  return DirectoryCache<List<FileItem>>();
});

final localFileDatasourceProvider = Provider<LocalFileDatasource>((ref) {
  return LocalFileDatasource();
});

final mediaMetadataDatasourceProvider = Provider<MediaMetadataDatasource>((
  ref,
) {
  final cache = ref.watch(metadataCacheProvider);
  return MediaMetadataDatasource(cache);
});

final directoryRepositoryProvider = Provider<DirectoryRepository>((ref) {
  return DirectoryRepositoryImpl(
    datasource: ref.watch(localFileDatasourceProvider),
    cache: ref.watch(directoryCacheProvider),
    watcher: ref.watch(directoryWatcherProvider),
  );
});

// ——— State Providers ———

/// The currently active directory path, scoped to the current tab.
class CurrentPathNotifier extends Notifier<String> {
  @override
  String build() {
    final tabId = ref.watch(tabIdProvider);
    return ref.watch(
      tabManagerProvider.select(
        (s) => s.tabs.firstWhere((t) => t.id == tabId).currentPath,
      ),
    );
  }

  set state(String value) {
    final tabId = ref.read(tabIdProvider);
    ref.read(tabManagerProvider.notifier).updateTabPath(tabId, value);
  }
}

final currentPathProvider = NotifierProvider<CurrentPathNotifier, String>(
  CurrentPathNotifier.new,
);

/// Per-folder zoom levels. Default 0.8x.
final zoomProvider = StateProvider<Map<String, double>>((ref) => {});

/// Current zoom for the active folder.
final currentZoomProvider = Provider<double>((ref) {
  final String path = ref.watch(currentPathProvider);
  final Map<String, double> zooms = ref.watch(zoomProvider);
  return zooms[path] ?? 0.8;
});

/// Global state for drag-and-drop operations.
final isDraggingProvider = StateProvider<bool>((ref) => false);

/// The paths currently being dragged.
final draggingPathsProvider = StateProvider<Set<String>>((ref) => {});

/// The currently previewed file (inline preview mode).
final previewFileProvider = StateProvider<FileItem?>((ref) => null);

/// Tracks if a marker editor is currently active to suppress conflicting global shortcuts.
final isMarkerEditorActiveProvider = StateProvider<bool>((ref) => false);

/// Global visibility state for the inline preview HUD.
final previewHudVisibleProvider = StateProvider<bool>((ref) => true);

/// Current search query, scoped to the current tab.
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() {
    final tabId = ref.watch(tabIdProvider);
    return ref.watch(
      tabManagerProvider.select(
        (s) => s.tabs.firstWhere((t) => t.id == tabId).searchQuery,
      ),
    );
  }

  set state(String value) {
    final tabId = ref.read(tabIdProvider);
    ref.read(tabManagerProvider.notifier).updateSearchQuery(tabId, value);
  }
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(
  SearchQueryNotifier.new,
);

/// Whether search mode is active, scoped to the current tab.
class IsSearchActiveNotifier extends Notifier<bool> {
  @override
  bool build() {
    final tabId = ref.watch(tabIdProvider);
    return ref.watch(
      tabManagerProvider.select(
        (s) => s.tabs.firstWhere((t) => t.id == tabId).isSearchActive,
      ),
    );
  }

  void set(bool value) {
    final tabId = ref.read(tabIdProvider);
    ref.read(tabManagerProvider.notifier).setSearchActive(tabId, value);
  }

  void toggle() {
    final tabId = ref.read(tabIdProvider);
    final current = ref.read(
      tabManagerProvider.select(
        (s) => s.tabs.firstWhere((t) => t.id == tabId).isSearchActive,
      ),
    );
    ref.read(tabManagerProvider.notifier).setSearchActive(tabId, !current);
  }
}

final isSearchActiveProvider = NotifierProvider<IsSearchActiveNotifier, bool>(
  IsSearchActiveNotifier.new,
);

/// Whether analysis mode is active, scoped to the current tab.
class IsAnalysisActiveNotifier extends Notifier<bool> {
  @override
  bool build() {
    final tabId = ref.watch(tabIdProvider);
    return ref.watch(
      tabManagerProvider.select(
        (s) => s.tabs.firstWhere((t) => t.id == tabId).isAnalysisActive,
      ),
    );
  }

  void set(bool value) {
    final tabId = ref.read(tabIdProvider);
    ref.read(tabManagerProvider.notifier).setAnalysisActive(tabId, value);
  }

  void toggle() {
    final tabId = ref.read(tabIdProvider);
    final current = ref.read(
      tabManagerProvider.select(
        (s) => s.tabs.firstWhere((t) => t.id == tabId).isAnalysisActive,
      ),
    );
    ref.read(tabManagerProvider.notifier).setAnalysisActive(tabId, !current);
  }
}

final isAnalysisActiveProvider =
    NotifierProvider<IsAnalysisActiveNotifier, bool>(
      IsAnalysisActiveNotifier.new,
    );

/// Whether location editing mode is active, scoped to the current tab.
class IsLocationEditingNotifier extends Notifier<bool> {
  @override
  bool build() {
    final tabId = ref.watch(tabIdProvider);
    return ref.watch(
      tabManagerProvider.select(
        (s) => s.tabs.firstWhere((t) => t.id == tabId).isLocationEditing,
      ),
    );
  }

  void set(bool value) {
    final tabId = ref.read(tabIdProvider);
    ref.read(tabManagerProvider.notifier).setLocationEditing(tabId, value);
  }

  void toggle() {
    final tabId = ref.read(tabIdProvider);
    final current = ref.read(
      tabManagerProvider.select(
        (s) => s.tabs.firstWhere((t) => t.id == tabId).isLocationEditing,
      ),
    );
    ref.read(tabManagerProvider.notifier).setLocationEditing(tabId, !current);
  }
}

final isLocationEditingProvider =
    NotifierProvider<IsLocationEditingNotifier, bool>(
      IsLocationEditingNotifier.new,
    );

/// Current error message for path editing.
final pathErrorProvider = StateProvider<String?>((ref) => null);

/// Whether the current path is a virtual path (recent, starred).
final isVirtualPathProvider = Provider<bool>((ref) {
  final String path = ref.watch(currentPathProvider);
  return path.startsWith('virtual:');
});

// ——— Sort & Filter State Providers ———

final sortSettingsProvider = Provider<SortSettings>((ref) {
  final tabId = ref.watch(tabIdProvider);
  return ref.watch(
    tabManagerProvider.select(
      (s) => s.tabs.firstWhere((t) => t.id == tabId).sortSettings,
    ),
  );
});

final filterSettingsProvider = Provider<FilterSettings>((ref) {
  final tabId = ref.watch(tabIdProvider);
  return ref.watch(
    tabManagerProvider.select(
      (s) => s.tabs.firstWhere((t) => t.id == tabId).filterSettings,
    ),
  );
});

// ——— Directory Items Provider ———

/// Loads directory items for the current path.
class DirectoryItemsNotifier extends AsyncNotifier<List<FileItem>> {
  StreamSubscription<FileChangeEvent>? _watchSubscription;

  @override
  Future<List<FileItem>> build() async {
    final String path = ref.watch(currentPathProvider);
    final showHidden = ref.watch(
      settingsProvider.select((s) => s.value?.showHiddenFiles ?? false),
    );

    // Handle virtual paths (allow filtering if data exists)
    if (path.startsWith('virtual:')) {
      if (path != 'virtual:recent' && path != 'virtual:starred') {
        return [];
      }
    }

    // Ensure directory exists
    final dir = Directory(path);
    if (!dir.existsSync()) {
      return [];
    }

    // Load items (checks cache first, then isolate)
    final repo = ref.read(directoryRepositoryProvider);
    final items = await repo.listDirectory(path);

    // Start watching for changes
    _watchSubscription?.cancel();
    _watchSubscription = repo.watchDirectory(path).listen((_) {
      // Invalidate cache and reload on any file change
      ref.read(directoryCacheProvider).invalidate(path);
      ref.invalidateSelf();
    });

    ref.onDispose(() {
      _watchSubscription?.cancel();
    });

    // Generate metadata async (aspect ratios)
    _generateMetadataAsync(items);

    return items;
  }

  /// Generates image aspect ratios in the background.
  Future<void> _generateMetadataAsync(List<FileItem> items) async {
    // Defer execution to avoid synchronous state mutation during the build phase
    await Future.delayed(Duration.zero);

    final mediaDatasource = ref.read(mediaMetadataDatasourceProvider);
    var changed = false;

    final updatedItems = List<FileItem>.from(items);

    for (var i = 0; i < updatedItems.length; i++) {
      final item = updatedItems[i];
      if (item.type == FileItemType.image && item.imageAspectRatio == null) {
        final ratio = await mediaDatasource.extractAspectRatio(item.path);
        if (ratio != null) {
          updatedItems[i] = item.copyWith(imageAspectRatio: ratio);
          changed = true;
        }
      }
    }

    if (changed) {
      state = AsyncValue.data(updatedItems);
    }
  }

  /// Force reload the current directory (invalidates cache).
  Future<void> refresh() async {
    final String path = ref.read(currentPathProvider);
    ref.read(directoryCacheProvider).invalidate(path);
    ref.invalidateSelf();
  }
}

final directoryItemsProvider =
    AsyncNotifierProvider<DirectoryItemsNotifier, List<FileItem>>(
      DirectoryItemsNotifier.new,
    );

/// Stage 2: Filters directory items based on settings.
final filteredDirectoryItemsProvider = Provider<AsyncValue<List<FileItem>>>((
  ref,
) {
  final itemsAsync = ref.watch(directoryItemsProvider);
  final filter = ref.watch(filterSettingsProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final showHidden = ref.watch(
    settingsProvider.select((s) => s.value?.showHiddenFiles ?? false),
  );

  return itemsAsync.whenData((items) {
    var filtered = items;

    // 1. Filter hidden files
    if (!showHidden) {
      filtered = filtered.where((item) => !item.name.startsWith(".")).toList();
    }

    // 2. Filter by search query
    if (query.isNotEmpty) {
      filtered = filtered
          .where((item) => item.name.toLowerCase().contains(query))
          .toList();
    }

    // 3. Apply advanced filters
    if (!filter.isEmpty) {
      filtered = filter.apply(filtered);
    }

    return filtered;
  });
});

/// Stage 3: Sorts the filtered items.
final sortedDirectoryItemsProvider = FutureProvider<List<FileItem>>((
  ref,
) async {
  final filteredAsync = ref.watch(filteredDirectoryItemsProvider);
  final sort = ref.watch(sortSettingsProvider);
  final pinnedAsync = ref.watch(pinnedItemsProvider);
  final pinnedMap = pinnedAsync.value ?? const {};

  final items = filteredAsync.value ?? [];
  if (items.isEmpty) return [];

  // Use compute for large directories to avoid UI lag
  if (items.length > 500) {
    return await compute(
      _sortItemsCompute,
      _SortParams(items, sort.option, pinnedMap),
    );
  } else {
    return _sortItems(items, sort.option, pinnedMap);
  }
});

// ——— Internal Sorting Logic ———

class _SortParams {
  final List<FileItem> items;
  final SortOption option;
  final Map<String, int> pinnedMap;
  _SortParams(this.items, this.option, this.pinnedMap);
}

List<FileItem> _sortItemsCompute(_SortParams params) {
  return _sortItems(params.items, params.option, params.pinnedMap);
}

List<FileItem> _sortItems(
  List<FileItem> items,
  SortOption option,
  Map<String, int> pinnedMap,
) {
  final pinnedList = <FileItem>[];
  final unpinnedList = <FileItem>[];

  for (final item in items) {
    if (pinnedMap.containsKey(item.path)) {
      pinnedList.add(item);
    } else {
      unpinnedList.add(item);
    }
  }

  // Sort pinned descending by timestamp
  pinnedList.sort((a, b) {
    final tA = pinnedMap[a.path] ?? 0;
    final tB = pinnedMap[b.path] ?? 0;
    return tB.compareTo(tA);
  });

  // Sort unpinned
  unpinnedList.sort((a, b) {
    // Folders first logic (unless filesFirst option is selected)
    if (option != SortOption.filesFirst) {
      if (a.type == FileItemType.folder && b.type != FileItemType.folder)
        return -1;
      if (a.type != FileItemType.folder && b.type == FileItemType.folder)
        return 1;
    } else {
      // Files first logic
      if (a.type != FileItemType.folder && b.type == FileItemType.folder)
        return -1;
      if (a.type == FileItemType.folder && b.type != FileItemType.folder)
        return 1;
    }

    // Secondary sort based on option
    switch (option) {
      case SortOption.aToZ:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      case SortOption.zToA:
        return b.name.toLowerCase().compareTo(a.name.toLowerCase());
      case SortOption.firstModified:
        return a.modified.compareTo(b.modified);
      case SortOption.lastModified:
        return b.modified.compareTo(a.modified);
      case SortOption.sizeSmallToLarge:
        return (a.sizeBytes ?? 0).compareTo(b.sizeBytes ?? 0);
      case SortOption.sizeLargeToSmall:
        return (b.sizeBytes ?? 0).compareTo(a.sizeBytes ?? 0);
      case SortOption.filesFirst:
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
  });

  return [...pinnedList, ...unpinnedList];
}

/// Whether the current tab is refreshing.
class IsRefreshingNotifier extends Notifier<bool> {
  @override
  bool build() {
    final tabId = ref.watch(tabIdProvider);
    return ref.watch(
      tabManagerProvider.select(
        (s) => s.tabs.firstWhere((t) => t.id == tabId).isRefreshing,
      ),
    );
  }

  set state(bool value) {
    final tabId = ref.read(tabIdProvider);
    ref.read(tabManagerProvider.notifier).setRefreshing(tabId, value);
  }
}

final isRefreshingProvider = NotifierProvider<IsRefreshingNotifier, bool>(
  IsRefreshingNotifier.new,
);

/// Current refresh count, scoped to the current tab.
class RefreshCountNotifier extends Notifier<int> {
  @override
  int build() {
    final tabId = ref.watch(tabIdProvider);
    return ref.watch(
      tabManagerProvider.select(
        (s) => s.tabs.firstWhere((t) => t.id == tabId).refreshCount,
      ),
    );
  }

  set state(int value) {
    // This is usually called as state++, so we need a way to increment.
    // But setting it directly works too.
    final tabId = ref.read(tabIdProvider);
    // If it's just incrementing, we could have a method,
    // but for compatibility with state = value:
    final current = ref.read(
      tabManagerProvider.select(
        (s) => s.tabs.firstWhere((t) => t.id == tabId).refreshCount,
      ),
    );
    if (value > current) {
      ref.read(tabManagerProvider.notifier).incrementRefreshCount(tabId);
    }
  }

  void update(int Function(int) updater) {
    final tabId = ref.read(tabIdProvider);
    final current = ref.read(
      tabManagerProvider.select(
        (s) => s.tabs.firstWhere((t) => t.id == tabId).refreshCount,
      ),
    );
    final next = updater(current);
    if (next > current) {
      ref.read(tabManagerProvider.notifier).incrementRefreshCount(tabId);
    }
  }
}

final refreshCountProvider = NotifierProvider<RefreshCountNotifier, int>(
  RefreshCountNotifier.new,
);
final mainFocusNodeProvider = Provider<FocusNode>((ref) => FocusNode());

/// Global registry of ItemCard GlobalKeys to find their positions for popovers (like Rename).
class ItemKeysNotifier extends Notifier<Map<String, GlobalKey>> {
  @override
  Map<String, GlobalKey> build() => {};

  void update(Map<String, GlobalKey> Function(Map<String, GlobalKey>) updater) {
    state = updater(state);
  }

  void register(String path, GlobalKey key) {
    state = {...state, path: key};
  }
}

final itemKeysProvider =
    NotifierProvider<ItemKeysNotifier, Map<String, GlobalKey>>(
      ItemKeysNotifier.new,
    );
