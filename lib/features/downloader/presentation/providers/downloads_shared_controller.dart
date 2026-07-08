import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// ignore: implementation_imports
import 'package:flutter_riverpod/legacy.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/services/downloader_process_wrapper.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

class DownloadsSharedController extends ChangeNotifier {

  DownloadsSharedController(this.ref);
  final Ref ref;

  final Set<String> backgroundLoadingProfiles = {};
  final Map<String, List<int>> activeHydrationPids = {};
  final ValueNotifier<int> hydrationNotifier = ValueNotifier<int>(0);

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  String selectedEngine = 'auto';

  // These are derived statistics, but we can compute them here
  int totalListSize = 0;
  int totalListImages = 0;
  int totalListVideos = 0;
  bool hasUnderestimatedSize = false;
  int pendingStatsUpdate = 0;

  DownloadsListCache get cache => ref.read(downloadsListCacheProvider);

  void recalculateFilteredStatistics() {
    totalListSize = 0;
    totalListImages = 0;
    totalListVideos = 0;
    hasUnderestimatedSize = false;

    final parsedItems = cache.parsedItems;
    if (parsedItems == null) {
      if (!_isDisposed) notifyListeners();
      return;
    }

    for (var i = 0; i < parsedItems.length; i++) {
      final itemGrp = parsedItems[i];
      final config = cache.configs[i];

      var groupSize = 0;
      if (config != null) {
        groupSize = _getGroupBytes(itemGrp, config);
      } else {
        groupSize = itemGrp.totalFilesize;
      }

      var groupVideos = 0;
      var groupImages = 0;

      for (final item in itemGrp.items) {
        if (item.isError) continue;

        if (config?.groupFilter == GroupDownloadType.images && item.isVideo) continue;
        if (config?.groupFilter == GroupDownloadType.videos && !item.isVideo) continue;

        if (item.isVideo) {
          groupVideos++;
        } else if (!item.isPlaylist && !item.isProfile) {
          groupImages++;
        }
      }
      
      if (itemGrp.first.isPlaylist || itemGrp.first.isProfile) {
        hasUnderestimatedSize = true;
      }

      totalListSize += groupSize;
      totalListVideos += groupVideos;
      totalListImages += groupImages;
    }
    if (!_isDisposed) notifyListeners();
  }

  int _getGroupBytes(MediaGroup group, DownloadConfig config) {
    if (config.mode == DownloadMode.normal) {
      if (config.groupFilter == GroupDownloadType.images) {
        return group.items.where((i) => !i.isVideo).fold(0, (sum, item) => sum + (item.filesize ?? 0));
      } else if (config.groupFilter == GroupDownloadType.videos) {
        return group.items.where((i) => i.isVideo).fold(0, (sum, item) => sum + (item.filesize ?? 0));
      }
      return group.totalFilesize;
    } else {
      if (config.itemFormats.isEmpty) return 0;
      return config.itemFormats.values.fold(0, (sum, fmt) => sum + (fmt?.filesize ?? 0));
    }
  }

  int _getHeight(String resStr) {
    final match = RegExp(r'(\d+)p').firstMatch(resStr);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 0;
    }
    return 0;
  }

  Future<void> analyzeUrls(String text) async {
    final urls = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();
    if (urls.isEmpty) return;

    cache.parsedItems ??= [];

    for (final url in urls) {
      final isDuplicate = cache.parsedItems!.any((existing) => existing.originalUrl == url);
      if (!isDuplicate) {
        final placeholderInfo = MediaInfo(
          id: 'fetch_loading',
          title: 'Fetching...',
          originalUrl: url,
          isVideo: false,
        );
        cache.parsedItems!.add(MediaGroup(originalUrl: url, items: [placeholderInfo]));
        backgroundLoadingProfiles.add(url);
        cache.configs[cache.parsedItems!.length - 1] = DownloadConfig(
           engine: selectedEngine,
        );
      }
    }
    cache.isListChanged = true;
    cache.notify();
    recalculateFilteredStatistics();
    if (!_isDisposed) notifyListeners();

    final browser = ref.read(settingsProvider).value?.downloadBrowser;
    
    for (final url in urls) {
      MediaDownloaderBackend.analyzeUrls(
        [url],
        engine: selectedEngine,
        browser: browser,
        onProcessStarted: (pid) {
          activeHydrationPids.putIfAbsent(url, () => []).add(pid);
          if (!_isDisposed) notifyListeners();
        },
      ).then((items) {
        backgroundLoadingProfiles.remove(url);
        activeHydrationPids.remove(url);

        if (cache.parsedItems != null) {
          final index = cache.parsedItems!.indexWhere((g) => g.originalUrl == url);
          if (index != -1) {
            if (items.isEmpty) {
              final errorInfo = MediaInfo(
                id: 'fetch_error',
                title: 'Error processing URL',
                originalUrl: url,
                errorMessage: 'No media found or extraction failed',
                isVideo: false,
              );
              cache.parsedItems![index] = MediaGroup(originalUrl: url, items: [errorInfo]);
            } else {
              cache.parsedItems![index] = MediaGroup(originalUrl: url, items: items);
            }
            if (items.isNotEmpty && (items.first.isPlaylist || items.first.isProfile)) {
              hydrateProfile(url);
            }
            cache.notify();
            recalculateFilteredStatistics();
          }
        }
        if (!_isDisposed) notifyListeners();
      }).catchError((e) {
        backgroundLoadingProfiles.remove(url);
        activeHydrationPids.remove(url);
        if (!_isDisposed) notifyListeners();
      });
    }
  }

  Future<void> hydrateProfile(String url) async {
    backgroundLoadingProfiles.add(url);
    if (!_isDisposed) notifyListeners();

    try {
      final browser = ref.read(settingsProvider).value?.downloadBrowser;
      final isPlaylist = cache.parsedItems?.any((g) => g.originalUrl == url && g.items.isNotEmpty && g.items.first.isPlaylist) ?? false;
      
      final items = await MediaDownloaderBackend.analyzeUrls(
        [url],
        engine: selectedEngine,
        browser: browser,
        fetchDeep: true,
        isPlaylist: isPlaylist,
        onProcessStarted: (int pid) {
          activeHydrationPids.putIfAbsent(url, () => []).add(pid);
          if (!_isDisposed) notifyListeners();
        },
        onProgress: (MediaInfo info) {
          if (cache.parsedItems != null) {
            final groupIndex = cache.parsedItems!.indexWhere((g) => g.originalUrl == url);
            if (groupIndex != -1) {
              final group = cache.parsedItems![groupIndex];
              if (info.isProfile && group.items.any((e) => e.isProfile)) return;

              final existsIndex = group.items.indexWhere((existing) => existing.id == info.id);
              if (existsIndex == -1) {
                group.items.add(info);
              } else {
                group.items[existsIndex] = info;
              }

              if (info.id != 'hydration_loading') {
                final loadingIndex = group.items.indexWhere((e) => e.id == 'hydration_loading');
                if (loadingIndex != -1 && loadingIndex < group.items.length - 1) {
                  final loadingItem = group.items.removeAt(loadingIndex);
                  group.items.add(loadingItem);
                }
              }

              if (group.items.isNotEmpty && group.items.first.isPlaylist) {
                group.items[0] = group.items[0].copyWith(fetchLogs: info.fetchLogs);
              }

              pendingStatsUpdate++;
              if (pendingStatsUpdate % 5 == 0) {
                recalculateFilteredStatistics();
              }
              hydrationNotifier.value++;
            }
          }
        },
      );

      backgroundLoadingProfiles.remove(url);
      activeHydrationPids.remove(url);

      if (cache.parsedItems != null) {
        final groupIndex = cache.parsedItems!.indexWhere((g) => g.originalUrl == url);
        if (groupIndex != -1) {
          final group = cache.parsedItems![groupIndex];
          final playlistInfo = group.items.isNotEmpty && group.items.first.isPlaylist ? group.items.first : null;
          final isGenericGroup = playlistInfo?.extractor?.toLowerCase() == 'generic' || (items.isNotEmpty && items.any((i) => i.extractor?.toLowerCase() == 'generic'));

          if (isGenericGroup) {
            items.sort((a, b) {
              final durA = a.duration ?? 0;
              final durB = b.duration ?? 0;
              if (durA != durB) return durB.compareTo(durA);
              final sizeA = a.filesize ?? 0;
              final sizeB = b.filesize ?? 0;
              return sizeB.compareTo(sizeA);
            });
          }

          group.items.clear();
          if (playlistInfo != null) {
            final errorMsg = items.isNotEmpty ? items.first.errorMessage : null;
            final fetchLogs = items.isNotEmpty ? items.first.fetchLogs : null;
            if (errorMsg != null || fetchLogs != null) {
              group.items.add(playlistInfo.copyWith(errorMessage: errorMsg, fetchLogs: fetchLogs));
            } else {
              group.items.add(playlistInfo);
            }
          }
          group.items.addAll(items);

          if (cache.configs.containsKey(groupIndex)) {
            final config = cache.configs[groupIndex]!;
            final formatSet = <String, MediaFormat>{};
            for (final vid in group.items) {
              if (vid.isVideo) {
                final sortedFormats = vid.formats.toList()..sort((a, b) => (b.filesize ?? 0).compareTo(a.filesize ?? 0));
                for (final f in sortedFormats) {
                  if (!formatSet.containsKey(f.resolution)) {
                    formatSet[f.resolution] = f;
                  } else {
                    final existing = formatSet[f.resolution]!;
                    if ((f.filesize ?? 0) > (existing.filesize ?? 0)) {
                      formatSet[f.resolution] = f;
                    }
                  }
                }
              }
            }
            if (formatSet.isNotEmpty) {
              final availableFormats = formatSet.values.toList();
              availableFormats.sort((a, b) {
                final hA = _getHeight(a.resolution);
                final hB = _getHeight(b.resolution);
                if (hA != hB) return hB.compareTo(hA);
                return (b.filesize ?? 0).compareTo(a.filesize ?? 0);
              });
              config.format = availableFormats.first;
              config.itemFormats.clear();
            }
          }

          cache.notify();
          recalculateFilteredStatistics();
          hydrationNotifier.value++;
        }
      }

      ref.read(downloadTaskProvider.notifier).onHydrationFinished(url, items);
      if (!_isDisposed) notifyListeners();
    } catch (e) {
      backgroundLoadingProfiles.remove(url);
      if (!_isDisposed) notifyListeners();
    }
  }

  Future<void> importListFromFile(String path, String fileName) async {
    try {
      if (cache.hasCache(path)) {
        cache.switchList(path);
        recalculateFilteredStatistics();
        return;
      }
      
      final file = File(path);
      if (!await file.exists()) return;

      final contents = await file.readAsString();
      
      cache.switchList(path);
      cache.clear();
      cache.importedListName = fileName;
      cache.importedListPath = path;
      cache.isListChanged = false;
      
      if (path.toLowerCase().endsWith('.json')) {
        try {
          final decoded = jsonDecode(contents);
          List<dynamic> itemsList;
          if (decoded is List) {
            itemsList = decoded;
          } else if (decoded is Map) {
            itemsList = decoded['items'] as List<dynamic>? ?? [];
          } else {
            throw Exception('Invalid JSON format');
          }

          final importedItems = itemsList
              .map((e) => MediaGroup.fromMap(e as Map<String, dynamic>))
              .toList();
          
          cache.parsedItems = importedItems;
          cache.configs.clear();
          for (var i = 0; i < importedItems.length; i++) {
            cache.configs[i] = DownloadConfig(
              
            );
          }
          
          recalculateFilteredStatistics();
          hydrationNotifier.value++;
          if (!_isDisposed) notifyListeners();
        } catch (e) {
          debugPrint('Error parsing JSON: $e');
          await analyzeUrls(contents);
        }
      } else {
        await analyzeUrls(contents);
      }
    } catch (e) {
      debugPrint('Error importing list: $e');
    }
  }

  Future<void> exportListToFile(String path) async {
    try {
      final file = File(path);
      
      if (path.toLowerCase().endsWith('.json')) {
        final itemsData = cache.parsedItems?.map((e) => e.toMap()).toList() ?? [];
        final data = {
          'items': itemsData,
          'statistics': {
            'totalSize': totalListSize,
            'images': totalListImages,
            'videos': totalListVideos,
          },
        };
        await file.writeAsString(jsonEncode(data));
      } else {
        final urls = cache.parsedItems?.map((g) => g.originalUrl).where((u) => u.isNotEmpty).toList() ?? [];
        await file.writeAsString(urls.join('\n'));
      }
      
      cache.importedListPath = path;
      cache.isListChanged = false;
      cache.notify();
    } catch (e) {
      debugPrint('Error exporting list: $e');
    }
  }
}

final downloadsSharedControllerProvider = ChangeNotifierProvider<DownloadsSharedController>((ref) {
  return DownloadsSharedController(ref);
});
