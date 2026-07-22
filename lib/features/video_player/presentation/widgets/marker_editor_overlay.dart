import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/features/file_picker/presentation/widgets/custom_file_picker_dialog.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/emoji_data.dart';

class CustomEmojiSet {
  CustomEmojiSet({required this.rawData, required this.parsedMap});

  factory CustomEmojiSet.fromJson(Map<String, dynamic> json) => CustomEmojiSet(
    rawData: json['rawData'] as String,
    parsedMap: Map<String, String>.from(json['parsedMap'] as Map),
  );
  final String rawData;
  final Map<String, String> parsedMap;

  Map<String, dynamic> toJson() => {'rawData': rawData, 'parsedMap': parsedMap};
}

class CustomIconSet {
  CustomIconSet({required this.imageBytes, required this.tags});

  factory CustomIconSet.fromJson(Map<String, dynamic> json) => CustomIconSet(
    imageBytes: base64Decode(json['imageBytes'] as String),
    tags: json['tags'] as String,
  );
  final Uint8List imageBytes;
  final String tags;

  Map<String, dynamic> toJson() => {
    'imageBytes': base64Encode(imageBytes),
    'tags': tags,
  };
}

class IconUploadItem {
  IconUploadItem({
    required this.tagController,
    this.rawFilePath,
    this.originalBytes,
    this.processedBytes,
    this.isProcessing = false,
    this.error,
  });
  String? rawFilePath;
  Uint8List? originalBytes;
  Uint8List? processedBytes;
  bool isProcessing;
  String? error;
  TextEditingController tagController;
}

Future<Uint8List?> _processAndResizeImage(Uint8List bytes) async {
  return compute((Uint8List data) {
    try {
      final original = img.decodeImage(data);
      if (original == null) return null;

      final int size = min(original.width, original.height);
      final x = (original.width - size) ~/ 2;
      final y = (original.height - size) ~/ 2;
      final cropped = img.copyCrop(
        original,
        x: x,
        y: y,
        width: size,
        height: size,
      );

      final resized = img.copyResize(
        cropped,
        width: 96,
        height: 96,
        interpolation: img.Interpolation.linear,
      );

      return Uint8List.fromList(img.encodePng(resized));
    } catch (e) {
      return null;
    }
  }, bytes);
}

class MarkerEditorOverlay extends ConsumerStatefulWidget {
  const MarkerEditorOverlay({
    required this.timestamp,
    required this.onSave,
    required this.onCancel,
    this.initialContent,
    this.initialIcon,
    this.notchOffset = 210.0,
    super.key,
  });
  final String? initialContent;
  final String? initialIcon;
  final Duration timestamp;
  final void Function(String, String) onSave;
  final VoidCallback onCancel;
  final double notchOffset;

  @override
  ConsumerState<MarkerEditorOverlay> createState() =>
      MarkerEditorOverlayState();
}

class MarkerEditorOverlayState extends ConsumerState<MarkerEditorOverlay>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  late final FocusNode _textFieldFocusNode;

  String _searchQuery = '';
  final List<String> _recentlyUsed = ['📍'];
  String? _selectedIcon;
  bool _isExpanded = false;
  int _activeTabIndex = 0; // 0: EMOJIS, 1: ICONS

  // Icon Cache for Recents
  final Map<String, Uint8List> _base64Cache = {};

  // Icon Upload State
  bool _isAddingIcon = false;
  final List<IconUploadItem> _iconUploads = [];
  String? _editorError;
  List<CustomIconSet> _customIcons = [];

  // Custom Sets State
  List<CustomEmojiSet> _customSets = [];
  bool _isCreatingCustom = false;
  int? _editingCustomIndex;
  late TextEditingController _customDataController;
  late FocusNode _customFocusNode;
  late ScrollController _sidebarScrollController;
  ScrollController? _gridScrollController;
  ScrollController? _recentScrollController;
  static const int _maxRecents = 20;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _controller.addListener(() => setState(() {}));

    _selectedIcon = widget.initialIcon ?? '📍';

    _customDataController = TextEditingController();
    _customFocusNode = FocusNode();
    _sidebarScrollController = ScrollController();
    _gridScrollController = ScrollController();
    _recentScrollController = ScrollController();
    _loadSettingsFromDrift();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _textFieldFocusNode = FocusNode();
    _iconUploads.add(IconUploadItem(tagController: TextEditingController()));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _textFieldFocusNode.requestFocus();
    });
  }

  bool get isCreatingCustom => _isCreatingCustom;
  bool get isTagFieldFocused => _textFieldFocusNode.hasFocus;

  Future<void> _loadSettingsFromDrift() async {
    try {
      final db = ref.read(databaseProvider);

      // Load custom emoji sets
      final emojiRows = await db.getAllCustomEmojiSets();
      if (emojiRows.isNotEmpty) {
        setState(() {
          _customSets = emojiRows
              .map(
                (r) => CustomEmojiSet(
                  rawData: r.rawData,
                  parsedMap: Map<String, String>.from(
                    jsonDecode(r.definitions) as Map,
                  ),
                ),
              )
              .toList();
        });
      }

      // Load custom icon sets
      final iconRows = await db.getAllCustomIconSets();
      if (iconRows.isNotEmpty) {
        setState(() {
          _customIcons = iconRows
              .map(
                (r) => CustomIconSet(
                  imageBytes: base64Decode(r.imageBytes),
                  tags: r.tags,
                ),
              )
              .toList();
        });
      }

      // Load recents
      final recentValues = await db.getMarkerRecents();
      if (recentValues.isNotEmpty) {
        setState(() {
          _recentlyUsed.clear();
          _recentlyUsed.addAll(recentValues);
          // Ensure Pin is ALWAYS first
          _recentlyUsed.remove('📍');
          _recentlyUsed.insert(0, '📍');
        });
      }
    } catch (e) {
      debugPrint('Error loading marker editor settings from Drift: $e');
    }
  }

  Future<void> _saveSettingsToDrift() async {
    try {
      final db = ref.read(databaseProvider);

      // Save emoji sets
      await db.replaceAllCustomEmojiSets(
        _customSets
            .map(
              (s) => (
                id: s.rawData.hashCode.toString(),
                rawData: s.rawData,
                definitions: jsonEncode(s.parsedMap),
              ),
            )
            .toList(),
      );

      // Save icon sets
      await db.replaceAllCustomIconSets(
        _customIcons
            .asMap()
            .entries
            .map(
              (e) => (
                id: e.key.toString(),
                imageBytes: base64Encode(e.value.imageBytes),
                tags: e.value.tags,
              ),
            )
            .toList(),
      );

      // Save recents (skip the first '📍' pin)
      for (final v in _recentlyUsed.skip(1)) {
        await db.upsertMarkerRecent(v);
      }
      await db.pruneMarkerRecents(_maxRecents);
    } catch (e) {
      debugPrint('Error saving marker editor settings to Drift: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _shakeController.dispose();
    _textFieldFocusNode.dispose();
    _customDataController.dispose();
    _customFocusNode.dispose();
    for (final item in _iconUploads) {
      item.tagController.dispose();
    }
    _sidebarScrollController.dispose();
    _gridScrollController?.dispose();
    _recentScrollController?.dispose();
    super.dispose();
  }

  void shake() {
    _shakeController.forward(from: 0);
  }

  void save() {
    if (_isAddingIcon) {
      if (_iconUploads.any((item) => item.isProcessing)) {
        setState(() => _editorError = 'Please wait for processing to finish');
        return;
      }

      final validItems = _iconUploads
          .where((item) => item.processedBytes != null)
          .toList();
      if (validItems.isEmpty) {
        setState(() => _editorError = 'Please add at least one valid image');
        return;
      }

      setState(() {
        for (final item in validItems) {
          _customIcons.add(
            CustomIconSet(
              imageBytes: item.processedBytes!,
              tags: item.tagController.text.trim(),
            ),
          );
        }
        _isAddingIcon = false;
        _editorError = null;
        _saveSettingsToDrift();
      });
    } else {
      widget.onSave(_controller.text, _selectedIcon ?? '📍');
    }
  }

  void _addIconToRecentlyUsed(String icon) {
    setState(() {
      if (!_recentlyUsed.contains(icon)) {
        if (_recentlyUsed.length >= 20) _recentlyUsed.removeLast();
        // Insert after the fixed Pin icon (index 0)
        _recentlyUsed.insert(1, icon);
      } else if (icon != '📍') {
        // Move to top but after Pin
        _recentlyUsed.remove(icon);
        _recentlyUsed.insert(1, icon);
      }
      _selectedIcon = icon;
      _saveSettingsToDrift();
    });
  }

  void _removeBase64FromRecents(Uint8List targetBytes) {
    _recentlyUsed.removeWhere((item) {
      if (item.startsWith('B64:')) {
        try {
          final bytes = base64Decode(item.substring(4));
          if (listEquals(bytes, targetBytes)) {
            return true;
          }
        } catch (_) {}
      }
      return false;
    });
  }

  void _resetRecentlyUsed() {
    setState(() {
      _recentlyUsed.clear();
      _recentlyUsed.addAll(['📍']);
      _selectedIcon = null;
      _saveSettingsToDrift();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final offset = sin(_shakeAnimation.value * pi * 8) * 6;
        return Transform.translate(offset: Offset(offset, 0), child: child);
      },
      child: GestureDetector(
        onTap: () {},
        onScaleStart: (_) {},
        onScaleUpdate: (_) {},
        onScaleEnd: (_) {},
        behavior: HitTestBehavior.opaque,
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: 420,
                      height: _isExpanded ? 650 : null,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: _isCreatingCustom
                          ? _buildCustomSetForm()
                          : _isAddingIcon
                          ? _buildIconEditorView()
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildExpandButton(),
                                if (_isExpanded)
                                  Expanded(child: _buildMainContent())
                                else
                                  _buildMainContent(),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
              _buildNotch(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isExpanded) ...[
            _buildSearchAndTabs(),
            const SizedBox(height: 12),
            Expanded(child: _buildExpandedGrid()),
            const SizedBox(height: 10),
          ],
          _buildRecentSection(),
          const SizedBox(height: 10),
          _buildTextAndFooter(),
        ],
      ),
    );
  }

  Widget _buildExpandButton() {
    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 32,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          _isExpanded
              ? Icons.keyboard_arrow_down_rounded
              : Icons.keyboard_arrow_up_rounded,
          color: Colors.white.withValues(alpha: 0.2),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildSearchAndTabs() {
    return Column(
      children: [
        Container(
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                color: Colors.white.withValues(alpha: 0.15),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: GoogleFonts.manrope(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search items .....',
                    hintStyle: GoogleFonts.manrope(color: Colors.white10),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12), // Reduced gap below search box as requested
        Row(children: [_buildTab('EMOJIS', 0), _buildTab('ICONS', 1)]),
      ],
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _activeTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTabIndex = index),
        child: Container(
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected
                    ? AppColors.magenta
                    : Colors.white.withValues(alpha: 0.05),
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              color: isSelected ? Colors.white : Colors.white24,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedGrid() {
    List<String> filteredEmojis;
    if (_searchQuery.isEmpty) {
      filteredEmojis = [];
      for (final cat in EmojiData.categories) {
        filteredEmojis.addAll(cat.emojis);
      }
      for (final set in _customSets) {
        filteredEmojis.addAll(set.parsedMap.keys);
      }
    } else {
      final query = _searchQuery.toLowerCase();
      final allEmojis = <String>{};
      for (final cat in EmojiData.categories) {
        allEmojis.addAll(cat.emojis);
      }
      for (final set in _customSets) {
        allEmojis.addAll(set.parsedMap.keys);
      }

      filteredEmojis = allEmojis.where((e) {
        if (e.contains(query)) return true;
        final k = EmojiData.keywords[e]?.toLowerCase() ?? '';
        if (k.contains(query)) return true;
        return false;
      }).toList();
    }

    final mainContent = _activeTabIndex == 1
        ? _customIcons.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.category_outlined,
                        color: Colors.white.withValues(alpha: 0.05),
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'NO ICONS ADDED YET',
                        style: GoogleFonts.manrope(
                          color: Colors.white10,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : ScrollConfiguration(
                  behavior: ScrollConfiguration.of(
                    context,
                  ).copyWith(scrollbars: false),
                  child: RawScrollbar(
                    controller:
                        _gridScrollController ??
                        (_gridScrollController = ScrollController()),
                    thumbVisibility: true,
                    thumbColor: AppColors.magenta.withValues(alpha: 0.5),
                    thickness: 5,
                    radius: const Radius.circular(2.5),
                    padding: const EdgeInsets.only(
                      bottom: 52,
                      top: 4,
                      right: 2,
                    ),
                    child: GridView.builder(
                      controller: _gridScrollController,
                      padding: const EdgeInsets.only(
                        right: 8,
                        bottom: 56,
                        top: 4,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                          ),
                      itemCount: _customIcons.length,
                      itemBuilder: (context, index) {
                        return _buildCustomIconItem(_customIcons[index]);
                      },
                    ),
                  ),
                )
        : ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(scrollbars: false),
            child: RawScrollbar(
              controller:
                  _gridScrollController ??
                  (_gridScrollController = ScrollController()),
              thumbVisibility: true,
              thumbColor: AppColors.magenta.withValues(alpha: 0.5),
              thickness: 5,
              radius: const Radius.circular(2.5),
              padding: const EdgeInsets.only(
                bottom: 52,
                top: 4,
                right: 2,
              ), // Shortens ONLY the scrollbar track
              child: GridView.builder(
                controller: _gridScrollController,
                padding: const EdgeInsets.only(
                  right: 8,
                  bottom: 56,
                  top: 4,
                ), // Emojis scroll full height but don't permanently hide
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: filteredEmojis.length,
                itemBuilder: (context, index) {
                  return _buildEmojiItem(filteredEmojis[index]);
                },
              ),
            ),
          );

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          mainContent, // Full height container restored
          Positioned(bottom: 0, right: 0, child: _buildGridAddButton()),
        ],
      ),
    );
  }

  Widget _buildGridAddButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_activeTabIndex == 0) {
            _isCreatingCustom = true;
            _editingCustomIndex = null;
            _customDataController.clear();
            _editorError = null;
          } else {
            _isAddingIcon = true;
            _editorError = null;
            _iconUploads.clear();
            _iconUploads.add(
              IconUploadItem(tagController: TextEditingController()),
            );
          }
        });
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A), // Solid dark color, no transparency
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(-2, -2),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 24),
      ),
    );
  }

  Future<void> _pickIconFiles(int index) async {
    try {
      final result = await CustomFilePickerDialog.show(
        context,
        title: 'SELECT ICONS',
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        allowMultiple: true,
      );

      if (result != null && result.isNotEmpty) {
        setState(() {
          if (_iconUploads[index].rawFilePath == null &&
              _iconUploads[index].originalBytes == null) {
            _iconUploads.removeAt(index);
          }

          for (final path in result) {
            final item = IconUploadItem(
              rawFilePath: path,
              isProcessing: true,
              tagController: TextEditingController(),
            );
            _iconUploads.insert(index, item);
            index++;
            _processIcon(item);
          }

          if (_iconUploads.isEmpty || _iconUploads.last.rawFilePath != null) {
            _iconUploads.add(
              IconUploadItem(tagController: TextEditingController()),
            );
          }
        });
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
    }
  }

  Future<void> _processIcon(IconUploadItem item) async {
    try {
      final bytes = await File(item.rawFilePath!).readAsBytes();
      setState(() => item.originalBytes = bytes);

      final processed = await _processAndResizeImage(bytes);

      if (mounted) {
        setState(() {
          item.isProcessing = false;
          if (processed != null) {
            item.processedBytes = processed;
          } else {
            item.error = 'Failed to process image';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          item.isProcessing = false;
          item.error = 'Corrupted file';
        });
      }
    }
  }

  Widget _buildIconEditorView() {
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ADD CUSTOM ICONS',
                  style: GoogleFonts.manrope(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isAddingIcon = false;
                      _editorError = null;
                      _iconUploads.clear();
                      _iconUploads.add(
                        IconUploadItem(tagController: TextEditingController()),
                      );
                    });
                  },
                  child: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.5),
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _iconUploads.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _iconUploads[index];
                return Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        if (item.rawFilePath == null && !item.isProcessing) {
                          _pickIconFiles(index);
                        }
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: item.error != null
                                ? Colors.redAccent
                                : Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _buildUploadBoxContent(item),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      ':',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.2),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: TextField(
                          controller: item.tagController,
                          style: GoogleFonts.manrope(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'space separated search tags...',
                            hintStyle: GoogleFonts.manrope(
                              color: Colors.white10,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    if (item.rawFilePath != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _iconUploads.removeAt(index);
                              if (_iconUploads.isEmpty) {
                                _iconUploads.add(
                                  IconUploadItem(
                                    tagController: TextEditingController(),
                                  ),
                                );
                              }
                            });
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.redAccent,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (_editorError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8, right: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  _editorError!,
                  style: GoogleFonts.manrope(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16).copyWith(top: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isAddingIcon = false;
                      _editorError = null;
                      _iconUploads.clear();
                      _iconUploads.add(
                        IconUploadItem(tagController: TextEditingController()),
                      );
                    });
                  },
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.manrope(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.magenta, AppColors.violet],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton(
                    onPressed: save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'SAVE',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadBoxContent(IconUploadItem item) {
    if (item.error != null) {
      return const Icon(
        Icons.error_outline_rounded,
        color: Colors.redAccent,
        size: 24,
      );
    }
    if (item.isProcessing) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (item.originalBytes != null)
            Opacity(
              opacity: 0.3,
              child: Image.memory(item.originalBytes!, fit: BoxFit.cover),
            ),
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.magenta,
              ),
            ),
          ),
        ],
      );
    }
    if (item.processedBytes != null) {
      return Image.memory(item.processedBytes!, fit: BoxFit.cover);
    }
    return const Icon(Icons.add, color: Colors.white54, size: 24);
  }

  Widget _buildEmojiItem(String emoji) {
    final isCustom = _customSets.any((set) => set.parsedMap.containsKey(emoji));

    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            if (_controller.text.characters.length < 50) {
              _addIconToRecentlyUsed(emoji);
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            alignment: Alignment.center,
            child: Text(emoji, style: const TextStyle(fontSize: 24)),
          ),
        ),
        if (isCustom)
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  for (final set in _customSets) {
                    if (set.parsedMap.containsKey(emoji)) {
                      set.parsedMap.remove(emoji);
                    }
                  }
                  _customSets.removeWhere((set) => set.parsedMap.isEmpty);
                  _recentlyUsed.removeWhere((item) => item == emoji);
                  _saveSettingsToDrift();
                  if (_selectedIcon == emoji) {
                    _selectedIcon = null;
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white70, size: 10),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCustomIconItem(CustomIconSet icon) {
    // Generate a unique identifier for the recent list based on hash or Base64 (we can just use '🖼️' for now or the first tag)
    // Actually we need to support saving CustomIconSets to recent list...
    // For now, let's just make it selectable.
    return Stack(
      children: [
        GestureDetector(
          onTap: () {
            final base64Icon = 'B64:${base64Encode(icon.imageBytes)}';
            _addIconToRecentlyUsed(base64Icon);
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(4),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(
                icon.imageBytes,
                width: 24,
                height: 24,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: () {
              setState(() {
                final base64String = 'B64:${base64Encode(icon.imageBytes)}';
                _customIcons.remove(icon);
                _removeBase64FromRecents(icon.imageBytes);
                _recentlyUsed.removeWhere(
                  (item) => item == base64String,
                ); // Fallback exact match
                _saveSettingsToDrift();
                if (_selectedIcon != null &&
                    _selectedIcon!.startsWith('B64:')) {
                  try {
                    final selectedBytes = base64Decode(
                      _selectedIcon!.substring(4),
                    );
                    if (listEquals(selectedBytes, icon.imageBytes)) {
                      _selectedIcon = null;
                    }
                  } catch (_) {}
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white70, size: 10),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RECENT TAG ICONS',
              style: GoogleFonts.manrope(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
            IconButton(
              onPressed: _resetRecentlyUsed,
              icon: Icon(
                Icons.refresh_rounded,
                color: Colors.white.withValues(alpha: 0.3),
                size: 18,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 20,
              tooltip: 'RESET',
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: 78,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Theme(
            data: ThemeData(
              scrollbarTheme: ScrollbarThemeData(
                thumbColor: WidgetStateProperty.all(
                  AppColors.magenta.withValues(alpha: 0.3),
                ),
                thickness: WidgetStateProperty.all(2), // Sleeker thickness
                radius: const Radius.circular(1),
                mainAxisMargin: 8,
                crossAxisMargin: 1, // Closer to edge
              ),
            ),
            child: Scrollbar(
              controller:
                  _recentScrollController ??
                  (_recentScrollController = ScrollController()),
              thumbVisibility: true,
              child: SingleChildScrollView(
                controller: _recentScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: _recentlyUsed
                      .where((item) {
                        if (item == '📍') return true;
                        if (item.startsWith('B64:')) {
                          try {
                            final itemBytes = base64Decode(item.substring(4));
                            return _customIcons.any(
                              (custom) =>
                                  listEquals(custom.imageBytes, itemBytes),
                            );
                          } catch (_) {
                            return false;
                          }
                        }
                        final isBuiltIn = EmojiData.categories.any(
                          (cat) => cat.emojis.contains(item),
                        );
                        if (isBuiltIn) return true;
                        final isCustom = _customSets.any(
                          (set) => set.parsedMap.containsKey(item),
                        );
                        return isCustom;
                      })
                      .map(_buildRecentItem)
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentItem(String icon) {
    final isSelected = _selectedIcon == icon;
    final isBase64 = icon.startsWith('B64:');

    return GestureDetector(
      onTap: () => setState(() => _selectedIcon = icon),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        width: 48,
        height: 56, // 48px box + 8px tail
        child: CustomPaint(
          painter: isSelected
              ? BubbleTailPainter(color: const Color(0xFF3B2F4C))
              : null, // Dark violet tint
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(
                bottom: 8,
              ), // Vertically center the emoji inside the 48px square
              child: isBase64
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.memory(
                        _base64Cache.putIfAbsent(
                          icon,
                          () => base64Decode(icon.substring(4)),
                        ),
                        width: 24,
                        height: 24,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    )
                  : Text(icon, style: const TextStyle(fontSize: 24)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextAndFooter() {
    return Column(
      children: [
        Container(
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            gradient: LinearGradient(
              colors: [
                AppColors.magenta.withValues(alpha: 0.3),
                AppColors.violet.withValues(alpha: 0.3),
              ],
            ),
          ),
          padding: const EdgeInsets.all(1),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E26),
              borderRadius: BorderRadius.circular(13),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: TextField(
              controller: _controller,
              focusNode: _textFieldFocusNode,
              maxLines: null,
              maxLength: 50,
              style: GoogleFonts.manrope(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Tell us about the scene.......',
                hintStyle: GoogleFonts.manrope(color: Colors.white10),
                counterText: '',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${_controller.text.characters.length}/50',
              style: GoogleFonts.manrope(
                color: Colors.white10,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Row(
              children: [
                if (_editorError != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Text(
                      _editorError!,
                      style: GoogleFonts.manrope(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(
                    'CANCEL',
                    style: GoogleFonts.manrope(
                      color: Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.magenta, AppColors.violet],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ElevatedButton(
                    onPressed: save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'SAVE',
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotch() {
    return Container(
      width: 420,
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(
          left: (widget.notchOffset - 16).clamp(0.0, 420.0 - 32.0),
        ),
        child: ClipPath(
          clipper: TriangleClipper(),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              width: 32,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
              ),
              child: CustomPaint(
                painter: NotchPainter(color: Colors.transparent),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomSetForm() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _editingCustomIndex != null ? 'EDIT CUSTOM SET' : 'ADD CUSTOM SET',
            style: GoogleFonts.manrope(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              padding: const EdgeInsets.all(12),
              child: Focus(
                onKeyEvent: (node, event) {
                  if (event is KeyDownEvent &&
                      (event.logicalKey == LogicalKeyboardKey.enter ||
                          event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
                    final text = _customDataController.text;
                    final selection = _customDataController.selection;
                    final newText = text.replaceRange(
                      selection.start,
                      selection.end,
                      '\n',
                    );
                    _customDataController.value = TextEditingValue(
                      text: newText,
                      selection: TextSelection.collapsed(
                        offset: selection.start + 1,
                      ),
                    );
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: TextField(
                  controller: _customDataController,
                  focusNode: _customFocusNode,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: GoogleFonts.manrope(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText:
                        "'😀': 'happy, smile, face',\n'🚀': 'launch, space, rocket'",
                    hintStyle: GoogleFonts.manrope(color: Colors.white10),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Stack(
            clipBehavior: Clip.none,
            children: [
              if (_editorError != null)
                Positioned(
                  right: 0,
                  bottom: 52, // Hover just above the buttons
                  child: Text(
                    _editorError!,
                    style: GoogleFonts.manrope(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => setState(() {
                      _isCreatingCustom = false;
                      _editorError = null;
                    }),
                    child: Text(
                      'CANCEL',
                      style: GoogleFonts.manrope(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.magenta, AppColors.violet],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        final map = _parseCustomData(
                          _customDataController.text,
                        );
                        if (map.isEmpty) {
                          setState(
                            () => _editorError =
                                "Invalid format. Use 'emoji': 'tags'",
                          );
                          return;
                        }
                        setState(() {
                          final newSet = CustomEmojiSet(
                            rawData: _customDataController.text,
                            parsedMap: map,
                          );
                          if (_editingCustomIndex != null) {
                            _customSets[_editingCustomIndex!] = newSet;
                          } else {
                            _customSets.add(newSet);
                          }
                          _isCreatingCustom = false;
                          _editorError = null;
                          _saveSettingsToDrift();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'SAVE SET',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Map<String, String> _parseCustomData(String data) {
    final result = <String, String>{};
    final lines = data.split('\n');
    for (final line in lines) {
      try {
        final parts = line.split(':');
        if (parts.length >= 2) {
          final emoji = parts[0].trim().replaceAll("'", '').replaceAll('"', '');
          final keywords = parts
              .sublist(1)
              .join(':')
              .trim()
              .replaceAll("'", '')
              .replaceAll('"', '');
          if (emoji.isNotEmpty) {
            result[emoji] = keywords;
          }
        }
      } catch (_) {}
    }
    return result;
  }
}

class NotchPainter extends CustomPainter {
  NotchPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);

    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawLine(
      const Offset(0, 0),
      Offset(size.width / 2, size.height),
      borderPaint,
    );
    canvas.drawLine(
      Offset(size.width / 2, size.height),
      Offset(size.width, 0),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldDelegate) => false;
}

class BubbleTailPainter extends CustomPainter {
  BubbleTailPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    const radius = 14.0; // Smooth rounded rectangle like Image 2
    const tailWidth = 12.0;
    const tailHeight = 8.0;

    final rectHeight = size.height - tailHeight;

    // Start top-left
    path.moveTo(radius, 0);
    // Top line
    path.lineTo(size.width - radius, 0);
    // Top-right corner
    path.quadraticBezierTo(size.width, 0, size.width, radius);
    // Right line
    path.lineTo(size.width, rectHeight - radius);
    // Bottom-right corner
    path.quadraticBezierTo(
      size.width,
      rectHeight,
      size.width - radius,
      rectHeight,
    );

    // Bottom line with tail
    path.lineTo((size.width + tailWidth) / 2, rectHeight);
    path.lineTo(size.width / 2, size.height); // Tip of tail
    path.lineTo((size.width - tailWidth) / 2, rectHeight);

    // Bottom-left corner
    path.lineTo(radius, rectHeight);
    path.quadraticBezierTo(0, rectHeight, 0, rectHeight - radius);
    // Left line
    path.lineTo(0, radius);
    // Top-left corner
    path.quadraticBezierTo(0, 0, radius, 0);

    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant BubbleTailPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
