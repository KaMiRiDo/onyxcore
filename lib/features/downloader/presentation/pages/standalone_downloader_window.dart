import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/domain/entities/downloader_filter_settings.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloader_readiness_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_shared_controller.dart';
import 'package:onyxcore/features/downloader/presentation/services/remote_video_thumbnail_resolver.dart';
import 'package:onyxcore/features/downloader/presentation/services/thumbnail_aspect_resolver.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_missing_binaries_view.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/properties_dialog.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/downloads_panel_helpers.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_action_bar.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_active_downloads.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_header.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_location_bar.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_media_grid.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_media_list.dart';
import 'package:onyxcore/features/downloader/services/dml_crypto_service.dart';
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
  Map<String, DownloaderViewPreferences> viewPreferences = {};
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
  ValueNotifier<int>? _urlFocusTrigger;
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
  bool _isProcessingList = false; // true while a .dml list is being decrypted & loaded
  bool _obscureUnlockPassword = true;
  final TextEditingController _unlockPasswordController = TextEditingController();
  String _listFilter = 'added_desc';
  final Map<String, DownloaderViewPreferences> _viewPreferences = {};

  final Map<String, _StandaloneTabState> _tabStates = {};

  String _getCurrentViewKey() {
    if (_isTrashView) return 'trash';
    if (_currentGroup != null) return 'group_${_currentGroup!.originalUrl}';
    return 'root';
  }

  DownloaderViewPreferences _getPreferencesForCurrentView() {
    final key = _getCurrentViewKey();
    return _viewPreferences[key] ?? const DownloaderViewPreferences();
  }

  void _updateViewSort(String sortOrder) {
    final key = _getCurrentViewKey();
    final current = _getPreferencesForCurrentView();
    setState(() {
      _viewPreferences[key] = current.copyWith(sortOrder: sortOrder);
      _listFilter = sortOrder;
      _selectedIndices.clear();
    });
  }

  void _updateViewFilter(DownloaderFilterSettings filterSettings) {
    final key = _getCurrentViewKey();
    final current = _getPreferencesForCurrentView();
    setState(() {
      _viewPreferences[key] = current.copyWith(filterSettings: filterSettings);
      _selectedIndices.clear();
    });
  }

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
      ..listFilter = _listFilter
      ..viewPreferences = Map.from(_viewPreferences);
  }

  void _restoreTabState(String path) {
    final state = _tabStates[path] ?? _StandaloneTabState();
    _currentGroup = state.currentGroup;
    _selectedIndices
      ..clear()
      ..addAll(state.selectedIndices);
    _lastSelectedIndex = state.lastSelectedIndex;
    _navigationHistory
      ..clear()
      ..addAll(state.navigationHistory);
    _historyIndex = state.historyIndex;
    _isTrashView = state.isTrashView;
    _searchController.text = state.searchQuery;
    _isSearchVisible = state.isSearchVisible;
    _listFilter = state.listFilter;
    _viewPreferences
      ..clear()
      ..addAll(state.viewPreferences);
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

    DownloadConfig? itemConfig;
    if (_currentGroup != null && _controller.cache.parsedItems != null) {
      final rootIndex = _controller.cache.parsedItems!.indexWhere(
        (g) => g.originalUrl == _currentGroup!.originalUrl,
      );
      if (rootIndex != -1) {
        itemConfig = _controller.cache.configs[rootIndex];
      }
    } else if (items.length == 1 && _controller.cache.parsedItems != null) {
      final item = items.first;
      final targetUrl = item is MediaGroup
          ? item.originalUrl
          : (item as MediaInfo).originalUrl;
      final rootIndex = _controller.cache.parsedItems!.indexWhere(
        (g) => g.originalUrl == targetUrl,
      );
      if (rootIndex != -1) {
        itemConfig = _controller.cache.configs[rootIndex];
      }
    }

    showDialog<void>(
      context: context,
      builder: (context) => PropertiesDialog(
        selectedItems: items,
        config: itemConfig,
        getFormatBytes: getFormatBytes,
        onClose: () => Navigator.of(context).pop(),
      ),
    );
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
            // Phase 1.1: cancel both extractor and hydration independently.
            _controller..cancelExtraction(item.originalUrl)
            ..cancelHydration(item.originalUrl);
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
            } else {
              final videoUrls = item.items
                  .where((e) => e.isVideo)
                  .map((e) => e.directUrl ?? e.originalUrl)
                  .whereType<String>();
              for (final url in videoUrls) {
                RemoteVideoThumbnailResolver.cleanup(url);
              }
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
            } else {
              if (item.isVideo) {
                final url = item.directUrl ?? item.originalUrl;
                RemoteVideoThumbnailResolver.cleanup(url);
              }
            }
          }
        }
        if (_currentGroup!.items.isEmpty) {
          // Phase 1.1: cancel both extractor and hydration independently.
          _controller..cancelExtraction(_currentGroup!.originalUrl)
          ..cancelHydration(_currentGroup!.originalUrl);
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

  static String _getDefaultDownloadsPath() {
    final home = Platform.isWindows
        ? (Platform.environment['USERPROFILE'] ?? r'C:\')
        : (Platform.environment['HOME'] ?? '/');
    return p.join(home, 'Downloads');
  }

  Future<void> _startDownload(MediaGroup group, int configIndex) async {
    try {
      final config = _controller.cache.configs[configIndex] ?? DownloadConfig();

      final dest = _currentPath.isNotEmpty
          ? _currentPath
          : _getDefaultDownloadsPath();
      if (!Directory(dest).existsSync()) {
        try {
          Directory(dest).createSync(recursive: true);
        } catch (_) {}
      }

      final itemsToDownload = List<MediaInfo>.from(group.items);

      // If group has multiple items, create a single enclosing folder in dest
      var groupDest = dest;
      final isGrouped =
          group.items.length > 1 ||
          group.first.isProfile ||
          group.first.isPlaylist;

      if (isGrouped) {
        // Replace newlines, tabs, carriage returns with a space first, then strip invalid FS chars
        var safeGroupName = group.first.title
            .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
            .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
            .trim();
        // Collapse multiple spaces into one
        safeGroupName = safeGroupName.replaceAll(RegExp('  +'), ' ');
        if (safeGroupName.isEmpty) safeGroupName = 'media_group';
        groupDest = p.join(dest, safeGroupName);
        if (!Directory(groupDest).existsSync()) {
          try {
            Directory(groupDest).createSync(recursive: true);
          } catch (_) {}
        }
      }

      // For playlists and profiles:
      if (group.first.isProfile || group.first.isPlaylist) {
        final folderName = p.basename(groupDest);
        final isSocialProfile = group.first.isProfile;

        // Apply media filter for profiles
        var totalFilteredItems = itemsToDownload.length;
        String? filterType;
        if (isSocialProfile && config.groupFilter != GroupDownloadType.all) {
          final isImages = config.groupFilter == GroupDownloadType.images;
          filterType = isImages ? 'images' : 'videos';
          totalFilteredItems = itemsToDownload
              .where((item) => isImages ? !item.isVideo : item.isVideo)
              .length;
        }

        final isFiltered =
            (filterType != null) ||
            (itemsToDownload.length < group.items.length);
        final indices = itemsToDownload
            .map((item) => item.galleryIndex ?? (group.items.indexOf(item) + 1))
            .where((idx) => idx > 0)
            .toList();
        final isIntact =
            !isFiltered &&
            itemsToDownload.length == group.items.length &&
            indices.length == group.items.length &&
            List.generate(indices.length, (i) => i + 1).join(',') ==
                indices.join(',');
        final itemsRange =
            (!isIntact &&
                indices.isNotEmpty &&
                indices.length == itemsToDownload.length)
            ? (indices.toSet().toList()..sort()).join(',')
            : null;

        ref
            .read(downloadTaskProvider.notifier)
            .startDownload(
              url: group.originalUrl,
              destination: groupDest,
              title: group.first.isProfile ? '$folderName Profile' : folderName,
              downloadType: group.first.isExtractorGroup 
                  ? 'extractor'
                  : group.first.isProfile
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
              expectedBytes: _controller.getGroupBytes(
                MediaGroup(
                  originalUrl: group.originalUrl,
                  items: itemsToDownload,
                ),
                config,
              ),
              itemsRange: itemsRange,
            );

        return;
      }

      // For non-profile/non-playlist grouped items (carousels / multi-photo posts):
      // Create ONE download task that runs gallery-dl on the group's originalUrl and
      // targets the single groupDest folder. This appears as a single tile in active
      // downloads with combined progress.
      if (isGrouped) {
        final folderName = p.basename(groupDest);

        // Count items that pass the active filter
        final filteredItems = itemsToDownload.where((item) {
          if (config.groupFilter == GroupDownloadType.images && item.isVideo) {
            return false;
          }
          if (config.groupFilter == GroupDownloadType.videos && !item.isVideo) {
            return false;
          }
          return !item.isProfile && !item.isPlaylist;
        }).toList();

        final totalFilteredItems = filteredItems.length;

        // Sum expected bytes for the group
        final expectedBytes = _controller.getGroupBytes(
          MediaGroup(originalUrl: group.originalUrl, items: itemsToDownload),
          config,
        );

        String? filterType;
        if (config.groupFilter == GroupDownloadType.images) {
          filterType = 'images';
        } else if (config.groupFilter == GroupDownloadType.videos) {
          filterType = 'videos';
        }

        final isFiltered =
            (filterType != null) || (filteredItems.length < group.items.length);
        final indices = filteredItems
            .map((item) => item.galleryIndex ?? (group.items.indexOf(item) + 1))
            .where((idx) => idx > 0)
            .toList();
        final isIntact =
            !isFiltered &&
            filteredItems.length == group.items.length &&
            indices.length == group.items.length &&
            List.generate(indices.length, (i) => i + 1).join(',') ==
                indices.join(',');
        final itemsRange =
            (!isIntact &&
                indices.isNotEmpty &&
                indices.length == filteredItems.length)
            ? (indices.toSet().toList()..sort()).join(',')
            : null;

        ref
            .read(downloadTaskProvider.notifier)
            .startDownload(
              url: group.originalUrl,
              destination: groupDest,
              title: folderName,
              downloadType: group.first.isExtractorGroup ? 'extractor' : 'carousel',
              format: config.format,
              audioOnly: config.mode == DownloadMode.audioOnly,
              mute: config.mode == DownloadMode.mute,
              engine: config.engine,
              browser: ref.read(settingsProvider).value?.downloadBrowser,
              filterType: filterType,
              totalItems: totalFilteredItems,
              expectedBytes: expectedBytes,
              isCarousel: true,
              itemsRange: itemsRange,
            );

        return;
      }

      // Single item (isGrouped == false) — download directly into dest root
      final info = itemsToDownload.first;
      final format = config.itemFormats[info.id] ?? config.format;
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

      final safeName = finalTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final dir = Directory(dest);
      if (dir.existsSync()) {
        final existingFiles = dir.listSync().whereType<File>().toList();
        if (existingFiles.any(
          (f) => p.basenameWithoutExtension(f.path) == safeName,
        )) {
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

      String downloadUrl;
      if (info.directUrl != null && info.directUrl!.isNotEmpty) {
        downloadUrl = info.directUrl!;
      } else if (info.webpageUrl != null && info.webpageUrl!.isNotEmpty) {
        downloadUrl = info.webpageUrl!;
      } else if (info.id.isNotEmpty &&
          (info.originalUrl.contains('youtu') ||
              info.originalUrl.contains('youtube.com'))) {
        downloadUrl = 'https://www.youtube.com/watch?v=${info.id}';
      } else {
        downloadUrl = info.originalUrl;
      }

      ref
          .read(downloadTaskProvider.notifier)
          .startDownload(
            url: downloadUrl,
            destination: dest,
            title: finalTitle,
            downloadType: info.isExtractorGroup ? 'extractor' : (info.isVideo ? 'video' : 'image'),
            format: format,
            audioOnly: config.mode == DownloadMode.audioOnly,
            mute: config.mode == DownloadMode.mute,
            galleryIndex: info.galleryIndex,
            engine: config.engine,
            browser: ref.read(settingsProvider).value?.downloadBrowser,
            totalItems: 1,
            singleItemId: info.id.isNotEmpty ? info.id : null,
            directUrl: info.directUrl,
            expectedBytes: info.filesize ?? 0,
          );
    } catch (e) {
      debugPrint('Error starting download: $e');
    }
  }

  Future<void> _startDownloadSingleItem(MediaInfo info, int configIndex) async {
    try {
      final dest = _currentPath.isNotEmpty
          ? _currentPath
          : _getDefaultDownloadsPath();
      if (!Directory(dest).existsSync()) {
        try {
          Directory(dest).createSync(recursive: true);
        } catch (_) {}
      }

      final itemDest = dest;

      final config = _controller.cache.configs[configIndex] ?? DownloadConfig();
      final format = config.itemFormats[info.id] ?? config.format;

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

      final safeName = finalTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final dir = Directory(itemDest);
      if (dir.existsSync()) {
        final existingFiles = dir.listSync().whereType<File>().toList();
        if (existingFiles.any(
          (f) => p.basenameWithoutExtension(f.path) == safeName,
        )) {
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

      String downloadUrl;
      if (info.directUrl != null && info.directUrl!.isNotEmpty) {
        downloadUrl = info.directUrl!;
      } else if (info.webpageUrl != null && info.webpageUrl!.isNotEmpty) {
        downloadUrl = info.webpageUrl!;
      } else if (info.id.isNotEmpty &&
          (info.originalUrl.contains('youtu') ||
              info.originalUrl.contains('youtube.com'))) {
        downloadUrl = 'https://www.youtube.com/watch?v=${info.id}';
      } else {
        downloadUrl = info.originalUrl;
      }

      ref
          .read(downloadTaskProvider.notifier)
          .startDownload(
            url: downloadUrl,
            destination: itemDest,
            title: finalTitle,
            downloadType: info.isExtractorGroup ? 'extractor' : (info.isVideo ? 'video' : 'image'),
            format: format,
            audioOnly: config.mode == DownloadMode.audioOnly,
            mute: config.mode == DownloadMode.mute,
            galleryIndex: info.galleryIndex,
            engine: config.engine,
            browser: ref.read(settingsProvider).value?.downloadBrowser,
            totalItems: 1,
            singleItemId: info.id.isNotEmpty ? info.id : null,
            directUrl: info.directUrl,
            expectedBytes: info.filesize ?? 0,
          );
    } catch (e) {
      debugPrint('Error starting single download: $e');
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
          final actualRootIndex = rootIndex >= 0 ? rootIndex : 0;
          for (final i in sortedIndices) {
            final item = _currentGroup!.items[i];
            await _startDownloadSingleItem(item, actualRootIndex);
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
          _navigationHistory
            ..clear()
            ..add(null);
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

  void _onUrlFocusTrigger() {
    if (mounted && _urlFocusNode.canRequestFocus) {
      FocusScope.of(context).requestFocus(_urlFocusNode);
      _urlController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _urlController.text.length,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _searchDebounce = null;
    _focusTrigger = PersistentViewerManager.getFocusTrigger(widget.windowId);
    _focusTrigger?.addListener(_onWindowFocus);
    _urlFocusTrigger = PersistentViewerManager.getUrlFocusTrigger(
      widget.windowId,
    );
    _urlFocusTrigger?.addListener(_onUrlFocusTrigger);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _mainFocusNode.requestFocus();
      }
    });

    final initialPath = widget.initParams['currentPath'] as String?;
    _currentPath = (initialPath != null && initialPath.isNotEmpty)
        ? initialPath
        : _getDefaultDownloadsPath();
        
    final importListPathRaw = widget.initParams['importListPath'] as String?;
    if (importListPathRaw != null && importListPathRaw.isNotEmpty) {
      // Mark as importing immediately so the first frame shows the spinner,
      // not an empty list.
      _isProcessingList = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          final importListPath = importListPathRaw.contains('?t=') 
              ? importListPathRaw.substring(0, importListPathRaw.indexOf('?t=')) 
              : importListPathRaw;
          final name = p.basenameWithoutExtension(importListPath);
          await _controller.importListFromFile(importListPath, name);
          _saveCurrentTabState(importListPath);
          if (mounted) {
            setState(() {
              _controller.cache.switchList(importListPath);
              _restoreTabState(importListPath);
              _isProcessingList = false;
            });
          }
        }
      });
    }

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
      final newPath = widget.initParams['currentPath'] as String?;
      if (newPath != null && newPath.isNotEmpty) {
        setState(() {
          _currentPath = newPath;
        });
      }
    }
    
    // Handle .dml file open when the downloader window is already visible
    // (e.g. user double-clicks a .dml while the app is running).
    final newImportPathRaw = widget.initParams['importListPath'] as String?;
    final oldImportPathRaw = oldWidget.initParams['importListPath'] as String?;
    if (newImportPathRaw != null &&
        newImportPathRaw.isNotEmpty &&
        newImportPathRaw != oldImportPathRaw) {
      setState(() => _isProcessingList = true);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        try {
          final actualPath = newImportPathRaw.contains('?t=') 
              ? newImportPathRaw.substring(0, newImportPathRaw.indexOf('?t=')) 
              : newImportPathRaw;
              
          final name = p.basenameWithoutExtension(actualPath);
          final previousPath = _controller.cache.importedListPath ?? 'default';
          _saveCurrentTabState(previousPath);
          await _controller.importListFromFile(actualPath, name);
          if (mounted) {
            setState(() {
              _controller.cache.switchList(actualPath);
              _restoreTabState(actualPath);
            });
          }
        } catch (e) {
          debugPrint('Error importing list from didUpdateWidget: $e');
        } finally {
          if (mounted) {
            setState(() => _isProcessingList = false);
          }
        }
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
          void performClose() {
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

          if (_controller.cache.isCacheChanged(path)) {
            showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: const Color(0xFF1E1E1E),
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
                title: Text(
                  'Unsaved Changes',
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                content: Text(
                  'You have unsaved changes. Are you sure you want to discard them?',
                  style: GoogleFonts.outfit(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                actionsAlignment: MainAxisAlignment.spaceBetween,
                actions: [
                  TextButton(
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white70)),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.error.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(color: AppColors.error.withValues(alpha: 0.2)),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          performClose();
                        },
                        child: Text('Discard', style: GoogleFonts.outfit(color: AppColors.error)),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: AppColors.violet,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        onPressed: () async {
                          Navigator.of(context).pop();

                      final itemsToSave = _controller.cache.getItemsForPath(path);
                      if (itemsToSave != null) {
                        final file = File(path);
                        final jsonString = await compute(_encodeJsonIsolateListSave, itemsToSave);
                        if (DmlCryptoService.isDmlFile(path)) {
                          final currentPassword = _controller.cache.currentPassword;
                          final encryptedBytes = await DmlCryptoService.encryptInIsolate(jsonString, password: currentPassword);
                          await file.writeAsBytes(encryptedBytes);
                        } else {
                          await file.writeAsString(jsonString);
                        }
                        setState(() {
                          _controller.cache.setCacheChanged(path, changed: false);
                        });
                      }
                    },
                        child: Text('Save', style: GoogleFonts.outfit(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            );
          } else {
            performClose();
          }
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
    ThumbnailAspectResolver.reset();
    _viewPreferences.clear();
    _tabStates.clear();
    _searchController.removeListener(_onSearchChanged);
    _focusTrigger?.removeListener(_onWindowFocus);
    _urlFocusTrigger?.removeListener(_onUrlFocusTrigger);
    _gradientController.dispose();
    _mainFocusNode.dispose();
    _urlController.dispose();
    _urlFocusNode.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    _mediaGridScrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _activeTagNotifier.dispose();
    HardwareKeyboard.instance.removeHandler(_handleGlobalRawKey);
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(_selectedIndices.clear); // Rebuild to filter media grid
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

    // Refresh _currentGroup if cache was updated behind the scenes
    if (_currentGroup != null && _controller.cache.parsedItems != null) {
      final rootIndex = _controller.cache.parsedItems!.indexWhere(
        (g) => g.originalUrl == _currentGroup!.originalUrl,
      );
      if (rootIndex != -1) {
        _currentGroup = _controller.cache.parsedItems![rootIndex];
      } else {
        _currentGroup = null;
      }
    }

    final readiness = ref.watch(downloaderReadinessProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: readiness.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (state) {
          if (!state.isReady) {
            return const DownloadsMissingBinariesView();
          }
          return Listener(
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
              final sidebarWidth = (constraints.maxWidth * 0.25).clamp(
                200.0,
                340.0,
              );

              final mainContent = Row(
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
                        Expanded(
                          child: Stack(
                            children: [
                              _buildMediaGrid(),
                              if (_isProcessingList)
                                Positioned.fill(
                                  child: ClipRect(
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.65),
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const BubbleLoader(size: 76),
                                              const SizedBox(height: 20),
                                              Text(
                                                'Processing...',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w600,
                                                      letterSpacing: 0.5,
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

                        // Location Bar
                        _buildLocationBar(),
                      ],
                    ),
                  ),
                ],
              );

              if (_isProcessingList) {
                return AbsorbPointer(child: mainContent);
              }

              return mainContent;
            },
          ),
        ),
      );
      },
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
          _controller.cache.setCacheChanged(path, changed: false);
        }
      });
    }
  }

  Future<void> _exportCurrentList() async {
    if (_isProcessingList) return;
    final saveLocation = await CustomFilePickerDialog.show(
      context,
      title: 'EXPORT LIST',
      saveMode: true,
      initialFileName: '${_controller.cache.importedListName ?? "export"}.dml',
      allowedExtensions: ['dml'],
    );
    if (saveLocation != null && saveLocation.isNotEmpty) {
      setState(() => _isProcessingList = true);
      try {
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
      } finally {
        if (mounted) {
          setState(() => _isProcessingList = false);
        }
      }
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
          _navigationHistory
            ..clear()
            ..add(null);
          _selectedIndices.clear();
          _lastSelectedIndex = -1;
        });
      },
      onImportTap: () async {
        if (_isProcessingList) return;
        final path = await CustomFilePickerDialog.show(
          context,
          title: 'IMPORT LIST',
          allowedExtensions: ['dml', 'json'],
        );
        if (path != null && path.isNotEmpty) {
          final file = File(path.first);
          if (file.existsSync()) {
            setState(() => _isProcessingList = true);
            try {
              final name = p.basenameWithoutExtension(path.first);
              final currentPath = _controller.cache.importedListPath ?? 'default';
              _saveCurrentTabState(currentPath);
              
              await _controller.importListFromFile(path.first, name);
              
              if (mounted) {
                setState(() {
                  _controller.cache.switchList(path.first);
                  _restoreTabState(path.first);
                });
              }
            } catch (e) {
              debugPrint('Error importing list from UI: $e');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to import list: $e', style: GoogleFonts.outfit(color: Colors.white)),
                    backgroundColor: Colors.red.shade900,
                  ),
                );
              }
            } finally {
              if (mounted) {
                setState(() => _isProcessingList = false);
              }
            }
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
          
          if (DmlCryptoService.isDmlFile(path)) {
            final jsonString = await compute(_encodeJsonIsolateListSave, itemsToSave);
            final currentPassword = _controller.cache.currentPassword;
            final encryptedBytes = await DmlCryptoService.encryptInIsolate(jsonString, password: currentPassword);
            await file.writeAsBytes(encryptedBytes);
          } else {
            final jsonString = await compute(_encodeJsonIsolateListSave, itemsToSave);
            await file.writeAsString(jsonString);
          }

          setState(() {
            if (_controller.cache.importedListPath == path ||
                (_controller.cache.importedListPath == null &&
                    path == 'default')) {
              _controller.cache.isListChanged = false;
            } else {
              _controller.cache.setCacheChanged(path, changed: false);
            }
          });
        }
      },
      onCustomListLock: (path) async {
        if (!DmlCryptoService.isDmlFile(path)) return;
        final listName = p.basenameWithoutExtension(path);
        final hasPassword = _controller.cache.hasPasswordForPath(path);

        if (hasPassword) {
          final currentPassword = _controller.cache.getPasswordForPath(path);
          if (currentPassword == null) return;

          final remove = await _showRemoveLockDialog(context, currentPassword);
          if (remove) {
            _controller.cache.removePasswordForPath(path);
            _controller.cache.setCacheChanged(path, changed: true);
            
            final itemsToSave = _controller.cache.getItemsForPath(path);
            if (itemsToSave != null) {
              final file = File(path);
              final jsonString = await compute(_encodeJsonIsolateListSave, itemsToSave);
              await file.writeAsString(jsonString);
              setState(() {
                _controller.cache.setCacheChanged(path, changed: false);
              });
            }
          }
        } else {
          final password = await _showLockDialog(context, listName);
          if (password != null && password.isNotEmpty) {
            if (_controller.cache.importedListPath == path) {
              _controller.cache.currentPassword = password;
              _controller.cache.isListChanged = true;
            }
            if (_controller.cache.importedListPath != path) {
              final currentPath = _controller.cache.importedListPath ?? 'default';
              _saveCurrentTabState(currentPath);
              setState(() {
                _controller.cache.switchList(path);
                _restoreTabState(path);
                _isTrashView = false;
              });
            }
            _controller.cache.currentPassword = password;
            _controller.cache.isListChanged = true;
            // Trigger save
            final itemsToSave = _controller.cache.getItemsForPath(path);
            if (itemsToSave != null) {
              final file = File(path);
              final jsonString = await compute(_encodeJsonIsolateListSave, itemsToSave);
              final encryptedBytes = await DmlCryptoService.encryptInIsolate(jsonString, password: password);
              await file.writeAsBytes(encryptedBytes);
              setState(() {
                _controller.cache.isListChanged = false;
                _controller.cache.currentPassword = null;
                _controller.cache.parsedItems = null;
                _controller.cache.isLocked = true;
              });
            }
          }
        }
      },
      onCustomListLockToggle: (path) {
        if (!_controller.cache.isLockedForPath(path)) {
          setState(() {
            _controller.cache.lockPath(path);
          });
        }
      },
      onDefaultExport: () async {
        final currentPath = _controller.cache.importedListPath ?? 'default';
        if (currentPath != 'default') {
          _saveCurrentTabState(currentPath);
          setState(() {
            _controller.cache.switchList('default');
            _restoreTabState('default');
            _isTrashView = false;
          });
        }
        await _exportCurrentList();
      },
      isDefaultExportDisabled:
          _isTrashView ||
          (_controller.cache.importedListPath == 'default' ||
                  _controller.cache.importedListPath == null
              ? (_controller.cache.parsedItems?.isEmpty ?? true)
              : (_controller.cache.getItemsForPath('default')?.isEmpty ??
                    true)),
    );
  }

  Future<String?> _showLockDialog(BuildContext context, String listName) async {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var obscurePassword = true;
    var obscureConfirm = true;
    String? errorMessage;

    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            'Lock $listName',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 360,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: 360,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                autofocus: true,
                                controller: passwordController,
                                obscureText: obscurePassword,
                                style: GoogleFonts.outfit(color: Colors.white),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                  labelText: 'Password',
                                  labelStyle: GoogleFonts.outfit(color: Colors.white70),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Colors.white30),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: AppColors.violet),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                validator: (_) => null,
                                onFieldSubmitted: (_) {
                                  final pwd = passwordController.text;
                                  final confirm = confirmController.text;
                                  if (pwd.isEmpty) {
                                    setState(() => errorMessage = 'Password is required');
                                  } else if (pwd != confirm) {
                                    setState(() => errorMessage = 'Passwords do not match');
                                  } else {
                                    Navigator.of(context).pop(pwd);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: IconButton(
                                icon: Icon(
                                  obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.white70,
                                ),
                                onPressed: () => setState(() => obscurePassword = !obscurePassword),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: confirmController,
                                obscureText: obscureConfirm,
                                style: GoogleFonts.outfit(color: Colors.white),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                  labelText: 'Confirm Password',
                                  labelStyle: GoogleFonts.outfit(color: Colors.white70),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Colors.white30),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: AppColors.violet),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                validator: (_) => null,
                                onFieldSubmitted: (_) {
                                  final pwd = passwordController.text;
                                  final confirm = confirmController.text;
                                  if (pwd.isEmpty) {
                                    setState(() => errorMessage = 'Password is required');
                                  } else if (pwd != confirm) {
                                    setState(() => errorMessage = 'Passwords do not match');
                                  } else {
                                    Navigator.of(context).pop(pwd);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: IconButton(
                                icon: Icon(
                                  obscureConfirm ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.white70,
                                ),
                                onPressed: () => setState(() => obscureConfirm = !obscureConfirm),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (errorMessage != null)
                    Positioned(
                      bottom: -20,
                      left: 0,
                      child: Text(
                        errorMessage!,
                        style: GoogleFonts.outfit(color: AppColors.error, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white70)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.violet,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                final pwd = passwordController.text;
                final confirm = confirmController.text;
                if (pwd.isEmpty) {
                  setState(() => errorMessage = 'Password is required');
                } else if (pwd != confirm) {
                  setState(() => errorMessage = 'Passwords do not match');
                } else {
                  Navigator.of(context).pop(pwd);
                }
              },
              child: Text('Lock', style: GoogleFonts.outfit(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _showRemoveLockDialog(BuildContext context, String currentPassword) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var obscurePassword = true;
    String? errorMessage;

    return await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            'Remove Password',
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 360,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    width: 360,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                autofocus: true,
                                controller: passwordController,
                                obscureText: obscurePassword,
                                style: GoogleFonts.outfit(color: Colors.white),
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                  labelText: 'Current Password',
                                  labelStyle: GoogleFonts.outfit(color: Colors.white70),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: Colors.white30),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: const BorderSide(color: AppColors.violet),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                validator: (_) => null,
                                onFieldSubmitted: (_) {
                                  if (passwordController.text != currentPassword) {
                                    setState(() => errorMessage = 'Incorrect password');
                                  } else {
                                    Navigator.of(context).pop(true);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: IconButton(
                                icon: Icon(
                                  obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  color: Colors.white70,
                                ),
                                onPressed: () => setState(() => obscurePassword = !obscurePassword),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (errorMessage != null)
                    Positioned(
                      bottom: -20,
                      left: 0,
                      child: Text(
                        errorMessage!,
                        style: GoogleFonts.outfit(color: AppColors.error, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel', style: GoogleFonts.outfit(color: Colors.white70)),
            ),
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.error,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                if (passwordController.text != currentPassword) {
                  setState(() => errorMessage = 'Incorrect password');
                } else {
                  Navigator.of(context).pop(true);
                }
              },
              child: Text('Remove', style: GoogleFonts.outfit(color: Colors.white)),
            ),
          ],
        ),
      ),
    ) ?? false;
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
            if (file.existsSync()) {
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

    setState(() {
      for (final t in _trash) {
        if (t.item is MediaGroup) {
          final videoUrls = (t.item as MediaGroup).items
              .where((e) => e.isVideo)
              .map((e) => e.directUrl ?? e.originalUrl)
              .whereType<String>();
          for (final url in videoUrls) {
            RemoteVideoThumbnailResolver.cleanup(url);
          }
        } else {
          final info = t.item as MediaInfo;
          if (info.isVideo) {
            final url = info.directUrl ?? info.originalUrl;
            RemoteVideoThumbnailResolver.cleanup(url);
          }
        }
      }
      _trash.clear();
      _selectedIndices.clear();
    });
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

    final viewPrefs = _getPreferencesForCurrentView();

    final availableTypes = <DownloaderItemType>{};
    final availableDates = <DateTime>{};
    final availableDatesByType = <DownloaderItemType, Set<DateTime>>{};

    void addTypeAndDate(DownloaderItemType type, DateTime? date) {
      availableTypes.add(type);
      if (date != null) {
        final d = DateTime(date.year, date.month, date.day);
        availableDates.add(d);
        availableDatesByType.putIfAbsent(type, () => <DateTime>{}).add(d);
      }
    }

    if (_isTrashView) {
      final currentListPath = _controller.cache.importedListPath ?? 'default';
      final currentTrash = _trash.where((t) => t.listPath == currentListPath);
      for (final t in currentTrash) {
        if (t.item is MediaGroup) {
          final g = t.item as MediaGroup;
          final type = DownloaderItemClassifier.classify(g);
          final gDate = DownloaderItemClassifier.extractDate(g);
          addTypeAndDate(type, gDate);
          for (final item in g.items) {
            if (item.uploadDate != null) {
              addTypeAndDate(type, item.uploadDate);
            }
          }
        } else if (t.item is MediaInfo) {
          final info = t.item as MediaInfo;
          if (info.isError) continue;
          final type = DownloaderItemClassifier.classifyItem(info);
          addTypeAndDate(type, info.uploadDate);
        }
      }
    } else if (_currentGroup != null) {
      for (final item in _currentGroup!.items) {
        if (item.isError) continue;
        if (_currentGroup!.first.isProfile &&
            item == _currentGroup!.items.first) {
          continue;
        }
        final type = DownloaderItemClassifier.classifyItem(item);
        addTypeAndDate(type, item.uploadDate);
      }
    } else if (_controller.cache.parsedItems != null) {
      for (final group in _controller.cache.parsedItems!) {
        final type = DownloaderItemClassifier.classify(group);
        final gDate = DownloaderItemClassifier.extractDate(group);
        addTypeAndDate(type, gDate);
        for (final item in group.items) {
          if (item.uploadDate != null) {
            addTypeAndDate(type, item.uploadDate);
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
      onEmptyTrash: () => setState(() {
        for (final t in _trash) {
          if (t.item is MediaGroup) {
            final videoUrls = (t.item as MediaGroup).items
                .where((e) => e.isVideo)
                .map((e) => e.directUrl ?? e.originalUrl)
                .whereType<String>();
            for (final url in videoUrls) {
              RemoteVideoThumbnailResolver.cleanup(url);
            }
          } else {
            final info = t.item as MediaInfo;
            if (info.isVideo) {
              final url = info.directUrl ?? info.originalUrl;
              RemoteVideoThumbnailResolver.cleanup(url);
            }
          }
        }
        _trash.clear();
        _selectedIndices.clear();
      }),
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
          _selectedIndices.clear();
        });
      },
      getHeight: _getHeight,
      matchTargetFormat: matchTargetFormat,
      searchController: _searchController,
      searchFocusNode: _searchFocusNode,
      isSearchVisible: _isSearchVisible,
      listFilter: viewPrefs.sortOrder,
      sortOrder: viewPrefs.sortOrder,
      onSortChanged: _updateViewSort,
      filterSettings: viewPrefs.filterSettings,
      onFilterSettingsChanged: _updateViewFilter,
      availableTypes: availableTypes,
      availableDates: availableDates,
      availableDatesByType: availableDatesByType,
      hasImages: hasImages,
      hasVideos: hasVideos,
      hasPlaylists: hasPlaylists,
      hasProfiles: hasProfiles,
      hasGroups: hasGroups,
      onListFilterChanged: _updateViewSort,
      activeTagNotifier: _activeTagNotifier,
      onTagTap: _scrollToTag,
      onTagSecondaryTapDown: _showTagHeaderContextMenu,
    );
  }

  void _handleTagItem(String url, String tag) {
    setState(() {
      final parsedItems = _controller.cache.parsedItems;
      if (parsedItems == null) return;

      final currentSort = _getPreferencesForCurrentView().sortOrder;
      if (_currentGroup == null) {
        final idx = parsedItems.indexWhere((g) => g.originalUrl == url);
        if (idx != -1) {
          final oldGroup = parsedItems[idx];
          parsedItems[idx] = oldGroup.copyWith(
            tag: tag,
            tagSortOrder: currentSort,
          );
        }
      } else {
        final idx = _currentGroup!.items.indexWhere((i) => i.id == url);
        if (idx != -1) {
          final oldItem = _currentGroup!.items[idx];
          _currentGroup!.items[idx] = oldItem.copyWith(
            tag: tag,
            tagSortOrder: currentSort,
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
    final currentSort = _getPreferencesForCurrentView().sortOrder;
    if (currentSort != sortOrder) {
      _updateViewSort(sortOrder);
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

  void _toggleSelection(
    int index, {
    bool isCtrl = false,
    bool isShift = false,
  }) {
    if (!mounted) return;

    void updateState() {
      if (!mounted) return;
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
          _selectedIndices
            ..clear()
            ..add(index);
          _lastSelectedIndex = index;
        }
      });
    }

    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.idle) {
      WidgetsBinding.instance.addPostFrameCallback((_) => updateState());
    } else {
      updateState();
    }
  }

  List<MediaGroup> _getVisibleGroups() {
    var mappedGroups = <MediaGroup>[];
    final searchTerm = _searchController.text.trim().toLowerCase();
    final viewPrefs = _getPreferencesForCurrentView();
    final filterSettings = viewPrefs.filterSettings;
    final sortOrder = viewPrefs.sortOrder;

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

      if (filterSettings.selectedTypes.isNotEmpty) {
        mappedGroups = mappedGroups
            .where(
              (g) => filterSettings.selectedTypes.contains(
                DownloaderItemClassifier.classify(g),
              ),
            )
            .toList();
      }

      if (filterSettings.selectedDates.isNotEmpty) {
        mappedGroups = mappedGroups
            .where(
              (g) => DownloaderItemClassifier.matchesDateFilter(
                g,
                filterSettings.selectedDates,
              ),
            )
            .toList();
      }

      if (sortOrder == 'added_asc') {
        mappedGroups = mappedGroups.reversed.toList();
      } else if (sortOrder == 'size_asc' || sortOrder == 'size_desc') {
        mappedGroups.sort((a, b) {
          final aSize = a.totalFilesize;
          final bSize = b.totalFilesize;
          return sortOrder == 'size_asc'
              ? aSize.compareTo(bSize)
              : bSize.compareTo(aSize);
        });
      }

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

      if (filterSettings.selectedTypes.isNotEmpty) {
        entries = entries
            .where(
              (g) => filterSettings.selectedTypes.contains(
                DownloaderItemClassifier.classify(g),
              ),
            )
            .toList();
      }

      if (filterSettings.selectedDates.isNotEmpty) {
        entries = entries
            .where(
              (g) => DownloaderItemClassifier.matchesDateFilter(
                g,
                filterSettings.selectedDates,
              ),
            )
            .toList();
      }

      if (sortOrder == 'added_asc') {
        entries = entries.reversed.toList();
      } else if (sortOrder == 'size_asc' || sortOrder == 'size_desc') {
        entries.sort((a, b) {
          final aSize = a.totalFilesize;
          final bSize = b.totalFilesize;
          return sortOrder == 'size_asc'
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
        var filteredItems = _currentGroup!.items.where((item) {
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
          return true;
        }).toList();

        if (filterSettings.selectedTypes.isNotEmpty) {
          filteredItems = filteredItems
              .where(
                (item) => filterSettings.selectedTypes.contains(
                  DownloaderItemClassifier.classifyItem(item),
                ),
              )
              .toList();
        }

        if (filterSettings.selectedDates.isNotEmpty) {
          filteredItems = filteredItems.where((item) {
            if (item.uploadDate == null) return false;
            final d = DateTime(
              item.uploadDate!.year,
              item.uploadDate!.month,
              item.uploadDate!.day,
            );
            return filterSettings.selectedDates.any(
              (DateTime sd) =>
                  sd.year == d.year && sd.month == d.month && sd.day == d.day,
            );
          }).toList();
        }

        if (sortOrder == 'added_asc') {
          filteredItems = filteredItems.reversed.toList();
        } else if (sortOrder == 'size_asc' || sortOrder == 'size_desc') {
          filteredItems.sort((a, b) {
            final aSize = a.filesize ?? 0;
            final bSize = b.filesize ?? 0;
            return sortOrder == 'size_asc'
                ? aSize.compareTo(bSize)
                : bSize.compareTo(aSize);
          });
        }

        if (searchTerm.isNotEmpty) {
          filteredItems = filteredItems
              .where((item) => item.title.toLowerCase().contains(searchTerm))
              .toList();
        }

        mappedGroups = filteredItems.map((info) {
          return MediaGroup(items: [info], originalUrl: info.originalUrl);
        }).toList();
      }
    }
    return mappedGroups;
  }

  int _calculateDisplaySize(
    MediaInfo item,
    DownloadConfig? config,
    bool isRootView,
  ) {
    if (item.formats.isNotEmpty) {
      MediaFormat? selectedFormat;
      if (!isRootView) {
        selectedFormat = config?.itemFormats[item.id];
      } else {
        selectedFormat = config?.format;
      }
      selectedFormat ??=
          item.formats
              .where((f) {
                final h = _getHeight(f.resolution);
                return h > 0 && h <= 1080;
              })
              .fold<MediaFormat?>(
                null,
                (a, b) => a == null
                    ? b
                    : ((a.filesize ?? 0) > (b.filesize ?? 0) ? a : b),
              ) ??
          item.formats.first;

      final bytes = (config != null)
          ? getFormatBytes(item, selectedFormat, config)
          : selectedFormat.filesize;

      if (bytes != null && bytes > 0) return bytes;
    }

    final bytes = item.filesize;
    if (bytes == null && item.formats.isNotEmpty) {
      for (final f in item.formats) {
        if (f.filesize != null && f.filesize! > 0) {
          return f.filesize!;
        }
      }
    }
    return bytes ?? 0;
  }

  ({int videos, int images, int size}) _computeVisibleStats() {
    final visibleGroups = _getVisibleGroups();
    var videos = 0;
    var images = 0;
    var size = 0;

    if (_isTrashView) {
      for (final group in visibleGroups) {
        for (final item in group.items) {
          if (item.isVideo) {
            videos++;
          } else if (!item.isPlaylist && !item.isProfile) {
            images++;
          }
          size += item.filesize ?? 0;
        }
      }
      return (videos: videos, images: images, size: size);
    }

    if (_currentGroup != null) {
      final rootIndex =
          _controller.cache.parsedItems?.indexWhere(
            (g) => g.originalUrl == _currentGroup!.originalUrl,
          ) ??
          -1;
      final config = rootIndex != -1
          ? _controller.cache.configs[rootIndex]
          : null;

      for (final group in visibleGroups) {
        for (final item in group.items) {
          if (item.isError ||
              item.id == 'fetch_loading' ||
              item.id == 'hydration_loading') {
            continue;
          }
          if (item.isVideo) {
            videos++;
          } else if (!item.isPlaylist && !item.isProfile) {
            images++;
          }

          size += _calculateDisplaySize(item, config, false);
        }
      }
      return (videos: videos, images: images, size: size);
    }

    // Root view: calculate from visible groups
    for (final group in visibleGroups) {
      final rootIndex =
          _controller.cache.parsedItems?.indexWhere(
            (g) => g.originalUrl == group.originalUrl,
          ) ??
          -1;
      final config = rootIndex != -1
          ? _controller.cache.configs[rootIndex]
          : null;

      for (final item in group.items) {
        if (item.isError ||
            item.id == 'fetch_loading' ||
            item.id == 'hydration_loading') {
          continue;
        }
        if (config?.groupFilter == GroupDownloadType.images && item.isVideo) {
          continue;
        }
        if (config?.groupFilter == GroupDownloadType.videos && !item.isVideo) {
          continue;
        }
        if (item.isVideo) {
          videos++;
        } else if (!item.isPlaylist && !item.isProfile) {
          images++;
        }
      }

      if (group.first.isProfile ||
          group.first.isPlaylist ||
          group.items.length > 1) {
        size += group.totalFilesize;
      } else if (group.items.isNotEmpty) {
        size += _calculateDisplaySize(group.items.first, config, true);
      }
    }

    return (videos: videos, images: images, size: size);
  }

  Widget _buildMediaGrid() {
    if (_controller.cache.isLocked) {
      return Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: Colors.white54, size: 48),
              const SizedBox(height: 16),
              Text(
                'This list is locked',
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      autofocus: true,
                      controller: _unlockPasswordController,
                      obscureText: _obscureUnlockPassword,
                      style: GoogleFonts.outfit(color: Colors.white),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        labelText: 'Password',
                        labelStyle: GoogleFonts.outfit(color: Colors.white70),
                        enabledBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Colors.white30),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: AppColors.violet),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onSubmitted: (value) async {
                        if (value.isNotEmpty) {
                          final path = _controller.cache.importedListPath;
                          final name = _controller.cache.importedListName;
                          if (path != null && name != null) {
                            try {
                              await _controller.importListFromFile(path, name, password: value);
                              _unlockPasswordController.clear();
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Incorrect password', style: GoogleFonts.outfit(color: Colors.white)),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: IconButton(
                      icon: Icon(
                        _obscureUnlockPassword ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white70,
                      ),
                      onPressed: () => setState(() => _obscureUnlockPassword = !_obscureUnlockPassword),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.violet,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    final value = _unlockPasswordController.text;
                    if (value.isNotEmpty) {
                      final path = _controller.cache.importedListPath;
                      final name = _controller.cache.importedListName;
                      if (path != null && name != null) {
                        try {
                          await _controller.importListFromFile(path, name, password: value);
                          _unlockPasswordController.clear();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Incorrect password', style: GoogleFonts.outfit(color: Colors.white)),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        }
                      }
                    }
                  },
                  child: Text('Unlock', style: GoogleFonts.outfit(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final mappedGroups = _getVisibleGroups();
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
      onCancelHydration: (url) async {
        // Phase 1.1: cancel both extractor and hydration independently.
        await _controller.cancelExtraction(url);
        await _controller.cancelHydration(url);
        if (mounted) setState(() {});
      },
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
          final rootIndex = _controller.cache.parsedItems!.indexOf(
            _currentGroup!,
          );
          _startDownloadSingleItem(item, rootIndex >= 0 ? rootIndex : 0);
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
    final stats = _computeVisibleStats();
    final videos = stats.videos;
    final images = stats.images;
    final size = stats.size;

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
        if (_isProcessingList) return;
        setState(() => _isProcessingList = true);
        try {
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
                  '${_controller.cache.importedListName ?? "export"}.dml',
              allowedExtensions: ['dml'],
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
        } finally {
          if (mounted) {
            setState(() => _isProcessingList = false);
          }
        }
      },
      onDownloadAll: _downloadAll,
      selectionCount: _selectedIndices.length,
    );
  }

  List<FileItem> _collectImagePlaylist() {
    final groups = _currentVisibleGroups.isNotEmpty
        ? _currentVisibleGroups
        : (_currentGroup != null
              ? [_currentGroup!]
              : (_controller.cache.parsedItems ?? []));

    final items = <FileItem>[];
    for (final group in groups) {
      for (final item in group.items) {
        if (!item.isVideo && !item.isError) {
          final url = item.directUrl ?? item.thumbnail ?? item.originalUrl;
          if (url.isNotEmpty) {
            items.add(
              FileItem(
                name: item.title.isNotEmpty ? item.title : p.basename(url),
                path: url,
                sizeBytes: item.filesize,
                modified: DateTime.now(),
                type: FileItemType.image,
                thumbnailPath: item.thumbnail,
              ),
            );
          }
        }
      }
    }
    return items;
  }

  List<FileItem> _collectVideoPlaylist() {
    final groups = _currentVisibleGroups.isNotEmpty
        ? _currentVisibleGroups
        : (_currentGroup != null
              ? [_currentGroup!]
              : (_controller.cache.parsedItems ?? []));

    final items = <FileItem>[];
    for (final group in groups) {
      for (final item in group.items) {
        if (item.isVideo && !item.isError) {
          final url = resolvePlaybackUrl(item);
          if (url.isNotEmpty) {
            items.add(
              FileItem(
                name: item.title.isNotEmpty ? item.title : p.basename(url),
                path: url,
                sizeBytes: item.filesize,
                modified: DateTime.now(),
                type: FileItemType.video,
                thumbnailPath: item.thumbnail,
              ),
            );
          }
        }
      }
    }
    return items;
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
        thumbnailPath: item.thumbnail,
      );

      final playlist = _collectImagePlaylist();
      final playlistJson = jsonEncode(playlist.map((e) => e.toJson()).toList());

      final windowParams = WindowParams(
        viewerType: ViewerType.image,
        file: fileItem,
        initParams: {
          'width': 600,
          'height': 800,
          'is_minimal': true,
          'is_network_stream': true,
          'playlistJson': playlistJson,
          'playlistPath': url,
        },
      );

      // ignore: unawaited_futures
      PersistentViewerManager.openMedia(windowParams).whenComplete(() {
        if (mounted) {
          setState(() {
            _downloadingImageIndices.remove(index);
          });
        }
      });
    } catch (e, st) {
      debugPrint('EXCEPTION IN START DOWNLOAD: $e\n$st');
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

      final playbackUrl = streamUrl;

      final fileItemForPlayer = FileItem(
        name: item.title.isNotEmpty ? item.title : p.basename(playbackUrl),
        path: playbackUrl,
        sizeBytes: effectiveFormat?.filesize ?? item.filesize,
        modified: DateTime.now(),
        type: FileItemType.video,
        thumbnailPath: item.thumbnail,
      );

      final playlist = _collectVideoPlaylist();
      final playlistJson = jsonEncode(playlist.map((e) => e.toJson()).toList());

      final windowParams = WindowParams(
        viewerType: ViewerType.video,
        file: fileItemForPlayer,
        initParams: {
          'width': 1280,
          'height': 720,
          'is_network_stream': true,
          'playlistJson': playlistJson,
          'playlistPath': playbackUrl,
          'formats': item.formats.map((f) => f.toJson()).toList(),
          'selectedFormatId': effectiveFormat?.formatId,
          if (audioUrl != null) 'audioUrl': audioUrl,
        },
      );

      // ignore: unawaited_futures
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
  set currentPathForTesting(String val) => _currentPath = val;

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
  void onItemTapForTesting(
    int index, {
    bool isCtrl = false,
    bool isShift = false,
  }) => _toggleSelection(index, isCtrl: isCtrl, isShift: isShift);

  @visibleForTesting
  MediaGroup? get currentGroupForTesting => _currentGroup;

  @visibleForTesting
  set currentGroupForTesting(MediaGroup? g) => _currentGroup = g;

  @visibleForTesting
  bool get isTrashViewForTesting => _isTrashView;

  @visibleForTesting
  void saveCurrentTabStateForTesting(String path) => _saveCurrentTabState(path);

  @visibleForTesting
  void restoreTabStateForTesting(String path) => _restoreTabState(path);

  @visibleForTesting
  void handleDeleteForTesting({required bool isShiftPressed}) =>
      _handleDelete(isShiftPressed);

  @visibleForTesting
  void toggleSelectionForTesting(int index) {
    _toggleSelection(index);
  }

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

  final validFormats = item.formats.toList()
    ..sort((a, b) {
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
  // For live streams, bypass the ytdl hook and return the direct HLS/m3u8 url.
  // The ytdl hook in media_kit can struggle with live streams.
  if (item.isLive) {
    if (selectedFormat != null &&
        selectedFormat.url != null &&
        selectedFormat.url!.isNotEmpty) {
      return selectedFormat.url;
    }
    if (item.directUrl != null && item.directUrl!.isNotEmpty) {
      return item.directUrl;
    }
    if (item.formats.isNotEmpty) {
      try {
        final hlsFormat = item.formats.firstWhere(
          (f) => f.url != null && f.url!.contains('.m3u8'),
        );
        if (hlsFormat.url != null && hlsFormat.url!.isNotEmpty) {
          return hlsFormat.url;
        }
      } catch (_) {
        // Fallback to highest quality url if no explicit m3u8 is found
        final bestFormat = item.formats.last;
        if (bestFormat.url != null && bestFormat.url!.isNotEmpty) {
          return bestFormat.url;
        }
      }
    }
  }

  // Let media_kit's ytdl hook handle DASH audio+video muxing natively
  // for yt-dlp extracted links. This also bypasses expired directUrls for old
  // imported JSON lists that might be missing the engineId field.
  final isLikelyYtDlp = item.engineId == 'yt-dlp' ||
      item.extractor != null ||
      item.originalUrl.contains('youtube.com') ||
      item.originalUrl.contains('youtu.be') ||
      item.originalUrl.contains('instagram.com') ||
      item.originalUrl.contains('tiktok.com') ||
      item.originalUrl.contains('twitter.com') ||
      item.originalUrl.contains('x.com') ||
      item.originalUrl.contains('reddit.com');

  if (isLikelyYtDlp) {
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

// Top-level isolate function for UI non-blocking json encode
String _encodeJsonIsolateListSave(List<MediaGroup> itemsData) {
  final data = {'items': itemsData.map((e) => e.toMap()).toList()};
  return jsonEncode(data);
}
