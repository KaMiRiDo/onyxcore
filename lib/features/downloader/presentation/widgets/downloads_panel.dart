import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/core/utils/process_utils.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/conflict_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_empty_state.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_header.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_missing_binaries_view.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_shared_components.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_shared_dropdowns.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_history_detail_view.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_history_view.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_task_tile.dart';
import 'package:onyxcore/features/downloader/services/downloader_process_wrapper.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';
import 'package:onyxcore/features/file_picker/presentation/widgets/custom_file_picker_dialog.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/settings/presentation/widgets/settings_dialog.dart';
import 'package:path/path.dart' as p;

part 'components/downloads_panel_controls.dart';
part 'components/downloads_panel_input.dart';
part 'components/downloads_panel_preview.dart';
part 'components/downloads_panel_results_view.dart';
part 'components/downloads_panel_tiles.dart';
part 'downloads_panel_helpers.dart';

class DownloadsPanel extends ConsumerWidget {
  const DownloadsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(downloadsPanelViewProvider);

    var viewIndex = 0;
    switch (view) {
      case DownloadsPanelView.tasks:
        viewIndex = 0;
      case DownloadsPanelView.history:
        viewIndex = 1;
      case DownloadsPanelView.historyDetail:
        viewIndex = 2;
    }

    return IndexedStack(
      index: viewIndex,
      children: const [
        _MediaDownloaderPanel(),
        DownloadHistoryView(),
        DownloadHistoryDetailView(),
      ],
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
  String? _error;

  DownloadsListCache get _cache => ref.read(downloadsListCacheProvider);

  List<MediaGroup>? get _parsedItems => _cache.parsedItems;
  set _parsedItems(List<MediaGroup>? value) => _cache.parsedItems = value;

  List<MapEntry<int, MediaGroup>>? _cachedFilteredItems;
  Map<int, DownloadConfig> get _configs => _cache.configs;

  String? get _importedListName => _cache.importedListName;
  set _importedListName(String? value) => _cache.importedListName = value;

  String? get _importedListPath => _cache.importedListPath;
  set _importedListPath(String? value) => _cache.importedListPath = value;

  bool get _isListChanged => _cache.isListChanged;
  set _isListChanged(bool value) => _cache.isListChanged = value;

  bool _binariesExist = false;
  bool _isDownloadsDrawerOpen = false;

  int _totalListSize = 0;
  int _totalListImages = 0;
  int _totalListVideos = 0;
  int _pendingStatsUpdate = 0; // C5: throttle counter for stats recalculation
  bool _hasUnderestimatedSize = false;

  void _recalculateFilteredStatistics() {
    _cachedFilteredItems = null; // RISK-004: Invalidate cache before reading
    _totalListSize = 0;
    _totalListImages = 0;
    _totalListVideos = 0;
    _hasUnderestimatedSize = false;
    if (_parsedItems == null) return;
    for (var i = 0; i < _parsedItems!.length; i++) {
      final itemGrp = _parsedItems![i];
      final config = _configs[i];

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

        if (config?.groupFilter == GroupDownloadType.images && item.isVideo) {
          continue;
        }
        if (config?.groupFilter == GroupDownloadType.videos && !item.isVideo) {
          continue;
        }

        if (item.isVideo) {
          groupVideos++;
        } else if (!item.isPlaylist && !item.isProfile) {
          groupImages++;
        }
      }
      // Count inflation removed per user request for incremental stats
      if (itemGrp.first.isPlaylist || itemGrp.first.isProfile) {
        _hasUnderestimatedSize = true;
      }

      _totalListSize += groupSize;
      _totalListVideos += groupVideos;
      _totalListImages += groupImages;
    }
  }

  bool _showUnsavedConfirmation = false;
  bool _showCancelAllConfirmation = false;
  String? _errorLogsMessage;
  MediaInfo? _activeLogItem;
  final ScrollController _logsScrollController = ScrollController();
  VoidCallback? _pendingClearAction;

  void _showLogs(MediaInfo item) {
    setState(() {
      _activeLogItem = item;
      _updateLogsMessage();
    });
    _scrollToBottomLogs();
  }

  void _updateLogsMessage() {
    if (_activeLogItem == null) return;
    try {
      final latestItem = _parsedItems
          ?.expand((group) => group.items)
          .firstWhere(
            (i) => i.id == _activeLogItem!.id,
            orElse: () => _activeLogItem!,
          );
      if (latestItem != null) {
        _activeLogItem = latestItem;
      }

      var logsToUse = _activeLogItem!.fetchLogs;

      // If the item is actively hydrating, pull live logs from backend
      if (_backgroundLoadingProfiles.contains(_activeLogItem!.originalUrl) ||
          _activeLogItem!.id == 'hydration_loading') {
        final liveLogs =
            MediaDownloaderBackend.activeLogs[_activeLogItem!.originalUrl];
        if (liveLogs != null && liveLogs.isNotEmpty) {
          final formattedErrors = liveLogs
              .trim()
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .join('\n\n');
          logsToUse = '--- Live Hydration Logs ---\n$formattedErrors';
        }
      }

      _errorLogsMessage = (logsToUse != null && logsToUse.isNotEmpty)
          ? logsToUse
          : (_activeLogItem!.errorMessage != null &&
                _activeLogItem!.errorMessage!.isNotEmpty)
          ? _activeLogItem!.errorMessage
          : '[${_activeLogItem!.engineId ?? 'yt-dlp'}]: Fetch completed successfully.';
    } catch (e) {
      _errorLogsMessage =
          _activeLogItem!.fetchLogs ??
          _activeLogItem!.errorMessage ??
          'Fetch completed successfully.';
    }
  }

  void _scrollToBottomLogs() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_logsScrollController.hasClients) {
        _logsScrollController.animateTo(
          _logsScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleClearRequest(VoidCallback clearAction) {
    if (_importedListName != null && _isListChanged) {
      setState(() {
        _showUnsavedConfirmation = true;
        _pendingClearAction = clearAction;
      });
    } else {
      clearAction();
    }
  }

  String _selectedEngine = 'auto';
  String _sortFilter = 'added_desc';

  void _setSortFilter(String val) {
    if (_sortFilter != val) {
      setState(() {
        _sortFilter = val;
        _recalculateFilteredStatistics();
      });
    }
  }

  final Set<int> _selectedIndices = {};
  int _lastSelectedIndex = -1;
  int _anchorIndex = -1;
  final Map<int, GlobalKey> _itemKeys = {};
  final Set<String> _backgroundLoadingProfiles = {};

  MediaGroup? _previewItem;
  int? _previewIndex;
  int _previewCarouselIndex = 0;

  final Map<String, List<int>> _activeHydrationPids = {};
  final ValueNotifier<int> _hydrationNotifier = ValueNotifier<int>(0);

  List<MediaInfo> get _visiblePreviewItems {
    if (_previewItem == null) return [];
    final config = _configs[_previewIndex!];
    if (config == null) return _previewItem!.items;

    final filtered = _previewItem!.items.where((info) {
      if (config.groupFilter == GroupDownloadType.images && info.isVideo) {
        return false;
      }
      if (config.groupFilter == GroupDownloadType.videos && !info.isVideo) {
        return false;
      }
      return true;
    }).toList();

    final isHydrating = _backgroundLoadingProfiles.contains(
      _previewItem!.originalUrl,
    );

    final actualItems = filtered
        .where((info) => !info.isPlaylist && !info.isProfile)
        .toList();

    if (actualItems.isNotEmpty) {
      if (isHydrating) {
        final placeholder = filtered.firstWhere(
          (info) => info.isPlaylist || info.isProfile,
          orElse: () => _previewItem!.first,
        );
        return [...actualItems, placeholder];
      }
      return actualItems;
    }
    return filtered;
  }

  late FocusNode _urlFocusNode;
  late FocusNode _listFocusNode;
  final FocusNode _previewFocusNode = FocusNode();
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

    _listFocusNode = FocusNode();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _checkBinaries();
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _urlFocusNode.canRequestFocus) {
        if (ref.read(downloadsPanelViewProvider) == DownloadsPanelView.tasks) {
          _urlFocusNode.requestFocus();
        }
      }
    });

    if (_parsedItems != null && _parsedItems!.isNotEmpty) {
      _recalculateFilteredStatistics();
    }
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

  Future<void> _checkBinaries() async {
    final exist = await Future.microtask(
      () => EngineRegistry.requiredInstalled,
    );
    if (mounted) {
      setState(() {
        _binariesExist = exist;
      });
    }
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
    }
    return false;
  }

  String? _toastMessage;
  bool _showToast = false;
  bool _isDraggingFile = false;

  void _showLocalToast(String message) {
    if (!mounted) return;
    setState(() {
      _toastMessage = message;
      _showToast = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _toastMessage == message) {
        setState(() {
          _showToast = false;
        });
      }
    });
  }

  Future<void> _exportList() async {
    if (_parsedItems == null || _parsedItems!.isEmpty) return;
    try {
      final currentDir = ref.read(currentPathProvider);
      final saveLocation = await CustomFilePickerDialog.show(
        context,
        title: 'EXPORT LIST',
        allowedExtensions: ['json'],
        saveMode: true,
        initialFileName: 'export_list.json',
        initialDirectory: currentDir,
      );
      if (saveLocation == null || saveLocation.isEmpty) return;

      final itemsData = _parsedItems!.map((e) => e.toMap()).toList();
      _recalculateFilteredStatistics();
      final data = {
        'items': itemsData,
        'statistics': {
          'totalSize': _totalListSize,
          'images': _totalListImages,
          'videos': _totalListVideos,
        },
      };
      final jsonString = jsonEncode(data);
      await File(saveLocation.first).writeAsString(jsonString);

      setState(() {
        _parsedItems?.clear();
        _configs.clear();
        _selectedIndices.clear();
        _lastSelectedIndex = -1;
        _previewItem = null;
        _importedListName = null;
        _importedListPath = null;
        _isListChanged = false;
        _recalculateFilteredStatistics();
      });
      _showLocalToast('List exported successfully');
    } catch (e) {
      _showLocalToast('Failed to export list');
    }
  }

  Future<void> _updateList() async {
    if (_importedListPath == null) return;
    try {
      final itemsData = _parsedItems?.map((e) => e.toMap()).toList() ?? [];
      _recalculateFilteredStatistics();
      final data = {
        'items': itemsData,
        'statistics': {
          'totalSize': _totalListSize,
          'images': _totalListImages,
          'videos': _totalListVideos,
        },
      };
      final jsonString = jsonEncode(data);
      await File(_importedListPath!).writeAsString(jsonString);

      setState(() {
        if (data.isEmpty) {
          _parsedItems = null;
          _configs.clear();
          _selectedIndices.clear();
          _lastSelectedIndex = -1;
          _previewItem = null;
          _importedListName = null;
          _importedListPath = null;
          _recalculateFilteredStatistics();
        }
        _isListChanged = false;
      });
      _showLocalToast('List updated successfully');
    } catch (e) {
      _showLocalToast('Failed to update list');
    }
  }

  Future<void> _importList([String? path]) async {
    try {
      var filePath = path;
      if (filePath == null) {
        final currentDir = ref.read(currentPathProvider);
        final files = await CustomFilePickerDialog.show(
          context,
          title: 'IMPORT LIST',
          allowedExtensions: ['json'],
          initialDirectory: currentDir,
        );
        if (files == null || files.isEmpty) return;
        filePath = files.first;
      }

      final content = await File(filePath).readAsString();
      final decoded = jsonDecode(content);

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

      setState(() {
        _cache.switchList(filePath);
        _parsedItems = importedItems;
        _configs.clear();
        for (var i = 0; i < importedItems.length; i++) {
          _configs[i] = DownloadConfig(
            engine: importedItems[i].first.engineId ?? 'auto',
          );
        }
        _importedListPath = filePath;
        _importedListName = filePath!.split(Platform.pathSeparator).last;
        _isListChanged = false;
        _selectedIndices.clear();
        _lastSelectedIndex = -1;
        _previewItem = null;
        _recalculateFilteredStatistics();
      });
      _showLocalToast('List imported successfully');
    } catch (e) {
      _showLocalToast('Invalid JSON file');
    }
  }

  @override
  void dispose() {
    _logsScrollController.dispose();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _gradientController.dispose();
    _urlFocusNode.dispose();
    _listFocusNode.dispose();
    _previewFocusNode.dispose();
    _urlController.dispose();
    _hydrationNotifier.dispose();
    super.dispose();
  }

  Future<void> _hydrateProfile(String url) async {
    if (!mounted) return;
    setState(() {
      _backgroundLoadingProfiles.add(url);
    });

    try {
      final browser = ref.read(settingsProvider).value?.downloadBrowser;
      final isPlaylist =
          _parsedItems?.any(
            (g) =>
                g.originalUrl == url &&
                g.items.isNotEmpty &&
                g.items.first.isPlaylist,
          ) ??
          false;
      final items = await MediaDownloaderBackend.analyzeUrls(
        [url],
        engine: _selectedEngine,
        browser: browser,
        fetchDeep: true,
        isPlaylist: isPlaylist,
        onProcessStarted: (int pid) {
          if (!mounted) return;
          setState(() {
            _activeHydrationPids.putIfAbsent(url, () => []).add(pid);
          });
        },
        onProgress: (MediaInfo info) {
          if (!mounted) return;
          if (_parsedItems != null) {
            final groupIndex = _parsedItems!.indexWhere(
              (g) => g.originalUrl == url,
            );
            if (groupIndex != -1) {
              final group = _parsedItems![groupIndex];
              if (info.isProfile && group.items.any((e) => e.isProfile)) {
                return; // Skip duplicate fallback profile
              }

              // Check if it already exists, if not, append to show progressive update
              final existsIndex = group.items.indexWhere(
                (existing) => existing.id == info.id,
              );
              if (existsIndex == -1) {
                group.items.add(info);
              } else {
                // Update it in case metadata changed
                group.items[existsIndex] = info;
              }

              // Ensure hydration_loading stays at the end of the list
              if (info.id != 'hydration_loading') {
                final loadingIndex = group.items.indexWhere(
                  (e) => e.id == 'hydration_loading',
                );
                if (loadingIndex != -1 &&
                    loadingIndex < group.items.length - 1) {
                  final loadingItem = group.items.removeAt(loadingIndex);
                  group.items.add(loadingItem);
                }
              }

              if (group.items.isNotEmpty && group.items.first.isPlaylist) {
                group.items[0] = group.items[0].copyWith(
                  fetchLogs: info.fetchLogs,
                );
              }

              // C5: Throttle stats recalculation to every 5th item
              _pendingStatsUpdate++;
              if (_pendingStatsUpdate % 5 == 0) {
                _recalculateFilteredStatistics();
              }
              _hydrationNotifier
                  .value++; // Trigger UI update via ValueNotifier instead of full setState rebuild
            }
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _backgroundLoadingProfiles.remove(url);
        _activeHydrationPids.remove(url);

        // Ensure sorted items from generic extractors replace the old unsorted items
        if (_parsedItems != null) {
          final groupIndex = _parsedItems!.indexWhere(
            (g) => g.originalUrl == url,
          );
          if (groupIndex != -1) {
            final group = _parsedItems![groupIndex];
            final playlistInfo =
                group.items.isNotEmpty && group.items.first.isPlaylist
                ? group.items.first
                : null;
            final isGenericGroup =
                playlistInfo?.extractor?.toLowerCase() == 'generic' ||
                (items.isNotEmpty &&
                    items.any((i) => i.extractor?.toLowerCase() == 'generic'));

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
              final errorMsg = items.isNotEmpty
                  ? items.first.errorMessage
                  : null;
              final fetchLogs = items.isNotEmpty
                  ? items.first.fetchLogs
                  : null;
              if (errorMsg != null || fetchLogs != null) {
                group.items.add(
                  playlistInfo.copyWith(
                    errorMessage: errorMsg,
                    fetchLogs: fetchLogs,
                  ),
                );
              } else {
                group.items.add(playlistInfo);
              }
            }
            group.items.addAll(items);

            // Auto-select the highest available format after hydration
            if (_configs.containsKey(groupIndex)) {
              final config = _configs[groupIndex]!;
              final formatSet = <String, MediaFormat>{};
              for (final vid in group.items) {
                if (vid.isVideo) {
                  final sortedFormats = vid.formats.toList()
                    ..sort(
                      (a, b) => (b.filesize ?? 0).compareTo(a.filesize ?? 0),
                    );
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

            _recalculateFilteredStatistics();
            _hydrationNotifier.value++;
          }
        }

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
      _error = null;
      _urlController.clear();
      _parsedItems ??= [];

      for (final url in urls) {
        final isDuplicate = _parsedItems!.any(
          (existing) => existing.originalUrl == url,
        );
        if (!isDuplicate) {
          final placeholderInfo = MediaInfo(
            id: 'fetch_loading',
            title: 'Fetching...',
            originalUrl: url,
            isVideo: false,
          );
          _parsedItems!.add(
            MediaGroup(originalUrl: url, items: [placeholderInfo]),
          );
          _backgroundLoadingProfiles.add(url);
          _configs[_parsedItems!.length - 1] = DownloadConfig(
            engine: _selectedEngine,
          );
        }
      }
      _isListChanged = true;
      _recalculateFilteredStatistics();
    });

    final browser = ref.read(settingsProvider).value?.downloadBrowser;

    for (final url in urls) {
      MediaDownloaderBackend.analyzeUrls(
            [url],
            engine: _selectedEngine,
            browser: browser,
            onProcessStarted: (pid) {
              if (!mounted) return;
              setState(() {
                _activeHydrationPids.putIfAbsent(url, () => []).add(pid);
              });
            },
          )
          .then((items) {
            if (!mounted) return;
            setState(() {
              _backgroundLoadingProfiles.remove(url);
              _activeHydrationPids.remove(url);

              if (_parsedItems != null) {
                final index = _parsedItems!.indexWhere(
                  (g) => g.originalUrl == url,
                );
                if (index != -1) {
                  if (items.isEmpty) {
                    final errorInfo = MediaInfo(
                      id: 'fetch_error',
                      title: 'Fetch failed',
                      originalUrl: url,
                      isVideo: false,
                      isError: true,
                      errorMessage: 'No media found or fetch failed.',
                    );
                    _parsedItems![index] = MediaGroup(
                      originalUrl: url,
                      items: [errorInfo],
                    );
                  } else {
                    final group = MediaGroup(originalUrl: url, items: items);
                    _parsedItems![index] = group;

                    final info = group.first;
                    final hasImages = group.items.any(
                      (item) =>
                          !item.isVideo && !item.isPlaylist && !item.isProfile,
                    );
                    final hasVideos = group.items.any(
                      (item) => item.isVideo || item.isPlaylist,
                    );

                    var defaultFilter = GroupDownloadType.all;
                    if (!info.isProfile) {
                      if (hasImages && !hasVideos) {
                        defaultFilter = GroupDownloadType.images;
                      } else if (hasVideos && !hasImages) {
                        defaultFilter = GroupDownloadType.videos;
                      }
                    }

                    _configs[index] = DownloadConfig(
                      format: info.formats.isNotEmpty
                          ? info.formats.last
                          : (info.isPlaylist
                                ? const MediaFormat(
                                    formatId:
                                        'bestvideo[height<=1080][ext=mp4]+bestaudio[ext=m4a]/best[height<=1080][ext=mp4]/best',
                                    extension: 'mp4',
                                    resolution: '1080p',
                                    formatString: '1080p mp4',
                                  )
                                : null),
                      groupFilter: defaultFilter,
                      engine: info.engineId ?? 'auto',
                    );

                    if ((info.isProfile || info.isPlaylist) &&
                        group.items.length <= 13) {
                      _hydrateProfile(url);
                    }
                  }
                  _isListChanged = true;
                  _recalculateFilteredStatistics();
                }
              }
            });
          })
          .catchError((Object e) {
            if (!mounted) return;
            setState(() {
              _backgroundLoadingProfiles.remove(url);
              _activeHydrationPids.remove(url);
              final index =
                  _parsedItems?.indexWhere((g) => g.originalUrl == url) ?? -1;
              if (index != -1) {
                final errorInfo = MediaInfo(
                  id: 'fetch_error',
                  title: 'Fetch failed',
                  originalUrl: url,
                  isVideo: false,
                  isError: true,
                  errorMessage: e.toString(),
                );
                _parsedItems![index] = MediaGroup(
                  originalUrl: url,
                  items: [errorInfo],
                );
                _error = e.toString();
              }
            });
          });
    }
  }

  Future<void> _startDownload(int index, {String? singleItemId}) async {
    if (_parsedItems == null || index >= _parsedItems!.length) return;

    try {
      final group = _parsedItems![index];
      final config = _configs[index]!;

      final downloadToCurrent =
          ref.read(settingsProvider).value?.downloadToCurrentFolder ?? true;
      final dest = downloadToCurrent
          ? ref.read(currentPathProvider)
          : '${Platform.environment['HOME']}/Downloads';

      // Use a copy to prevent concurrent modification if background tasks update group.items
      final itemsToDownload = List<MediaInfo>.from(group.items);

      // Batch download logic for profiles AND grouped posts
      if ((group.first.isProfile || group.items.length > 1) &&
          singleItemId == null) {
        var safeName = group.first.title.replaceAll(
          RegExp(r'[\\/:*?"<>|]'),
          '_',
        );
        final isProfileOrPlaylist =
            group.first.isProfile || group.first.isPlaylist;
        final itemDest = isProfileOrPlaylist ? p.join(dest, safeName) : dest;
        if (isProfileOrPlaylist && !Directory(itemDest).existsSync()) {
          Directory(itemDest).createSync(recursive: true);
        }

        if (!isProfileOrPlaylist) {
          final dir = Directory(itemDest);
          var existingFiles = <File>[];
          if (dir.existsSync()) {
            existingFiles = dir.listSync().whereType<File>().toList();
          }

          final groupExists = existingFiles.any((f) {
            final base = p.basenameWithoutExtension(f.path);
            return base.startsWith('${safeName}_') || base == safeName;
          });

          if (groupExists) {
            var conflictCounter = 1;
            while (existingFiles.any((f) {
              final base = p.basenameWithoutExtension(f.path);
              return base.startsWith('$safeName ($conflictCounter)_') ||
                  base == '$safeName ($conflictCounter)';
            })) {
              conflictCounter++;
            }
            safeName = '$safeName ($conflictCounter)';
          }
        }

        String? filterType;
        int? totalFilteredItems;
        final isHydrating = _backgroundLoadingProfiles.contains(
          group.originalUrl,
        );
        var shouldAbortHydration = false;

        if (config.groupFilter == GroupDownloadType.images) {
          filterType = 'images';
          totalFilteredItems = isHydrating
              ? null
              : itemsToDownload
                    .where(
                      (item) =>
                          !item.isVideo && !item.isProfile && !item.isPlaylist,
                    )
                    .length;
        } else if (config.groupFilter == GroupDownloadType.videos) {
          filterType = 'videos';
          totalFilteredItems = isHydrating
              ? null
              : itemsToDownload
                    .where(
                      (item) =>
                          item.isVideo && !item.isProfile && !item.isPlaylist,
                    )
                    .length;
        } else {
          if (isHydrating) {
            totalFilteredItems = group.first.itemCount ?? 0;
            if (totalFilteredItems > 0) {
              shouldAbortHydration = true;
            }
          } else {
            totalFilteredItems = itemsToDownload
                .where((item) => !item.isProfile && !item.isPlaylist)
                .length;
          }
        }

        final expectedBytes = isHydrating
            ? 0
            : _getGroupBytes(
                MediaGroup(
                  originalUrl: group.originalUrl,
                  items: itemsToDownload,
                ),
                config,
              );

        ref
            .read(downloadTaskProvider.notifier)
            .startDownload(
              url: group.originalUrl,
              destination: itemDest,
              title: group.first.isProfile ? '$safeName Profile' : safeName,
              downloadType: group.first.isProfile
                  ? 'profile'
                  : (group.first.isPlaylist ? 'playlist' : 'generic'),
              format: config.format,
              audioOnly: config.mode == DownloadMode.audioOnly,
              mute: config.mode == DownloadMode.mute,
              engine: config.engine, // C3: use engine captured at fetch time
              isPlaylist: group.first.isPlaylist, // C2: pass actual isPlaylist
              isProfile: group.first.isProfile,
              browser: ref
                  .read(settingsProvider)
                  .value
                  ?.downloadBrowser, // C4: add missing browser
              filterType: filterType,
              totalItems: totalFilteredItems,
              expectedBytes: expectedBytes,
            );

        setState(() {
          if (_parsedItems != null) {
            final currentIndex = _parsedItems!.indexOf(group);
            if (currentIndex != -1) {
              _removeParsedItems([
                currentIndex,
              ], abortHydration: shouldAbortHydration);
              if (_previewItem == group) {
                _previewItem = null;
              }
            }
          }
        });
        return;
      }

      final dirCache = <String, List<File>>{};
      var count = 0;

      for (final info in itemsToDownload) {
        if (count++ % 20 == 0) await Future<void>.delayed(Duration.zero);
        if (singleItemId != null && info.id != singleItemId) continue;

        if (config.groupFilter == GroupDownloadType.images && info.isVideo) {
          continue;
        }
        if (config.groupFilter == GroupDownloadType.videos && !info.isVideo) {
          continue;
        }

        final format = config.itemFormats[info.id] ?? config.format;

        var itemDest = dest;
        if ((group.first.isPlaylist || group.first.isProfile) &&
            singleItemId == null) {
          final safeName = group.first.title.replaceAll(
            RegExp(r'[\\/:*?"<>|]'),
            '_',
          );
          itemDest = p.join(dest, safeName);
          if (!Directory(itemDest).existsSync()) {
            Directory(itemDest).createSync(recursive: true);
          }
        }

        var finalTitle = info.title;
        var suffix = '';
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
            var conflictCounter = 1;
            while (existingFiles.any(
              (f) =>
                  p.basenameWithoutExtension(f.path) ==
                  '$safeName ($conflictCounter)',
            )) {
              conflictCounter++;
            }
            finalTitle = '$finalTitle ($conflictCounter)';
          }
        }

        ref
            .read(downloadTaskProvider.notifier)
            .startDownload(
              url: info.webpageUrl ?? info.directUrl ?? info.originalUrl,
              destination: itemDest,
              title: finalTitle,
              downloadType: info.isPlaylist
                  ? 'playlist'
                  : (info.isProfile
                        ? 'profile'
                        : (info.isVideo ? 'video' : 'image')),
              format: format,
              audioOnly: config.mode == DownloadMode.audioOnly,
              mute: config.mode == DownloadMode.mute,
              galleryIndex: info.galleryIndex,
              engine: config.engine, // C3: use engine captured at fetch time
              browser: ref.read(settingsProvider).value?.downloadBrowser,
              totalItems: 1,
              singleItemId: singleItemId,
              directUrl: info.directUrl,
            );
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
    } finally {
      ref.read(conflictProvider.notifier).clearGlobalResolution();
    }
  }

  Future<void> _startDownloadAll() async {
    final itemsToDownload = _selectedIndices.isNotEmpty
        ? _filteredItems.where((e) => _selectedIndices.contains(e.key)).toList()
        : List.of(_filteredItems);
    if (itemsToDownload.isEmpty) return;

    final sessionNames = <String>{};

    try {
      // Collect group references and their configs instead of just indices
      final groupsToProcess = <MediaGroup, DownloadConfig>{};
      for (final item in itemsToDownload) {
        if (_parsedItems != null && item.key < _parsedItems!.length) {
          groupsToProcess[_parsedItems![item.key]] = _configs[item.key]!;
        }
      }

      final dirCache = <String, List<File>>{};

      for (final entry in groupsToProcess.entries) {
        final group = entry.key;
        final config = entry.value;

        final downloadToCurrent =
            ref.read(settingsProvider).value?.downloadToCurrentFolder ?? true;
        final dest = downloadToCurrent
            ? ref.read(currentPathProvider)
            : '${Platform.environment['HOME']}/Downloads';

        // Use a copy to prevent concurrent modification if background tasks update group.items
        final itemsToDownloadLocal = List<MediaInfo>.from(group.items);

        // Batch download logic for profiles AND grouped posts
        if (group.first.isProfile || group.items.length > 1) {
          var safeName = group.first.title.replaceAll(
            RegExp(r'[\\/:*?"<>|]'),
            '_',
          );
          final isProfileOrPlaylist =
              group.first.isProfile || group.first.isPlaylist;
          final itemDest = isProfileOrPlaylist ? p.join(dest, safeName) : dest;
          if (isProfileOrPlaylist && !Directory(itemDest).existsSync()) {
            Directory(itemDest).createSync(recursive: true);
          }

          if (!isProfileOrPlaylist) {
            if (!dirCache.containsKey(itemDest)) {
              final dir = Directory(itemDest);
              if (dir.existsSync()) {
                dirCache[itemDest] = dir.listSync().whereType<File>().toList();
              } else {
                dirCache[itemDest] = [];
              }
            }
            final existingFiles = dirCache[itemDest]!;

            final groupExists = existingFiles.any((f) {
              final base = p.basenameWithoutExtension(f.path);
              return base.startsWith('${safeName}_') || base == safeName;
            });

            if (groupExists || sessionNames.contains(safeName)) {
              var conflictCounter = 1;
              while (existingFiles.any((f) {
                    final base = p.basenameWithoutExtension(f.path);
                    return base.startsWith('$safeName ($conflictCounter)_') ||
                        base == '$safeName ($conflictCounter)';
                  }) ||
                  sessionNames.contains('$safeName ($conflictCounter)')) {
                conflictCounter++;
              }
              safeName = '$safeName ($conflictCounter)';
            }
          }

          sessionNames.add(safeName);

          String? filterType;
          int? totalFilteredItems;
          final isHydrating = _backgroundLoadingProfiles.contains(
            group.originalUrl,
          );

          if (config.groupFilter == GroupDownloadType.images) {
            filterType = 'images';
            totalFilteredItems = isHydrating
                ? null
                : itemsToDownloadLocal
                      .where((item) => !item.isVideo && !item.isProfile)
                      .length;
          } else if (config.groupFilter == GroupDownloadType.videos) {
            filterType = 'videos';
            totalFilteredItems = isHydrating
                ? null
                : itemsToDownloadLocal
                      .where((item) => item.isVideo && !item.isProfile)
                      .length;
          } else {
            if (isHydrating) {
              totalFilteredItems = group.first.itemCount ?? 0;
              // shouldAbortHydration is unused
            } else {
              totalFilteredItems = itemsToDownloadLocal
                  .where((item) => !item.isProfile)
                  .length;
            }
          }

          final expectedBytes = _getGroupBytes(
            MediaGroup(
              originalUrl: group.originalUrl,
              items: itemsToDownloadLocal,
            ),
            config,
          );

          ref
              .read(downloadTaskProvider.notifier)
              .startDownload(
                url: group.originalUrl,
                destination: itemDest,
                title: group.first.isProfile ? '$safeName Profile' : safeName,
                downloadType: group.first.isProfile
                    ? 'profile'
                    : (group.first.isPlaylist ? 'playlist' : 'generic'),
                format: config.format,
                audioOnly: config.mode == DownloadMode.audioOnly,
                mute: config.mode == DownloadMode.mute,
                engine: config.engine, // C3: use engine captured at fetch time
                isPlaylist:
                    group.first.isPlaylist, // C2: pass actual isPlaylist
                isProfile: group.first.isProfile,
                browser: ref
                    .read(settingsProvider)
                    .value
                    ?.downloadBrowser, // C4: add missing browser
                filterType: filterType,
                totalItems: totalFilteredItems,
                expectedBytes: expectedBytes,
              );
          continue;
        }

        var count = 0;

        for (final info in itemsToDownloadLocal) {
          if (count++ % 20 == 0) await Future<void>.delayed(Duration.zero);
          if (config.groupFilter == GroupDownloadType.images && info.isVideo) {
            continue;
          }
          if (config.groupFilter == GroupDownloadType.videos && !info.isVideo) {
            continue;
          }

          var itemDest = dest;
          if (info.isPlaylist) {
            final safeName = info.title.replaceAll(
              RegExp(r'[\\/:*?"<>|]'),
              '_',
            );
            itemDest = p.join(dest, safeName);
            if (!Directory(itemDest).existsSync()) {
              Directory(itemDest).createSync(recursive: true);
            }
          }

          var finalTitle = info.title;
          var suffix = '';
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
            final safeName = finalTitle.replaceAll(
              RegExp(r'[\\/:*?"<>|]'),
              '_',
            );

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
              var conflictCounter = 1;
              while (existingFiles.any(
                    (f) =>
                        p.basenameWithoutExtension(f.path) ==
                        '$safeName ($conflictCounter)',
                  ) ||
                  sessionNames.contains('$safeName ($conflictCounter)')) {
                conflictCounter++;
              }
              finalTitle = '$finalTitle ($conflictCounter)';
            }
          }

          sessionNames.add(finalTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_'));
          ref
              .read(downloadTaskProvider.notifier)
              .startDownload(
                url: info.originalUrl,
                destination: itemDest,
                title: finalTitle,
                downloadType: info.isPlaylist
                    ? 'playlist'
                    : (info.isProfile
                          ? 'profile'
                          : (info.isVideo ? 'video' : 'image')),
                format: config.format,
                audioOnly: config.mode == DownloadMode.audioOnly,
                mute: config.mode == DownloadMode.mute,
                galleryIndex: info.galleryIndex,
                engine: config.engine, // C3: use engine captured at fetch time
                isPlaylist: info.isPlaylist,
                browser: ref.read(settingsProvider).value?.downloadBrowser,
                totalItems: 1,
              );
        }
      }

      setState(() {
        if (_parsedItems != null) {
          final currentIndices = groupsToProcess.keys
              .map((g) => _parsedItems!.indexOf(g))
              .where((i) => i != -1)
              .toList();
          if (currentIndices.isNotEmpty) {
            var shouldAbort = false;
            for (final group in groupsToProcess.keys) {
              final config = groupsToProcess[group];
              if (config != null &&
                  config.groupFilter == GroupDownloadType.all) {
                final groupItems = group.items;
                if (groupItems.isNotEmpty &&
                    (groupItems.first.itemCount ?? 0) > 0) {
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
    } finally {
      ref.read(conflictProvider.notifier).clearGlobalResolution();
    }
  }

  void _removeParsedItems(List<int> indices, {bool abortHydration = true}) {
    if (_parsedItems == null) return;

    for (final i in indices) {
      if (i >= 0 && i < _parsedItems!.length) {
        final url = _parsedItems![i].originalUrl;
        if (abortHydration && _activeHydrationPids.containsKey(url)) {
          for (final pid in _activeHydrationPids[url]!) {
            ProcessUtils.killProcessTreeSync(pid);
          }
          _activeHydrationPids.remove(url);
          _backgroundLoadingProfiles.remove(url);
        }
      }
    }

    final sortedIndices = List<int>.from(indices)
      ..sort((a, b) => b.compareTo(a));
    final remainingItems = <MediaGroup>[];
    final remainingConfigs = <DownloadConfig>[];

    for (var i = 0; i < _parsedItems!.length; i++) {
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
    _itemKeys.clear(); // RISK-008: Prevent GlobalKey memory leak
    for (var i = 0; i < remainingItems.length; i++) {
      _configs[i] = remainingConfigs[i];
    }

    _selectedIndices.clear();
    _lastSelectedIndex = -1;
    _anchorIndex = -1;
    _isListChanged = true;
    if (_parsedItems!.isEmpty) {
      _parsedItems = null;
      FocusScope.of(context).unfocus();
    }
    _previewItem = null;
    _recalculateFilteredStatistics();
  }

  void _removeSingleItem(int groupIndex, String itemId) {
    if (_parsedItems == null || groupIndex >= _parsedItems!.length) return;

    final group = _parsedItems![groupIndex];
    group.items.removeWhere((i) => i.id == itemId);

    if (group.items.isEmpty) {
      _removeParsedItems([groupIndex]);
    } else {
      // Re-trigger rebuild
      setState(() {
        _isListChanged = true;
        _recalculateFilteredStatistics();
      });
    }
  }

  void _updateShiftSelection(List<MapEntry<int, MediaGroup>> items) {
    if (_anchorIndex == -1) _anchorIndex = _lastSelectedIndex;
    final visualStart = items.indexWhere((e) => e.key == _anchorIndex);
    final visualEnd = items.indexWhere((e) => e.key == _lastSelectedIndex);
    if (visualStart != -1 && visualEnd != -1) {
      final start = visualStart < visualEnd ? visualStart : visualEnd;
      final end = visualStart > visualEnd ? visualStart : visualEnd;
      _selectedIndices.clear();
      for (var i = start; i <= end; i++) {
        _selectedIndices.add(items[i].key);
      }
    }
  }

  Widget _buildErrorLogsOverlay() {
    var isCopied = false;

    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _errorLogsMessage = null;
          });
        },
        child: ColoredBox(
          color: Colors.black.withValues(alpha: 0.8),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Prevent taps inside the dialog from bubbling up
              child: Container(
                width: 400,
                height: 375,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceBase,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Pipeline Logs',
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            StatefulBuilder(
                              builder: (context, setStateOverlay) {
                                return IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                  splashRadius: 18,
                                  icon: Icon(
                                    isCopied
                                        ? Icons.check_rounded
                                        : Icons.copy_rounded,
                                    color: isCopied
                                        ? Colors.greenAccent
                                        : Colors.white70,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    if (_errorLogsMessage != null &&
                                        !isCopied) {
                                      Clipboard.setData(
                                        ClipboardData(text: _errorLogsMessage!),
                                      );
                                      setStateOverlay(() {
                                        isCopied = true;
                                      });
                                      Future.delayed(
                                        const Duration(seconds: 3),
                                        () {
                                          if (mounted) {
                                            setStateOverlay(() {
                                              isCopied = false;
                                            });
                                          }
                                        },
                                      );
                                    }
                                  },
                                  tooltip: 'Copy Logs',
                                );
                              },
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              splashRadius: 18,
                              icon: const Icon(
                                Icons.refresh_rounded,
                                color: Colors.white70,
                                size: 18,
                              ),
                              onPressed: () {
                                setState(_updateLogsMessage);
                                _scrollToBottomLogs();
                              },
                              tooltip: 'Refresh Logs',
                            ),
                            IconButton(
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(
                                minWidth: 36,
                                minHeight: 36,
                              ),
                              splashRadius: 18,
                              icon: const Icon(
                                Icons.close_rounded,
                                color: Colors.white70,
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  _errorLogsMessage = null;
                                  _activeLogItem = null;
                                });
                              },
                              tooltip: 'Close',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        child: TextField(
                          controller: TextEditingController(
                            text: _errorLogsMessage ?? '',
                          ),
                          scrollController: _logsScrollController,
                          readOnly: true,
                          maxLines: null,
                          style: GoogleFonts.firaCode(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnsavedConfirmationOverlay() {
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.8),
        child: Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surfaceBase,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Unsaved Changes',
                  style: GoogleFonts.manrope(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You have unsaved changes in this imported list. If you close it now, your changes will be lost.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _showUnsavedConfirmation = false;
                            _pendingClearAction = null;
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.manrope(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _showUnsavedConfirmation = false;
                            final action = _pendingClearAction;
                            _pendingClearAction = null;
                            if (action != null) {
                              action();
                            }
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                          foregroundColor: Colors.redAccent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: Colors.redAccent.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                        child: Text(
                          'Close Anyway',
                          style: GoogleFonts.manrope(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(downloadUrlFocusRequestProvider, (_, __) {
      if (mounted && _urlFocusNode.canRequestFocus) {
        if (ref.read(downloadsPanelViewProvider) == DownloadsPanelView.tasks) {
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) {
              _urlFocusNode.requestFocus();
            }
          });
        }
      }
    });

    ref.listen<DownloadsPanelView>(downloadsPanelViewProvider, (_, next) {
      if (next == DownloadsPanelView.tasks) {
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 50), () {
            if (mounted) {
              _urlFocusNode.requestFocus();
            }
          });
        }
      }
    });

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
          if (_importedListPath != null && _isListChanged) {
            _updateList();
          }
        },
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (_errorLogsMessage != null) {
            setState(() {
              _errorLogsMessage = null;
            });
            return;
          }
          if (_showUnsavedConfirmation) {
            setState(() {
              _showUnsavedConfirmation = false;
              _pendingClearAction = null;
            });
            return;
          }
          setState(() {
            _selectedIndices.clear();
            _anchorIndex = -1;
            _previewItem = null;
          });
        },
        const SingleActivator(LogicalKeyboardKey.delete): () {
          if (_selectedIndices.isNotEmpty) {
            setState(() {
              _removeParsedItems(_selectedIndices.toList());
            });
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): () {
          setState(() {
            final items = _filteredItems;
            if (items.isNotEmpty) {
              _selectedIndices.clear();
              for (final item in items) {
                _selectedIndices.add(item.key);
              }
              _anchorIndex = items.first.key;
              _lastSelectedIndex = items.last.key;
            }
          });
        },
        const SingleActivator(LogicalKeyboardKey.arrowDown): () {
          setState(() {
            final items = _filteredItems;
            if (items.isEmpty) return;
            final currentVisualIndex = items.indexWhere(
              (e) => e.key == _lastSelectedIndex,
            );
            if (currentVisualIndex < items.length - 1) {
              _lastSelectedIndex = items[currentVisualIndex + 1].key;
              _anchorIndex = _lastSelectedIndex;
              _selectedIndices.clear();
              _selectedIndices.add(_lastSelectedIndex);
              _scrollToIndex(_lastSelectedIndex);
            }
          });
        },
        const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): () {
          setState(() {
            final items = _filteredItems;
            if (items.isEmpty) return;
            if (_anchorIndex == -1) _anchorIndex = _lastSelectedIndex;
            final currentVisualIndex = items.indexWhere(
              (e) => e.key == _lastSelectedIndex,
            );
            if (currentVisualIndex < items.length - 1) {
              _lastSelectedIndex = items[currentVisualIndex + 1].key;
              _updateShiftSelection(items);
              _scrollToIndex(_lastSelectedIndex);
            }
          });
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp): () {
          setState(() {
            final items = _filteredItems;
            if (items.isEmpty) return;
            final currentVisualIndex = items.indexWhere(
              (e) => e.key == _lastSelectedIndex,
            );
            if (currentVisualIndex > 0) {
              _lastSelectedIndex = items[currentVisualIndex - 1].key;
              _anchorIndex = _lastSelectedIndex;
              _selectedIndices.clear();
              _selectedIndices.add(_lastSelectedIndex);
              _scrollToIndex(_lastSelectedIndex);
            } else if (currentVisualIndex == -1 && items.isNotEmpty) {
              _lastSelectedIndex = items.last.key;
              _anchorIndex = _lastSelectedIndex;
              _selectedIndices.clear();
              _selectedIndices.add(_lastSelectedIndex);
              _scrollToIndex(_lastSelectedIndex);
            }
          });
        },
        const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): () {
          setState(() {
            final items = _filteredItems;
            if (items.isEmpty) return;
            if (_anchorIndex == -1) _anchorIndex = _lastSelectedIndex;
            final currentVisualIndex = items.indexWhere(
              (e) => e.key == _lastSelectedIndex,
            );
            if (currentVisualIndex > 0) {
              _lastSelectedIndex = items[currentVisualIndex - 1].key;
              _updateShiftSelection(items);
              _scrollToIndex(_lastSelectedIndex);
            }
          });
        },
      },
      child: ColoredBox(
        color: Colors.transparent,
        child: Focus(
          focusNode: _listFocusNode,
          descendantsAreFocusable: true,
          child: Listener(
            onPointerDown: (_) {
              if (_listFocusNode.canRequestFocus) _listFocusNode.requestFocus();
            },
            child: MouseRegion(
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
                                      child: ColoredBox(
                                        color: Colors.black.withValues(
                                          alpha: 0.2,
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

                    if (_showUnsavedConfirmation)
                      _buildUnsavedConfirmationOverlay(),

                    if (_errorLogsMessage != null) _buildErrorLogsOverlay(),

                    // Local Toast Overlay
                    Positioned(
                      top: 60,
                      left: 20,
                      right: 20,
                      child: AnimatedSlide(
                        offset: _showToast
                            ? Offset.zero
                            : const Offset(0, -1.5),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutBack,
                        child: AnimatedOpacity(
                          opacity: _showToast ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 200),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceBase.withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    color: AppColors.violet,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _toastMessage ?? '',
                                    style: GoogleFonts.manrope(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _JugglingBallsLoader extends StatefulWidget {
  const _JugglingBallsLoader();

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
            final t = _controller.value * 2 * pi;
            final offset = index * (pi / 2);
            final y = sin(t + offset) * 3;
            return Transform.translate(
              offset: Offset(0, y),
              child: Padding(
                padding: EdgeInsets.only(right: index < 2 ? 5 : 0),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8 - (index * 0.2)),
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

  _GradientBorderPainter(
    this.animation, {
    this.colors = const [
      AppColors.magenta,
      AppColors.violet,
      AppColors.indigo,
      AppColors.magenta,
    ],
    this.radius = 12.0,
    this.strokeWidth = 1.5,
  });
  final double animation;
  final List<Color> colors;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = SweepGradient(
        colors: colors,
        transform: GradientRotation(animation * 2 * 3.141592653589793),
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter old) =>
      old.animation != animation ||
      old.colors != colors ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth;

}