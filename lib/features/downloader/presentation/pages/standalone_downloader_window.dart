import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_shared_controller.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_task_tile.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/conflict_provider.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:file_selector/file_selector.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/features/settings/presentation/widgets/settings_dialog.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';

import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_shared_dropdowns.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/downloads_panel.dart';
import 'package:onyxcore/features/file_picker/presentation/widgets/custom_file_picker_dialog.dart';

class StandaloneDownloaderWindow extends ConsumerStatefulWidget {
  final int windowId;
  final Map<String, dynamic> initParams;

  const StandaloneDownloaderWindow({
    super.key,
    required this.windowId,
    this.initParams = const {},
  });

  @override
  ConsumerState<StandaloneDownloaderWindow> createState() =>
      _StandaloneDownloaderWindowState();
}

class _StandaloneDownloaderWindowState
    extends ConsumerState<StandaloneDownloaderWindow>
    with SingleTickerProviderStateMixin, DownloadsPanelHelpersMixin {
  late DownloadsSharedController _controller;
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
      showDialog(
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

  @override
  int _getHeight(String res) => getHeightForTesting(res);

  int _getGroupBytes(MediaGroup group, DownloadConfig config) => 0;

  final Set<int> _downloadingImageIndices = {};

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

      // Basic download using HttpClient
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
        initParams: {
          'width': 600,
          'height': 800,
          'is_minimal': true, // Suggest minimal size to the viewer window logic
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

  void _closeCustomList() {
    setState(() {
      if (_lastCustomListPath != null) {
        _controller.cache.invalidateCache(_lastCustomListPath!);
      }
      _lastCustomListPath = null;
      _lastCustomListName = null;
    });
    _controller.cache.switchList('default');
    _controller.recalculateFilteredStatistics();
  }

  Future<void> _exportCustomList(String path) async {
    final items = _controller.cache.parsedItems;
    if (items == null) return;

    final mapList = items.map((e) => e.toMap()).toList();
    final jsonString = jsonEncode(mapList);

    final file = File(path);
    await file.writeAsString(jsonString, flush: true);

    _controller.cache.isListChanged = false;

    // Invalidate cache if it's not the active one
    if (_controller.cache.importedListPath != path) {
      _controller.cache.invalidateCache(path);
    }
  }

  Future<void> _startDownload(int index) async {
    final parsedItems = _controller.cache.parsedItems;
    if (parsedItems == null || index >= parsedItems.length) return;

    try {
      final group = parsedItems[index];
      final config = _controller.cache.configs[index]!;

      final downloadToCurrent =
          ref.read(settingsProvider).value?.downloadToCurrentFolder ?? true;
      String dest = downloadToCurrent
          ? ref.read(currentPathProvider)
          : '${Platform.environment['HOME']}/Downloads';

      final itemsToDownload = List<MediaInfo>.from(group.items);

      if (group.first.isProfile || group.first.isPlaylist) {
        String safeName = group.first.title.replaceAll(
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
          List<File> existingFiles = [];
          if (dir.existsSync()) {
            existingFiles = dir.listSync().whereType<File>().toList();
          }
          bool groupExists = existingFiles.any((f) {
            final base = p.basenameWithoutExtension(f.path);
            return base.startsWith('${safeName}_') || base == safeName;
          });
          if (groupExists) {
            int conflictCounter = 1;
            while (existingFiles.any((f) {
              final base = p.basenameWithoutExtension(f.path);
              return base.startsWith('${safeName} ($conflictCounter)_') ||
                  base == '${safeName} ($conflictCounter)';
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

        int expectedBytes = _getGroupBytes(
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
              isZip: false,
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

      final Map<String, List<File>> dirCache = {};
      int count = 0;
      final Set<String> sessionNames = {};

      for (final info in itemsToDownload) {
        if (count++ % 20 == 0) await Future<void>.delayed(Duration.zero);
        if (config.groupFilter == GroupDownloadType.images && info.isVideo)
          continue;
        if (config.groupFilter == GroupDownloadType.videos && !info.isVideo)
          continue;

        final format = config.itemFormats[info.id] ?? config.format;
        String itemDest = dest;

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
              isPlaylist: false,
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
        onTap: () => _mainFocusNode.requestFocus(),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.borderColor)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input Box
          Expanded(
            child: AnimatedBuilder(
              animation: _gradientController,
              builder: (context, child) {
                final isFocused = _urlFocusNode.hasFocus;
                return CustomPaint(
                  painter: isFocused
                      ? _GradientBorderPainter(_gradientController.value)
                      : null,
                  child: Container(
                    height: 84, // Reduced to accommodate ~2 lines comfortably
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: !isFocused
                          ? Border.all(color: Colors.white10)
                          : Border.all(color: Colors.transparent, width: 1.5),
                    ),
                    child: CallbackShortcuts(
                      bindings: {
                        const SingleActivator(
                          LogicalKeyboardKey.enter,
                          control: true,
                        ): _fetchUrl,
                      },
                      child: TextField(
                        controller: _urlController,
                        focusNode: _urlFocusNode,
                        maxLines: null,
                        expands: true,
                        style: GoogleFonts.firaCode(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'https://youtube.com/watch?v=...\nhttps://instagram.com/...',
                          hintStyle: GoogleFonts.firaCode(
                            color: Colors.white24,
                          ),
                          contentPadding: const EdgeInsets.all(16),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 24),
          // Action Column
          SizedBox(
            height: 84, // Reduced to match input box exactly
            child: IntrinsicWidth(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Fetch Button
                  Container(
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          AppColors.magenta,
                          AppColors.violet,
                          AppColors.indigo,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ElevatedButton(
                      onPressed: _fetchUrl,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Fetch',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Bottom Row (Dropdown + Settings)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      EngineSelectorDropdown(
                        selectedEngine: _controller.selectedEngine,
                        onChanged: (val) {
                          if (val != null)
                            setState(() {
                              _controller.selectedEngine = val;
                            });
                        },
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'Downloader Settings',
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => SettingsDialog.show(
                              context,
                              initialTab: 0,
                              section: 'Download Manager',
                            ),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceBase,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: const Icon(
                                Icons.settings_outlined,
                                size: 18,
                                color: Colors.white70,
                              ),
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
        ],
      ),
    );
  }

  Widget _buildMediaListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Media List',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: 28,
                    child: ElevatedButton.icon(
                      onPressed: () {
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
                      icon: Icon(
                        Icons.delete_outline,
                        size: 14,
                        color: _isTrashView ? Colors.redAccent : Colors.white70,
                      ),
                      label: Text(
                        'Trash',
                        style: GoogleFonts.outfit(
                          color: _isTrashView ? Colors.redAccent : Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTrashView 
                            ? Colors.redAccent.withValues(alpha: 0.15) 
                            : const Color(0xFF262626),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(
                            color: _isTrashView 
                                ? Colors.redAccent.withValues(alpha: 0.3) 
                                : Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),
                  SizedBox(
                    height: 28,
                    child: ElevatedButton.icon(
                  onPressed: () async {
                    final files = await CustomFilePickerDialog.show(
                      context,
                      title: 'IMPORT LIST',
                      allowMultiple: false,
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
                  icon: const Icon(
                    Icons.file_upload_outlined,
                    size: 14,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Import',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 11,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF262626),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                  ),
                  ),
                ),
              ],
            ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 4),
                // Default List Item
                GestureDetector(
                  onTap: () {
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
                  child: _buildListItem(
                    name: 'Default List',
                    isCustom: false,
                    isActive: _controller.cache.importedListName == null && !_isTrashView,
                  ),
                ),

                if (_controller.cache.importedListName != null ||
                    _lastCustomListName != null) ...[
                  GestureDetector(
                    onTap: () async {
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
                    child: _buildListItem(
                      name:
                          _controller.cache.importedListName ??
                          _lastCustomListName!,
                      isCustom: true,
                      isChanged: _controller.cache.isListChanged,
                      isActive: _controller.cache.importedListName != null && !_isTrashView,
                      cachedVideos: _lastCustomListVideos,
                      cachedImages: _lastCustomListImages,
                      cachedSize: _lastCustomListSize,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _restoreTrash() async {
    // Group trashed items by their list path
    final mapByList = <String, List<_TrashItem>>{};
    for (var item in _trash) {
      mapByList.putIfAbsent(item.listPath, () => []).add(item);
    }

    final currentListPath = _controller.cache.importedListPath ?? 'default';

    for (final entry in mapByList.entries) {
      final listPath = entry.key;
      final itemsToRestore = entry.value;

      if (listPath == currentListPath) {
        // Restore to active memory
        setState(() {
          for (var tItem in itemsToRestore) {
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
              final List<dynamic> jsonList = jsonDecode(jsonStr) as List<dynamic>;
              final List<MediaGroup> parsed = jsonList
                  .map((j) => MediaGroup.fromMap(j as Map<String, dynamic>))
                  .toList();

              for (var tItem in itemsToRestore) {
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
      _trash.clear();
    });
  }

  Widget _buildTrashTab() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isTrashView = true;
          _currentGroup = null;
          _selectedIndices.clear();
          _lastSelectedIndex = -1;
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: _isTrashView
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: _isTrashView ? AppColors.violet : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        padding: const EdgeInsets.only(left: 13, right: 16, top: 12, bottom: 12),
        child: Row(
          children: [
            const Icon(Icons.delete_outline, color: Colors.white54, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Trash',
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
              ),
            ),
            if (_trash.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_trash.length}',
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 11),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildListItem({
    required String name,
    required bool isCustom,
    bool isChanged = false,
    bool isActive = false,
    int? cachedVideos,
    int? cachedImages,
    int? cachedSize,
  }) {
    final videos = isActive ? _controller.totalListVideos : (cachedVideos ?? 0);
    final images = isActive ? _controller.totalListImages : (cachedImages ?? 0);
    final size = isActive ? _controller.totalListSize : (cachedSize ?? 0);
    final sizeStr = (size / (1024 * 1024)).toStringAsFixed(2);
    final hasItems = size > 0;

    return Container(
      decoration: BoxDecoration(
        color: isActive
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.transparent,
        border: Border(
          bottom: const BorderSide(color: Colors.white10),
        ),
      ),
      child: Stack(
        children: [
          if (isActive)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.magenta, AppColors.violet],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(left: 13, right: 16, top: 12, bottom: 12),
      child: Row(
        children: [
          isActive
              ? ShaderMask(
                  blendMode: BlendMode.srcIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppColors.magenta, AppColors.violet],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Icon(Icons.list_alt, size: 20, color: Colors.white),
                )
              : const Icon(Icons.list_alt, color: Colors.white54, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: isActive
                ? ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [AppColors.magenta, AppColors.violet],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      name,
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  )
                : Text(
                    name,
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
          ),

          if (isCustom) ...[
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                final path = _lastCustomListPath;
                if (path != null && _controller.cache.isCacheChanged(path)) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1E1E),
                      title: Text(
                        'Unsaved Changes',
                        style: GoogleFonts.outfit(color: Colors.white),
                      ),
                      content: Text(
                        'You have unsaved changes. Are you sure you want to discard them?',
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
                          onPressed: () {
                            Navigator.of(context).pop();
                            _closeCustomList();
                          },
                          child: Text(
                            'Discard',
                            style: GoogleFonts.outfit(color: AppColors.error),
                          ),
                        ),
                        TextButton(
                          style: TextButton.styleFrom(
                            backgroundColor: AppColors.violet,
                          ),
                          onPressed: () async {
                            Navigator.of(context).pop();
                            await _exportCustomList(path);
                            _closeCustomList();
                          },
                          child: Text(
                            'Save',
                            style: GoogleFonts.outfit(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  _closeCustomList();
                }
              },
              icon: const Icon(Icons.close, size: 16, color: Colors.white54),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ],
      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveDownloadsSection() {
    final tasks = ref.watch(downloadTaskProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Active Downloads',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_done_rounded,
                        size: 48,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No active downloads',
                        style: GoogleFonts.outfit(
                          color: Colors.white38,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: tasks.length,
                  padding: EdgeInsets.zero,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: DownloadTaskTile(task: task),
                    );
                  },
                ),
        ),
        if (tasks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  for (final t in tasks) {
                    ref
                        .read(downloadTaskProvider.notifier)
                        .cancelDownload(t.id);
                  }
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Cancel All',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActionBar() {
    if (_isTrashView) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(bottom: BorderSide(color: AppColors.borderColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Trash',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (_trash.isNotEmpty) ...[
              ElevatedButton.icon(
                icon: const Icon(Icons.restore, size: 16),
                label: const Text('Restore All'),
                onPressed: _restoreTrash,
                style: ElevatedButton.styleFrom(
                   backgroundColor: AppColors.violet,
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: const Icon(Icons.delete_forever, size: 16),
                label: const Text('Empty'),
                onPressed: () {
                  setState(() { _trash.clear(); });
                },
                style: ElevatedButton.styleFrom(
                   backgroundColor: AppColors.error,
                   foregroundColor: Colors.white,
                   padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final hasItems = _controller.cache.parsedItems?.isNotEmpty ?? false;

    int? rootIndex;
    DownloadConfig? config;
    if (_currentGroup != null && hasItems) {
      rootIndex = _controller.cache.parsedItems!.indexOf(_currentGroup!);
      if (rootIndex != -1) {
        config = _controller.cache.configs[rootIndex];
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                if (_currentGroup != null) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      setState(() {
                        _currentGroup = null;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _currentGroup = null;
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.0,
                          vertical: 2.0,
                        ),
                        child: Text(
                          _controller.cache.importedListName ?? 'Default List',
                          style: GoogleFonts.outfit(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8.0),
                    child: Icon(Icons.chevron_right, color: Colors.white54),
                  ),
                  Expanded(
                    child: Text(
                      _currentGroup!.first.title.isNotEmpty
                          ? _currentGroup!.first.title
                          : 'Group',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ] else
                  Expanded(
                    child: Text(
                      _controller.cache.importedListName ?? 'Default List',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (hasItems) ...[
            if (_currentGroup != null &&
                config != null &&
                rootIndex != null &&
                rootIndex != -1) ...[
              if (_currentGroup!.first.isPlaylist)
                SizedBox(
                  width: 140,
                  height: 36,
                  child: FormatSelectionDropdown(
                    item: _currentGroup!.first,
                    config: config,
                    index: rootIndex,
                    group: _currentGroup!,
                    getHeight: _getHeight,
                    matchTargetFormat: matchTargetFormat,
                    onChanged: (val) {
                      setState(() {
                        config!.format = val;
                      });
                      _controller.recalculateFilteredStatistics();
                    },
                  ),
                )
              else
                SizedBox(
                  width: 140,
                  height: 36,
                  child: GroupFilterDropdown(
                    selectedFilter: config.groupFilter,
                    isEnabled:
                        _currentGroup!.first.isProfile ||
                        (_currentGroup!.items.any((i) => !i.isVideo) &&
                            _currentGroup!.items.any((i) => i.isVideo)),
                    onChanged: (val) {
                      setState(() {
                        config!.groupFilter = val;
                      });
                      _controller.recalculateFilteredStatistics();
                    },
                  ),
                ),
              const SizedBox(width: 16),
            ],
            SizedBox(
              height: 36,
              child: TextButton(
                onPressed: () {
                  _controller.cache.clear();
                  setState(() {
                    _currentGroup = null;
                  });
                },
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white12,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Clear',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdown(String hint) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Text(
            hint,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_drop_down, color: Colors.white54, size: 16),
        ],
      ),
    );
  }

  Widget _buildMediaGrid() {
    if (_isTrashView) {
      if (_trash.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delete_outline,
                size: 48,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 16),
              const Text(
                'Trash is empty',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        );
      }
    } else {
      final rootGroups = _controller.cache.parsedItems;
      if (rootGroups == null || (rootGroups.isEmpty && _currentGroup == null)) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.inbox,
                size: 48,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 16),
              const Text(
                'List is empty',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        );
      }
    }

    List<MediaGroup> groups;
    if (_isTrashView) {
      groups = _trash.map((t) {
        if (t.item is MediaGroup) {
          return t.item as MediaGroup;
        } else {
          final info = t.item as MediaInfo;
          return MediaGroup(originalUrl: info.originalUrl, items: [info]);
        }
      }).toList();
    } else if (_currentGroup != null) {
      int rootIndex = _controller.cache.parsedItems!.indexOf(_currentGroup!);
      final config = rootIndex != -1
          ? _controller.cache.configs[rootIndex]
          : null;

      var filteredItems = _currentGroup!.items.where((item) {
        if (config?.groupFilter == GroupDownloadType.images && item.isVideo)
          return false;
        if (config?.groupFilter == GroupDownloadType.videos && !item.isVideo)
          return false;
        return true;
      }).toList();

      groups = filteredItems
          .map((e) => MediaGroup(originalUrl: e.originalUrl, items: [e]))
          .toList();
    } else {
      groups = _controller.cache.parsedItems!;
    }

    return GestureDetector(
      onTap: () {
        _mainFocusNode.requestFocus();
        setState(() {
          _selectedIndices.clear();
          _lastSelectedIndex = -1;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AlignedGridView.extent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        padding: const EdgeInsets.all(16),
        itemCount: groups.length,
        itemBuilder: (context, index) {
          final group = groups[index];
          final isHydrating = _controller.backgroundLoadingProfiles.contains(
            group.originalUrl,
          );
          final firstItem = group.items.isNotEmpty ? group.items.first : null;

          DownloadConfig? config;
          if (_currentGroup == null) {
            if (index < _controller.cache.configs.length) {
              config = _controller.cache.configs[index];
            }
          } else {
            int rootIndex = _controller.cache.parsedItems!.indexOf(
              _currentGroup!,
            );
            if (rootIndex != -1 &&
                rootIndex < _controller.cache.configs.length) {
              config = _controller.cache.configs[rootIndex];
            }
          }

          IconData typeIcon = Icons.image_rounded;
          if (group.first.isProfile) {
            typeIcon = Icons.account_circle_rounded;
          } else if (group.first.isPlaylist) {
            typeIcon = Icons.video_library_rounded;
          } else if (group.items.length > 1) {
            typeIcon = Icons.filter_none_rounded;
          } else if (firstItem?.isVideo == true) {
            typeIcon = Icons.videocam_rounded;
          }

          final isSelected = _selectedIndices.contains(index);

          double aspectRatio = 1.0;
          if (firstItem != null) {
            if (firstItem.width != null &&
                firstItem.height != null &&
                firstItem.width! > 0 &&
                firstItem.height! > 0) {
              aspectRatio = firstItem.width! / firstItem.height!;
            } else if (firstItem.isVideo) {
              aspectRatio = 16 / 9;
            }
          }

          Widget itemCard = GestureDetector(
            onTap: () {
              _mainFocusNode.requestFocus();
              final isCtrl = HardwareKeyboard.instance.isControlPressed;
              final isShift = HardwareKeyboard.instance.isShiftPressed;

              setState(() {
                if (isCtrl) {
                  if (_selectedIndices.contains(index)) {
                    _selectedIndices.remove(index);
                  } else {
                    _selectedIndices.add(index);
                  }
                  _lastSelectedIndex = index;
                } else if (isShift && _lastSelectedIndex != -1) {
                  final start = _lastSelectedIndex < index
                      ? _lastSelectedIndex
                      : index;
                  final end = _lastSelectedIndex > index
                      ? _lastSelectedIndex
                      : index;
                  _selectedIndices.clear();
                  for (int i = start; i <= end; i++) {
                    _selectedIndices.add(i);
                  }
                } else {
                  _selectedIndices.clear();
                  _selectedIndices.add(index);
                  _lastSelectedIndex = index;
                }
              });
            },
            onDoubleTap: () {
              if (_currentGroup == null && group.items.length > 1) {
                setState(() {
                  _historyIndex++;
                  if (_historyIndex < _navigationHistory.length) {
                    _navigationHistory.removeRange(
                      _historyIndex,
                      _navigationHistory.length,
                    );
                  }
                  _navigationHistory.add(group);
                  _currentGroup = group;
                  _selectedIndices.clear();
                  _lastSelectedIndex = -1;
                });
              } else if (firstItem != null) {
                if (firstItem.isVideo) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Video playback is still in development.',
                        style: GoogleFonts.outfit(color: Colors.white),
                      ),
                      backgroundColor: const Color(0xFF1E1E1E),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } else {
                  _openImageInViewer(firstItem, index);
                }
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceBase,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? AppColors.violet : AppColors.borderColor,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (firstItem?.thumbnail != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        firstItem!.thumbnail!,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => const Icon(
                          Icons.broken_image,
                          color: Colors.white24,
                        ),
                      ),
                    )
                  else
                    const Center(
                      child: Icon(Icons.image, size: 48, color: Colors.white10),
                    ),

                  if (isHydrating ||
                      firstItem?.id == 'fetch_loading' ||
                      firstItem?.id == 'hydration_loading' ||
                      _downloadingImageIndices.contains(index))
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.54),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: BubbleLoader()),
                    ),

                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(typeIcon, color: Colors.white, size: 14),
                    ),
                  ),

                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Builder(
                        builder: (context) {
                          double sizeInMB = 0;
                          bool hasSize = false;

                          if (group.first.isProfile ||
                              group.first.isPlaylist ||
                              group.items.length > 1) {
                            sizeInMB = group.totalFilesize / (1024 * 1024);
                            hasSize = sizeInMB > 0;
                          } else if (firstItem != null) {
                            if (firstItem.filesize != null &&
                                firstItem.filesize! > 0) {
                              sizeInMB = firstItem.filesize! / (1024 * 1024);
                              hasSize = true;
                            } else if (firstItem.formats.isNotEmpty) {
                              MediaFormat? selectedFormat;
                              if (_currentGroup != null) {
                                selectedFormat =
                                    config?.itemFormats[firstItem.id];
                              } else {
                                selectedFormat = config?.format;
                              }
                              if (selectedFormat == null) {
                                selectedFormat = firstItem.formats
                                    .fold<MediaFormat>(
                                      firstItem.formats.first,
                                      (a, b) =>
                                          (a.filesize ?? 0) > (b.filesize ?? 0)
                                          ? a
                                          : b,
                                    );
                              }
                              if (selectedFormat.filesize != null &&
                                  selectedFormat.filesize! > 0) {
                                sizeInMB =
                                    selectedFormat.filesize! / (1024 * 1024);
                                hasSize = true;
                              }
                            }
                          }

                          if (hasSize) {
                            return Text(
                              '${sizeInMB.toStringAsFixed(2)}MB',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          } else if (firstItem?.isVideo == false &&
                              firstItem?.width != null) {
                            return Text(
                              '${firstItem!.width}x${firstItem.height}',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          } else if (firstItem?.isVideo == true &&
                              firstItem?.duration != null) {
                            return Text(
                              '${firstItem!.duration! ~/ 60}:${(firstItem.duration! % 60).toString().padLeft(2, '0')}',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          } else {
                            return Text(
                              'Unknown',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),

                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                        stops: const [0.0, 0.3, 0.7, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          firstItem?.title ?? group.originalUrl,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (group.items.length > 1) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              if (group.videoCount > 0) ...[
                                Text(
                                  '${group.videoCount}',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.videocam_rounded,
                                  color: Colors.white70,
                                  size: 10,
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  '·',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              if (group.imageCount > 0) ...[
                                Text(
                                  '${group.imageCount}',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.image_rounded,
                                  color: Colors.white70,
                                  size: 10,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(aspectRatio: aspectRatio, child: itemCard),
              const SizedBox(height: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (_isTrashView)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {},
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.restore, size: 14),
                              label: const Text('Restore'),
                              onPressed: () {
                                setState(() {
                                  final item = _trash.removeAt(index);
                                  final listPath = _controller.cache.importedListPath ?? 'default';
                                  if (item.listPath == listPath) {
                                    if (item.parentGroup != null) {
                                      item.parentGroup!.items.add(item.item as MediaInfo);
                                    } else {
                                      _controller.cache.parsedItems!.add(item.item as MediaGroup);
                                      if (item.config != null) {
                                        _controller.cache.configs[_controller.cache.parsedItems!.length - 1] = item.config!;
                                      }
                                    }
                                    _controller.recalculateFilteredStatistics();
                                  }
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.violet,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size.fromHeight(32),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                        )
                      else ...[
                        Expanded(
                          child: GestureDetector(
                            onTap:
                                () {}, // Prevent selection when clicking dropdown area
                            child: Builder(
                              builder: (context) {
                                if (_currentGroup == null &&
                                    (group.first.isProfile ||
                                        group.first.isPlaylist ||
                                        group.items.length > 1)) {
                                  final hasImages = group.items.any(
                                    (i) => !i.isVideo,
                                  );
                                  final hasVideos = group.items.any(
                                    (i) => i.isVideo,
                                  );

                                  return SizedBox(
                                    height: 32,
                                    child: GroupFilterDropdown(
                                      selectedFilter:
                                          config?.groupFilter ??
                                          GroupDownloadType.all,
                                      isEnabled: true,
                                      hasImages: hasImages,
                                      hasVideos: hasVideos,
                                      onChanged: (val) {
                                        setState(() {
                                          if (config != null)
                                            config!.groupFilter = val;
                                        });
                                        _controller
                                            .recalculateFilteredStatistics();
                                      },
                                    ),
                                  );
                                } else {
                                  return SizedBox(
                                    height: 32,
                                    child: FormatSelectionDropdown(
                                      item: firstItem!,
                                      config:
                                          config ??
                                          DownloadConfig(
                                            engine: 'auto',
                                            mode: DownloadMode.normal,
                                            groupFilter: GroupDownloadType.all,
                                          ),
                                      index: index,
                                      group: group,
                                      isItemLevel: _currentGroup != null,
                                      getHeight: _getHeight,
                                      matchTargetFormat: matchTargetFormat,
                                      onChanged: (val) {
                                        setState(() {
                                          if (_currentGroup == null) {
                                            config?.format = val;
                                          } else {
                                            config?.itemFormats[firstItem!.id] =
                                                val;
                                          }
                                        });
                                        _controller
                                            .recalculateFilteredStatistics();
                                      },
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap:
                              () {}, // Prevent selection when clicking download button area
                          child: Container(
                            height: 32,
                            width: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.download_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                _startDownload(index);
                                // Remove from list visually if we are at root level
                                if (_currentGroup == null) {
                                  setState(() {
                                    _controller.cache.parsedItems!.removeAt(
                                      index,
                                    );
                                  });
                                }
                                _controller.recalculateFilteredStatistics();
                              },
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLocationBar() {
    int videos = 0;
    int images = 0;
    int size = 0;

    if (_isTrashView) {
      for (var t in _trash) {
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
      videos = _controller.cache.importedListName != null ? _lastCustomListVideos : _controller.totalListVideos;
      images = _controller.cache.importedListName != null ? _lastCustomListImages : _controller.totalListImages;
      size = _controller.cache.importedListName != null ? _lastCustomListSize : _controller.totalListSize;
    }
    
    final sizeStr = '${(size / 1024 / 1024).toStringAsFixed(1)} MB';
    final statsText = '$videos Videos • $images Images • $sizeStr';

    final bool isCustom = _controller.cache.importedListName != null;
    final bool isChanged = _controller.cache.isListChanged;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white10)),
      ),
      child: Row(
        children: [
          Text(
            'Location : ',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1, // 1/3 of the flex space
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: _currentPath.isEmpty
                        ? Text(
                            'Select a folder',
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          )
                        : ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [
                                AppColors.magenta,
                                AppColors.violet,
                                AppColors.indigo,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Text(
                              _currentPath,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                  ),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: () async {
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
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E1E1E),
                        elevation: 0,
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: Size.zero,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Text(
                        'Change',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2, // 2/3 of the flex space
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    statsText,
                    style: GoogleFonts.outfit(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            height: 36,
            decoration: BoxDecoration(
              gradient: (_isTrashView || (isCustom && !isChanged))
                  ? null
                  : const LinearGradient(
                      colors: [AppColors.magenta, AppColors.violet, AppColors.indigo],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              color: (_isTrashView || (isCustom && !isChanged))
                  ? const Color(0xFF1E1E1E).withValues(alpha: 0.5)
                  : null,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(
                color: (_isTrashView || (isCustom && !isChanged))
                    ? Colors.white.withValues(alpha: 0.02)
                    : Colors.transparent,
              ),
            ),
            child: ElevatedButton.icon(
              onPressed: (_isTrashView || (isCustom && !isChanged)) ? null : () async {
                if (isCustom && isChanged && _controller.cache.importedListPath != null) {
                  await _controller.exportListToFile(_controller.cache.importedListPath!);
                } else {
                  final saveLocation = await CustomFilePickerDialog.show(
                    context,
                    title: 'EXPORT LIST',
                    allowMultiple: false,
                    allowedExtensions: ['json', 'txt'],
                  );
                  if (saveLocation != null && saveLocation.isNotEmpty) {
                    await _controller.exportListToFile(saveLocation.first);
                  }
                }
              },
              icon: Icon(
                Icons.file_download_outlined,
                size: 16,
                color: (_isTrashView || (isCustom && !isChanged)) ? Colors.white30 : Colors.white,
              ),
              label: Text(
                isCustom ? 'Update' : 'Export',
                style: GoogleFonts.outfit(
                  color: (_isTrashView || (isCustom && !isChanged)) ? Colors.white30 : Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),

          const SizedBox(width: 12),
          Container(
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.magenta, AppColors.violet, AppColors.indigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: ElevatedButton(
              onPressed: () {
                _downloadAll();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: Text(
                'Download All',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  final double animation;
  final List<Color> colors;
  final double radius;
  final double strokeWidth;

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

class _TrashItem {
  final dynamic item;
  final String listPath;
  final MediaGroup? parentGroup;
  final DownloadConfig? config;

  _TrashItem({
    required this.item,
    required this.listPath,
    this.parentGroup,
    this.config,
  });
}
