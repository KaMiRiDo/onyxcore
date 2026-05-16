import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/core/utils/app_launcher_utils.dart';

class OpenWithDialog extends StatefulWidget {
  final String filePath;

  const OpenWithDialog({
    required this.filePath,
    super.key,
  });

  static Future<void> show(BuildContext context, String filePath) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) => OpenWithDialog(filePath: filePath),
    );
  }

  @override
  State<OpenWithDialog> createState() => _OpenWithDialogState();
}

class _OpenWithDialogState extends State<OpenWithDialog> {
  double _width = 500;
  double _height = 650;
  bool _isResizing = false;
  bool _isLoading = true;
  String _searchQuery = '';
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  AppInfo? _defaultApp;
  List<AppInfo> _recommendedApps = [];
  List<AppInfo> _otherApps = [];
  AppInfo? _selectedApp;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDimensions();
    _loadApps();
    
    // Maintain persistent focus on search
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && mounted) {
        _searchFocusNode.requestFocus();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<AppInfo> get _visibleApps {
    final List<AppInfo> allAvailable = [
      if (_defaultApp != null) _defaultApp!,
      ..._recommendedApps,
      ..._otherApps,
    ];

    if (_searchQuery.isEmpty) return allAvailable;
    
    final query = _searchQuery.toLowerCase();
    return allAvailable.where((app) => 
      app.name.toLowerCase().contains(query) ||
      app.id.toLowerCase().contains(query)
    ).toList();
  }

  Timer? _repeatTimer;
  LogicalKeyboardKey? _pressedKey;

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      // Ignore if it's the same key (OS repeat) - we use our own timer
      if (_pressedKey == event.logicalKey) return;
      
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
        _pressedKey = key;
        _moveSelection(key);
        
        _repeatTimer?.cancel();
        _repeatTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
          _moveSelection(key);
        });
      } else if (key == LogicalKeyboardKey.enter) {
        _launch();
      }
    } else if (event is KeyUpEvent) {
      if (event.logicalKey == _pressedKey) {
        _repeatTimer?.cancel();
        _pressedKey = null;
      }
    }
  }

  void _moveSelection(LogicalKeyboardKey key) {
    final apps = _visibleApps;
    if (apps.isEmpty) return;

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1).clamp(0, apps.length - 1);
        _selectedApp = apps[_selectedIndex];
      });
      _scrollToSelected();
    } else if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = (_selectedIndex - 1).clamp(0, apps.length - 1);
        _selectedApp = apps[_selectedIndex];
      });
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    if (_scrollController.hasClients) {
      final apps = _visibleApps;
      if (apps.isEmpty) return;

      // Calculate the exact target offset for the current index
      double targetTop = 0;
      for (int i = 0; i < _selectedIndex; i++) {
        targetTop += 62.0; // Tile height
        if (_searchQuery.isEmpty) {
          if (i == 0 && _defaultApp != null) targetTop += 42.0; // Header height
          if (i == (_defaultApp != null ? 1 : 0) && _recommendedApps.isNotEmpty) targetTop += 42.0;
          if (i == (_defaultApp != null ? 1 : 0) + _recommendedApps.length) targetTop += 42.0;
        }
      }

      final viewportHeight = _height - 220;
      // Target the middle of the viewport
      final centerScroll = targetTop - (viewportHeight / 2) + 31.0;

      _scrollController.animateTo(
        centerScroll.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _loadApps({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    if (forceRefresh) {
      await AppLauncherUtils.refresh();
    } else {
      await AppLauncherUtils.init();
    }
    
    final defaultApp = await AppLauncherUtils.getDefaultApp(widget.filePath);
    final recommended = await AppLauncherUtils.getRecommendedApps(widget.filePath);
    
    final recIds = recommended.map((e) => e.id).toSet();
    if (defaultApp != null) recIds.add(defaultApp.id);
    
    final other = AppLauncherUtils.cachedApps.where((app) => !recIds.contains(app.id)).toList();

    if (mounted) {
      setState(() {
        _defaultApp = defaultApp;
        _recommendedApps = recommended;
        _otherApps = other;
        _isLoading = false;
        _selectedApp = defaultApp ?? (recommended.isNotEmpty ? recommended[0] : (other.isNotEmpty ? other[0] : null));
        _selectedIndex = 0;
      });
    }
  }

  Future<void> _loadDimensions() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _width = prefs.getDouble('open_with_dialog_width') ?? 500;
        _height = prefs.getDouble('open_with_dialog_height') ?? 650;
      });
    }
  }

  Future<void> _saveDimensions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('open_with_dialog_width', _width);
    await prefs.setDouble('open_with_dialog_height', _height);
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(), // Captures global keys for the dialog
      onKeyEvent: _handleKeyEvent,
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(color: Colors.black.withOpacity(0.2)),
            ),
          ),
          Center(
            child: Material(
              type: MaterialType.transparency,
              child: SizedBox(
                width: _width,
                height: _height,
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF161616).withOpacity(0.95),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: Colors.white.withOpacity(0.08)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.6),
                                blurRadius: 60,
                                offset: const Offset(0, 30),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildHeader(),
                              Expanded(
                                child: _isLoading 
                                  ? _buildLoadingState()
                                  : _buildContent(),
                              ),
                              _buildFooter(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.resizeDownRight,
                        child: GestureDetector(
                          onPanStart: (_) => setState(() => _isResizing = true),
                          onPanUpdate: (details) {
                            setState(() {
                              _width = (_width + details.delta.dx).clamp(450, 900);
                              _height = (_height + details.delta.dy).clamp(350, 800);
                            });
                          },
                          onPanEnd: (_) {
                            setState(() => _isResizing = false);
                            _saveDimensions();
                          },
                          child: Container(
                            width: 30,
                            height: 30,
                            padding: const EdgeInsets.all(4),
                            child: CustomPaint(
                              painter: _ResizeHandlePainter(
                                color: _isResizing ? Colors.white70 : Colors.white24
                              )
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
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          const Icon(Icons.open_in_new_rounded, color: AppColors.violet, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OPEN WITH',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                Text(
                  widget.filePath.split('/').last,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white38),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const BubbleLoader(),
        const SizedBox(height: 24),
        Text(
          'Scanning for applications...',
          style: GoogleFonts.manrope(
            color: Colors.white.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    final apps = _visibleApps;

    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextField(
              focusNode: _searchFocusNode,
              autofocus: true,
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                  final newApps = _visibleApps;
                  if (newApps.isNotEmpty) {
                    _selectedApp = newApps[0];
                    _selectedIndex = 0;
                  }
                });
                // Ensure we scroll back to top when searching
                if (_scrollController.hasClients) {
                  _scrollController.jumpTo(0);
                }
              },
              style: GoogleFonts.manrope(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search applications...',
                hintStyle: GoogleFonts.manrope(color: Colors.white24, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Colors.white24, size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
        
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];
              final isSelected = _selectedApp?.id == app.id;
              
              // Add section labels if not searching
              Widget? label;
              if (_searchQuery.isEmpty) {
                if (index == 0 && _defaultApp != null) {
                  label = _buildSectionLabel('DEFAULT APPLICATION');
                } else if (index == (_defaultApp != null ? 1 : 0) && _recommendedApps.isNotEmpty) {
                  label = _buildSectionLabel('RECOMMENDED APPLICATIONS');
                } else if (index == (_defaultApp != null ? 1 : 0) + _recommendedApps.length) {
                  label = _buildSectionLabel('ALL APPLICATIONS');
                }
              }

              final tile = _buildAppTile(app, isSelected, index);
              
              if (label != null) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [label, tile],
                );
              }
              return tile;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 12),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          color: AppColors.violet.withOpacity(0.8),
        ),
      ),
    );
  }

  Widget _buildAppTile(AppInfo app, bool isSelected, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () => setState(() {
          _selectedApp = app;
          _selectedIndex = index;
        }),
        onDoubleTap: () {
          setState(() {
            _selectedApp = app;
            _selectedIndex = index;
          });
          _launch();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _buildAppIcon(app),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.name,
                      style: GoogleFonts.manrope(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                    Text(
                      app.id,
                      style: GoogleFonts.manrope(
                        color: Colors.white.withOpacity(0.3),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: AppColors.violet, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: _isLoading ? null : () => _loadApps(forceRefresh: true),
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(
              'REFRESH',
              style: GoogleFonts.manrope(fontWeight: FontWeight.w800, fontSize: 12),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white38,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'CANCEL',
              style: GoogleFonts.manrope(
                color: Colors.white.withOpacity(0.5),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _selectedApp != null ? _launch : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.violet,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ).copyWith(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.disabled)) return Colors.white10;
                return AppColors.violet;
              }),
            ),
            child: Text(
              'OPEN',
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppIcon(AppInfo app) {
    if (app.icon != null && app.icon!.startsWith('/')) {
      final path = app.icon!;
      if (path.endsWith('.svg')) {
        return SvgPicture.file(
          File(path),
          width: 24,
          height: 24,
          placeholderBuilder: (_) => const Icon(Icons.apps_rounded, color: Colors.white38, size: 20),
        );
      } else {
        return Image.file(
          File(path),
          width: 24,
          height: 24,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const Icon(Icons.apps_rounded, color: Colors.white38, size: 20),
        );
      }
    }
    return const Icon(Icons.apps_rounded, color: Colors.white38, size: 20);
  }

  void _launch() {
    if (_selectedApp != null) {
      AppLauncherUtils.launchApp(_selectedApp!, widget.filePath);
      Navigator.pop(context);
    }
  }
}

class _ResizeHandlePainter extends CustomPainter {
  final Color color;
  _ResizeHandlePainter({this.color = Colors.white24});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(size.width * 0.7, size.height * 0.9), Offset(size.width * 0.9, size.height * 0.7), paint);
    canvas.drawLine(Offset(size.width * 0.4, size.height * 0.9), Offset(size.width * 0.9, size.height * 0.4), paint);
    canvas.drawLine(Offset(size.width * 0.1, size.height * 0.9), Offset(size.width * 0.9, size.height * 0.1), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
