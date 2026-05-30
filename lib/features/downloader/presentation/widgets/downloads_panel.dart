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

enum DownloadMode { normal, mute, audioOnly }
enum GroupDownloadType { all, images, videos }

class DownloadConfig {
  MediaFormat? format;
  Map<String, MediaFormat?> itemFormats;
  DownloadMode mode;
  GroupDownloadType groupFilter;
  DownloadConfig({
    this.format, 
    this.mode = DownloadMode.normal, 
    this.groupFilter = GroupDownloadType.all,
    Map<String, MediaFormat?>? itemFormats,
  }) : itemFormats = itemFormats ?? {};
}

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
    with SingleTickerProviderStateMixin {
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

  MediaGroup? _previewItem;
  int? _previewIndex;
  int _previewCarouselIndex = 0;

  List<MediaInfo> get _visiblePreviewItems {
    if (_previewItem == null) return [];
    final config = _configs[_previewIndex!];
    if (config == null) return _previewItem!.items;
    
    return _previewItem!.items.where((info) {
      if (config.groupFilter == GroupDownloadType.images && info.isVideo) return false;
      if (config.groupFilter == GroupDownloadType.videos && !info.isVideo) return false;
      return true;
    }).toList();
  }

  String _trimMiddle(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    final half = (maxLength - 3) ~/ 2;
    return '${text.substring(0, half)}...${text.substring(text.length - half)}';
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
            (existing) => existing.originalUrl == entry.key
          );
          if (!isDuplicate) {
            _parsedItems!.add(MediaGroup(originalUrl: entry.key, items: groupItems));
          }
        }

        for (int i = 0; i < _parsedItems!.length; i++) {
          if (!_configs.containsKey(i)) {
            final group = _parsedItems![i];
            final info = group.first;
            _configs[i] = DownloadConfig(
              format: info.formats.isNotEmpty ? info.formats.last : null,
              groupFilter: GroupDownloadType.all,
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

    for (final info in group.items) {
      if (singleItemId != null && info.id != singleItemId) continue;
      
      if (config.groupFilter == GroupDownloadType.images && info.isVideo) continue;
      if (config.groupFilter == GroupDownloadType.videos && !info.isVideo) continue;

      final format = config.itemFormats[info.id] ?? config.format;

      String itemDest = dest;
      if (info.isPlaylist || info.isProfile) {
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
        finalTitle = finalTitle.replaceAll(
          RegExp(r' \(\d+\)$'),
          '',
        );
      } else if (info.galleryIndex != null) {
        suffix = ' - ${info.galleryIndex}';
      }

      if (finalTitle.length > 80) {
        finalTitle = finalTitle.substring(0, 80).trim();
      }
      finalTitle = '$finalTitle$suffix';

      if (!info.isPlaylist && !info.isProfile) {
        final safeName = finalTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final dir = Directory(itemDest);
        if (dir.existsSync()) {
          final existingFiles = dir.listSync().whereType<File>().toList();
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
            if (result == null || result.resolution == ConflictResolution.skip) {
              shouldDownload = false;
            } else if (result.resolution == ConflictResolution.rename) {
              int counter = 1;
              while (existingFiles.any(
                (f) =>
                    p.basenameWithoutExtension(f.path) == '$safeName ($counter)',
              )) {
                counter++;
              }
              finalTitle = '$finalTitle ($counter)';
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
            );
      }
    }

    setState(() {
      if (singleItemId != null) {
        group.items.removeWhere((i) => i.id == singleItemId);
        if (group.items.isEmpty) {
          _parsedItems!.removeAt(index);
        }
      } else {
        _parsedItems!.removeAt(index);
      }

      final newConfigs = <int, DownloadConfig>{};
      for (int i = 0; i < _parsedItems!.length; i++) {
        final g = _parsedItems![i];
        final info = g.first;
        final oldFormat = info.formats.isNotEmpty ? info.formats.last : null;
        newConfigs[i] = DownloadConfig(format: oldFormat, groupFilter: GroupDownloadType.all);
      }
      _configs.clear();
      _configs.addAll(newConfigs);
    });
  }

  Future<void> _startDownloadAll() async {
    final itemsToDownload = _selectedIndices.isNotEmpty
        ? _filteredItems.where((e) => _selectedIndices.contains(e.key)).toList()
        : List.of(_filteredItems);
    if (itemsToDownload.isEmpty) return;

    ConflictResolution? globalResolution;
    final Set<String> sessionNames = {};

    // Sort original indices descending so we can remove them safely from _parsedItems
    final indices = itemsToDownload.map((e) => e.key).toList()
      ..sort((a, b) => b.compareTo(a));

    for (final i in indices) {
      if (_parsedItems == null || i >= _parsedItems!.length) continue;

      final group = _parsedItems![i];
      final config = _configs[i]!;

      String dest = _destinationMode == 'current'
          ? ref.read(currentPathProvider)
          : '${Platform.environment['HOME']}/Downloads';

      for (final info in group.items) {
        if (config.groupFilter == GroupDownloadType.images && info.isVideo) continue;
        if (config.groupFilter == GroupDownloadType.videos && !info.isVideo) continue;

        String itemDest = dest;
        if (info.isPlaylist || info.isProfile) {
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

        if (finalTitle.length > 80) {
          finalTitle = finalTitle.substring(0, 80).trim();
        }
        finalTitle = '$finalTitle$suffix';

        if (!info.isPlaylist && !info.isProfile) {
          final safeName = finalTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
          final dir = Directory(itemDest);
          bool exists = false;
          List<File> existingFiles = [];
          if (dir.existsSync()) {
          existingFiles = dir.listSync().whereType<File>().toList();
          exists = existingFiles.any(
            (f) => p.basenameWithoutExtension(f.path) == safeName,
          );
        }

        if (exists || sessionNames.contains(safeName)) {
          ConflictResolution resolution;
          if (globalResolution != null) {
            resolution = globalResolution;
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
              );
        }
      }
    }

    setState(() {
      _removeParsedItems(indices);
    });

    setState(() {
      _sortFilter = 'added_desc';
    });
  }

  void _removeParsedItems(List<int> indicesToRemove) {
    if (_parsedItems == null) return;

    final sortedIndices = List<int>.from(indicesToRemove)
      ..sort((a, b) => b.compareTo(a));
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
          onPointerDown: (_) => _listFocusNode.requestFocus(),
          onPointerSignal: (_) => _listFocusNode.requestFocus(),
          child: MouseRegion(
            onEnter: (_) => _listFocusNode.requestFocus(),
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
                  _buildHeader(),
                  const Divider(color: Colors.white10, height: 1),
                  Expanded(
                    child: !_binariesExist
                        ? _buildMissingBinariesView(context)
                        : Column(
                            children: [
                              _buildInputView(),
                              const Divider(color: Colors.white10, height: 1),
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
                _previewItem!.isSingle ? _buildSinglePreviewOverlay() : _buildGroupPreviewOverlay(),
            ],
          ),
        ),
      ),
    ),
    ),
  );
  }

  Widget _buildEngineDropdown() {
    final options = [
      {
        'key': 'auto',
        'label': 'Auto Select',
        'icon': Icons.auto_awesome_rounded,
        'color': AppColors.violet,
      },
      {
        'key': 'yt-dlp',
        'label': 'yt-dlp',
        'icon': Icons.video_library_rounded,
        'color': Colors.redAccent,
      },
      {
        'key': 'gallery-dl',
        'label': 'gallery-dl',
        'icon': Icons.photo_library_rounded,
        'color': Colors.blueAccent,
      },
    ];

    final selected = options.firstWhere((o) => o['key'] == _selectedEngine);

    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      color: const Color(0xFF2A2A35),
      elevation: 24,
      tooltip: '',
      padding: EdgeInsets.zero,
      onSelected: (val) {
        setState(() => _selectedEngine = val);
      },
      itemBuilder: (context) => options.map((opt) {
        final isSelected = opt['key'] == _selectedEngine;
        return PopupMenuItem<String>(
          value: opt['key'] as String,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withAlpha(15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  opt['icon'] as IconData,
                  size: 16,
                  color: opt['color'] as Color,
                ),
                const SizedBox(width: 8),
                Text(
                  opt['label'] as String,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              selected['icon'] as IconData,
              size: 16,
              color: selected['color'] as Color,
            ),
            const SizedBox(width: 8),
            Text(
              selected['label'] as String,
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSinglePreviewOverlay() {
    final item = _previewItem;
    if (item == null) return const SizedBox.shrink();
    final index = _previewIndex;
    if (index == null) return const SizedBox.shrink();
    final config = _configs[index];
    if (config == null) return const SizedBox.shrink();

    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _previewItem = null;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black.withOpacity(
            0.8,
          ), // Made the background more shaded
          child: Center(
            child: GestureDetector(
              onTap:
                  () {}, // Absorb taps on the dialog itself so it doesn't close
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C35).withOpacity(
                        0.85,
                      ), // Lighter, more visible glassmorphism shade
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.15),
                      ), // Stronger border to help it pop
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header (cross button)
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                            padding: const EdgeInsets.all(12),
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _previewItem = null;
                              });
                            },
                          ),
                        ),
                        // Image area
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 210,
                            ), // Slightly reduced thumbnail size
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                item.first.thumbnail != null
                                    ? Image.network(
                                        item.first.thumbnail!,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) =>
                                            _buildFallbackThumb(),
                                      )
                                    : _buildFallbackThumb(),
                                if (item.isSingle && item.first.isVideo && item.first.duration != null)
                                  Positioned(
                                    bottom: 8,
                                    right: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        _formatDuration(item.first.duration!),
                                        style: GoogleFonts.manrope(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),

                              ],
                            ),
                          ),
                        ),
                        // Details
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.first.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (item.first.extractor != null) ...[
                                    Text(
                                      item.first.extractor!,
                                      style: GoogleFonts.manrope(
                                        color: Colors.white70,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                      ),
                                      child: Text(
                                        '•',
                                        style: TextStyle(
                                          color: Colors.white38,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                  Text(
                                    !item.isSingle 
                                        ? _formatBytes(item.totalFilesize)
                                        : (_getFileSize(item.first, config) ?? 'Unknown size'),
                                    style: GoogleFonts.manrope(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Controls footer
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                          child: Row(
                            children: [
                              if (item.isSingle && item.first.formats.isNotEmpty)
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: SizedBox(
                                      width: 140,
                                      child: _buildFormatDropdown(
                                        item.first,
                                        config,
                                        index,
                                      ),
                                    ),
                                  ),
                                )
                              else if (!item.isSingle)
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: SizedBox(
                                      width: 140,
                                      child: _buildGroupFilterDropdown(config, index),
                                    ),
                                  ),
                                )
                              else
                                const Spacer(),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _removeParsedItems([index]);
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(
                                    color: Colors.white.withOpacity(0.1),
                                  ),
                                  backgroundColor: Colors.white.withOpacity(
                                    0.05,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  fixedSize: const Size.fromHeight(32),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Remove',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  _startDownload(index);
                                  setState(() {
                                    _previewItem = null;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.violet.withOpacity(
                                    0.2,
                                  ),
                                  foregroundColor: AppColors.violet,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  fixedSize: const Size.fromHeight(32),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Download',
                                  style: GoogleFonts.manrope(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupPreviewOverlay() {
    final group = _previewItem;
    if (group == null) return const SizedBox.shrink();
    final groupIndex = _previewIndex;
    if (groupIndex == null) return const SizedBox.shrink();
    final config = _configs[groupIndex];
    if (config == null) return const SizedBox.shrink();
    final visibleItems = _visiblePreviewItems;

    // Safety fallback
    if (visibleItems.isEmpty) {
      return const SizedBox.shrink();
    }
    if (_previewCarouselIndex >= visibleItems.length) {
      _previewCarouselIndex = visibleItems.length - 1;
    }
    if (_previewCarouselIndex < 0) {
      _previewCarouselIndex = 0;
    }

    final currentItem = visibleItems[_previewCarouselIndex];
    final totalSize = visibleItems.fold<int>(0, (sum, i) => sum + (i.filesize ?? 0));

    return Positioned.fill(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _previewItem = null;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          color: Colors.black.withOpacity(0.8),
          child: Center(
            child: GestureDetector(
              onTap: () {}, // Absorb taps
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    width: 650, // Fixed width for better carousel look
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C2C35).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.15)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Row 1: Title and Close Button
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      group.first.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.manrope(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      setState(() {
                                        _previewItem = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              // Row 2: Source • Size
                              Row(
                                children: [
                                  if (group.first.extractor != null) ...[
                                    Text(
                                      group.first.extractor!,
                                      style: GoogleFonts.manrope(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6),
                                      child: Text('•', style: TextStyle(color: Colors.white38, fontSize: 12)),
                                    ),
                                  ],
                                  Text(
                                    _formatBytes(totalSize),
                                    style: GoogleFonts.manrope(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              // Row 3: Dropdown & Download All
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  SizedBox(
                                    width: 140,
                                    child: _buildGroupFilterDropdown(config, groupIndex),
                                  ),
                                  ElevatedButton(
                                    onPressed: () {
                                      _startDownload(groupIndex);
                                      setState(() {
                                        _previewItem = null;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.violet.withOpacity(0.2),
                                      foregroundColor: AppColors.violet,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      fixedSize: const Size.fromHeight(32),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      'Download All',
                                      style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Image Carousel
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              // Prev Button
                              IconButton(
                                icon: Icon(
                                  Icons.arrow_back_ios,
                                  color: _previewCarouselIndex > 0 ? Colors.white : Colors.white24,
                                ),
                                onPressed: _previewCarouselIndex > 0
                                    ? () {
                                        setState(() {
                                          _previewCarouselIndex--;
                                        });
                                      }
                                    : null,
                              ),
                              Expanded(
                                child: SizedBox(
                                  height: 280,
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      currentItem.thumbnail != null
                                          ? Image.network(
                                              currentItem.thumbnail!,
                                              fit: BoxFit.contain,
                                              loadingBuilder: (context, child, loadingProgress) {
                                                if (loadingProgress == null) return child;
                                                return const Center(
                                                  child: _JugglingBallsLoader(),
                                                );
                                              },
                                              errorBuilder: (_, __, ___) => _buildFallbackThumb(),
                                            )
                                          : _buildFallbackThumb(),
                                      if (currentItem.isVideo && currentItem.duration != null)
                                        Positioned(
                                          bottom: 8,
                                          right: 8,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withOpacity(0.7),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _formatDuration(currentItem.duration!),
                                              style: GoogleFonts.manrope(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ),
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.7),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${_previewCarouselIndex + 1} / ${visibleItems.length}',
                                            style: GoogleFonts.manrope(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Next Button
                              IconButton(
                                icon: Icon(
                                  Icons.arrow_forward_ios,
                                  color: _previewCarouselIndex < visibleItems.length - 1 ? Colors.white : Colors.white24,
                                ),
                                onPressed: _previewCarouselIndex < visibleItems.length - 1
                                    ? () {
                                        setState(() {
                                          _previewCarouselIndex++;
                                        });
                                      }
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        // Footer
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _trimMiddle(currentItem.title, 40) + ' (${_getFileSize(currentItem, config) ?? "Unknown size"})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  if (currentItem.formats.isNotEmpty)
                                    SizedBox(
                                      width: 140,
                                      child: _buildFormatDropdown(currentItem, config, groupIndex, isItemLevel: true),
                                    )
                                  else
                                    const Spacer(),
                                  const Spacer(),
                                  OutlinedButton(
                                    onPressed: () {
                                      _removeSingleItem(groupIndex, currentItem.id);
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: BorderSide(color: Colors.white.withOpacity(0.1)),
                                      backgroundColor: Colors.white.withOpacity(0.05),
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      fixedSize: const Size.fromHeight(32),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Text(
                                      'Remove',
                                      style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      _startDownload(groupIndex, singleItemId: currentItem.id);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.violet.withOpacity(0.2),
                                      foregroundColor: AppColors.violet,
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      fixedSize: const Size.fromHeight(32),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    child: Text(
                                      'Download',
                                      style: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCountIndicator(IconData icon, int count, {bool disabled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: disabled ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: disabled ? Colors.white38 : Colors.white, size: 10),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: GoogleFonts.manrope(
              color: disabled ? Colors.white38 : Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupFilterDropdown(DownloadConfig config, int index) {
    String getLabel(GroupDownloadType type) {
      switch (type) {
        case GroupDownloadType.all:
          return 'All';
        case GroupDownloadType.images:
          return 'Images Only';
        case GroupDownloadType.videos:
          return 'Videos Only';
      }
    }

    return PopupMenuButton<GroupDownloadType>(
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      color: const Color(0xFF1E1E1E),
      surfaceTintColor: Colors.transparent,
      elevation: 24,
      tooltip: '',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(maxHeight: 250),
      onSelected: (val) {
        setState(() {
          config.groupFilter = val;
          _previewCarouselIndex = 0;
        });
      },
      itemBuilder: (context) => GroupDownloadType.values.map((f) {
        final isSelected = f == config.groupFilter;
        return PopupMenuItem<GroupDownloadType>(
          value: f,
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withAlpha(15) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              getLabel(f),
              style: GoogleFonts.manrope(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }).toList(),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                getLabel(config.groupFilter),
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDropdown() {
    final options = [
      {
        'key': 'current',
        'label': 'Current Location',
        'icon': Icons.folder_open_rounded,
      },
      {
        'key': 'system',
        'label': 'Downloads Folder',
        'icon': Icons.download_done_rounded,
      },
    ];

    final selected = options.firstWhere((o) => o['key'] == _destinationMode);

    return PopupMenuButton<String>(
      offset: const Offset(0, -90),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      color: const Color(0xFF2A2A35),
      elevation: 24,
      tooltip: '',
      padding: EdgeInsets.zero,
      onSelected: (val) {
        setState(() => _destinationMode = val);
      },
      itemBuilder: (context) => options.map((opt) {
        final isSelected = opt['key'] == _destinationMode;
        return PopupMenuItem<String>(
          value: opt['key'] as String,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withAlpha(15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  opt['icon'] as IconData,
                  size: 16,
                  color: isSelected ? AppColors.violet : Colors.white70,
                ),
                const SizedBox(width: 8),
                Text(
                  opt['label'] as String,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected['icon'] as IconData, size: 16, color: Colors.white54),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                selected['label'] as String,
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.keyboard_arrow_up,
              color: Colors.white54,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_download_outlined,
            size: 64,
            color: Colors.white10,
          ),
          const SizedBox(height: 16),
          Text(
            'No Media to Download',
            style: GoogleFonts.manrope(
              color: Colors.white54,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Paste URLs above and click Fetch',
            style: GoogleFonts.manrope(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: ShaderMask(
              shaderCallback: (bounds) =>
                  AppTheme.primaryGradient.createShader(bounds),
              child: Text(
                'Download Manager',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(downloadsPanelViewProvider.notifier).state =
                  DownloadsPanelView.history;
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: Text(
              'History',
              style: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Close button
          Tooltip(
            message: 'Close Panel',
            waitDuration: const Duration(milliseconds: 500),
            child: InkWell(
              onTap: () {
                ref.read(downloadsPanelOpenProvider.notifier).state = false;
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedBuilder(
            animation: _gradientController,
            builder: (context, child) {
              final isFocused = _urlFocusNode.hasFocus;
              return CustomPaint(
                painter: isFocused
                    ? _GradientBorderPainter(_gradientController.value)
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(12),
                    border: !isFocused
                        ? Border.all(color: Colors.white10)
                        : Border.all(color: Colors.transparent, width: 1.5),
                  ),
                  child: child,
                ),
              );
            },
            child: Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  if (event.logicalKey == LogicalKeyboardKey.enter &&
                      HardwareKeyboard.instance.isControlPressed) {
                    _analyzeUrls();
                    return KeyEventResult.handled;
                  }

                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    if (_parsedItems != null && _parsedItems!.isNotEmpty) {
                      _urlFocusNode.unfocus();
                      _listFocusNode.requestFocus();
                      setState(() {
                        final items = _filteredItems;
                        if (items.isNotEmpty) {
                          _selectedIndices.clear();
                          _lastSelectedIndex = items.first.key;
                          _selectedIndices.add(_lastSelectedIndex);
                        }
                      });
                      if (_lastSelectedIndex != -1)
                        _scrollToIndex(_lastSelectedIndex);
                      return KeyEventResult.handled;
                    }
                  }
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: _urlController,
                focusNode: _urlFocusNode,
                autofocus: true,
                maxLines: 3,
                minLines: 3,
                textInputAction: TextInputAction.newline,
                style: GoogleFonts.firaCode(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText:
                      'https://youtube.com/watch?v=...\nhttps://instagram.com/...',
                  hintStyle: GoogleFonts.firaCode(color: Colors.white24),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _error!,
                style: GoogleFonts.manrope(
                  color: AppColors.error,
                  fontSize: 13,
                ),
              ),
            ),
          Row(
            children: [
              _buildEngineDropdown(),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 32,
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
                    onPressed: _isLoading ? null : _analyzeUrls,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      fixedSize: const Size.fromHeight(32),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            child: _JugglingBallsLoader(),
                          )
                        : Text(
                            'Fetch / Analyse',
                            style: GoogleFonts.manrope(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<MapEntry<int, MediaGroup>> get _filteredItems {
    if (_parsedItems == null) return [];
    var entries = _parsedItems!.asMap().entries.toList();

    // First apply filters
    if (_sortFilter == 'image') {
      entries = entries
          .where((e) => !e.value.first.isVideo && !e.value.first.isPlaylist)
          .toList();
    } else if (_sortFilter == 'video') {
      entries = entries
          .where((e) => e.value.first.isVideo && !e.value.first.isPlaylist)
          .toList();
    }

    // Then apply sorting (added_desc is default, meaning newest at top. Assuming parse order is old -> new, so reverse order)
    if (_sortFilter == 'added_asc') {
      entries.sort((a, b) => a.key.compareTo(b.key));
    } else if (_sortFilter == 'size_asc' || _sortFilter == 'size_desc') {
      entries.sort((a, b) {
        final aSize = a.value.totalFilesize;
        final bSize = b.value.totalFilesize;
        return _sortFilter == 'size_asc'
            ? aSize.compareTo(bSize)
            : bSize.compareTo(aSize);
      });
    } else {
      // added_desc
      entries.sort((a, b) => b.key.compareTo(a.key));
    }

    return entries;
  }

  Widget _buildResultsView() {
    final displayItems = _filteredItems;
    final hasItems = _parsedItems != null && _parsedItems!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 0, 8),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  'Fetched Media',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Spacer(),
              // Filter Dropdown
              IgnorePointer(
                ignoring: !hasItems,
                child: Opacity(
                  opacity: hasItems ? 1.0 : 0.4,
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortFilter,
                        icon: const Icon(
                          Icons.sort_rounded,
                          size: 16,
                          color: Colors.white70,
                        ),
                        dropdownColor: const Color(0xFF1E1E1E),
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 13,
                        ),
                        items:
                            [
                              {
                                'value': 'added_desc',
                                'label': 'Added',
                                'icon': Icons.arrow_upward_rounded,
                              },
                              {
                                'value': 'added_asc',
                                'label': 'Added',
                                'icon': Icons.arrow_downward_rounded,
                              },
                              {
                                'value': 'size_asc',
                                'label': 'Size',
                                'icon': Icons.arrow_upward_rounded,
                              },
                              {
                                'value': 'size_desc',
                                'label': 'Size',
                                'icon': Icons.arrow_downward_rounded,
                              },
                              {
                                'value': 'image',
                                'label': 'Image',
                                'icon': Icons.image_rounded,
                              },
                              {
                                'value': 'video',
                                'label': 'Video',
                                'icon': Icons.videocam_rounded,
                              },
                            ].map((item) {
                              return DropdownMenuItem<String>(
                                value: item['value'] as String,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        item['icon'] as IconData,
                                        size: 14,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(item['label'] as String),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() {
                              _sortFilter = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Clear All Button
              IgnorePointer(
                ignoring: !hasItems,
                child: Opacity(
                  opacity: hasItems ? 1.0 : 0.4,
                  child: SizedBox(
                    height: 32,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          if (_selectedIndices.isNotEmpty) {
                            _removeParsedItems(_selectedIndices.toList());
                          } else {
                            _parsedItems?.clear();
                            _configs.clear();
                            _selectedIndices.clear();
                            _lastSelectedIndex = -1;
                            _previewItem = null;
                          }
                        });
                      },
                      icon: const Icon(Icons.clear_all_rounded, size: 16),
                      label: Text(
                        _selectedIndices.isNotEmpty
                            ? 'Clear ${_selectedIndices.length}'
                            : 'Clear All',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.1),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize
                            .shrinkWrap, // Removes hidden invisible padding
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // List View
        Expanded(
          child: displayItems.isEmpty
              ? _buildEmptyState()
              : CallbackShortcuts(
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.escape): () {
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
                    const SingleActivator(
                      LogicalKeyboardKey.keyA,
                      control: true,
                    ): () {
                      setState(() {
                        final items = _filteredItems;
                        if (items.isNotEmpty) {
                          _selectedIndices.clear();
                          for (var item in items) {
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
                        int currentVisualIndex = items.indexWhere(
                          (e) => e.key == _lastSelectedIndex,
                        );
                        if (currentVisualIndex < items.length - 1) {
                          _lastSelectedIndex =
                              items[currentVisualIndex + 1].key;
                          _anchorIndex = _lastSelectedIndex;
                          _selectedIndices.clear();
                          _selectedIndices.add(_lastSelectedIndex);
                          _scrollToIndex(_lastSelectedIndex);
                        }
                      });
                    },
                    const SingleActivator(
                      LogicalKeyboardKey.arrowDown,
                      shift: true,
                    ): () {
                      setState(() {
                        final items = _filteredItems;
                        if (items.isEmpty) return;
                        if (_anchorIndex == -1)
                          _anchorIndex = _lastSelectedIndex;
                        int currentVisualIndex = items.indexWhere(
                          (e) => e.key == _lastSelectedIndex,
                        );
                        if (currentVisualIndex < items.length - 1) {
                          _lastSelectedIndex =
                              items[currentVisualIndex + 1].key;
                          _updateShiftSelection(items);
                          _scrollToIndex(_lastSelectedIndex);
                        }
                      });
                    },
                    const SingleActivator(LogicalKeyboardKey.arrowUp): () {
                      setState(() {
                        final items = _filteredItems;
                        if (items.isEmpty) return;
                        int currentVisualIndex = items.indexWhere(
                          (e) => e.key == _lastSelectedIndex,
                        );
                        if (currentVisualIndex > 0) {
                          _lastSelectedIndex =
                              items[currentVisualIndex - 1].key;
                          _anchorIndex = _lastSelectedIndex;
                          _selectedIndices.clear();
                          _selectedIndices.add(_lastSelectedIndex);
                          _scrollToIndex(_lastSelectedIndex);
                        } else if (currentVisualIndex == -1 &&
                            items.isNotEmpty) {
                          _lastSelectedIndex = items.last.key;
                          _anchorIndex = _lastSelectedIndex;
                          _selectedIndices.clear();
                          _selectedIndices.add(_lastSelectedIndex);
                          _scrollToIndex(_lastSelectedIndex);
                        }
                      });
                    },
                    const SingleActivator(
                      LogicalKeyboardKey.arrowUp,
                      shift: true,
                    ): () {
                      setState(() {
                        final items = _filteredItems;
                        if (items.isEmpty) return;
                        if (_anchorIndex == -1)
                          _anchorIndex = _lastSelectedIndex;
                        int currentVisualIndex = items.indexWhere(
                          (e) => e.key == _lastSelectedIndex,
                        );
                        if (currentVisualIndex > 0) {
                          _lastSelectedIndex =
                              items[currentVisualIndex - 1].key;
                          _updateShiftSelection(items);
                          _scrollToIndex(_lastSelectedIndex);
                        }
                      });
                    },
                  },
                  child: Focus(
                    focusNode: _listFocusNode,
                    autofocus: false,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      itemCount: displayItems.length,
                      itemBuilder: (context, listIndex) {
                        final entry = displayItems[listIndex];
                        final index = entry.key;
                        final item = entry.value;
                        final key = _itemKeys.putIfAbsent(
                          index,
                          () => GlobalKey(),
                        );

                        Widget tile;
                        if (item.first.isPlaylist || item.first.isProfile) {
                          tile = _buildGroupTile(index, item);
                        } else {
                          tile = _buildMediaTile(index, item);
                        }
                        return Container(key: key, child: tile);
                      },
                    ),
                  ),
                ),
        ),
        // Bottom Block (Controls + Drawer)
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161616),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.05)),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Controls Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: IgnorePointer(
                          ignoring: !hasItems,
                          child: Opacity(
                            opacity: hasItems ? 1.0 : 0.4,
                            child: _buildLocationDropdown(),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 36,
                      width: 100,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _isDownloadsDrawerOpen =
                                    !_isDownloadsDrawerOpen;
                              });
                            },
                            icon: const Icon(
                              Icons.downloading_rounded,
                              color: AppColors.violet,
                              size: 20,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.violet.withOpacity(
                                0.1,
                              ),
                              minimumSize: const Size(36, 36),
                              padding: EdgeInsets.zero,
                            ),
                            tooltip: 'Active Downloads',
                          ),
                          if (!_isDownloadsDrawerOpen)
                            Positioned(
                              top: -18,
                              child: Transform.scale(
                                scaleX: 1.4,
                                scaleY: 0.8,
                                child: const Icon(
                                  Icons.keyboard_arrow_up_rounded,
                                  color: AppColors.violet,
                                  size: 24,
                                ),
                              ),
                            ),
                          if (_isDownloadsDrawerOpen)
                            Positioned(
                              bottom: -18,
                              child: Transform.scale(
                                scaleX: 1.4,
                                scaleY: 0.8,
                                child: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.violet,
                                  size: 24,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: IgnorePointer(
                          ignoring: !hasItems,
                          child: Opacity(
                            opacity: hasItems ? 1.0 : 0.4,
                            child: ElevatedButton.icon(
                              onPressed: _startDownloadAll,
                              icon: const Icon(
                                Icons.download_rounded,
                                size: 16,
                              ),
                              label: Text(
                                _selectedIndices.isNotEmpty
                                    ? 'Download ${_selectedIndices.length}'
                                    : 'Download All',
                                style: GoogleFonts.manrope(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.violet,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                minimumSize: const Size(0, 36),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 2. Drawer Content
              AnimatedSize(
                duration: const Duration(milliseconds: 350),
                curve: Curves.fastOutSlowIn,
                alignment: Alignment.bottomCenter,
                child: !_isDownloadsDrawerOpen
                    ? const SizedBox(width: double.infinity, height: 0)
                    : SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: SizedBox(
                          height: MediaQuery.of(context).size.height * 0.34,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Active Downloads',
                                  style: GoogleFonts.manrope(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Expanded(
                                  child: Consumer(
                                    builder: (context, ref, child) {
                                      final activeTasks = ref.watch(
                                        activeDownloadTaskProvider,
                                      );
                                      if (activeTasks.isEmpty) {
                                        return Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.download_done_rounded,
                                                color: Colors.white24,
                                                size: 32,
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'No active downloads',
                                                style: GoogleFonts.manrope(
                                                  color: Colors.white54,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }

                                      return ListView.builder(
                                        padding: const EdgeInsets.only(top: 8),
                                        itemCount: activeTasks.length,
                                        itemBuilder: (context, index) {
                                          return DownloadTaskTile(
                                            task: activeTasks[index],
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGroupTile(int index, MediaGroup group) {
    final item = group.first;
    final config = _configs[index]!;
    final isPlaylist = item.isPlaylist;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF22222A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                item.thumbnail != null && item.isProfile
                    ? CircleAvatar(
                        radius: 20,
                        backgroundImage: NetworkImage(item.thumbnail!),
                        backgroundColor: AppColors.violet.withOpacity(0.2),
                      )
                    : Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.violet.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isPlaylist
                              ? Icons.playlist_play_rounded
                              : Icons.account_circle_rounded,
                          color: AppColors.violet,
                          size: 24,
                        ),
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.manrope(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPlaylist
                            ? (item.itemCount != null && item.itemCount! > 0
                                  ? '${item.itemCount} Videos'
                                  : 'Playlist')
                            : (item.itemCount != null && item.itemCount! > 0
                                  ? '${item.itemCount} Posts'
                                  : 'Profile'),
                        style: GoogleFonts.manrope(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.download_rounded,
                    color: AppColors.violet,
                    size: 20,
                  ),
                  onPressed: () => _startDownload(index),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: Colors.white38,
                    size: 18,
                  ),
                  onPressed: () {
                    setState(() {
                      _removeParsedItems([index]);
                    });
                  },
                ),
              ],
            ),
            if (item.formats.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Quality:',
                    style: GoogleFonts.manrope(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: _buildFormatDropdown(item, config, index)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMediaTile(int index, MediaGroup group) {
    final item = group.first;
    final config = _configs[index]!;
    final isSelected = _selectedIndices.contains(index);

    return GestureDetector(
      onTap: () {
        _listFocusNode.requestFocus();
        final isCtrl = HardwareKeyboard.instance.isControlPressed;
        final isShift = HardwareKeyboard.instance.isShiftPressed;

        setState(() {
          if (isCtrl) {
            if (isSelected)
              _selectedIndices.remove(index);
            else
              _selectedIndices.add(index);
            _lastSelectedIndex = index;
            _anchorIndex = index;
          } else if (isShift && _anchorIndex != -1) {
            final items = _filteredItems;
            _lastSelectedIndex = index;
            _updateShiftSelection(items);
          } else {
            _selectedIndices.clear();
            _selectedIndices.add(index);
            _lastSelectedIndex = index;
            _anchorIndex = index;
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2D2D38) : const Color(0xFF22222A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.violet.withOpacity(0.5)
                : Colors.white.withOpacity(0.05),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              GestureDetector(
                onTap: () {
                  setState(() {
                    _previewItem = group;
                    _previewIndex = index;
                    _previewCarouselIndex = 0;
                  });
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        item.thumbnail != null
                            ? Image.network(
                                item.thumbnail!,
                                width: 160,
                                height: 104,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildFallbackThumb(),
                              )
                            : _buildFallbackThumb(),
                        if (item.extractor != null)
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.extractor!,
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              !group.isSingle
                                  ? Icons.filter_none_rounded
                                  : (item.isVideo
                                      ? Icons.videocam_rounded
                                      : Icons.image_rounded),
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                        if (group.isSingle && item.isVideo && item.duration != null)
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _formatDuration(item.duration!),
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        if (!group.isSingle)
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Row(
                              children: [
                                if (group.imageCount > 0)
                                  _buildCountIndicator(Icons.image_rounded, group.imageCount, disabled: config.groupFilter == GroupDownloadType.videos),
                                if (group.imageCount > 0 && group.videoCount > 0)
                                  const SizedBox(width: 4),
                                if (group.videoCount > 0)
                                  _buildCountIndicator(Icons.videocam_rounded, group.videoCount, disabled: config.groupFilter == GroupDownloadType.images),
                              ],
                            ),
                          ),
                        if (!group.isSingle || _getFileSize(item, config) != null)
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                !group.isSingle 
                                    ? _formatBytes(_getGroupBytes(group, config))
                                    : _getFileSize(item, config) ?? 'Unknown size',
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Title, Metadata, and Actions
              Expanded(
                child: SizedBox(
                  height: 104,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: GoogleFonts.manrope(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _removeParsedItems([index]);
                                    });
                                  },
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white38,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Builder(
                        builder: (context) {
                          return Align(
                            alignment: Alignment.centerRight,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (group.isSingle && item.formats.isNotEmpty)
                                  SizedBox(
                                    width: 130,
                                    child: _buildFormatDropdown(
                                      item,
                                      config,
                                      index,
                                    ),
                                  )
                                else if (!group.isSingle)
                                  SizedBox(
                                    width: 130,
                                    child: _buildGroupFilterDropdown(config, index),
                                  ),
                                ElevatedButton(
                                  onPressed: () => _startDownload(index),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.violet
                                        .withOpacity(0.2),
                                    foregroundColor: AppColors.violet,
                                    elevation: 0,
                                    fixedSize: const Size.fromHeight(32),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    'Download',
                                    style: GoogleFonts.manrope(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackThumb() {
    return Container(
      width: 160,
      height: 104,
      color: Colors.black26,
      child: const Icon(Icons.broken_image, color: Colors.white24, size: 24),
    );
  }

  Widget _buildModeRadio(
    int index,
    DownloadConfig config,
    DownloadMode mode,
    String label,
  ) {
    final isSelected = config.mode == mode;
    return InkWell(
      onTap: () {
        setState(() => config.mode = mode);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isSelected ? Colors.white : Colors.white38,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.manrope(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormatDropdown(
    MediaInfo item,
    DownloadConfig config,
    int index, {
    bool isItemLevel = false,
  }) {
    var formats = item.formats.toSet().toList();

    formats.sort((a, b) {
      final aAudio =
          a.resolution == 'audio only' || a.resolution.toLowerCase() == 'audio';
      final bAudio =
          b.resolution == 'audio only' || b.resolution.toLowerCase() == 'audio';
      if (aAudio != bAudio) return aAudio ? 1 : -1;
      return _getHeight(b.resolution).compareTo(_getHeight(a.resolution));
    });

    final maxH = formats.fold<int>(0, (max, f) {
      final h = _getHeight(f.resolution);
      return h > max ? h : max;
    });

    if (maxH >= 480) {
      formats = formats.where((f) {
        if (f.resolution == 'audio only' ||
            f.resolution.toLowerCase() == 'audio')
          return true;
        return _getHeight(f.resolution) >= 480;
      }).toList();
    }

    final currentFormat = isItemLevel ? config.itemFormats[item.id] ?? config.format : config.format;

    final hasMultiple = formats.length > 1;
    final displayFormat = formats.contains(currentFormat)
        ? currentFormat
        : (formats.isNotEmpty ? formats.first : null);

    return PopupMenuButton<MediaFormat>(
      enabled: hasMultiple,
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      color: const Color(0xFF1E1E1E),
      surfaceTintColor: Colors.transparent,
      elevation: 24,
      tooltip: '',
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(maxHeight: 250),
      onSelected: (val) {
        setState(() {
          if (isItemLevel) {
            config.itemFormats[item.id] = val;
          } else {
            config.format = val;
          }
        });
      },
      itemBuilder: (context) => formats.map((f) {
        final isSelected = f == currentFormat;
        return PopupMenuItem<MediaFormat>(
          value: f,
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withAlpha(15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_formatResolution(f.resolution)} (${f.extension})',
              style: GoogleFonts.manrope(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }).toList(),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(hasMultiple ? 0.05 : 0.02),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withOpacity(hasMultiple ? 0.1 : 0.05),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                displayFormat != null
                    ? '${_formatResolution(displayFormat.resolution)} (${displayFormat.extension})'
                    : 'Select',
                style: GoogleFonts.manrope(
                  color: hasMultiple ? Colors.white : Colors.white54,
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasMultiple)
              const Icon(
                Icons.keyboard_arrow_down,
                color: Colors.white70,
                size: 14,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingBinariesView(BuildContext context) {
    final updateState = ref.watch(downloaderUpdateProvider);

    ref.listen(downloaderUpdateProvider, (prev, next) {
      if (prev?.isUpdating == true && !next.isUpdating && next.error == null) {
        _checkBinaries();
      }
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 40,
            color: Colors.amber,
          ),
          const SizedBox(height: 12),
          Text(
            'Dependencies Needed',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Requires yt-dlp and gallery-dl binaries.',
            style: GoogleFonts.manrope(
              color: Colors.white70,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          if (updateState.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                'Error: ${updateState.error}',
                style: GoogleFonts.manrope(
                  color: AppColors.error,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          if (updateState.isUpdating) ...[
            LinearProgressIndicator(
              value: updateState.progress,
              backgroundColor: Colors.white10,
              color: AppColors.violet,
            ),
            const SizedBox(height: 8),
            Text(
              '${(updateState.progress * 100).toStringAsFixed(0)}% downloaded',
              style: GoogleFonts.manrope(color: Colors.white54, fontSize: 12),
            ),
          ] else
            ElevatedButton.icon(
              onPressed: () {
                ref.read(downloaderUpdateProvider.notifier).updateBinaries();
              },
              icon: const Icon(Icons.cloud_download, size: 16),
              label: Text(
                'Download',
                style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.violet,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatResolution(String res) {
    if (res.isEmpty) return 'Unknown';
    if (res == 'audio only' || res.toLowerCase() == 'audio')
      return 'Audio Only';

    final parts = res.toLowerCase().split('x');
    if (parts.length == 2) {
      final height = int.tryParse(parts[1]);
      if (height != null) {
        if (height >= 2160) return '4K';
        if (height >= 1440) return '1440p';
        return '${height}p';
      }
    } else {
      final height = int.tryParse(res.replaceAll(RegExp(r'[^0-9]'), ''));
      if (height != null) {
        if (height >= 2160) return '4K';
        if (height >= 1440) return '1440p';
        return '${height}p';
      }
    }
    return res;
  }

  int _getHeight(String res) {
    if (res.isEmpty || res == 'audio only' || res.toLowerCase() == 'audio')
      return 0;
    final parts = res.toLowerCase().split('x');
    if (parts.length == 2) {
      return int.tryParse(parts[1]) ?? 0;
    } else {
      return int.tryParse(res.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    }
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '0:${seconds.toString().padLeft(2, '0')}';
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes < 60) {
      return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
    }
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    return '$hours:${remainingMinutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String? _getFileSize(MediaInfo item, DownloadConfig config) {
    int? bytes;
    final currentFormat = config.itemFormats[item.id] ?? config.format;
    
    if (config.mode == DownloadMode.mute ||
        config.mode == DownloadMode.normal) {
      final formatId = currentFormat?.formatId;
      if (formatId != null) {
        final format = item.formats
            .where((f) => f.formatId == formatId)
            .firstOrNull;
        bytes = format?.filesize;
      }
    } else if (config.mode == DownloadMode.audioOnly) {
      final audioFormat = item.formats
          .where((f) => f.resolution == 'audio only')
          .firstOrNull;
      bytes = audioFormat?.filesize;
    }

    bytes ??= item.filesize;

    if (bytes != null && bytes > 0) {
      return _formatBytes(bytes);
    }
    return null;
  }

  int _getGroupBytes(MediaGroup group, DownloadConfig config) {
    int total = 0;
    for (final item in group.items) {
      if (config.groupFilter == GroupDownloadType.images && item.isVideo) continue;
      if (config.groupFilter == GroupDownloadType.videos && !item.isVideo) continue;
      
      int? bytes;
      final currentFormat = config.itemFormats[item.id] ?? config.format;
      
      if (config.mode == DownloadMode.mute || config.mode == DownloadMode.normal) {
        final formatId = currentFormat?.formatId;
        if (formatId != null) {
          final format = item.formats.where((f) => f.formatId == formatId).firstOrNull;
          bytes = format?.filesize;
        }
      } else if (config.mode == DownloadMode.audioOnly) {
        final audioFormat = item.formats.where((f) => f.resolution == 'audio only').firstOrNull;
        bytes = audioFormat?.filesize;
      }
      
      bytes ??= item.filesize;
      total += bytes ?? 0;
    }
    return total;
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
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
