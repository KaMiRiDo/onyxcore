import "dart:math" as math;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';

import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';

import 'package:onyxcore/features/directory_browser/presentation/providers/conflict_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_shared_controller.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/window_management/window_params.dart';

import 'package:onyxcore/features/downloader/presentation/widgets/downloads_panel.dart';
import 'package:onyxcore/features/file_picker/presentation/widgets/custom_file_picker_dialog.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_header.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_media_list.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_active_downloads.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_action_bar.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_media_grid.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_location_bar.dart';
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

class _StandaloneDownloaderWindowState
    extends ConsumerState<StandaloneDownloaderWindow>
    with SingleTickerProviderStateMixin, DownloadsPanelHelpersMixin {
  late DownloadsSharedController _controller;
  final Set<int> _downloadingImageIndices = {};

  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  final FocusNode _mainFocusNode = FocusNode();
  late AnimationController _gradientController;
  String _currentPath = '';
  MediaGroup? _currentGroup;
  String? _lastCustomListPath;
  String? _lastCustomListName;
  int _lastCustomListVideos = 0;
  int _lastCustomListImages = 0;
  int _lastCustomListSize = 0;

  final Set<int> _selectedIndices = {};
  int _lastSelectedIndex = -1;
  final List<MediaGroup?> _navigationHistory = [null];
  int _historyIndex = 0;
  final List<_TrashItem> _trash = [];
  bool _isTrashView = false;

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

  Future<void> _startDownload(int index) async {
    final parsedItems = _controller.cache.parsedItems;
    if (parsedItems == null || index >= parsedItems.length) return;

    try {
      final group = parsedItems[index];
      final config = _controller.cache.configs[index]!;

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

        setState(() {
          parsedItems.removeAt(index);
          _controller.cache.isListChanged = true;
          _controller.cache.notify();
        });
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

      setState(() {
        parsedItems.removeAt(index);
        _controller.cache.isListChanged = true;
        _controller.cache.notify();
      });
    } finally {
      ref.read(conflictProvider.notifier).clearGlobalResolution();
    }
  }

  Future<void> _downloadAll() async {
    final parsedItems = _controller.cache.parsedItems;
    if (parsedItems == null || parsedItems.isEmpty) return;

    while (parsedItems.isNotEmpty) {
      await _startDownload(0);
    }
  }

  @override
  void initState() {
    super.initState();

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

    PersistentViewerManager.presentWindow(widget.windowId);
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

  @override
  void dispose() {
    _gradientController.dispose();
    _mainFocusNode.dispose();
    _urlController.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  void _fetchUrl() {
    if (_urlController.text.trim().isNotEmpty) {
      _controller.analyzeUrls(_urlController.text.trim());
      _urlController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    _controller = ref.watch(downloadsSharedControllerProvider);
    // Also watch the cache explicitly so UI updates when cache changes
    ref.watch(downloadsListCacheProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: GestureDetector(
        onTap: _mainFocusNode.requestFocus,
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

              if (HardwareKeyboard.instance.isControlPressed &&
                  (event.logicalKey == LogicalKeyboardKey.keyD)) {
                if (mounted && _urlFocusNode.canRequestFocus) {
                  FocusScope.of(node.context!).requestFocus(_urlFocusNode);
                }
                return KeyEventResult.handled;
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
                }
              }
            }
            return KeyEventResult.ignored;
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Sidebar
              Container(
                width: 380,
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
      onFetch: () => _fetchUrl(),
    );
  }

  Widget _buildMediaListSection() {
    return StandaloneWindowMediaList(
      isTrashView: _isTrashView,
      importedListName: _controller.cache.importedListName,
      isListChanged: _controller.cache.isListChanged,
      lastCustomListName: _lastCustomListName,
      lastCustomListVideos: _lastCustomListVideos,
      lastCustomListImages: _lastCustomListImages,
      lastCustomListSize: _lastCustomListSize,
      onDefaultListTap: () {
        setState(() {
          _isTrashView = false;
          if (_controller.cache.importedListName != null) {
            _lastCustomListVideos = _controller.totalListVideos;
            _lastCustomListImages = _controller.totalListImages;
            _lastCustomListSize = _controller.totalListSize;
          }

          _navigationHistory.clear();
          _navigationHistory.add(null);
          _historyIndex = 0;
          _currentGroup = null;
          _selectedIndices.clear();
          _lastSelectedIndex = -1;
        });
        if (_controller.cache.importedListName != null) {
          _controller.cache.switchList('default');
          _controller.recalculateFilteredStatistics();
        }
      },
      onTrashTap: () {
        setState(() {
          _isTrashView = true;
          _navigationHistory.clear();
          _navigationHistory.add(null);
          _historyIndex = 0;
          _currentGroup = null;
          _selectedIndices.clear();
          _lastSelectedIndex = -1;
        });
      },
      onImportTap: () async {
        final files = await CustomFilePickerDialog.show(
          context,
          title: 'IMPORT LIST',
          allowedExtensions: ['txt', 'json'],
          initialDirectory: _currentPath,
        );
        if (files != null && files.isNotEmpty) {
          final file = File(files.first);
          if (await file.exists()) {
            final name = p.basename(file.path);
            setState(() {
              _lastCustomListPath = file.path;
              _lastCustomListName = name;
            });
            await _controller.importListFromFile(file.path, name);
          }
        }
      },
      onCustomListTap: () async {
        setState(() {
          _isTrashView = false;
        });
        if (_controller.cache.importedListName == null &&
            _lastCustomListPath != null) {
          setState(() {
            _navigationHistory.clear();
            _navigationHistory.add(null);
            _historyIndex = 0;
            _currentGroup = null;
            _selectedIndices.clear();
            _lastSelectedIndex = -1;
          });
          await _controller.importListFromFile(
            _lastCustomListPath!,
            _lastCustomListName!,
          );
        }
      },
      onCustomListClose: () {
        setState(() {
          _lastCustomListName = null;
          _lastCustomListPath = null;
        });
        if (_controller.cache.importedListName != null) {
          _controller.cache.switchList('default');
          _controller.recalculateFilteredStatistics();
        }
      },
      onCustomListSave: () async {
        if (_lastCustomListPath != null) {
          await _controller.exportListToFile(_lastCustomListPath!);
          _controller.cache.isListChanged = false;
          _controller.recalculateFilteredStatistics();

          setState(() {
            _lastCustomListName = null;
            _lastCustomListPath = null;
          });
          if (_controller.cache.importedListName != null) {
            _controller.cache.switchList('default');
            _controller.recalculateFilteredStatistics();
          }
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

  Widget _buildActionBar() {
    return StandaloneWindowActionBar(
      isTrashView: _isTrashView,
      trashNotEmpty: _trash.isNotEmpty,
      hasItems: _controller.cache.parsedItems?.isNotEmpty ?? false,
      currentGroup: _currentGroup,
      importedListName: _controller.cache.importedListName,
      rootIndex:
          _currentGroup != null && _controller.cache.parsedItems!.isNotEmpty
          ? _controller.cache.parsedItems!.indexOf(_currentGroup!)
          : null,
      config:
          _currentGroup != null &&
              _controller.cache.parsedItems!.isNotEmpty &&
              _controller.cache.parsedItems!.indexOf(_currentGroup!) != -1
          ? _controller.cache.configs[_controller.cache.parsedItems!.indexOf(
              _currentGroup!,
            )]
          : null,
      onRestoreAll: _restoreTrash,
      onEmptyTrash: () => setState(_trash.clear),
      onBackToRoot: () => setState(() => _currentGroup = null),
      onFormatChanged: (val) {
        final rootIdx = _controller.cache.parsedItems!.indexOf(_currentGroup!);
        if (rootIdx != -1) {
          setState(() {
            _controller.cache.configs[rootIdx]!.format = val;
          });
          _controller.recalculateFilteredStatistics();
        }
      },
      onFilterChanged: (val) {
        final rootIdx = _controller.cache.parsedItems!.indexOf(_currentGroup!);
        if (rootIdx != -1) {
          setState(() {
            _controller.cache.configs[rootIdx]!.groupFilter = val;
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
    );
  }

  void _toggleSelection(int index, bool isCtrl, bool isShift) {
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
        for (int i = start; i <= end; i++) {
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
    List<MediaGroup> mappedGroups = [];
    if (_currentGroup == null) {
      mappedGroups = _controller.cache.parsedItems ?? [];
    } else {
      final rootIndex =
          _controller.cache.parsedItems?.indexOf(_currentGroup!) ?? -1;
      if (rootIndex != -1) {
        final config = _controller.cache.configs[rootIndex];
        final filteredItems = _currentGroup!.items.where((item) {
          if (item.isError) return false;
          if (config?.groupFilter == GroupDownloadType.images && item.isVideo)
            return false;
          if (config?.groupFilter == GroupDownloadType.videos && !item.isVideo)
            return false;
          return true;
        }).toList();

        mappedGroups = filteredItems.map((info) {
          return MediaGroup(items: [info], originalUrl: info.originalUrl);
        }).toList();
      }
    }

    return StandaloneWindowMediaGrid(
      isTrashView: _isTrashView,
      groups: mappedGroups,
      currentGroup: _currentGroup,
      selectedIndices: _selectedIndices,
      downloadingImageIndices: _downloadingImageIndices,
      configs: _controller.cache.configs,
      isHydratingItem: (url) =>
          _controller.activeHydrationPids.containsKey(url),
      onTapItem: _toggleSelection,
      onDoubleTapItem: (index, group) {
        if (_currentGroup == null && group.items.length > 1) {
          setState(() {
            _navigationHistory.add(_currentGroup);
            _historyIndex++;
            _currentGroup = group;
          });
        } else {
          final firstItem = group.items.isNotEmpty ? group.items.first : null;
          if (firstItem == null) return;

          if (firstItem.isVideo) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video playback in grid is not supported yet.'),
                duration: Duration(seconds: 2),
              ),
            );
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
      onFormatChanged: (index, format) {
        setState(() {
          _controller.cache.configs[index]?.format = format;
        });
        _controller.recalculateFilteredStatistics();
      },
      onFilterChanged: (index, filter) {
        setState(() {
          _controller.cache.configs[index]?.groupFilter = filter;
        });
        _controller.recalculateFilteredStatistics();
      },
      onStartDownload: (index) {
        _startDownload(index);
        if (_currentGroup == null) {
          setState(() {
            _controller.cache.parsedItems?.removeAt(index);
          });
        }
        _controller.recalculateFilteredStatistics();
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
      videos = _controller.cache.importedListName != null
          ? _lastCustomListVideos
          : _controller.totalListVideos;
      images = _controller.cache.importedListName != null
          ? _lastCustomListImages
          : _controller.totalListImages;
      size = _controller.cache.importedListName != null
          ? _lastCustomListSize
          : _controller.totalListSize;
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
            allowedExtensions: ['json', 'txt'],
          );
          if (saveLocation != null && saveLocation.isNotEmpty) {
            await _controller.exportListToFile(saveLocation.first);
          }
        }
      },
      onDownloadAll: _downloadAll,
    );
  }

  Future<void> _openImageInViewer(MediaInfo item, int index) async {
    final url = item.directUrl ?? item.thumbnail ?? item.originalUrl;
    if (url.isEmpty) return;

    setState(() {
      _downloadingImageIndices.add(index);
    });

    try {
      final ext = url.contains('.png') ? '.png' : '.jpg';
      final cacheDir = Directory(
        p.join(
          Platform.environment['HOME'] ?? '',
          '.cache',
          'onyxcore',
          'viewer_cache',
        ),
      );
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
      }

      final tempFile = File(
        p.join(
          cacheDir.path,
          '${item.id}_${DateTime.now().millisecondsSinceEpoch}$ext',
        ),
      );

      final request = await HttpClient().getUrl(Uri.parse(url));
      final response = await request.close();
      await response.pipe(tempFile.openWrite());

      final fileItem = FileItem(
        name: item.title.isNotEmpty ? item.title : p.basename(tempFile.path),
        path: tempFile.path,
        sizeBytes: tempFile.lengthSync(),
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
        },
      );

      await PersistentViewerManager.openMedia(windowParams);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load image: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingImageIndices.remove(index);
        });
      }
    }
  }
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
