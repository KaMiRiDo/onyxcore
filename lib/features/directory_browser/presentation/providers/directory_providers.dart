import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';
import 'package:onyxcore/core/cache/directory_cache.dart';
import 'package:onyxcore/core/platform/directory_watcher.dart';
import 'package:onyxcore/core/utils/file_type_utils.dart';
import 'package:onyxcore/features/directory_browser/data/datasources/directory_size_datasource.dart';
import 'package:onyxcore/features/directory_browser/data/datasources/local_file_datasource.dart';
import 'package:onyxcore/features/directory_browser/data/datasources/media_metadata_datasource.dart';
import 'package:onyxcore/features/directory_browser/data/repositories/directory_repository_impl.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/filter_settings.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/sort_settings.dart';
import 'package:onyxcore/features/directory_browser/domain/repositories/directory_repository.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/pinned_items_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

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

  @override
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
  final path = ref.watch(currentPathProvider);
  final zooms = ref.watch(zoomProvider);
  return zooms[path] ?? 0.8;
});

/// Global state for drag-and-drop operations.
final isDraggingProvider = StateProvider<bool>((ref) => false);

/// The paths currently being dragged.
final draggingPathsProvider = StateProvider<Set<String>>((ref) => {});

/// The currently previewed file (inline preview mode).
final previewFileProvider = StateProvider<FileItem?>((ref) => null);

/// Init parameters for the currently previewed file.
final previewFileInitParamsProvider = StateProvider<Map<String, dynamic>?>((ref) => null);

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

  @override
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
    final current = ref.read(
      tabManagerProvider.select(
        (s) => s.tabs.firstWhere((t) => t.id == tabId).isSearchActive,
      ),
    );
    if (current == value) return;
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
    final current = ref.read(
      tabManagerProvider.select(
        (s) => s.tabs.firstWhere((t) => t.id == tabId).isAnalysisActive,
      ),
    );
    if (current == value) return;
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
    final current = ref.read(
      tabManagerProvider.select(
        (s) => s.tabs.firstWhere((t) => t.id == tabId).isLocationEditing,
      ),
    );
    if (current == value) return;
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
  final path = ref.watch(currentPathProvider);
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
    final path = ref.watch(currentPathProvider);

    // Wait for user settings to load to avoid UI jumps on startup
    try {
      await ref.read(settingsProvider.future);
    } catch (_) {}

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

    // Preserve metadata from previous state to prevent UI jumping during refresh
    final previousItems = state.value ?? [];
    if (previousItems.isNotEmpty) {
      final prevMap = {for (final item in previousItems) item.path: item};
      for (var i = 0; i < items.length; i++) {
        final prev = prevMap[items[i].path];
        if (prev != null) {
          items[i] = items[i].copyWith(
            sizeBytes: items[i].sizeBytes ?? prev.sizeBytes,
            imageAspectRatio: items[i].imageAspectRatio ?? prev.imageAspectRatio,
          );
        }
      }
    }

    final sort = ref.read(sortSettingsProvider);
    final needsMetadataForSort = sort.option == SortOption.sizeSmallToLarge || 
                                 sort.option == SortOption.sizeLargeToSmall;

    final hasMissingSizes = items.any((i) => i.type == FileItemType.folder && i.sizeBytes == null);

    if (needsMetadataForSort && hasMissingSizes) {
      // Start watching for changes
      _watchSubscription?.cancel().ignore();
      _watchSubscription = repo.watchDirectory(path).listen((_) {
        // Invalidate cache and reload on any file change
        ref.read(directoryCacheProvider).invalidate(path);
        ref.invalidateSelf();
      });

      ref.onDispose(() {
        _watchSubscription?.cancel().ignore();
      });

      // Await metadata generation to avoid default sort jump on startup or navigation
      return _generateMetadataAsync(items, path, returnOnly: true);
    } else {
      // Start watching for changes
      _watchSubscription?.cancel().ignore();
      _watchSubscription = repo.watchDirectory(path).listen((_) {
        // Invalidate cache and reload on any file change
        ref.read(directoryCacheProvider).invalidate(path);
        ref.invalidateSelf();
      });

      ref.onDispose(() {
        _watchSubscription?.cancel().ignore();
      });

      // Generate metadata async (aspect ratios)
      _generateMetadataAsync(items, path).ignore();

      return items;
    }
  }

  /// Generates image aspect ratios and directory sizes in the background.
  Future<List<FileItem>> _generateMetadataAsync(List<FileItem> items, String originalPath, {bool returnOnly = false}) async {
    // Defer execution to avoid synchronous state mutation during the build phase
    if (!returnOnly) {
      await Future<void>.delayed(Duration.zero);
    }

    final mediaDatasource = ref.read(mediaMetadataDatasourceProvider);
    final sizeDatasource = ref.read(directorySizeDatasourceProvider);
    var changed = false;

    final updatedItems = List<FileItem>.from(items);
    final folders = <String>[];
    final images = <String>[];

    for (final item in updatedItems) {
      if (item.type == FileItemType.folder && item.sizeBytes == null) {
        folders.add(item.path);
      } else if (item.type == FileItemType.image && item.imageAspectRatio == null) {
        images.add(item.path);
      }
    }

    if (folders.isNotEmpty) {
      final sizes = await sizeDatasource.getDirectorySizes(folders);
      for (var i = 0; i < updatedItems.length; i++) {
        if (sizes.containsKey(updatedItems[i].path)) {
          updatedItems[i] = updatedItems[i].copyWith(sizeBytes: sizes[updatedItems[i].path]);
          changed = true;
        }
      }
      // Yield to the event loop
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }

    if (images.isNotEmpty) {
      // Chunk the images to avoid running ffprobe on 10,000 files in one isolate run, which could take a long time
      const chunkSize = 100;
      for (var i = 0; i < images.length; i += chunkSize) {
        final chunk = images.skip(i).take(chunkSize).toList();
        final ratios = await mediaDatasource.extractAspectRatios(chunk);
        
        for (var j = 0; j < updatedItems.length; j++) {
          if (ratios.containsKey(updatedItems[j].path)) {
            updatedItems[j] = updatedItems[j].copyWith(imageAspectRatio: ratios[updatedItems[j].path]);
            changed = true;
          }
        }
        
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    if (changed) {
      // Cache it for the path we generated metadata for
      ref.read(directoryCacheProvider).put(originalPath, updatedItems);
      
      if (!returnOnly) {
        // Only update the UI state if the user hasn't navigated away
        final currentPath = ref.read(currentPathProvider);
        if (currentPath == originalPath) {
          state = AsyncValue.data(updatedItems);
        }
      }
    }
    
    return updatedItems;
  }

  /// Force reload the current directory (invalidates cache).
  Future<void> refresh() async {
    final path = ref.read(currentPathProvider);
    ref.read(directoryCacheProvider).invalidate(path);
    ref.invalidateSelf();
  }

  /// Optimistically remove items from the visible list.
  ///
  /// Used for trash/delete operations to provide instant UI feedback
  /// before the async operation completes. If the operation fails,
  /// call [restoreItems] with the removed items to roll back.
  List<FileItem> optimisticallyRemove(List<String> paths) {
    final current = state.value;
    if (current == null) return [];

    final pathSet = paths.toSet();
    final removed = current.where((item) => pathSet.contains(item.path)).toList();

    state = AsyncValue.data(
      current.where((item) => !pathSet.contains(item.path)).toList(),
    );

    return removed;
  }

  /// Restore previously removed items (rollback for failed operations).
  void restoreItems(List<FileItem> items) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data([...current, ...items]);
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
      filtered = filtered.where((item) => !item.name.startsWith('.')).toList();
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
    return compute(
      _sortItemsCompute,
      _SortParams(items, sort.option, pinnedMap),
    );
  } else {
    return _sortItems(items, sort.option, pinnedMap);
  }
});

// ——— Internal Sorting Logic ———

class _SortParams {
  _SortParams(this.items, this.option, this.pinnedMap);
  final List<FileItem> items;
  final SortOption option;
  final Map<String, int> pinnedMap;
}

List<FileItem> _sortItemsCompute(_SortParams params) {
  return _sortItems(params.items, params.option, params.pinnedMap);
}

List<FileItem> _sortItems(
  List<FileItem> items,
  SortOption option,
  Map<String, int> pinnedMap,
) {
  if (items.isEmpty) return [];

  String stripDot(String name) => name.startsWith('.') ? name.substring(1) : name;

  // Split into pinned and unpinned
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
    // Folders first logic (unless filesFirst or size-based options are selected)
    if (option != SortOption.filesFirst &&
        option != SortOption.sizeSmallToLarge &&
        option != SortOption.sizeLargeToSmall) {
      if (a.type == FileItemType.folder && b.type != FileItemType.folder) {
        return -1;
      }
      if (a.type != FileItemType.folder && b.type == FileItemType.folder) {
        return 1;
      }
    } else if (option == SortOption.filesFirst) {
      // Files first logic
      if (a.type != FileItemType.folder && b.type == FileItemType.folder) {
        return -1;
      }
      if (a.type == FileItemType.folder && b.type != FileItemType.folder) {
        return 1;
      }
    }

    // Secondary sort based on option
    switch (option) {
      case SortOption.aToZ:
        return stripDot(a.name).toLowerCase().compareTo(stripDot(b.name).toLowerCase());
      case SortOption.zToA:
        return stripDot(b.name).toLowerCase().compareTo(stripDot(a.name).toLowerCase());
      case SortOption.firstModified:
        return a.modified.compareTo(b.modified);
      case SortOption.lastModified:
        return b.modified.compareTo(a.modified);
      case SortOption.sizeSmallToLarge:
        final cmp = (a.sizeBytes ?? 0).compareTo(b.sizeBytes ?? 0);
        if (cmp != 0) return cmp;
        return stripDot(a.name).toLowerCase().compareTo(stripDot(b.name).toLowerCase());
      case SortOption.sizeLargeToSmall:
        final cmp = (b.sizeBytes ?? 0).compareTo(a.sizeBytes ?? 0);
        if (cmp != 0) return cmp;
        return stripDot(a.name).toLowerCase().compareTo(stripDot(b.name).toLowerCase());
      case SortOption.filesFirst:
        return stripDot(a.name).toLowerCase().compareTo(stripDot(b.name).toLowerCase());
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

  @override
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

  @override
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
