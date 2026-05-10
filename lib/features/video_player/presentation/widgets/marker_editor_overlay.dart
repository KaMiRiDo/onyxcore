import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:hive/hive.dart';
import 'emoji_data.dart';

class CustomEmojiSet {
  final String rawData; // The '😀': 'keywords' string
  final Map<String, String> parsedMap;

  CustomEmojiSet({required this.rawData, required this.parsedMap});

  Map<String, dynamic> toJson() => {
        'rawData': rawData,
        'parsedMap': parsedMap,
      };

  factory CustomEmojiSet.fromJson(Map<String, dynamic> json) => CustomEmojiSet(
        rawData: json['rawData'] as String,
        parsedMap: Map<String, String>.from(json['parsedMap'] as Map),
      );
}

class MarkerEditorOverlay extends StatefulWidget {
  final String? initialContent;
  final Duration timestamp;
  final Function(String) onSave;
  final VoidCallback onCancel;
  final double notchOffset; // New parameter for dynamic notch positioning

  const MarkerEditorOverlay({
    this.initialContent,
    required this.timestamp,
    required this.onSave,
    required this.onCancel,
    this.notchOffset = 210.0, // Default to center of 420px box
    super.key,
  });

  @override
  State<MarkerEditorOverlay> createState() => MarkerEditorOverlayState();
}

class MarkerEditorOverlayState extends State<MarkerEditorOverlay> with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final AnimationController _shakeController;
  late final Animation<double> _shakeAnimation;
  late final FocusNode _textFieldFocusNode;
  
  String _searchQuery = '';
  static final List<String> _recentlyUsed = ['🎬', '📍', '🔥', '✂️', '❤️', '✅', '⚠️'];
  
  // Custom Sets State
  List<CustomEmojiSet> _customSets = [];
  bool _isCreatingCustom = false;
  int? _editingCustomIndex;
  late TextEditingController _customDataController;
  late FocusNode _customFocusNode;
  late ScrollController _sidebarScrollController;
  static const String _hiveBoxName = 'custom_emojis';

  int _selectedCategoryIndex = 0; // Default to first real category (Smileys)

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialContent);
    _controller.addListener(() => setState(() {}));
    
    _customDataController = TextEditingController();
    _customFocusNode = FocusNode();
    _sidebarScrollController = ScrollController();
    _loadCustomSetsFromHive();

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _textFieldFocusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _textFieldFocusNode.requestFocus();
    });
  }

  bool get isCreatingCustom => _isCreatingCustom;
  bool get isTagFieldFocused => _textFieldFocusNode.hasFocus;

  Future<void> _loadCustomSetsFromHive() async {
    try {
      final box = await Hive.openBox(_hiveBoxName);
      final List? savedSets = box.get('sets');
      if (savedSets != null) {
        setState(() {
          _customSets = savedSets
              .map((e) => CustomEmojiSet.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading custom emojis: $e');
    }
  }

  Future<void> _saveCustomSetsToHive() async {
    try {
      final box = await Hive.openBox(_hiveBoxName);
      await box.put('sets', _customSets.map((e) => e.toJson()).toList());
    } catch (e) {
      debugPrint('Error saving custom emojis: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _shakeController.dispose();
    _textFieldFocusNode.dispose();
    _customDataController.dispose();
    _customFocusNode.dispose();
    _sidebarScrollController.dispose();
    super.dispose();
  }

  void shake() {
    _shakeController.forward(from: 0.0);
  }

  void save() {
    widget.onSave(_controller.text);
  }

  void _addEmojiToRecentlyUsed(String emoji) {
    if (!_recentlyUsed.contains(emoji)) {
      setState(() {
        _recentlyUsed.insert(0, emoji);
        if (_recentlyUsed.length > 20) { // Increased to 20
          _recentlyUsed.removeLast();
        }
      });
    } else {
      setState(() {
        _recentlyUsed.remove(emoji);
        _recentlyUsed.insert(0, emoji);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> filteredEmojis;
    String categoryTitle;

    if (_searchQuery.isEmpty) {
      if (_selectedCategoryIndex == -1) {
        filteredEmojis = _recentlyUsed;
        categoryTitle = 'RECENTLY USED';
      } else if (_selectedCategoryIndex >= 100) {
        final index = _selectedCategoryIndex - 100;
        if (index < _customSets.length) {
          filteredEmojis = _customSets[index].parsedMap.keys.toList();
          categoryTitle = 'CUSTOM SET ${index + 1}';
        } else {
          filteredEmojis = [];
          categoryTitle = 'EMPTY SET';
        }
      } else {
        filteredEmojis = EmojiData.categories[_selectedCategoryIndex].emojis;
        categoryTitle = EmojiData.categories[_selectedCategoryIndex].title;
      }
    } else {
      // Global search across all categories (including custom)
      final Set<String> allEmojis = {};
      for (final cat in EmojiData.categories) {
        allEmojis.addAll(cat.emojis);
      }
      for (final set in _customSets) {
        allEmojis.addAll(set.parsedMap.keys);
      }
      
      final query = _searchQuery.toLowerCase();
      filteredEmojis = allEmojis.where((e) {
        if (e.contains(query)) return true;
        // Search in standard keywords
        final standardKeywords = EmojiData.keywords[e]?.toLowerCase() ?? '';
        if (standardKeywords.contains(query)) return true;
        
        // Search in custom keywords
        for (final set in _customSets) {
          final customKeywords = set.parsedMap[e]?.toLowerCase() ?? '';
          if (customKeywords.contains(query)) return true;
        }
        
        return false;
      }).toList();
      categoryTitle = 'SEARCH RESULTS (${filteredEmojis.length})';
    }

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        final double offset = sin(_shakeAnimation.value * pi * 8) * 6;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: child,
        );
      },
      child: GestureDetector(
        onTap: () {}, // Block tap from reaching dismissal layer
        behavior: HitTestBehavior.opaque,
        child: Material(
          color: Colors.transparent,
          child: Listener(
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              // Internal scroll handling for recently used/grid is handled by their widgets
            }
          },
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                  child: Container(
                    width: 420,
                    height: 520,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 40,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Sidebar
                        Container(
                          width: 64,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            border: Border(right: BorderSide(color: Colors.white.withOpacity(0.05))),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                child: Theme(
                                  data: Theme.of(context).copyWith(
                                    scrollbarTheme: ScrollbarThemeData(
                                      thickness: MaterialStateProperty.all(3),
                                      radius: const Radius.circular(10),
                                      thumbColor: MaterialStateProperty.all(Colors.white.withOpacity(0.1)),
                                    ),
                                  ),
                                  child: Scrollbar(
                                    controller: _sidebarScrollController,
                                    child: SingleChildScrollView(
                                      controller: _sidebarScrollController,
                                      child: Column(
                                        children: [
                                          const SizedBox(height: 20),
                                          _buildSidebarIcon(-1, Icons.access_time_filled_rounded),
                                          _buildSidebarIcon(0, Icons.emoji_emotions_rounded),
                                          _buildSidebarIcon(1, Icons.pets_rounded),
                                          _buildSidebarIcon(2, Icons.fastfood_rounded),
                                          _buildSidebarIcon(3, Icons.sports_soccer_rounded),
                                          _buildSidebarIcon(4, Icons.directions_car_rounded),
                                          _buildSidebarIcon(5, Icons.back_hand_rounded),
                                          _buildSidebarIcon(6, Icons.flag_rounded),
                                          
                                          // Custom Sets
                                          if (_customSets.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            ...List.generate(_customSets.length, (i) => _buildCustomSidebarIcon(i)),
                                          ],
                                          const SizedBox(height: 20),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              
                              // Add Button at Bottom
                              _buildAddButton(),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),

                        // Main Content
                        Expanded(
                          child: _isCreatingCustom 
                            ? _buildCustomSetForm()
                            : Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Search Bar
                                    Container(
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                                      ),
                                      child: TextField(
                                        onChanged: (v) => setState(() => _searchQuery = v),
                                        style: GoogleFonts.manrope(color: Colors.white, fontSize: 14),
                                        decoration: InputDecoration(
                                          hintText: 'Search emoji...',
                                          hintStyle: GoogleFonts.manrope(color: Colors.white24, fontSize: 14),
                                          prefixIcon: const Icon(Icons.search, size: 20, color: Colors.white24),
                                          border: InputBorder.none,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Top Recently Used Section
                                    if (_selectedCategoryIndex != -1 && _recentlyUsed.isNotEmpty) ...[
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('RECENTLY USED', 
                                            style: GoogleFonts.manrope(
                                              color: Colors.white38, 
                                              fontSize: 10, 
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1.5,
                                            )
                                          ),
                                          GestureDetector(
                                            onTap: () => setState(() => _recentlyUsed.clear()),
                                            child: Text('CLEAR', 
                                              style: GoogleFonts.manrope(
                                                color: Colors.white38, 
                                                fontSize: 10, 
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1.5,
                                              )
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 44,
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Row(
                                            children: _recentlyUsed.map((e) => _buildEmojiItem(e, isRecent: true)).toList(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                    ],

                                    // Categories
                                    Text(categoryTitle, 
                                      style: GoogleFonts.manrope(
                                        color: Colors.white38, 
                                        fontSize: 10, 
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                      )
                                    ),
                                    const SizedBox(height: 12),
                                    Expanded(
                                      child: GridView.builder(
                                        padding: EdgeInsets.zero,
                                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 7,
                                          mainAxisSpacing: 8,
                                          crossAxisSpacing: 8,
                                        ),
                                        itemCount: filteredEmojis.length,
                                        itemBuilder: (context, index) => _buildEmojiItem(filteredEmojis[index]),
                                      ),
                                    ),
                                    
                                    const SizedBox(height: 20),

                                    // Text Input Area
                                    Container(
                                      height: 68,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        gradient: const LinearGradient(
                                          colors: [AppColors.magenta, AppColors.violet],
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(1.5),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E1E26),
                                          borderRadius: BorderRadius.circular(12.5),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: TextField(
                                          controller: _controller,
                                          focusNode: _textFieldFocusNode,
                                          autofocus: true,
                                          maxLength: 20,
                                          style: GoogleFonts.manrope(
                                            color: Colors.white, 
                                            fontSize: 16,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Marker tag...',
                                            hintStyle: GoogleFonts.manrope(color: Colors.white24),
                                            counterText: '',
                                            border: InputBorder.none,
                                          ),
                                          onSubmitted: (_) => widget.onSave(_controller.text),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),

                                    // Footer Actions
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('${_controller.text.characters.length}/20',
                                          style: GoogleFonts.manrope(
                                            color: Colors.white24,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            TextButton(
                                              onPressed: widget.onCancel,
                                              style: TextButton.styleFrom(
                                                foregroundColor: Colors.white38,
                                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                              ),
                                              child: Text('CANCEL', 
                                                style: GoogleFonts.manrope(
                                                  fontSize: 12, 
                                                  fontWeight: FontWeight.w800,
                                                  letterSpacing: 1.2,
                                                )
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Container(
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [AppColors.magenta, AppColors.violet],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius.circular(12),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors.violet.withOpacity(0.3),
                                                    blurRadius: 15,
                                                    offset: const Offset(0, 5),
                                                  ),
                                                ],
                                              ),
                                              child: ElevatedButton(
                                                onPressed: () => widget.onSave(_controller.text),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.transparent,
                                                  foregroundColor: Colors.white,
                                                  shadowColor: Colors.transparent,
                                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                ),
                                                child: Text('SAVE', 
                                                  style: GoogleFonts.manrope(
                                                    fontSize: 13, 
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 1.5,
                                                  )
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
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
              
              // Downward pointing notch - Unified with glassmorphism box
              Container(
                width: 420,
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: (widget.notchOffset - 16).clamp(0.0, 420.0 - 32.0)),
                  child: ClipPath(
                    clipper: TriangleClipper(),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                      child: Container(
                        width: 32,
                        height: 16,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                        ),
                        child: CustomPaint(
                          painter: NotchPainter(color: Colors.transparent), // Only draw borders now
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
  );
}

  Widget _buildSidebarIcon(int index, IconData icon) {
    final isSelected = _selectedCategoryIndex == index && !_isCreatingCustom;
    return GestureDetector(
      onTap: () => setState(() {
        _isCreatingCustom = false;
        _selectedCategoryIndex = index;
      }),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 64,
        height: 54,
        child: Stack(
          children: [
            // Selection Indicator Pill
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              left: isSelected ? 0 : -4,
              top: 12,
              bottom: 12,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: AppColors.magenta,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                ),
              ),
            ),
            
            // Icon with Background Highlight
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: isSelected ? Colors.white : Colors.white24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomSidebarIcon(int index) {
    final displayIndex = 100 + index;
    final isSelected = _selectedCategoryIndex == displayIndex && !_isCreatingCustom;
    
    return GestureDetector(
      onTap: () => setState(() {
        _isCreatingCustom = false;
        _selectedCategoryIndex = displayIndex;
      }),
      onSecondaryTapDown: (details) => _showCustomSetMenu(details.globalPosition, index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 64,
        height: 54,
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              left: isSelected ? 0 : -4,
              top: 12,
              bottom: 12,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: AppColors.magenta,
                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                ),
              ),
            ),
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.folder_open_rounded,
                      size: 22,
                      color: isSelected ? Colors.white : Colors.white24,
                    ),
                    Positioned(
                      top: 10,
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.manrope(
                          color: isSelected ? Colors.white : Colors.white24,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () => setState(() {
        _isCreatingCustom = true;
        _editingCustomIndex = null;
        _customDataController.clear();
      }),
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _isCreatingCustom && _editingCustomIndex == null 
              ? AppColors.magenta.withOpacity(0.2) 
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isCreatingCustom && _editingCustomIndex == null 
                ? AppColors.magenta.withOpacity(0.5) 
                : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Icon(
          Icons.add_rounded,
          size: 24,
          color: _isCreatingCustom && _editingCustomIndex == null ? Colors.white : Colors.white60,
        ),
      ),
    );
  }

  void _showCustomSetMenu(Offset position, int index) {
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      color: const Color(0xFF1A1A1A),
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              setState(() {
                _isCreatingCustom = true;
                _editingCustomIndex = index;
                _customDataController.text = _customSets[index].rawData;
              });
            });
          },
          child: Row(
            children: [
              const Icon(Icons.edit_rounded, size: 18, color: Colors.white70),
              const SizedBox(width: 12),
              Text('Edit Set', style: GoogleFonts.manrope(color: Colors.white70)),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () {
            setState(() {
              _customSets.removeAt(index);
              if (_selectedCategoryIndex == 100 + index) {
                _selectedCategoryIndex = 0;
              }
              _saveCustomSetsToHive();
            });
          },
          child: Row(
            children: [
              const Icon(Icons.delete_rounded, size: 18, color: Colors.redAccent),
              const SizedBox(width: 12),
              Text('Remove', style: GoogleFonts.manrope(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCustomSetForm() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _editingCustomIndex != null ? 'EDIT EMOJI SET' : 'ADD NEW EMOJI SET',
            style: GoogleFonts.manrope(
              color: AppColors.magenta,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: CallbackShortcuts(
                  bindings: {
                    SingleActivator(LogicalKeyboardKey.enter): () {
                      final val = _customDataController.text;
                      final selection = _customDataController.selection;
                      final newText = val.replaceRange(selection.start, selection.end, '\n');
                      _customDataController.value = TextEditingValue(
                        text: newText,
                        selection: TextSelection.collapsed(offset: selection.start + 1),
                      );
                    },
                  },
                  child: TextField(
                    controller: _customDataController,
                    focusNode: _customFocusNode,
                    autofocus: true,
                    maxLines: null,
                    expands: true,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: GoogleFonts.manrope(color: Colors.white70, fontSize: 14, height: 1.6),
                    decoration: InputDecoration(
                      hintText: "'😀': 'smile happy grin face',\n'😗': 'kiss face smiley',",
                      hintStyle: GoogleFonts.manrope(color: Colors.white10, fontSize: 14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildFormButton(
                  'CANCEL',
                  onTap: () => setState(() => _isCreatingCustom = false),
                  isSecondary: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFormButton(
                  'SAVE',
                  onTap: _saveCustomSet,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFormButton(String label, {required VoidCallback onTap, bool isSecondary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSecondary ? Colors.white.withOpacity(0.05) : AppColors.magenta.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSecondary ? Colors.white.withOpacity(0.1) : AppColors.magenta.withOpacity(0.4),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.manrope(
            color: isSecondary ? Colors.white70 : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  void _saveCustomSet() {
    final rawData = _customDataController.text;
    if (rawData.trim().isEmpty) return;

    final parsedMap = _parseCustomData(rawData);
    if (parsedMap.isEmpty) return;

    setState(() {
      if (_editingCustomIndex != null) {
        _customSets[_editingCustomIndex!] = CustomEmojiSet(rawData: rawData, parsedMap: parsedMap);
      } else {
        _customSets.add(CustomEmojiSet(rawData: rawData, parsedMap: parsedMap));
        _selectedCategoryIndex = 100 + _customSets.length - 1;
      }
      _isCreatingCustom = false;
      _saveCustomSetsToHive();
    });
  }

  Map<String, String> _parseCustomData(String data) {
    final Map<String, String> result = {};
    final regExp = RegExp(r"'(.+?)':\s*'(.+?)'");
    final matches = regExp.allMatches(data);
    
    for (final match in matches) {
      final emoji = match.group(1);
      final keywords = match.group(2);
      if (emoji != null && keywords != null) {
        result[emoji] = keywords;
      }
    }
    return result;
  }

  Widget _buildEmojiItem(String emoji, {bool isRecent = false}) {
    return GestureDetector(
      onTap: () {
        final currentText = _controller.text;
        if (currentText.characters.length < 20) {
          final newText = currentText + emoji;
          if (newText.characters.length <= 20) {
            // Use immediate update to prevent lag
            _controller.text = newText;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: _controller.text.length),
            );
            _addEmojiToRecentlyUsed(emoji);
          }
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: isRecent ? 40 : 44,
        height: isRecent ? 40 : 44,
        alignment: Alignment.center,
        child: Text(
          emoji,
          style: TextStyle(fontSize: isRecent ? 24 : 26),
        ),
      ),
    );
  }
}

class NotchPainter extends CustomPainter {
  final Color color;

  NotchPainter({required this.color});

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
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    
    canvas.drawLine(const Offset(0, 0), Offset(size.width / 2, size.height), borderPaint);
    canvas.drawLine(Offset(size.width / 2, size.height), Offset(size.width, 0), borderPaint);
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
