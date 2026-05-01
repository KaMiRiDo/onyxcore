import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

final mediaMetadataDatasourceProvider = Provider<MediaMetadataDatasource>((ref) {
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

/// The currently active directory path.
final currentPathProvider = StateProvider<String>((ref) {
  return Platform.environment['HOME'] ?? '/';
});

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

/// Global visibility state for the inline preview HUD.
final previewHudVisibleProvider = StateProvider<bool>((ref) => true);

/// Current search query.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Whether search mode is active in TopBar.
final isSearchActiveProvider = StateProvider<bool>((ref) => false);

/// Whether location editing mode is active in TopBar.
final isLocationEditingProvider = StateProvider<bool>((ref) => false);

/// Current error message for path editing.
final pathErrorProvider = StateProvider<String?>((ref) => null);

/// Whether the current path is a virtual path (recent, starred).
final isVirtualPathProvider = Provider<bool>((ref) {
  final String path = ref.watch(currentPathProvider);
  return path.startsWith('virtual:');
});

// ——— Directory Items Provider ———

/// Loads directory items for the current path.
class DirectoryItemsNotifier extends AsyncNotifier<List<FileItem>> {
  StreamSubscription<FileChangeEvent>? _watchSubscription;

  @override
  Future<List<FileItem>> build() async {
    final String path = ref.watch(currentPathProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final showHidden = settingsAsync.value?.showHiddenFiles ?? false;

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

/// Filters directory items based on the current search query and settings.
final filteredDirectoryItemsProvider = Provider<AsyncValue<List<FileItem>>>((ref) {
  final itemsAsync = ref.watch(directoryItemsProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final settingsAsync = ref.watch(settingsProvider);
  final showHidden = settingsAsync.value?.showHiddenFiles ?? false;
  
  return itemsAsync.whenData((items) {
    var filtered = items;
    
    // Filter hidden files
    if (!showHidden) {
      filtered = filtered.where((item) => !item.name.startsWith(".")).toList();
    }
    
    // Filter by search query
    if (query.isNotEmpty) {
      filtered = filtered.where((item) => item.name.toLowerCase().contains(query)).toList();
    }
    
    return filtered;
  });
});

final isRefreshingProvider = StateProvider<bool>((ref) => false);
final refreshCountProvider = StateProvider<int>((ref) => 0);
final mainFocusNodeProvider = Provider<FocusNode>((ref) => FocusNode());
