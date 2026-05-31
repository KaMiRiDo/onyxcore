import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_task_tile.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_history_view.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_history_detail_view.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/downloader_process_wrapper.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/downloader/services/downloader_update_service.dart';
import 'package:path/path.dart' as p;
import 'package:onyxcore/features/directory_browser/presentation/widgets/conflict_dialog.dart';

import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_header.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_empty_state.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_shared_components.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_missing_binaries_view.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/core/utils/process_utils.dart';

part 'downloads_panel_helpers.dart';
part 'components/downloads_panel_input.dart';
part 'components/downloads_panel_results_view.dart';
part 'components/downloads_panel_tiles.dart';
part 'components/downloads_panel_preview.dart';
part 'components/downloads_panel_controls.dart';

class DownloadsPanel extends ConsumerWidget {
  const DownloadsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOpen = ref.watch(downloadsPanelOpenProvider);
    final view = ref.watch(downloadsPanelViewProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final panelWidth = screenWidth * 0.25;

    Widget content;
    switch (view) {
      case DownloadsPanelView.tasks:
        content = const _MediaDownloaderPanel();
        break;
      case DownloadsPanelView.history:
        content = const DownloadHistoryView();
        break;
      case DownloadsPanelView.historyDetail:
        content = const DownloadHistoryDetailView();
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: isOpen ? panelWidth : 0,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border: isOpen
            ? Border(
                left: BorderSide(
                  color: Colors.white.withOpacity(0.12),
                  width: 1,
                ),
              )
            : null,
        boxShadow: isOpen
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 30,
                  offset: const Offset(-6, 0),
                ),
              ]
            : null,
      ),
      child: OverflowBox(
        alignment: Alignment.topLeft,
        minWidth: panelWidth,
        maxWidth: panelWidth,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: content,
        ),
      ),
    );
  }
}

class _MediaDownloaderPanel extends ConsumerStatefulWidget {
  const _MediaDownloaderPanel();

  @override
  ConsumerState<_MediaDownloaderPanel> createState() =>
      _MediaDownloaderPanelState();
}

class _MediaDownloaderPanelState extends ConsumerState<_MediaDownloaderPanel>
    with SingleTickerProviderStateMixin, DownloadsPanelHelpersMixin {
  late TextEditingController _urlController;
  bool _isLoading = false;
  String? _error;

  List<MediaGroup>? _parsedItems;
  final Map<int, DownloadConfig> _configs = {};

  String _destinationMode = 'current';
  bool _binariesExist = false;
  bool _isDownloadsDrawerOpen = false;

  String _selectedEngine = 'auto';
  String _sortFilter = 'added_desc';

  final Set<int> _selectedIndices = {};
  int _lastSelectedIndex = -1;
  int _anchorIndex = -1;
  final Map<int, GlobalKey> _itemKeys = {};
  final Set<String> _backgroundLoadingProfiles = {};

  MediaGroup? _previewItem;
  int? _previewIndex;
  int _previewCarouselIndex = 0;

  final Map<String, int> _activeHydrationPids = {};

  List<MediaInfo> get _visiblePreviewItems {
    if (_previewItem == null) return [];
    final config = _configs[_previewIndex!];
    if (config == null) return _previewItem!.items;

    return _previewItem!.items.where((info) {
      if (config.groupFilter == GroupDownloadType.images && info.isVideo)
        return false;
      if (config.groupFilter == GroupDownloadType.videos && !info.isVideo)
        return false;
      return true;
    }).toList();
  }

  late FocusNode _urlFocusNode;
  final FocusNode _listFocusNode = FocusNode();
  late AnimationController _gradientController;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController();
    _urlFocusNode = FocusNode()
      ..addListener(() {
        ref.read(isDownloadInputFocusedProvider.notifier).state =
            _urlFocusNode.hasFocus;
        setState(() {});
      });
    _listFocusNode.addListener(() {
      ref.read(isDownloadsPanelFocusedProvider.notifier).state =
          _listFocusNode.hasFocus;
    });
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _checkBinaries();
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  void _scrollToIndex(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[index];
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        );
      }
    });
  }

  void _checkBinaries() {
    final binDir = '${Platform.environment['HOME']}/.local/share/onyxcore/bin';
    setState(() {
      _binariesExist =
          File('$binDir/yt-dlp').existsSync() &&
          File('$binDir/gallery-dl').existsSync();
    });
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && HardwareKeyboard.instance.isControlPressed) {
      if (event.logicalKey == LogicalKeyboardKey.backquote ||
          event.logicalKey == LogicalKeyboardKey.tilde ||
          event.physicalKey == PhysicalKeyboardKey.backquote) {
        if (mounted) {
          final isOpen = ref.read(downloadsPanelOpenProvider);
          if (isOpen) {
            setState(() {
              _isDownloadsDrawerOpen = !_isDownloadsDrawerOpen;
            });
          }
        }
        return true;
      }

      if (event.logicalKey == LogicalKeyboardKey.keyD ||
          event.physicalKey == PhysicalKeyboardKey.keyD) {
        if (mounted) {
          final isOpen = ref.read(downloadsPanelOpenProvider);
          if (isOpen) {
            if (!_urlFocusNode.hasFocus) {
              _urlFocusNode.requestFocus();
            } else {
              ref.read(downloadsPanelOpenProvider.notifier).state = false;
            }
          } else {
            ref.read(downloadsPanelOpenProvider.notifier).state = true;
            Future.delayed(const Duration(milliseconds: 50), () {
              if (mounted) {
                _urlFocusNode.requestFocus();
              }
            });
          }
          return true;
        }
      }
    }
    return false;
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _gradientController.dispose();
    _urlFocusNode.dispose();
    _listFocusNode.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _hydrateProfile(String url) async {
    if (!mounted) return;
    setState(() {
      _backgroundLoadingProfiles.add(url);
    });

    try {
      final browser = ref.read(settingsProvider).value?.downloadBrowser;
      final items = await MediaDownloaderBackend.analyzeUrls(
        [url],
        engine: _selectedEngine,
        browser: browser,
        fetchDeep: true,
        onProcessStarted: (int pid) {
          if (!mounted) return;
          setState(() {
            _activeHydrationPids[url] = pid;
          });
        },
        onProgress: (MediaInfo info) {
          if (!mounted) return;
          setState(() {
            if (_parsedItems != null) {
              final groupIndex = _parsedItems!.indexWhere((g) => g.originalUrl == url);
              if (groupIndex != -1) {
                final group = _parsedItems![groupIndex];
                if (info.isProfile && group.items.any((e) => e.isProfile)) return; // Skip duplicate fallback profile

                // Check if it already exists, if not, append to show progressive update
                final existsIndex = group.items.indexWhere((existing) => existing.id == info.id);
                if (existsIndex == -1) {
                  group.items.add(info);
                } else {
                  // Update it in case metadata changed
                  group.items[existsIndex] = info;
                }
              }
            }
          });
        },
      );

      if (!mounted) return;
      setState(() {
        _backgroundLoadingProfiles.remove(url);
        _activeHydrationPids.remove(url);
        ref.read(downloadTaskProvider.notifier).onHydrationFinished(url, items);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _backgroundLoadingProfiles.remove(url);
        });
        debugPrint('Failed to hydrate profile $url: $e');
      }
    }
  }

  Future<void> _analyzeUrls() async {
    final text = _urlController.text.trim();
    if (text.isEmpty) return;

    final urls = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final browser = ref.read(settingsProvider).value?.downloadBrowser;
      final items = await MediaDownloaderBackend.analyzeUrls(
        urls,
        engine: _selectedEngine,
        browser: browser,
      );

      setState(() {
        if (_parsedItems == null) {
          _parsedItems = [];
        }

        final newGroups = <String, List<MediaInfo>>{};
        for (final item in items) {
          if (!newGroups.containsKey(item.originalUrl)) {
            newGroups[item.originalUrl] = [];
          }
          newGroups[item.originalUrl]!.add(item);
        }

        for (final entry in newGroups.entries) {
          final groupItems = entry.value;
          final isDuplicate = _parsedItems!.any(
            (existing) => existing.originalUrl == entry.key,
          );
          if (!isDuplicate) {
            final group = MediaGroup(originalUrl: entry.key, items: groupItems);
            _parsedItems!.add(group);
            
            if (group.first.isProfile && group.items.length <= 13 && entry.key != null) {
              _hydrateProfile(entry.key!);
            }
          }
        }

        for (int i = 0; i < _parsedItems!.length; i++) {
          if (!_configs.containsKey(i)) {
            final group = _parsedItems![i];
            final info = group.first;
            
            bool hasImages = group.items.any((item) => !item.isVideo);
            bool hasVideos = group.items.any((item) => item.isVideo);
            
            GroupDownloadType defaultFilter = GroupDownloadType.all;
            if (!info.isProfile) {
              if (hasImages && !hasVideos) {
                defaultFilter = GroupDownloadType.images;
              } else if (hasVideos && !hasImages) {
                defaultFilter = GroupDownloadType.videos;
              }
            }

            _configs[i] = DownloadConfig(
              format: info.formats.isNotEmpty ? info.formats.last : null,
              groupFilter: defaultFilter,
            );
          }
        }
        _urlController.clear();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _startDownload(int index, {String? singleItemId}) async {
    if (_parsedItems == null || index >= _parsedItems!.length) return;

    final group = _parsedItems![index];
    final config = _configs[index]!;

    String dest = _destinationMode == 'current'
        ? ref.read(currentPathProvider)
        : '${Platform.environment['HOME']}/Downloads';

    // Use a copy to prevent concurrent modification if background tasks update group.items
    final itemsToDownload = List.from(group.items);

    // Batch download logic for profiles AND grouped posts
    if ((group.first.isProfile || group.items.length > 1) && singleItemId == null) {
      final safeName = group.first.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final itemDest = group.first.isProfile ? p.join(dest, safeName) : dest;
      if (group.first.isProfile && !Directory(itemDest).existsSync()) {
        Directory(itemDest).createSync(recursive: true);
      }
      
      String? filterType;
      int? totalFilteredItems;
      bool isHydrating = _backgroundLoadingProfiles.contains(group.originalUrl);
      bool shouldAbortHydration = false;

      if (config.groupFilter == GroupDownloadType.images) {
        filterType = 'images';
        totalFilteredItems = isHydrating ? null : itemsToDownload.where((item) => !item.isVideo && !item.isProfile).length;
      } else if (config.groupFilter == GroupDownloadType.videos) {
        filterType = 'videos';
        totalFilteredItems = isHydrating ? null : itemsToDownload.where((item) => item.isVideo && !item.isProfile).length;
      } else {
        if (isHydrating) {
           totalFilteredItems = group.first.itemCount ?? 0;
           if (totalFilteredItems != null && totalFilteredItems > 0) {
              shouldAbortHydration = true;
           }
        } else {
           totalFilteredItems = itemsToDownload.where((item) => !item.isProfile).length; 
        }
      }
      
      ref.read(downloadTaskProvider.notifier).startDownload(
            url: group.originalUrl,
            destination: itemDest,
            title: group.first.isProfile ? '$safeName Profile' : safeName,
            format: config.format,
            audioOnly: config.mode == DownloadMode.audioOnly,
            mute: config.mode == DownloadMode.mute,
            engine: _selectedEngine,
            isPlaylist: false,
            isZip: false, // Ensure zip is off
            filterType: filterType,
            totalItems: totalFilteredItems,
          );
      
      setState(() {
        if (_parsedItems != null) {
          final currentIndex = _parsedItems!.indexOf(group);
          if (currentIndex != -1) {
            _removeParsedItems([currentIndex], abortHydration: shouldAbortHydration);
            if (_previewItem == group) {
              _previewItem = null;
            }
          }
        }
      });
      return;
    }

    final Map<String, List<File>> dirCache = {};
    int count = 0;

    for (final info in itemsToDownload) {
      if (count++ % 20 == 0) await Future.delayed(Duration.zero);
      if (singleItemId != null && info.id != singleItemId) continue;

      if (config.groupFilter == GroupDownloadType.images && info.isVideo)
        continue;
      if (config.groupFilter == GroupDownloadType.videos && !info.isVideo)
        continue;

      final format = config.itemFormats[info.id] ?? config.format;

      String itemDest = dest;
      if (group.first.isPlaylist) {
        final safeName = group.first.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        itemDest = p.join(dest, safeName);
        if (!Directory(itemDest).existsSync()) {
          Directory(itemDest).createSync(recursive: true);
        }
      }

      bool shouldDownload = true;
      String finalTitle = info.title;
      String suffix = '';
      final match = RegExp(r' \((\d+)\)$').firstMatch(finalTitle);
      if (match != null) {
        suffix = ' - ${match.group(1)}';
        finalTitle = finalTitle.replaceAll(
          RegExp(r' \(\d+\)$'),
          '',
        );
      } else if (info.galleryIndex != null) {
        suffix = ' - ${info.galleryIndex}';
      }

      if (finalTitle.runes.length > 80) {
        finalTitle = String.fromCharCodes(finalTitle.runes.take(80)).trim();
      }
      finalTitle = '$finalTitle$suffix';

      if (!info.isPlaylist) {
        final safeName = finalTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        if (!dirCache.containsKey(itemDest)) {
          final dir = Directory(itemDest);
          if (dir.existsSync()) {
            dirCache[itemDest] = dir.listSync().whereType<File>().toList();
          } else {
            dirCache[itemDest] = [];
          }
        }
        final existingFiles = dirCache[itemDest]!;
        
        final exists = existingFiles.any(
          (f) => p.basenameWithoutExtension(f.path) == safeName,
        );
        if (exists) {
          final result = await showDialog<ConflictResult>(
            context: context,
            barrierColor: Colors.black54,
            builder: (context) => ConflictDialog(
              fileName: safeName,
              destinationPath: itemDest,
              showApplyToAll: false,
            ),
          );
          if (result == null ||
              result.resolution == ConflictResolution.skip) {
            shouldDownload = false;
          } else if (result.resolution == ConflictResolution.rename) {
            int conflictCounter = 1;
            while (existingFiles.any(
              (f) =>
                  p.basenameWithoutExtension(f.path) ==
                  '$safeName ($conflictCounter)',
            )) {
              conflictCounter++;
            }
            finalTitle = '$finalTitle ($conflictCounter)';
          } else if (result.resolution == ConflictResolution.replace) {
            try {
              final fileToDelete = existingFiles.firstWhere(
                (f) => p.basenameWithoutExtension(f.path) == safeName,
              );
              fileToDelete.deleteSync();
            } catch (_) {}
          }
        }
      }

      if (shouldDownload) {
        ref
            .read(downloadTaskProvider.notifier)
            .startDownload(
              url: info.originalUrl,
              destination: itemDest,
              title: finalTitle,
              format: format,
              audioOnly: config.mode == DownloadMode.audioOnly,
              mute: config.mode == DownloadMode.mute,
              galleryIndex: info.galleryIndex,
              engine: _selectedEngine,
              isPlaylist: info.isPlaylist,
              browser: ref.read(settingsProvider).value?.downloadBrowser,
              totalItems: 1,
            );
      }
    }

    setState(() {
      if (_parsedItems != null) {
        final currentIndex = _parsedItems!.indexOf(group);
        if (currentIndex != -1) {
          if (singleItemId != null) {
            group.items.removeWhere((i) => i.id == singleItemId);
            if (group.items.isEmpty) {
              _removeParsedItems([currentIndex]);
              if (_previewItem == group) {
                _previewItem = null;
              }
            }
          } else {
            _removeParsedItems([currentIndex]);
          }
        }
      }
    });
  }

  Future<void> _startDownloadAll() async {
    final itemsToDownload = _selectedIndices.isNotEmpty
        ? _filteredItems.where((e) => _selectedIndices.contains(e.key)).toList()
        : List.of(_filteredItems);
    if (itemsToDownload.isEmpty) return;

    ConflictResolution? globalResolution;
    final Set<String> sessionNames = {};

    // Collect group references and their configs instead of just indices
    final groupsToProcess = <MediaGroup, DownloadConfig>{};
    for (final item in itemsToDownload) {
      if (_parsedItems != null && item.key < _parsedItems!.length) {
         groupsToProcess[_parsedItems![item.key]] = _configs[item.key]!;
      }
    }

    for (final entry in groupsToProcess.entries) {
      final group = entry.key;
      final config = entry.value;

      String dest = _destinationMode == 'current'
          ? ref.read(currentPathProvider)
          : '${Platform.environment['HOME']}/Downloads';

      // Use a copy to prevent concurrent modification if background tasks update group.items
      final itemsToDownload = List.from(group.items);

      // Batch download logic for profiles AND grouped posts
      if (group.first.isProfile || group.items.length > 1) {
        final safeName = group.first.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final itemDest = group.first.isProfile ? p.join(dest, safeName) : dest;
        if (group.first.isProfile && !Directory(itemDest).existsSync()) {
          Directory(itemDest).createSync(recursive: true);
        }
        
        String? filterType;
        int? totalFilteredItems;
        bool isHydrating = _backgroundLoadingProfiles.contains(group.originalUrl);
        bool shouldAbortHydration = false;

        if (config.groupFilter == GroupDownloadType.images) {
          filterType = 'images';
          totalFilteredItems = isHydrating ? null : itemsToDownload.where((item) => !item.isVideo && !item.isProfile).length;
        } else if (config.groupFilter == GroupDownloadType.videos) {
          filterType = 'videos';
          totalFilteredItems = isHydrating ? null : itemsToDownload.where((item) => item.isVideo && !item.isProfile).length;
        } else {
          if (isHydrating) {
             totalFilteredItems = group.first.itemCount ?? 0;
             if (totalFilteredItems != null && totalFilteredItems > 0) {
                 shouldAbortHydration = true;
             }
          } else {
             totalFilteredItems = itemsToDownload.where((item) => !item.isProfile).length;
          }
        }
        
        ref.read(downloadTaskProvider.notifier).startDownload(
              url: group.originalUrl,
              destination: itemDest,
              title: group.first.isProfile ? '$safeName Profile' : safeName,
              format: config.format,
              audioOnly: config.mode == DownloadMode.audioOnly,
              mute: config.mode == DownloadMode.mute,
              engine: _selectedEngine,
              isPlaylist: false,
              isZip: false, // Ensure zip is off
              filterType: filterType,
              totalItems: totalFilteredItems,
            );
        continue;
      }

      final Map<String, List<File>> dirCache = {};
      int count = 0;

      for (final info in itemsToDownload) {
        if (count++ % 20 == 0) await Future.delayed(Duration.zero);
        if (config.groupFilter == GroupDownloadType.images && info.isVideo)
          continue;
        if (config.groupFilter == GroupDownloadType.videos && !info.isVideo)
          continue;

        String itemDest = dest;
        if (info.isPlaylist) {
          final safeName = info.title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
          itemDest = p.join(dest, safeName);
          if (!Directory(itemDest).existsSync()) {
            Directory(itemDest).createSync(recursive: true);
          }
        }

        bool shouldDownload = true;
        String finalTitle = info.title;
        String suffix = '';
        final match = RegExp(r' \((\d+)\)$').firstMatch(finalTitle);
        if (match != null) {
          suffix = ' - ${match.group(1)}';
          finalTitle = finalTitle.replaceAll(RegExp(r' \(\d+\)$'), '');
        } else if (info.galleryIndex != null) {
          suffix = ' - ${info.galleryIndex}';
        }

        if (finalTitle.runes.length > 80) {
          finalTitle = String.fromCharCodes(finalTitle.runes.take(80)).trim();
        }
        finalTitle = '$finalTitle$suffix';

        if (!info.isPlaylist && !info.isProfile) {
          final safeName = finalTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
          
          if (!dirCache.containsKey(itemDest)) {
            final dir = Directory(itemDest);
            if (dir.existsSync()) {
              dirCache[itemDest] = dir.listSync().whereType<File>().toList();
            } else {
              dirCache[itemDest] = [];
            }
          }
          final existingFiles = dirCache[itemDest]!;
          final exists = existingFiles.any(
            (f) => p.basenameWithoutExtension(f.path) == safeName,
          );

          if (exists || sessionNames.contains(safeName)) {
            ConflictResolution resolution;
            if (globalResolution != null) {
              resolution = globalResolution;
              if (resolution == ConflictResolution.skip) {
                shouldDownload = false;
              } else if (resolution == ConflictResolution.rename) {
                int conflictCounter = 1;
                while (existingFiles.any(
                      (f) =>
                          p.basenameWithoutExtension(f.path) ==
                          '$safeName ($conflictCounter)',
                    ) ||
                    sessionNames.contains('$safeName ($conflictCounter)')) {
                  conflictCounter++;
                }
                finalTitle = '$finalTitle ($conflictCounter)';
              } else if (resolution == ConflictResolution.replace) {
                try {
                  final fileToDelete = existingFiles.firstWhere(
                    (f) => p.basenameWithoutExtension(f.path) == safeName,
                  );
                  fileToDelete.deleteSync();
                } catch (_) {}
              }
            } else {
              final result = await showDialog<ConflictResult>(
                context: context,
                barrierColor: Colors.black54,
                builder: (context) => ConflictDialog(
                  fileName: safeName,
                  destinationPath: itemDest,
                  showApplyToAll: true,
                ),
              );
              if (result == null) {
                shouldDownload = false;
              } else {
                resolution = result.resolution;
                if (result.applyToAll) {
                  globalResolution = resolution;
                }
                if (resolution == ConflictResolution.skip) {
                  shouldDownload = false;
                } else if (resolution == ConflictResolution.rename) {
                  int counter = 1;
                  while (existingFiles.any(
                        (f) =>
                            p.basenameWithoutExtension(f.path) ==
                            '$safeName ($counter)',
                      ) ||
                      sessionNames.contains('$safeName ($counter)')) {
                    counter++;
                  }
                  finalTitle = '$finalTitle ($counter)';
                } else if (resolution == ConflictResolution.replace) {
                  try {
                    final fileToDelete = existingFiles.firstWhere(
                      (f) => p.basenameWithoutExtension(f.path) == safeName,
                    );
                    fileToDelete.deleteSync();
                  } catch (_) {}
                }
              }
            }
          }
        }

        if (shouldDownload) {
          sessionNames.add(finalTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_'));
          ref
              .read(downloadTaskProvider.notifier)
              .startDownload(
                url: info.originalUrl,
                destination: itemDest,
                title: finalTitle,
                format: config.format,
                audioOnly: config.mode == DownloadMode.audioOnly,
                mute: config.mode == DownloadMode.mute,
                galleryIndex: info.galleryIndex,
                engine: _selectedEngine,
                isPlaylist: info.isPlaylist,
                browser: ref.read(settingsProvider).value?.downloadBrowser,
                totalItems: 1,
              );
        }
      }
    }

    setState(() {
      if (_parsedItems != null) {
        final currentIndices = groupsToProcess.keys
            .map((g) => _parsedItems!.indexOf(g))
            .where((i) => i != -1)
            .toList();
        if (currentIndices.isNotEmpty) {
          bool shouldAbort = false;
          for (final group in groupsToProcess.keys) {
            final config = groupsToProcess[group];
            if (config != null && config.groupFilter == GroupDownloadType.all) {
              final groupItems = group.items;
              if (groupItems.isNotEmpty && (groupItems.first.itemCount ?? 0) > 0) {
                shouldAbort = true;
              }
            }
          }
          _removeParsedItems(currentIndices, abortHydration: shouldAbort);
        }
      }
    });

    setState(() {
      _sortFilter = 'added_desc';
    });
  }

  void _removeParsedItems(List<int> indices, {bool abortHydration = true}) {
    if (_parsedItems == null) return;
    
    for (final i in indices) {
      if (i >= 0 && i < _parsedItems!.length) {
        final url = _parsedItems![i].originalUrl;
        if (abortHydration && _activeHydrationPids.containsKey(url)) {
          ProcessUtils.killProcessTree(_activeHydrationPids[url]!);
          _activeHydrationPids.remove(url);
          _backgroundLoadingProfiles.remove(url);
        }
      }
    }
    
    final sortedIndices = List<int>.from(indices)..sort((a, b) => b.compareTo(a));
    final remainingItems = <MediaGroup>[];
    final remainingConfigs = <DownloadConfig>[];

    for (int i = 0; i < _parsedItems!.length; i++) {
      if (!sortedIndices.contains(i)) {
        remainingItems.add(_parsedItems![i]);
        remainingConfigs.add(
          _configs[i] ??
              DownloadConfig(
                format: _parsedItems![i].first.formats.isNotEmpty
                    ? _parsedItems![i].first.formats.last
                    : null,
              ),
        );
      }
    }

    _parsedItems!
      ..clear()
      ..addAll(remainingItems);

    _configs.clear();
    for (int i = 0; i < remainingItems.length; i++) {
      _configs[i] = remainingConfigs[i];
    }

    _selectedIndices.clear();
    _lastSelectedIndex = -1;
    _anchorIndex = -1;
    if (_parsedItems!.isEmpty) {
      _parsedItems = null;
      FocusScope.of(context).unfocus();
    }
    _previewItem = null;
  }

  void _removeSingleItem(int groupIndex, String itemId) {
    if (_parsedItems == null || groupIndex >= _parsedItems!.length) return;

    final group = _parsedItems![groupIndex];
    group.items.removeWhere((i) => i.id == itemId);

    if (group.items.isEmpty) {
      _removeParsedItems([groupIndex]);
    } else {
      // Re-trigger rebuild
      setState(() {});
    }
  }

  void _updateShiftSelection(List<MapEntry<int, MediaGroup>> items) {
    if (_anchorIndex == -1) _anchorIndex = _lastSelectedIndex;
    int visualStart = items.indexWhere((e) => e.key == _anchorIndex);
    int visualEnd = items.indexWhere((e) => e.key == _lastSelectedIndex);
    if (visualStart != -1 && visualEnd != -1) {
      int start = visualStart < visualEnd ? visualStart : visualEnd;
      int end = visualStart > visualEnd ? visualStart : visualEnd;
      _selectedIndices.clear();
      for (int i = start; i <= end; i++) {
        _selectedIndices.add(items[i].key);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (_) {
        _listFocusNode.unfocus();
      },
      child: Focus(
        autofocus: false,
        canRequestFocus: false,
        descendantsAreFocusable: true,
        child: Listener(
          onPointerDown: (_) {
             if (_listFocusNode.canRequestFocus) _listFocusNode.requestFocus();
          },
          onPointerSignal: (_) {
             if (_listFocusNode.canRequestFocus) _listFocusNode.requestFocus();
          },
          child: MouseRegion(
            onEnter: (_) {
               if (_listFocusNode.canRequestFocus) _listFocusNode.requestFocus();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() {
                  _selectedIndices.clear();
                  _anchorIndex = -1;
                  _previewItem = null;
                });
              },
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const DownloadsHeader(),
                      const Divider(color: Colors.white10, height: 1),
                      Expanded(
                        child: !_binariesExist
                            ? DownloadsMissingBinariesView(
                                onCheckBinaries: _checkBinaries,
                              )
                            : Column(
                                children: [
                                  _buildInputView(),
                                  const Divider(
                                    color: Colors.white10,
                                    height: 1,
                                  ),
                                  Expanded(
                                    child: Container(
                                      color: Colors.black.withOpacity(
                                        0.2,
                                      ), // Differentiate the results section
                                      child: _buildResultsView(),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                  if (_previewItem != null)
                    (_previewItem!.isSingle && !_previewItem!.first.isProfile)
                        ? _buildSinglePreviewOverlay()
                        : _buildGroupPreviewOverlay(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _JugglingBallsLoader extends StatefulWidget {
  const _JugglingBallsLoader({super.key});

  @override
  State<_JugglingBallsLoader> createState() => _JugglingBallsLoaderState();
}

class _JugglingBallsLoaderState extends State<_JugglingBallsLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            final double t = _controller.value * 2 * pi;
            final double offset = index * (pi / 2);
            final double y = sin(t + offset) * 3;
            return Transform.translate(
              offset: Offset(0, y),
              child: Padding(
                padding: EdgeInsets.only(right: index < 2 ? 15 : 0),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  final double animation;
  _GradientBorderPainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = SweepGradient(
        colors: const [
          AppColors.magenta,
          AppColors.violet,
          AppColors.indigo,
          AppColors.magenta,
        ],
        transform: GradientRotation(animation * 2 * pi),
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter old) =>
      old.animation != animation;
}
