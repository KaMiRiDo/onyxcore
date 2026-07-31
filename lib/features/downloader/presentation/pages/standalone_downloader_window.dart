import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/conflict_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_shared_controller.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/properties_dialog.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/downloads_panel.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_action_bar.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_active_downloads.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_header.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_location_bar.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_media_grid.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_media_list.dart';
import 'package:onyxcore/features/file_picker/presentation/widgets/custom_file_picker_dialog.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:path/path.dart' as p;

class StandaloneDownloaderWindow extends ConsumerStatefulWidget {
  const StandaloneDownloaderWindow({
    required this.windowId,
    super.key,
    this.initParams = const {},
  });
  final int windowId;
  final Map<String, dynamic> initParams;

  @override
  ConsumerState<StandaloneDownloaderWindow> createState() =>
      _StandaloneDownloaderWindowState();
}

class _StandaloneTabState {
  MediaGroup? currentGroup;
  Set<int> selectedIndices = {};
  int lastSelectedIndex = -1;
  List<MediaGroup?> navigationHistory = [null];
  int historyIndex = 0;
  bool isTrashView = false;
  String searchQuery = '';
  bool isSearchVisible = false;
  String listFilter = 'added_desc';
}

class _StandaloneDownloaderWindowState
    extends ConsumerState<StandaloneDownloaderWindow>
    with SingleTickerProviderStateMixin, DownloadsPanelHelpersMixin {
  late DownloadsSharedController _controller;
  final Set<int> _downloadingImageIndices = {};

  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _mainFocusNode = FocusNode();
  ValueNotifier<int>? _focusTrigger;
  Timer? _searchDebounce;
  late AnimationController _gradientController;
  final ScrollController _mediaGridScrollController = ScrollController();
  final Map<String, GlobalKey> _tagKeys = {};
  final ValueNotifier<Map<String, String>?> _activeTagNotifier = ValueNotifier(
    null,
  );
  List<MediaGroup> _currentVisibleGroups = [];
  String _currentPath = '';
  MediaGroup? _currentGroup;

  final Set<int> _selectedIndices = {};
  int _lastSelectedIndex = -1;
  final List<MediaGroup?> _navigationHistory = [null];
  int _historyIndex = 0;
  final List<_TrashItem> _trash = [];
  bool _isTrashView = false;
  bool _isSearchVisible = false;
  String _listFilter = 'added_desc';

  final Map<String, _StandaloneTabState> _tabStates = {};

  void _saveCurrentTabState(String path) {
    _tabStates[path] = _StandaloneTabState()
      ..currentGroup = _currentGroup
      ..selectedIndices = Set.from(_selectedIndices)
      ..lastSelectedIndex = _lastSelectedIndex
      ..navigationHistory = List.from(_navigationHistory)
      ..historyIndex = _historyIndex
      ..isTrashView = _isTrashView
      ..searchQuery = _searchController.text
      ..isSearchVisible = _isSearchVisible
      ..listFilter = _listFilter;
  }

  void _restoreTabState(String path) {
    final state = _tabStates[path] ?? _StandaloneTabState();
    _currentGroup = state.currentGroup;
    _selectedIndices.clear();
    _selectedIndices.addAll(state.selectedIndices);
    _lastSelectedIndex = state.lastSelectedIndex;
    _navigationHistory.clear();
    _navigationHistory.addAll(state.navigationHistory);
    _historyIndex = state.historyIndex;
    _isTrashView = state.isTrashView;
    _searchController.text = state.searchQuery;
    _isSearchVisible = state.isSearchVisible;
    _listFilter = state.listFilter;
  }

  void _showPropertiesDialog([dynamic itemOverride]) {
    final items = <dynamic>[];
    if (itemOverride != null) {
      items.add(itemOverride);
    } else {
      if (_selectedIndices.isEmpty) return;
      if (_currentGroup == null) {
        for (final index in _selectedIndices) {
          if (index < (_controller.cache.parsedItems?.length ?? 0)) {
            items.add(_controller.cache.parsedItems![index]);
          }
        }
      } else {
        for (final index in _selectedIndices) {
          if (index < _currentGroup!.items.length) {
            items.add(_currentGroup!.items[index]);
          }
        }
      }
    }

    if (items.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (context) => PropertiesDialog(
        selectedItems: items,
        onClose: () => Navigator.of(context).pop(),
        onDownload: () {
          final sortedIndices = _selectedIndices.toList()
            ..sort((a, b) => b.compareTo(a));
          if (sortedIndices.isNotEmpty) {
            _handleDownloadSelected(sortedIndices);
          } else if (itemOverride != null) {
            // If invoked via itemOverride, handle downloading that specific item
            // For now, if no selection, we select the item and then download it
            if (itemOverride is MediaGroup) {
              final idx =
                  _controller.cache.parsedItems?.indexOf(itemOverride) ?? -1;
              if (idx != -1) _handleDownloadSelected([idx]);
            } else if (itemOverride is MediaInfo && _currentGroup != null) {
              final idx = _currentGroup!.items.indexOf(itemOverride);
              if (idx != -1) _handleDownloadSelected([idx]);
            }
          }
        },
      ),
    );
  }

  void _handleDownloadSelected(List<int> sortedIndices) {
    setState(() {
      for (final index in sortedIndices) {
        if (_currentGroup == null) {
          if (index < (_controller.cache.parsedItems?.length ?? 0)) {
            final group = _controller.cache.parsedItems![index];
            _startDownload(group, index);
            _controller.cache.parsedItems!.removeAt(index);
          }
        } else {
          if (index < _currentGroup!.items.length) {
            final item = _currentGroup!.items[index];
            final group = MediaGroup(
              originalUrl: item.originalUrl,
              items: [item],
            );
            final rootIndex = _controller.cache.parsedItems!.indexOf(
              _currentGroup!,
            );
            _startDownload(group, rootIndex);
            _currentGroup!.items.removeAt(index);
          }
        }
      }
      _selectedIndices.clear();
      _lastSelectedIndex = -1;
    });
  }

  void _handleDelete(bool isShiftPressed) {
    if (_selectedIndices.isEmpty) return;

    final sortedIndices = _selectedIndices.toList()
      ..sort((a, b) => b.compareTo(a)); // Reverse sort to remove from end

    if (isShiftPressed) {
      // Prompt for permanent delete
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: Text(
            'Permanently Delete',
            style: GoogleFonts.outfit(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to permanently delete these ${_selectedIndices.length} items? This cannot be undone.',
            style: GoogleFonts.outfit(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(color: Colors.white70),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () {
                Navigator.of(context).pop();
                _performDelete(
                  moveToTrash: false,
                  sortedIndices: sortedIndices,
                );
              },
              child: Text(
                'Delete',
                style: GoogleFonts.outfit(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    } else {
      _performDelete(moveToTrash: true, sortedIndices: sortedIndices);
    }
  }

  void _performDelete({
    required bool moveToTrash,
    required List<int> sortedIndices,
  }) {
    setState(() {
      final listPath = _controller.cache.importedListPath ?? 'default';

      if (_currentGroup == null) {
        // Deleting root groups
        for (final index in sortedIndices) {
          if (index < (_controller.cache.parsedItems?.length ?? 0)) {
            final item = _controller.cache.parsedItems!.removeAt(index);
            final config = _controller.cache.configs.remove(index);
            // Re-index configs
            final newConfigs = <int, DownloadConfig>{};
            for (final entry in _controller.cache.configs.entries) {
              if (entry.key > index) {
                newConfigs[entry.key - 1] = entry.value;
              } else {
                newConfigs[entry.key] = entry.value;
              }
            }
            _controller.cache.configs.clear();
            _controller.cache.configs.addAll(newConfigs);

            if (moveToTrash) {
              _trash.add(
                _TrashItem(item: item, listPath: listPath, config: config),
              );
            }
          }
        }
      } else {
        // Deleting inner items
        for (final index in sortedIndices) {
          if (index < _currentGroup!.items.length) {
            final item = _currentGroup!.items.removeAt(index);
            if (moveToTrash) {
              _trash.add(
                _TrashItem(
                  item: item,
                  listPath: listPath,
                  parentGroup: _currentGroup,
                ),
              );
            }
          }
        }
      }

      _selectedIndices.clear();
      _lastSelectedIndex = -1;
      _controller.cache.isListChanged = true;
    });
    _controller.recalculateFilteredStatistics();
  }

  int _getHeight(String res) {
    if (res.isEmpty || res == 'audio only' || res.toLowerCase() == 'audio') {
      return 0;
    }
    final lower = res.toLowerCase();
    if (lower.contains('4k') || lower.contains('2160')) return 2160;
    if (lower.contains('1440') || lower.contains('2k')) return 1440;
    if (lower.contains('1080')) return 1080;
    if (lower.contains('720')) return 720;
    if (lower.contains('480')) return 480;

    final parts = lower.split('x');
    if (parts.length == 2) {
      return int.tryParse(parts[1]) ?? 0;
    } else {
      return int.tryParse(lower.replaceAll(RegExp('[^0-9]'), '')) ?? 0;
    }
  }

  int _getGroupBytes(MediaGroup group, DownloadConfig config) => 0;

  Future<void> _startDownload(MediaGroup group, int configIndex) async {
    try {
      final config = _controller.cache.configs[configIndex] ?? DownloadConfig();

      final downloadToCurrent =
          ref.read(settingsProvider).value?.downloadToCurrentFolder ?? true;
      final dest = downloadToCurrent
          ? ref.read(currentPathProvider)
          : '${Platform.environment['HOME']}/Downloads';

      final itemsToDownload = List<MediaInfo>.from(group.items);

      if (group.first.isProfile || group.first.isPlaylist) {
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
        if (config.groupFilter == GroupDownloadType.images) {
          filterType = 'images';
          totalFilteredItems = itemsToDownload
              .where(
                (item) => !item.isVideo && !item.isProfile && !item.isPlaylist,
              )
              .length;
        } else if (config.groupFilter == GroupDownloadType.videos) {
          filterType = 'videos';
          totalFilteredItems = itemsToDownload
              .where(
                (item) => item.isVideo && !item.isProfile && !item.isPlaylist,
              )
              .length;
        } else {
          totalFilteredItems = itemsToDownload
              .where((item) => !item.isProfile && !item.isPlaylist)
              .length;
        }

        final expectedBytes = _getGroupBytes(
          MediaGroup(originalUrl: group.originalUrl, items: itemsToDownload),
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
              engine: config.engine,
              isPlaylist: group.first.isPlaylist,
              isProfile: group.first.isProfile,
              browser: ref.read(settingsProvider).value?.downloadBrowser,
              filterType: filterType,
              totalItems: totalFilteredItems,
              expectedBytes: expectedBytes,
            );

        return;
      }

      final dirCache = <String, List<File>>{};
      var count = 0;
      final sessionNames = <String>{};

      for (final info in itemsToDownload) {
        if (count++ % 20 == 0) await Future<void>.delayed(Duration.zero);
        if (config.groupFilter == GroupDownloadType.images && info.isVideo) {
          continue;
        }
        if (config.groupFilter == GroupDownloadType.videos && !info.isVideo) {
          continue;
        }

        final format = config.itemFormats[info.id] ?? config.format;
        var itemDest = dest;

        if (group.first.isPlaylist || group.first.isProfile) {
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
              engine: config.engine,
              browser: ref.read(settingsProvider).value?.downloadBrowser,
              totalItems: 1,
              directUrl: info.directUrl,
            );
      }
    } catch (e) {
      debugPrint('Error starting download: $e');
    }
  }

  Future<void> _downloadAll() async {
    final parsedItems = _controller.cache.parsedItems;
    if (parsedItems == null || parsedItems.isEmpty) return;

    try {
      if (_selectedIndices.isNotEmpty) {
        // Selection scenario: Download only selected items
        // We iterate backwards to safely remove from the list.
        final sortedIndices = _selectedIndices.toList()
          ..sort((a, b) => b.compareTo(a));
        if (_currentGroup == null) {
          for (final i in sortedIndices) {
            await _startDownload(parsedItems[i], i);
            parsedItems.removeAt(i);
          }
        } else {
          final rootIndex = parsedItems.indexOf(_currentGroup!);
          for (final i in sortedIndices) {
            final item = _currentGroup!.items[i];
            await _startDownload(
              MediaGroup(originalUrl: item.originalUrl, items: [item]),
              rootIndex,
            );
            _currentGroup!.items.removeAt(i);
          }
        }
        setState(() {
          _selectedIndices.clear();
          _lastSelectedIndex = -1;
        });
      } else if (_currentGroup != null) {
        // Sub-item scenario: Download all items in current group
        final rootIndex = parsedItems.indexOf(_currentGroup!);
        await _startDownload(_currentGroup!, rootIndex);
        setState(() {
          parsedItems.remove(_currentGroup);
          _currentGroup = null;
          _historyIndex = 0;
          _navigationHistory.clear();
          _navigationHistory.add(null);
        });
      } else {
        // Main list scenario
        final itemsToDownload = List<MediaGroup>.from(parsedItems);
        for (var i = 0; i < itemsToDownload.length; i++) {
          await _startDownload(itemsToDownload[i], i);
        }
        setState(parsedItems.clear);
      }

      _controller.cache.isListChanged = true;
      _controller.cache.notify();
    } finally {
      ref.read(conflictProvider.notifier).clearGlobalResolution();
    }
  }

  void _onWindowFocus() {
    if (mounted && !_searchFocusNode.hasFocus && !_urlFocusNode.hasFocus) {
      _mainFocusNode.requestFocus();
    }
  }

  @override
  void initState() {
    super.initState();
    _searchDebounce = null;
    _focusTrigger = PersistentViewerManager.getFocusTrigger(widget.windowId);
    _focusTrigger?.addListener(_onWindowFocus);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mainFocusNode.requestFocus();
      }
    });

    _currentPath = widget.initParams['currentPath'] as String? ?? '';

    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _searchController.addListener(_onSearchChanged);

    HardwareKeyboard.instance.addHandler(_handleGlobalRawKey);
    _mediaGridScrollController.addListener(_handleScroll);
    PersistentViewerManager.presentWindow(widget.windowId);
  }

  void _handleScroll() {
    if (!mounted) return;
    final tag = _calculateNearestTag();
    if (_activeTagNotifier.value?['url'] != tag?['url']) {
      _activeTagNotifier.value = tag;
    }
  }

  Map<String, String>? _calculateNearestTag() {
    var currentIndex = 0;
    var lastVisibleIndex = 0;
    if (_mediaGridScrollController.hasClients) {
      final offset = _mediaGridScrollController.offset;
      final height = MediaQuery.of(context).size.height;
      final width = MediaQuery.of(context).size.width - 380;
      final crossAxisCount = (width / 236).floor().clamp(1, 10);
      final row = (offset / 300).floor();
      currentIndex = row * crossAxisCount;
      final visibleRows = (height / 300).ceil();
      lastVisibleIndex = currentIndex + (visibleRows * crossAxisCount);
    }

    final allTags = <Map<String, dynamic>>[];
    for (var i = 0; i < _currentVisibleGroups.length; i++) {
      final group = _currentVisibleGroups[i];
      if (_currentGroup == null) {
        if (group.tag != null && group.tag!.isNotEmpty) {
          allTags.add({
            'index': i,
            'tag': group.tag,
            'url': group.originalUrl,
            'sort': group.tagSortOrder ?? 'added_desc',
          });
        }
      } else {
        if (group.items.isNotEmpty) {
          final item = group.items.first;
          if (item.tag != null && item.tag!.isNotEmpty) {
            allTags.add({
              'index': i,
              'tag': item.tag,
              'url': item.id,
              'sort': item.tagSortOrder ?? 'added_desc',
            });
          }
        }
      }
    }

    if (allTags.isEmpty) return null;

    final upcomingTags = allTags
        .where((t) => (t['index'] as int) >= currentIndex)
        .toList();

    if (upcomingTags.isEmpty) {
      final last = allTags.last;
      return {
        'tag': last['tag'] as String,
        'url': last['url'] as String,
        'sort': last['sort'] as String,
      };
    }

    var targetTag = upcomingTags.first;

    if ((targetTag['index'] as int) <= lastVisibleIndex) {
      final targetIndexInAll = allTags.indexOf(targetTag);
      if (targetIndexInAll < allTags.length - 1) {
        targetTag = allTags[targetIndexInAll + 1];
      }
    }

    return {
      'tag': targetTag['tag'] as String,
      'url': targetTag['url'] as String,
      'sort': targetTag['sort'] as String,
    };
  }

  @override
  void didUpdateWidget(covariant StandaloneDownloaderWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initParams['currentPath'] !=
        oldWidget.initParams['currentPath']) {
      setState(() {
        _currentPath = widget.initParams['currentPath'] as String? ?? '';
      });
    }
  }

  bool _handleGlobalRawKey(KeyEvent event) {
    if (!mounted) return false;

    if (event is KeyDownEvent && HardwareKeyboard.instance.isControlPressed) {
      if (event.logicalKey == LogicalKeyboardKey.keyF) {
        setState(() {
          if (_searchFocusNode.hasFocus) {
            _searchController.clear();
            _searchFocusNode.unfocus();
            _isSearchVisible = false;
            if (mounted && _mainFocusNode.canRequestFocus) {
              FocusScope.of(context).requestFocus(_mainFocusNode);
            }
          } else {
            _isSearchVisible = true;
            if (mounted && _searchFocusNode.canRequestFocus) {
              FocusScope.of(context).requestFocus(_searchFocusNode);
              _searchController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _searchController.text.length,
              );
            }
          }
        });
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyD) {
        if (mounted && _urlFocusNode.canRequestFocus) {
          FocusScope.of(context).requestFocus(_urlFocusNode);
          _urlController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _urlController.text.length,
          );
        }
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyW) {
        final path = _controller.cache.importedListPath;
        if (path != null && path != 'default') {
          final index = _controller.cache.customLists.indexWhere(
            (l) => l.path == path,
          );
          _controller.cache.invalidateCache(path);
          _tabStates.remove(path);

          var newPath = 'default';
          if (_controller.cache.customLists.isNotEmpty) {
            final nextIndex = index < _controller.cache.customLists.length
                ? index
                : _controller.cache.customLists.length - 1;
            newPath = _controller.cache.customLists[nextIndex].path;
          }

          setState(() {
            _controller.cache.switchList(newPath);
            _restoreTabState(newPath);
          });
        }
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.tab) {
        final lists = _controller.cache.customLists;
        final allPaths = ['default', ...lists.map((l) => l.path)];
        final currentPath = _controller.cache.importedListPath ?? 'default';
        final currentIndex = allPaths.indexOf(currentPath);

        final nextIndex = (currentIndex + 1) % allPaths.length;
        final nextPath = allPaths[nextIndex];

        _saveCurrentTabState(currentPath);

        setState(() {
          _controller.cache.switchList(nextPath);
          _restoreTabState(nextPath);
        });
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyS) {
        final path = _controller.cache.importedListPath;
        if (path == null || path == 'default') {
          _exportCurrentList();
        } else if (_controller.cache.isListChanged) {
          _saveCustomList(path);
        }
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _focusTrigger?.removeListener(_onWindowFocus);
    _gradientController.dispose();
    _mainFocusNode.dispose();
    _urlController.dispose();
    _urlFocusNode.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    _mediaGridScrollController.removeListener(_handleScroll);
    _mediaGridScrollController.dispose();
    _activeTagNotifier.dispose();
    HardwareKeyboard.instance.removeHandler(_handleGlobalRawKey);
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {}); // Rebuild to filter media grid
      }
    });
  }

  void _fetchUrl() {
    if (_urlController.text.trim().isNotEmpty) {
      _controller.analyzeUrls(_urlController.text.trim());
      _urlController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleScroll();
    });

    _controller = ref.watch(downloadsSharedControllerProvider);
    // Also watch the cache explicitly so UI updates when cache changes
    ref.watch(downloadsListCacheProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Listener(
        onPointerDown: (_) {
          if (!_searchFocusNode.hasFocus && !_urlFocusNode.hasFocus) {
            _mainFocusNode.requestFocus();
          }
        },
        child: Focus(
          focusNode: _mainFocusNode,
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent) {
              if (event.logicalKey == LogicalKeyboardKey.delete) {
                if (_selectedIndices.isNotEmpty) {
                  _handleDelete(HardwareKeyboard.instance.isShiftPressed);
                  return KeyEventResult.handled;
                }
              }

              if (HardwareKeyboard.instance.isAltPressed) {
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  if (_historyIndex > 0) {
                    setState(() {
                      _historyIndex--;
                      _currentGroup = _navigationHistory[_historyIndex];
                      _selectedIndices.clear();
                      _lastSelectedIndex = -1;
                    });
                  }
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  if (_historyIndex < _navigationHistory.length - 1) {
                    setState(() {
                      _historyIndex++;
                      _currentGroup = _navigationHistory[_historyIndex];
                      _selectedIndices.clear();
                      _lastSelectedIndex = -1;
                    });
                  }
                  return KeyEventResult.handled;
                } else if (event.logicalKey == LogicalKeyboardKey.enter) {
                  if (_selectedIndices.isNotEmpty) {
                    _showPropertiesDialog();
                  }
                  return KeyEventResult.handled;
                }
              }
            }
            return KeyEventResult.ignored;
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sidebarWidth = (constraints.maxWidth * 0.25).clamp(200.0, 340.0);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left Sidebar
                  Container(
                    width: sidebarWidth,
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceBase,
                      border: Border(right: BorderSide(color: Colors.white10)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Media List Section
                        Expanded(child: _buildMediaListSection()),

                        const Divider(height: 1, color: Colors.white10),

                        // Active Downloads Section
                        Expanded(child: _buildActiveDownloadsSection()),
                      ],
                    ),
                  ),

                  // Right Main Content
                  Expanded(
                    child: Column(
                      children: [
                        // Header
                        _buildHeader(),

                        // Contextual Action Bar
                        _buildActionBar(),

                        // Media Grid
                        Expanded(child: _buildMediaGrid()),

                        // Location Bar
                        _buildLocationBar(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return StandaloneWindowHeader(
      urlController: _urlController,
      urlFocusNode: _urlFocusNode,
      gradientController: _gradientController,
      selectedEngine: _controller.selectedEngine,
      onEngineChanged: (engine) {
        setState(() {
          _controller.selectedEngine = engine;
        });
      },
      onFetch: _fetchUrl,
    );
  }

  Future<void> _saveCustomList(String path) async {
    final stateItems = _controller.cache.getItemsForPath(path);
    if (stateItems != null) {
      final file = File(path);
      final data = {'items': stateItems.map((e) => e.toMap()).toList()};
      await file.writeAsString(jsonEncode(data));
      setState(() {
        if (_controller.cache.importedListPath == path ||
            (_controller.cache.importedListPath == null && path == 'default')) {
          _controller.cache.isListChanged = false;
        } else {
          _controller.cache.setCacheChanged(path, false);
        }
      });
    }
  }

  Future<void> _exportCurrentList() async {
    final saveLocation = await CustomFilePickerDialog.show(
      context,
      title: 'EXPORT LIST',
      saveMode: true,
      initialFileName: '${_controller.cache.importedListName ?? "export"}.json',
      allowedExtensions: ['json', 'txt'],
    );
    if (saveLocation != null && saveLocation.isNotEmpty) {
      final exportedPath = saveLocation.first;
      final isDefaultList =
          _controller.cache.importedListPath == null ||
          _controller.cache.importedListPath == 'default';

      await _controller.exportListToFile(exportedPath);

      if (isDefaultList) {
        _controller.cache.clear();
      }

      await _controller.importListFromFile(
        exportedPath,
        p.basenameWithoutExtension(exportedPath),
      );

      setState(() {
        _controller.cache.switchList('default');
        _restoreTabState('default');
      });
    }
  }

  Widget _buildMediaListSection() {
    return StandaloneWindowMediaList(
      isTrashView: _isTrashView,
      trashCount: _trash.length,
      activeListPath: _controller.cache.importedListPath ?? 'default',
      customLists: _controller.cache.customLists,
      isListChanged: (path) => _controller.cache.isCacheChanged(path),
      onListTap: (path) {
        final currentPath = _controller.cache.importedListPath ?? 'default';
        _saveCurrentTabState(currentPath);

        setState(() {
          _controller.cache.switchList(path);
          _restoreTabState(path);
          _isTrashView = false;
        });
      },
      onTrashTap: () {
        setState(() {
          _isTrashView = true;
          _currentGroup = null;
          _historyIndex = 0;
          _navigationHistory.clear();
          _navigationHistory.add(null);
          _selectedIndices.clear();
          _lastSelectedIndex = -1;
        });
      },
      onImportTap: () async {
        final path = await CustomFilePickerDialog.show(
          context,
          title: 'IMPORT LIST',
          allowedExtensions: ['json'],
        );
        if (path != null && path.isNotEmpty) {
          final file = File(path.first);
          if (file.existsSync()) {
            final content = await file.readAsString();
            final data = jsonDecode(content) as Map<String, dynamic>;
            final items = (data['items'] as List)
                .map((e) => MediaGroup.fromMap(e as Map<String, dynamic>))
                .toList();

            final name = p.basenameWithoutExtension(path.first);
            final currentPath = _controller.cache.importedListPath ?? 'default';
            _saveCurrentTabState(currentPath);

            setState(() {
              _controller.cache.switchList(path.first);
              _controller.cache.parsedItems = items;
              _controller.cache.importedListPath = path.first;
              _controller.cache.importedListName = name;
              _controller.cache.isListChanged = false;
              _restoreTabState(path.first);
            });
            _controller.recalculateFilteredStatistics();
          }
        }
      },
      onCustomListClose: (path) {
        setState(() {
          _controller.cache.invalidateCache(path);
          _tabStates.remove(path);

          if (_controller.cache.importedListPath == path) {
            _controller.cache.switchList('default');
            _restoreTabState('default');
          }
        });
      },
      onCustomListSave: (path) async {
        // Save the list from the cache state
        final itemsToSave = _controller.cache.getItemsForPath(path);
        if (itemsToSave != null) {
          final file = File(path);
          final data = {'items': itemsToSave.map((e) => e.toMap()).toList()};
          await file.writeAsString(jsonEncode(data));

          setState(() {
            if (_controller.cache.importedListPath == path ||
                (_controller.cache.importedListPath == null &&
                    path == 'default')) {
              _controller.cache.isListChanged = false;
            } else {
              _controller.cache.setCacheChanged(path, false);
            }
          });
        }
      },
    );
  }

  Future<void> _restoreTrash() async {
    // Group trashed items by their list path
    final mapByList = <String, List<_TrashItem>>{};
    for (final item in _trash) {
      mapByList.putIfAbsent(item.listPath, () => []).add(item);
    }

    final currentListPath = _controller.cache.importedListPath ?? 'default';

    for (final entry in mapByList.entries) {
      final listPath = entry.key;
      final itemsToRestore = entry.value;

      if (listPath == currentListPath) {
        // Restore to active memory
        setState(() {
          for (final tItem in itemsToRestore) {
            if (tItem.parentGroup == null) {
              // Root level
              _controller.cache.parsedItems?.add(tItem.item as MediaGroup);
              if (tItem.config != null) {
                _controller
                        .cache
                        .configs[_controller.cache.parsedItems!.length - 1] =
                    tItem.config!;
              }
            } else {
              // Inner item
              tItem.parentGroup!.items.add(tItem.item as MediaInfo);
            }
          }
          _controller.cache.isListChanged = true;
        });
        _controller.recalculateFilteredStatistics();
      } else {
        // Restore to inactive list by reading from JSON and saving
        if (listPath != 'default') {
          try {
            final file = File(listPath);
            if (await file.exists()) {
              final jsonStr = await file.readAsString();
              final jsonList = jsonDecode(jsonStr) as List<dynamic>;
              final parsed = jsonList
                  .map((j) => MediaGroup.fromMap(j as Map<String, dynamic>))
                  .toList();

              for (final tItem in itemsToRestore) {
                if (tItem.parentGroup == null) {
                  parsed.add(tItem.item as MediaGroup);
                } else {
                  // Attempt to find parent group in parsed
                  final matchGroup = parsed.firstWhere(
                    (g) => g.originalUrl == tItem.parentGroup!.originalUrl,
                    orElse: () => parsed.first,
                  );
                  matchGroup.items.add(tItem.item as MediaInfo);
                }
              }
              // Save back
              await file.writeAsString(
                jsonEncode(parsed.map((e) => e.toMap()).toList()),
                flush: true,
              );
            }
          } catch (e) {
            debugPrint('Failed to restore trash to disk: $e');
          }
        }
      }
    }

    setState(_trash.clear);
  }

  Widget _buildActiveDownloadsSection() {
    return Consumer(
      builder: (context, ref, _) {
        return StandaloneWindowActiveDownloads(
          tasks: ref.watch(downloadTaskProvider),
          onCancelAll: () {
            final tasks = ref.read(downloadTaskProvider);
            for (final t in tasks) {
              ref.read(downloadTaskProvider.notifier).cancelDownload(t.id);
            }
          },
        );
      },
    );
  }

  void _showTagHeaderContextMenu(TapDownDetails details, String url) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => entry.remove(),
              behavior: HitTestBehavior.opaque,
            ),
          ),
          Positioned(
            left: details.globalPosition.dx,
            top: details.globalPosition.dy,
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        _clearTag(url);
                        entry.remove();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.delete, size: 14, color: Colors.white70),
                            SizedBox(width: 8),
                            Text(
                              'Delete',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    InkWell(
                      onTap: () {
                        _clearAllTags();
                        entry.remove();
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_sweep,
                              size: 14,
                              color: Colors.redAccent,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Clear All',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(entry);
  }

  void _clearTag(String url) {
    setState(() {
      final parsedItems = _controller.cache.parsedItems;
      if (parsedItems == null) return;

      if (_currentGroup == null) {
        final idx = parsedItems.indexWhere((g) => g.originalUrl == url);
        if (idx != -1) {
          parsedItems[idx] = parsedItems[idx].copyWith(clearTag: true);
        }
      } else {
        final idx = _currentGroup!.items.indexWhere((i) => i.id == url);
        if (idx != -1) {
          final oldItem = _currentGroup!.items[idx];
          _currentGroup!.items[idx] = oldItem.copyWith(clearTag: true);

          final rootIndex = parsedItems.indexWhere(
            (g) => g.originalUrl == _currentGroup!.originalUrl,
          );
          if (rootIndex != -1) {
            final oldRoot = parsedItems[rootIndex];
            final items = List<MediaInfo>.from(oldRoot.items);
            final itemIndex = items.indexWhere((i) => i.id == url);
            if (itemIndex != -1) {
              items[itemIndex] = _currentGroup!.items[idx];
              parsedItems[rootIndex] = oldRoot.copyWith(items: items);
            }
          }
        }
      }
      _controller.cache.isListChanged = true;
      final currentPath = _controller.cache.importedListPath;
      if (currentPath != null && currentPath != 'default') {
        _saveCustomList(currentPath);
      }
      _handleScroll();
    });
  }

  void _clearAllTags() {
    setState(() {
      final parsedItems = _controller.cache.parsedItems;
      if (parsedItems == null) return;

      if (_currentGroup == null) {
        for (var i = 0; i < parsedItems.length; i++) {
          parsedItems[i] = parsedItems[i].copyWith(clearTag: true);
        }
      } else {
        final rootIndex = parsedItems.indexWhere(
          (g) => g.originalUrl == _currentGroup!.originalUrl,
        );
        if (rootIndex != -1) {
          final oldRoot = parsedItems[rootIndex];
          final items = List<MediaInfo>.from(oldRoot.items);
          for (var i = 0; i < items.length; i++) {
            items[i] = items[i].copyWith(clearTag: true);
          }
          _currentGroup = _currentGroup!.copyWith(items: items);
          parsedItems[rootIndex] = oldRoot.copyWith(items: items);
        }
      }
      _controller.cache.isListChanged = true;
      final currentPath = _controller.cache.importedListPath;
      if (currentPath != null && currentPath != 'default') {
        _saveCustomList(currentPath);
      }
      _activeTagNotifier.value = null;
    });
  }

  Widget _buildActionBar() {
    var hasImages = false;
    var hasVideos = false;
    var hasPlaylists = false;
    var hasProfiles = false;
    var hasGroups = false;

    if (_controller.cache.parsedItems != null) {
      for (final group in _controller.cache.parsedItems!) {
        final first = group.first;
        if (first.isProfile) {
          hasProfiles = true;
        } else if (first.isPlaylist) {
          hasPlaylists = true;
        } else if (group.items.length > 1) {
          hasGroups = true;
          if (group.items.any((i) => !i.isVideo)) hasImages = true;
          if (group.items.any((i) => i.isVideo)) hasVideos = true;
        } else {
          if (first.isVideo) {
            hasVideos = true;
          } else {
            hasImages = true;
          }
        }
      }
    }

    var rootIndex = -1;
    if (_currentGroup != null &&
        (_controller.cache.parsedItems?.isNotEmpty ?? false)) {
      rootIndex = _controller.cache.parsedItems!.indexWhere(
        (g) => g.originalUrl == _currentGroup!.originalUrl,
      );
    }

    return StandaloneWindowActionBar(
      isTrashView: _isTrashView,
      trashNotEmpty: _trash.isNotEmpty,
      hasItems: _controller.cache.parsedItems?.isNotEmpty ?? false,
      currentGroup: _currentGroup,
      importedListName: _controller.cache.importedListName,
      rootIndex: rootIndex != -1 ? rootIndex : null,
      config: rootIndex != -1 ? _controller.cache.configs[rootIndex] : null,
      onRestoreAll: _restoreTrash,
      onEmptyTrash: () => setState(_trash.clear),
      onBackToRoot: () => setState(() => _currentGroup = null),
      onFormatChanged: (val) {
        if (rootIndex != -1) {
          setState(() {
            _controller.cache.configs[rootIndex]!.format = val;
            _controller.cache.configs[rootIndex]!.itemFormats.clear();
          });
          _controller.recalculateFilteredStatistics();
        }
      },
      onFilterChanged: (val) {
        if (rootIndex != -1) {
          setState(() {
            if (_controller.cache.configs[rootIndex] == null) {
              _controller.cache.configs[rootIndex] = DownloadConfig();
            }
            _controller.cache.configs[rootIndex]!.groupFilter = val;
          });
          _controller.recalculateFilteredStatistics();
        }
      },
      onClear: () {
        _controller.cache.clear();
        setState(() {
          _currentGroup = null;
        });
      },
      getHeight: _getHeight,
      matchTargetFormat: matchTargetFormat,
      searchController: _searchController,
      searchFocusNode: _searchFocusNode,
      isSearchVisible: _isSearchVisible,
      listFilter: _listFilter,
      hasImages: hasImages,
      hasVideos: hasVideos,
      hasPlaylists: hasPlaylists,
      hasProfiles: hasProfiles,
      hasGroups: hasGroups,
      onListFilterChanged: (val) {
        setState(() {
          _listFilter = val;
        });
      },
      activeTagNotifier: _activeTagNotifier,
      onTagTap: _scrollToTag,
      onTagSecondaryTapDown: _showTagHeaderContextMenu,
    );
  }

  void _handleTagItem(String url, String tag) {
    setState(() {
      final parsedItems = _controller.cache.parsedItems;
      if (parsedItems == null) return;

      if (_currentGroup == null) {
        final idx = parsedItems.indexWhere((g) => g.originalUrl == url);
        if (idx != -1) {
          final oldGroup = parsedItems[idx];
          parsedItems[idx] = oldGroup.copyWith(
            tag: tag,
            tagSortOrder: _listFilter,
          );
        }
      } else {
        final idx = _currentGroup!.items.indexWhere((i) => i.id == url);
        if (idx != -1) {
          final oldItem = _currentGroup!.items[idx];
          _currentGroup!.items[idx] = oldItem.copyWith(
            tag: tag,
            tagSortOrder: _listFilter,
          );

          final rootIndex = parsedItems.indexWhere(
            (g) => g.originalUrl == _currentGroup!.originalUrl,
          );
          if (rootIndex != -1) {
            final oldRoot = parsedItems[rootIndex];
            final items = List<MediaInfo>.from(oldRoot.items);
            final itemIndex = items.indexWhere((i) => i.id == url);
            if (itemIndex != -1) {
              items[itemIndex] = _currentGroup!.items[idx];
              parsedItems[rootIndex] = oldRoot.copyWith(items: items);
            }
          }
        }
      }
      _controller.cache.isListChanged = true;
      final currentPath = _controller.cache.importedListPath;
      if (currentPath != null && currentPath != 'default') {
        _saveCustomList(currentPath);
      }
      _handleScroll(); // Trigger update for active tag in header
    });
  }

  void _scrollToTag(String url, String sortOrder) {
    OverlayEntry? scrollLoaderEntry;
    var cancelled = false;

    void cancelScroll() {
      cancelled = true;
      scrollLoaderEntry?.remove();
      scrollLoaderEntry = null;
      if (_mediaGridScrollController.hasClients) {
        _mediaGridScrollController.jumpTo(_mediaGridScrollController.offset);
      }
    }

    scrollLoaderEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: 250,
        top: 0,
        right: 0,
        bottom: 0,
        child: ColoredBox(
          color: Colors.black54,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BubbleLoader(color: Colors.amber, size: 60),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: cancelScroll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(scrollLoaderEntry!);

    void scrollToKey() {
      if (cancelled) return;
      final key = _tagKeys[url];
      if (key != null && key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        ).then((_) {
          if (!cancelled) {
            scrollLoaderEntry?.remove();
            scrollLoaderEntry = null;
          }
        });
      } else {
        if (!cancelled) {
          scrollLoaderEntry?.remove();
          scrollLoaderEntry = null;
        }
      }
    }

    void executeScroll() {
      if (cancelled) return;
      var itemIndex = -1;
      if (_currentGroup == null) {
        itemIndex = _currentVisibleGroups.indexWhere(
          (g) => g.originalUrl == url,
        );
      } else {
        itemIndex = _currentVisibleGroups.indexWhere(
          (g) => g.items.isNotEmpty && g.items.first.id == url,
        );
      }

      if (itemIndex != -1 && _mediaGridScrollController.hasClients) {
        final width =
            MediaQuery.of(context).size.width - 380; // approximate grid width
        final crossAxisCount = (width / 236).floor().clamp(1, 10);
        final row = itemIndex ~/ crossAxisCount;
        final estimatedOffset = row * 300.0;

        _mediaGridScrollController
            .animateTo(
              estimatedOffset,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            )
            .then((_) {
              if (!cancelled) {
                Future.delayed(const Duration(milliseconds: 100), scrollToKey);
              }
            });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) => scrollToKey());
      }
    }

    // 1. Revert Sort Order
    if (_listFilter != sortOrder) {
      setState(() {
        _listFilter = sortOrder;
      });
      // Show Toast
      final overlay = Overlay.of(context);
      late OverlayEntry toastEntry;
      toastEntry = OverlayEntry(
        builder: (context) => Positioned(
          top: 130, // Just below the action bar
          right: 20,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                border: Border.all(color: Colors.amber, width: 1.5),
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'Sort order updated to match tag',
                style: TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      );
      overlay.insert(toastEntry);
      Future.delayed(const Duration(seconds: 2), () => toastEntry.remove());

      WidgetsBinding.instance.addPostFrameCallback((_) {
        executeScroll();
      });
    } else {
      executeScroll();
    }
  }

  void _toggleSelection(int index, {bool isCtrl = false, bool isShift = false}) {
    if (index == -1) {
      setState(() {
        _selectedIndices.clear();
        _lastSelectedIndex = -1;
      });
      return;
    }
    setState(() {
      if (isShift && _lastSelectedIndex != -1) {
        final start = math.min(_lastSelectedIndex, index);
        final end = math.max(_lastSelectedIndex, index);
        _selectedIndices.clear();
        for (var i = start; i <= end; i++) {
          _selectedIndices.add(i);
        }
      } else if (isCtrl) {
        if (_selectedIndices.contains(index)) {
          _selectedIndices.remove(index);
        } else {
          _selectedIndices.add(index);
        }
        _lastSelectedIndex = index;
      } else {
        _selectedIndices.clear();
        _selectedIndices.add(index);
        _lastSelectedIndex = index;
      }
    });
  }

  Widget _buildMediaGrid() {
    var mappedGroups = <MediaGroup>[];
    final searchTerm = _searchController.text.trim().toLowerCase();

    if (_isTrashView) {
      final currentListPath = _controller.cache.importedListPath ?? 'default';
      final currentTrash = _trash
          .where((t) => t.listPath == currentListPath)
          .toList();
      mappedGroups = currentTrash.map((t) {
        if (t.item is MediaGroup) {
          return t.item as MediaGroup;
        } else {
          var info = t.item as MediaInfo;
          if (info.isProfile || info.isPlaylist) {
            info = info.copyWith(isProfile: false);
          }
          return MediaGroup(items: [info], originalUrl: info.originalUrl);
        }
      }).toList();
      if (searchTerm.isNotEmpty) {
        mappedGroups = mappedGroups.where((group) {
          final titleMatch =
              group.items.isNotEmpty &&
              group.items.first.title.toLowerCase().contains(searchTerm);
          final urlMatch = group.originalUrl.toLowerCase().contains(searchTerm);
          return titleMatch || urlMatch;
        }).toList();
      }
    } else if (_currentGroup == null) {
      var entries = _controller.cache.parsedItems?.toList() ?? [];

      if (_listFilter == 'image') {
        entries = entries
            .where(
              (e) =>
                  !e.first.isVideo && !e.first.isPlaylist && !e.first.isProfile,
            )
            .toList();
      } else if (_listFilter == 'video') {
        entries = entries
            .where(
              (e) =>
                  e.first.isVideo && !e.first.isPlaylist && !e.first.isProfile,
            )
            .toList();
      } else if (_listFilter == 'playlist') {
        entries = entries
            .where((e) => e.first.isPlaylist && !e.first.isProfile)
            .toList();
      } else if (_listFilter == 'profile') {
        entries = entries.where((e) => e.first.isProfile).toList();
      }

      if (_listFilter == 'added_asc') {
        entries = entries.reversed.toList();
      } else if (_listFilter == 'size_asc' || _listFilter == 'size_desc') {
        entries.sort((a, b) {
          final aSize = a.totalFilesize;
          final bSize = b.totalFilesize;
          return _listFilter == 'size_asc'
              ? aSize.compareTo(bSize)
              : bSize.compareTo(aSize);
        });
      }
      mappedGroups = entries;

      if (searchTerm.isNotEmpty) {
        mappedGroups = mappedGroups.where((group) {
          final titleMatch =
              group.items.isNotEmpty &&
              group.items.first.title.toLowerCase().contains(searchTerm);
          final urlMatch = group.originalUrl.toLowerCase().contains(searchTerm);
          return titleMatch || urlMatch;
        }).toList();
      }
    } else {
      final rootIndex =
          _controller.cache.parsedItems?.indexWhere(
            (g) => g.originalUrl == _currentGroup!.originalUrl,
          ) ??
          -1;
      if (rootIndex != -1) {
        final config = _controller.cache.configs[rootIndex];
        final filteredItems = _currentGroup!.items.where((item) {
          if (item.isError) return false;
          if (_currentGroup!.first.isProfile &&
              item == _currentGroup!.items.first) {
            return false;
          }
          if (config?.groupFilter == GroupDownloadType.images && item.isVideo) {
            return false;
          }
          if (config?.groupFilter == GroupDownloadType.videos &&
              !item.isVideo) {
            return false;
          }
          if (searchTerm.isNotEmpty &&
              !item.title.toLowerCase().contains(searchTerm)) {
            return false;
          }
          return true;
        }).toList();

        mappedGroups = filteredItems.map((info) {
          return MediaGroup(items: [info], originalUrl: info.originalUrl);
        }).toList();
      }
    }

    _currentVisibleGroups = mappedGroups;

    final listPath = _controller.cache.importedListPath ?? 'default';

    int? currentGroupRootIndex;
    if (_currentGroup != null && _controller.cache.parsedItems != null) {
      currentGroupRootIndex = _controller.cache.parsedItems!.indexWhere(
        (g) => g.originalUrl == _currentGroup!.originalUrl,
      );
      if (currentGroupRootIndex == -1) currentGroupRootIndex = null;
    }

    return StandaloneWindowMediaGrid(
      listPath: listPath,
      isTrashView: _isTrashView,
      groups: mappedGroups,
      currentGroup: _currentGroup,
      onShowProperties: _showPropertiesDialog,
      currentGroupRootIndex: currentGroupRootIndex,
      selectedIndices: _selectedIndices,
      downloadingImageIndices: _downloadingImageIndices,
      getConfig: (group) {
        if (_controller.cache.parsedItems == null) return null;
        final idx = _controller.cache.parsedItems!.indexWhere(
          (g) => g.originalUrl == group.originalUrl,
        );
        return idx != -1 ? _controller.cache.configs[idx] : null;
      },
      getFormatBytes: getFormatBytes,
      scrollController: _mediaGridScrollController,
      tagKeys: _tagKeys,
      onTagItem: _handleTagItem,
      isHydratingItem: (url) =>
          _controller.activeHydrationPids.containsKey(url),
      onTapItem: _toggleSelection,
      onDoubleTapItem: (index, group) {
        if (_currentGroup == null && group.items.length > 1) {
          setState(() {
            if (_historyIndex < _navigationHistory.length - 1) {
              _navigationHistory.removeRange(
                _historyIndex + 1,
                _navigationHistory.length,
              );
            }
            _navigationHistory.add(group);
            _historyIndex++;
            _currentGroup = group;
          });
        } else {
          final firstItem = group.items.isNotEmpty ? group.items.first : null;
          if (firstItem == null) return;

          int? rootIndex;
          if (_controller.cache.parsedItems != null) {
            final targetGroup = _currentGroup ?? group;
            rootIndex = _controller.cache.parsedItems!.indexWhere(
              (g) => g.originalUrl == targetGroup.originalUrl,
            );
            if (rootIndex == -1) rootIndex = null;
          }
          final config = rootIndex != null
              ? _controller.cache.configs[rootIndex]
              : null;
          final isAudioOnly =
              config != null &&
              (config.itemFormats[firstItem.id]?.isAudioOnly ?? false);
          final selectedFormat =
              config?.itemFormats[firstItem.id] ?? config?.format;

          if (isAudioOnly) {
            _openAudioPlayer(firstItem, index);
          } else if (firstItem.isVideo) {
            _openVideoPreview(firstItem, index, selectedFormat: selectedFormat);
          } else {
            _openImageInViewer(firstItem, index);
          }
        }
      },
      onRestoreTrashItem: (index) {
        final t = _trash[index];
        setState(() {
          if (t.parentGroup == null) {
            _controller.cache.parsedItems?.add(t.item as MediaGroup);
            if (t.config != null) {
              _controller.cache.configs[_controller.cache.parsedItems!.length -
                      1] =
                  t.config!;
            }
          } else {
            t.parentGroup!.items.add(t.item as MediaInfo);
          }
          _trash.removeAt(index);
          _controller.cache.isListChanged = true;
        });
        _controller.recalculateFilteredStatistics();
      },
      onFormatChanged: (group, format) {
        if (_controller.cache.parsedItems == null) return;
        final rootIdx = _controller.cache.parsedItems!.indexWhere(
          (g) => g.originalUrl == group.originalUrl,
        );
        if (rootIdx != -1) {
          setState(() {
            _controller.cache.configs[rootIdx]?.format = format;
          });
          _controller.recalculateFilteredStatistics();
        }
      },
      onFilterChanged: (group, filter) {
        if (_controller.cache.parsedItems == null) return;
        final rootIdx = _controller.cache.parsedItems!.indexWhere(
          (g) => g.originalUrl == group.originalUrl,
        );
        if (rootIdx != -1) {
          setState(() {
            _controller.cache.configs[rootIdx]?.groupFilter = filter;
          });
          _controller.recalculateFilteredStatistics();
        }
      },
      onStartDownload: (index) {
        if (_currentGroup == null) {
          final group = _controller.cache.parsedItems![index];
          _startDownload(group, index);
          setState(() {
            _controller.cache.parsedItems?.removeAt(index);
          });
        } else {
          final item = _currentGroup!.items[index];
          final group = MediaGroup(
            originalUrl: item.originalUrl,
            items: [item],
          );
          final rootIndex = _controller.cache.parsedItems!.indexOf(
            _currentGroup!,
          );
          _startDownload(group, rootIndex);
          setState(() {
            _currentGroup!.items.removeAt(index);
          });
        }
        _controller.cache.isListChanged = true;
        _controller.cache.notify();
        _controller.recalculateFilteredStatistics();
        ref.read(conflictProvider.notifier).clearGlobalResolution();
      },
      mainFocusNode: _mainFocusNode,
      matchTargetFormat: matchTargetFormat,
      getHeight: _getHeight,
      trash: _trash,
    );
  }

  Widget _buildLocationBar() {
    var videos = 0;
    var images = 0;
    var size = 0;

    if (_isTrashView) {
      for (final t in _trash) {
        if (t.item is MediaGroup) {
          final g = t.item as MediaGroup;
          videos += g.items.where((i) => i.isVideo).length;
          images += g.items.where((i) => !i.isVideo).length;
        } else {
          final i = t.item as MediaInfo;
          if (i.isVideo) {
            videos++;
          } else {
            images++;
          }
        }
      }
    } else {
      videos = _controller.totalListVideos;
      images = _controller.totalListImages;
      size = _controller.totalListSize;
    }

    return StandaloneWindowLocationBar(
      isTrashView: _isTrashView,
      isCustom: _controller.cache.importedListName != null,
      isChanged: _controller.cache.isListChanged,
      currentPath: _currentPath,
      totalVideos: videos,
      totalImages: images,
      totalSize: size,
      onChangeLocation: () async {
        final result = await CustomFilePickerDialog.show(
          context,
          title: 'SELECT DOWNLOAD LOCATION',
          pickDirectory: true,
          initialDirectory: _currentPath,
        );
        if (result != null && result.isNotEmpty) {
          setState(() {
            _currentPath = result.first;
          });
        }
      },
      onExport: () async {
        if (_controller.cache.importedListName != null &&
            _controller.cache.isListChanged &&
            _controller.cache.importedListPath != null) {
          await _controller.exportListToFile(
            _controller.cache.importedListPath!,
          );
        } else {
          final saveLocation = await CustomFilePickerDialog.show(
            context,
            title: 'EXPORT LIST',
            saveMode: true,
            initialFileName:
                '${_controller.cache.importedListName ?? "export"}.json',
            allowedExtensions: ['json', 'txt'],
          );
          if (saveLocation != null && saveLocation.isNotEmpty) {
            final exportedPath = saveLocation.first;
            final isDefaultList = _controller.cache.importedListName == null;

            await _controller.exportListToFile(exportedPath);

            if (isDefaultList) {
              _controller.cache.clear();
            }

            await _controller.importListFromFile(
              exportedPath,
              p.basename(exportedPath),
            );
          }
        }
      },
      onDownloadAll: _downloadAll,
      selectionCount: _selectedIndices.length,
    );
  }

  Future<void> _openImageInViewer(MediaInfo item, int index) async {
    final url = item.directUrl ?? item.thumbnail ?? item.originalUrl;
    if (url.isEmpty) return;

    setState(() {
      _downloadingImageIndices.add(index);
    });

    // Yield control to the Flutter event loop to render the loader UI immediately.
    // Without this, the synchronous method channel call to open the window blocks
    // the platform thread, dropping frames and causing a perceived visual delay.
    await Future<void>.delayed(const Duration(milliseconds: 16));

    try {
      final fileItem = FileItem(
        name: item.title.isNotEmpty ? item.title : p.basename(url),
        path: url,
        sizeBytes: item.filesize,
        modified: DateTime.now(),
        type: FileItemType.image,
      );

      final windowParams = WindowParams(
        viewerType: ViewerType.image,
        file: fileItem,
        initParams: const {
          'width': 600,
          'height': 800,
          'is_minimal': true,
          'is_network_stream': true,
        },
      );

      PersistentViewerManager.openMedia(windowParams).whenComplete(() {
        if (mounted) {
          setState(() {
            _downloadingImageIndices.remove(index);
          });
        }
      });
    } catch (e, st) {
      print('EXCEPTION IN START DOWNLOAD: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load image: $e')));
      }
      if (mounted) {
        setState(() {
          _downloadingImageIndices.remove(index);
        });
      }
    }
  }

  /// Opens the video stream preview in the existing video player window.
  ///
  /// Resolves the best streamable URL from [item], passes it to
  /// [PersistentViewerManager] as a [ViewerType.video], and handles errors
  /// with a styled dialog matching the downloader error tile UX.
  void _openAudioPlayer(MediaInfo item, int index) {
    final file = FileItem(
      path: item.originalUrl,
      name: item.title,
      type: FileItemType.audio,
      modified: DateTime.now(),
      sizeBytes: 0,
    );
    PersistentViewerManager.openMedia(
      WindowParams(
        viewerType: ViewerType.audio,
        file: file,
        initParams: const {'is_audio_play_only': true},
      ),
    );
  }

  Future<void> _openVideoPreview(
    MediaInfo item,
    int index, {
    MediaFormat? selectedFormat,
  }) async {
    final streamUrl = resolveStreamUrl(item, selectedFormat: selectedFormat);
    if (streamUrl == null) {
      if (mounted) {
        _showVideoPreviewErrorDialog(
          context: context,
          title: item.title.isNotEmpty ? item.title : item.originalUrl,
          errorMessage: 'No streamable URL found for this item.',
          details:
              'Tried directUrl, format urls, webpageUrl, and originalUrl — all were empty.',
        );
      }
      return;
    }

    setState(() {
      _downloadingImageIndices.add(index);
    });

    // Yield control to the Flutter event loop to render the loader UI immediately.
    // Without this, the synchronous method channel call to open the window blocks
    // the platform thread, dropping frames and causing a perceived visual delay.
    await Future<void>.delayed(const Duration(milliseconds: 16));

    try {
      String? audioUrl;
      // If the user explicitly selected a format from the dropdown, honor it.
      // We keep the selectedFormat's formatId so that the video player can set
      // ytdl-format to the right stream. We do NOT override it with a "best URL
      // format" — that would silently ignore the user's resolution choice.
      final effectiveFormat = resolveEffectiveFormat(
        item,
        selectedFormat: selectedFormat,
      );

      if (effectiveFormat != null && effectiveFormat.audioCodec == 'none') {
        final audioFormats = item.formats
            .where((f) => f.videoCodec == 'none')
            .toList();
        if (audioFormats.isNotEmpty) {
          audioFormats.sort(
            (a, b) => (b.filesize ?? 0).compareTo(a.filesize ?? 0),
          );
          final bestAudio = audioFormats.first;
          audioUrl = (bestAudio.url != null && bestAudio.url!.isNotEmpty)
              ? bestAudio.url
              : bestAudio.formatString;
        }
      }

      final playbackUrl = resolvePlaybackUrl(item);

      final fileItemForPlayer = FileItem(
        name: item.title.isNotEmpty ? item.title : p.basename(playbackUrl),
        path: playbackUrl,
        sizeBytes: effectiveFormat?.filesize ?? item.filesize,
        modified: DateTime.now(),
        type: FileItemType.video,
        thumbnailPath: item.thumbnail,
      );

      final windowParams = WindowParams(
        viewerType: ViewerType.video,
        file: fileItemForPlayer,
        initParams: {
          'width': 1280,
          'height': 720,
          'is_network_stream': true,
          'formats': item.formats.map((f) => f.toJson()).toList(),
          'selectedFormatId': effectiveFormat?.formatId,
          if (audioUrl != null) 'audioUrl': audioUrl,
        },
      );

      PersistentViewerManager.openMedia(windowParams).whenComplete(() {
        if (mounted) {
          setState(() {
            _downloadingImageIndices.remove(index);
          });
        }
      });
    } catch (e, st) {
      debugPrint('Stream preview error: $e\n$st');
      if (mounted) {
        _showVideoPreviewErrorDialog(
          context: context,
          title: item.title.isNotEmpty ? item.title : item.originalUrl,
          errorMessage: e.toString(),
          details: st.toString(),
        );
      }
      if (mounted) {
        setState(() {
          _downloadingImageIndices.remove(index);
        });
      }
    }
  }

  /// Shows the styled video preview error dialog.
  ///
  /// Matches the downloader error tile UX: dark red background,
  /// error icon, message body, and an expandable logs section.
  void _showVideoPreviewErrorDialog({
    required BuildContext context,
    required String title,
    required String errorMessage,
    String? details,
  }) {
    var logsExpanded = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF2A1515),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
          ),
          title: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Stream Preview Failed',
                  style: GoogleFonts.manrope(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.manrope(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                errorMessage,
                style: GoogleFonts.manrope(
                  color: Colors.redAccent.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (details != null && details.isNotEmpty) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () =>
                      setDialogState(() => logsExpanded = !logsExpanded),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: logsExpanded
                              ? Colors.redAccent
                              : AppColors.violet,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          logsExpanded ? 'Hide logs' : 'View logs',
                          style: GoogleFonts.manrope(
                            color: logsExpanded
                                ? Colors.redAccent
                                : AppColors.violet,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (logsExpanded) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.2),
                      ),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(10),
                      child: SelectableText(
                        details,
                        style: GoogleFonts.jetBrainsMono(
                          color: Colors.white54,
                          fontSize: 10,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.manrope(
                  color: Colors.white54,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  @visibleForTesting
  int getHeightForTesting(String res) => _getHeight(res);

  @visibleForTesting
  String get currentPathForTesting => _currentPath;

  @visibleForTesting
  TextEditingController get searchControllerForTesting => _searchController;

  @visibleForTesting
  void onSearchChangedForTesting() => _onSearchChanged();

  @visibleForTesting
  Timer? get searchDebounceForTesting => _searchDebounce;

  @visibleForTesting
  bool get isSearchVisibleForTesting => _isSearchVisible;

  @visibleForTesting
  set isSearchVisibleForTesting(bool v) => _isSearchVisible = v;

  @visibleForTesting
  Set<int> get selectedIndicesForTesting => _selectedIndices;

  @visibleForTesting
  bool get isTrashViewForTesting => _isTrashView;

  @visibleForTesting
  void saveCurrentTabStateForTesting(String path) => _saveCurrentTabState(path);

  @visibleForTesting
  void restoreTabStateForTesting(String path) => _restoreTabState(path);

  @visibleForTesting
  void handleDeleteForTesting(bool isShiftPressed) =>
      _handleDelete(isShiftPressed);

  @visibleForTesting
  void onDoubleTapItemForTesting(int index, MediaGroup group) {
    if (_currentGroup == null && group.items.length > 1) {
      setState(() {
        if (_historyIndex < _navigationHistory.length - 1) {
          _navigationHistory.removeRange(
            _historyIndex + 1,
            _navigationHistory.length,
          );
        }
        _navigationHistory.add(group);
        _historyIndex++;
        _currentGroup = group;
      });
    } else {
      final firstItem = group.items.isNotEmpty ? group.items.first : null;
      if (firstItem == null) return;
      if (firstItem.isVideo) {
        _openVideoPreview(firstItem, index);
      } else {
        _openImageInViewer(firstItem, index);
      }
    }
  }

  @visibleForTesting
  void onFormatChangedForTesting(MediaFormat val) {
    var rootIndex = -1;
    if (_currentGroup != null &&
        (_controller.cache.parsedItems?.isNotEmpty ?? false)) {
      rootIndex = _controller.cache.parsedItems!.indexWhere(
        (g) => g.originalUrl == _currentGroup!.originalUrl,
      );
    }
    if (rootIndex != -1) {
      setState(() {
        _controller.cache.configs[rootIndex]!.format = val;
        _controller.cache.configs[rootIndex]!.itemFormats.clear();
      });
      _controller.recalculateFilteredStatistics();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top-level helpers — kept outside the widget class so they are easily testable
// without a Flutter widget pump.
// ─────────────────────────────────────────────────────────────────────────────

/// Resolves the best direct streamable URL from a [MediaInfo] object.
///
/// Priority order:
///   1. [MediaInfo.directUrl]        — yt-dlp resolved direct CDN stream URL
///   2. Best format url              — highest-resolution [MediaFormat] with non-null url
///   3. [MediaInfo.webpageUrl]       — fallback (libmpv may re-fetch via demuxer)
///   4. [MediaInfo.originalUrl]      — last resort
///   5. null                         — no usable URL found
@visibleForTesting
MediaFormat? resolveEffectiveFormat(
  MediaInfo item, {
  MediaFormat? selectedFormat,
}) {
  if (selectedFormat != null) return selectedFormat;
  if (item.formats.isEmpty) return null;

  int getH(String res) {
    final parts = res.toLowerCase().split('x');
    if (parts.length == 2) {
      return int.tryParse(parts[1].replaceAll(RegExp('[^0-9]'), '')) ?? 0;
    }
    return int.tryParse(res.replaceAll(RegExp('[^0-9]'), '')) ?? 0;
  }

  final validFormats = item.formats.toList();

  validFormats.sort((a, b) {
    return getH(b.resolution).compareTo(getH(a.resolution));
  });

  return validFormats.firstWhere((f) {
    final h = getH(f.resolution);
    return h > 0 && h <= 1080;
  }, orElse: () => validFormats.first);
}

@visibleForTesting
String resolvePlaybackUrl(MediaInfo item) {
  return (item.webpageUrl != null && item.webpageUrl!.isNotEmpty)
      ? item.webpageUrl!
      : item.originalUrl;
}

@visibleForTesting
String? resolveStreamUrl(MediaInfo item, {MediaFormat? selectedFormat}) {
  // Let media_kit's ytdl hook handle DASH audio+video muxing natively
  // for yt-dlp extracted links.
  if (item.engineId == 'yt-dlp' || item.extractor != null) {
    if (item.webpageUrl != null && item.webpageUrl!.isNotEmpty) {
      return item.webpageUrl;
    }
    if (item.originalUrl.isNotEmpty) {
      return item.originalUrl;
    }
  }

  // 0. Use selected format if provided and has a URL
  if (selectedFormat != null) {
    if (selectedFormat.url != null && selectedFormat.url!.isNotEmpty) {
      return selectedFormat.url;
    }
    if (selectedFormat.formatString.startsWith('http://') ||
        selectedFormat.formatString.startsWith('https://')) {
      return selectedFormat.formatString;
    }
  }

  // 1. directUrl is best
  if (item.directUrl != null && item.directUrl!.isNotEmpty) {
    return item.directUrl;
  }

  // 2. Best format URL — pick the highest-resolution format that has a url.
  // Also checks formatString as a fallback because gallery-dl stores the CDN
  // URL there (formatId='original', formatString=<direct cdn url>, url=null).
  if (item.formats.isNotEmpty) {
    final formatsWithUrl = item.formats.where((f) {
      if (f.url != null && f.url!.isNotEmpty) return true;
      // gallery-dl pattern: CDN URL stored in formatString
      return f.formatString.startsWith('http://') ||
          f.formatString.startsWith('https://');
    }).toList();
    if (formatsWithUrl.isNotEmpty) {
      formatsWithUrl.sort((a, b) {
        final hA = _parseResolutionHeight(a.resolution);
        final hB = _parseResolutionHeight(b.resolution);
        return hB.compareTo(hA);
      });
      final best = formatsWithUrl.first;
      // Prefer the explicit url field; fall back to formatString
      return (best.url != null && best.url!.isNotEmpty)
          ? best.url
          : best.formatString;
    }
  }

  // 3. webpageUrl fallback
  if (item.webpageUrl != null && item.webpageUrl!.isNotEmpty) {
    return item.webpageUrl;
  }

  // 4. originalUrl last resort
  if (item.originalUrl.isNotEmpty) {
    return item.originalUrl;
  }

  return null;
}

/// Parses a resolution string (e.g. "1920x1080", "1080p", "4k") to its height
/// in pixels for comparison purposes. Returns 0 for audio-only or unparseable.
int _parseResolutionHeight(String resolution) {
  if (resolution.isEmpty || resolution == 'audio only') return 0;
  final lower = resolution.toLowerCase();
  if (lower.contains('2160') || lower.contains('4k')) return 2160;
  if (lower.contains('1440') || lower.contains('2k')) return 1440;
  if (lower.contains('1080')) return 1080;
  if (lower.contains('720')) return 720;
  if (lower.contains('480')) return 480;
  if (lower.contains('360')) return 360;
  if (lower.contains('240')) return 240;
  final parts = lower.split('x');
  if (parts.length == 2) return int.tryParse(parts[1]) ?? 0;
  return int.tryParse(lower.replaceAll(RegExp('[^0-9]'), '')) ?? 0;
}

class _TrashItem {
  _TrashItem({
    required this.item,
    required this.listPath,
    this.parentGroup,
    this.config,
  });
  final dynamic item;
  final String listPath;
  final MediaGroup? parentGroup;
  final DownloadConfig? config;
}
