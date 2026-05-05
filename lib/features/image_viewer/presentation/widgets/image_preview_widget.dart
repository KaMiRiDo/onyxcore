import 'dart:io';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/settings/presentation/widgets/settings_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/widgets/viewer_top_bar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';

class ImagePreviewWidget extends ConsumerStatefulWidget {
  const ImagePreviewWidget({
    required this.item, 
    this.windowId,
    this.parentWindowId,
    this.isStandalone = false,
    super.key,
  });

  final FileItem item;
  final String? windowId;
  final String? parentWindowId;
  final bool isStandalone;

  @override
  ConsumerState<ImagePreviewWidget> createState() => _ImagePreviewWidgetState();
}

class _ImagePreviewWidgetState extends ConsumerState<ImagePreviewWidget> with WindowListener {
  bool _isClosing = false;
  String? _metadata;
  bool _isControlsVisible = true;
  bool _isEditing = false;
  Timer? _hideTimer;
  Timer? _zoomTimer;
  final FocusNode _focusNode = FocusNode();
  final TransformationController _transformationController = TransformationController();
  double _currentScale = 1.0;
  bool _showZoomIndicator = false;
  
  // Image Edit State
  double _rotationAngle = 0.0;
  double _brightness = 0.0;

  bool _isGlobalHudVisible = true;
  bool _isWindowDecorated = false; // Track decoration state locally

  @override
  void initState() {
    super.initState();
    _isGlobalHudVisible = ref.read(previewHudVisibleProvider);
    if (widget.windowId != null) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
      // Initialize title bar style for standalone mode
      windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
    _loadMetadata();
    _startHideTimer();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if (scale != _currentScale) {
      setState(() {
        _currentScale = scale;
        _showZoomIndicator = true;
        // Immediately hide top panel if we are zoomed in
        if (_currentScale > 1.0) {
          _isControlsVisible = false;
        }
      });
      _startZoomTimer();
    }
  }

  void _startZoomTimer() {
    _zoomTimer?.cancel();
    _zoomTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _showZoomIndicator = false);
      }
    });
  }

  void _setZoom(double newScale) {
    // Clamp zoom between 1.0x and 10.0x
    final clampedScale = newScale.clamp(1.0, 10.0);
    
    // Calculate center point for centered scaling
    final size = MediaQuery.of(context).size;
    final center = Offset(size.width / 2, size.height / 2);
    
    // Scale from center logic: T(center) * S(scale) * T(-center)
    final Matrix4 newMatrix = Matrix4.identity()
      ..translate(center.dx, center.dy)
      ..scale(clampedScale)
      ..translate(-center.dx, -center.dy);
      
    _transformationController.value = newMatrix;
    _onTransformationChanged();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isEditing) {
        setState(() => _isControlsVisible = false);
      }
    });
  }

  void _onInteraction() {
    // Wake up global HUD if it was manually hidden
    if (widget.windowId == null && !ref.read(previewHudVisibleProvider)) {
      // Immediate update is safe here because listeners handle 'mounted' check
      ref.read(previewHudVisibleProvider.notifier).state = true;
    }

    if (mounted && !_isControlsVisible) {
      setState(() => _isControlsVisible = true);
    }
    _startHideTimer();
  }

  Future<void> _toggleFullscreen() async {
    final isFullScreen = await windowManager.isFullScreen();
    final willBeFullScreen = !isFullScreen;
    
    await windowManager.setFullScreen(willBeFullScreen);
    
    if (willBeFullScreen) {
      await windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    } else {
      await windowManager.setTitleBarStyle(TitleBarStyle.normal);
    }
    
    _onInteraction();
  }

  Future<void> _loadMetadata() async {
    try {
      final isSvg = widget.item.path.toLowerCase().endsWith('.svg');
      if (isSvg) {
        setState(() {
          _metadata = 'Vector Graphic • Scalable';
        });
        return;
      }

      final bytes = await File(widget.item.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      
      if (mounted) {
        final mp = (image.width * image.height / 1000000).toStringAsFixed(1);
        setState(() {
          _metadata = '${image.width}x${image.height} px • $mp MP';
        });
      }
    } catch (e) {
      debugPrint('Error loading image metadata: $e');
    }
  }

  @override
  void dispose() {
    if (widget.windowId != null) {
      windowManager.removeListener(this);
    }
    _hideTimer?.cancel();
    _zoomTimer?.cancel();
    _focusNode.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (_isClosing) return;
    debugPrint('[ImagePreview] Standalone hiding triggered.');
    await windowManager.hide();
  }

  @override
  void didUpdateWidget(ImagePreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path) {
      _loadMetadata();
      if (mounted) {
        _focusNode.requestFocus();
      }
    }
  }

  Future<void> _openInNewWindow() async {
    final windowParams = WindowParams(
      viewerType: ViewerType.image,
      file: widget.item,
    );

    try {
      await PersistentViewerManager.openMedia(windowParams);
      if (mounted) {
        ref.read(previewFileProvider.notifier).state = null;
      }
    } catch (e) {
      debugPrint('Error opening persistent image viewer: $e');
    }
  }

  void _navigateMedia(bool forward) {
    if (widget.windowId != null) {
      // 1. Standalone Mode: Send reverse IPC to Main Window (Window 0)
      final payload = jsonEncode({
        'direction': forward ? 'next' : 'prev',
        'currentPath': widget.item.path,
        'type': 'image',
        'targetWindowId': widget.windowId!,
      });
      WindowController.fromWindowId(widget.parentWindowId ?? '0').invokeMethod('request_navigation', payload);
    } else {
      // 2. Inline Mode: Local Riverpod state update
      final items = ref.read(directoryItemsProvider).value ?? [];
      if (items.isEmpty) return;

      final mediaItems = items.where((i) => i.type == FileItemType.image).toList();
      if (mediaItems.isEmpty) return;

      final currentIndex = mediaItems.indexWhere((i) => i.path == widget.item.path);
      if (currentIndex == -1) return;

      int nextIndex;
      if (forward) {
        nextIndex = (currentIndex + 1) % mediaItems.length;
      } else {
        nextIndex = (currentIndex - 1 + mediaItems.length) % mediaItems.length;
      }

      ref.read(previewFileProvider.notifier).state = mediaItems[nextIndex];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.windowId == null && !widget.isStandalone) {
      ref.listen(previewHudVisibleProvider, (previous, next) {
        if (mounted) {
          setState(() => _isGlobalHudVisible = next);
        }
      });
    }

    // In standalone mode, we ignore the global HUD visibility provider as the window 
    // itself is the dedicated viewer. We only care about the internal control timer.
    final isVisible = _isControlsVisible && (widget.windowId != null || widget.isStandalone || _isGlobalHudVisible);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          final ctrl = HardwareKeyboard.instance.isControlPressed;
          
          if (event.logicalKey == LogicalKeyboardKey.keyF) {
            if (widget.windowId != null) {
              _toggleFullscreen();
              return KeyEventResult.handled;
            }
            // Preview 'F' is now handled by PreviewContainer globally
          }
          
          if (ctrl && event.logicalKey == LogicalKeyboardKey.keyW) {
            if (widget.windowId == null) {
              ref.read(previewFileProvider.notifier).state = null;
              return KeyEventResult.handled;
            }
          }
          
          if (ctrl) {
            if (event.logicalKey == LogicalKeyboardKey.equal || event.logicalKey == LogicalKeyboardKey.add) {
              _setZoom(_currentScale + 0.2);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.minus || event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
              _setZoom(_currentScale - 0.2);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit0) {
              _setZoom(1.0);
              return KeyEventResult.handled;
            }
          }

          if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            _navigateMedia(true);
            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            // Check if Alt is NOT pressed (Alt+Left is Back)
            if (!HardwareKeyboard.instance.isAltPressed) {
              _navigateMedia(false);
              return KeyEventResult.handled;
            }
          }

          // Navigation Back Shortcuts (Preview Mode only)
          if (widget.windowId == null) {
            final isAltPressed = HardwareKeyboard.instance.isAltPressed;
            if (event.logicalKey == LogicalKeyboardKey.backspace || 
                (isAltPressed && event.logicalKey == LogicalKeyboardKey.arrowLeft)) {
              ref.read(previewFileProvider.notifier).state = null;
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MouseRegion(
          onEnter: (_) => _onInteraction(),
          onHover: (_) => _onInteraction(),
          child: Stack(
            children: [
              // Main Image View
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  minScale: 1.0,
                  maxScale: 10.0,
                  onInteractionUpdate: (_) => _onTransformationChanged(),
                  child: GestureDetector(
                    onTap: () {
                      _focusNode.requestFocus();
                      setState(() {
                        _isControlsVisible = !_isControlsVisible;
                        if (_isControlsVisible) _startHideTimer();
                      });
                    },
                    onDoubleTap: widget.windowId == null ? _openInNewWindow : null,
                    child: Center(
                      child: Hero(
                        tag: widget.item.path,
                        child: Transform.rotate(
                          angle: _rotationAngle * 3.14159 / 180,
                          child: ColorFiltered(
                            colorFilter: ColorFilter.matrix([
                              1, 0, 0, 0, _brightness * 255,
                              0, 1, 0, 0, _brightness * 255,
                              0, 0, 1, 0, _brightness * 255,
                              0, 0, 0, 1, 0,
                            ]),
                            child: widget.item.path.toLowerCase().endsWith('.svg')
                                ? SvgPicture.file(
                                    File(widget.item.path),
                                    fit: BoxFit.contain,
                                  )
                                : Image.file(
                                    File(widget.item.path),
                                    fit: BoxFit.contain,
                                    filterQuality: FilterQuality.high,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Top Bar (Standardized)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: isVisible ? 1.0 : 0.0,
                  child: ViewerTopBar(
                    title: widget.item.name,
                    metadata: _metadata,
                    isStandalone: widget.isStandalone || widget.windowId != null,
                    onPopOut: _openInNewWindow,
                    onClose: () => ref.read(previewFileProvider.notifier).state = null,
                    extraActions: [
                      _buildTopBarButton(
                        icon: _isEditing ? Icons.edit_rounded : Icons.edit_outlined,
                        onPressed: () => setState(() => _isEditing = !_isEditing),
                        tooltip: 'Edit Image',
                        active: _isEditing,
                      ),
                      const SizedBox(width: 8),
                      _buildTopBarButton(
                        icon: Icons.settings_rounded,
                        onPressed: () => SettingsDialog.show(context, initialTab: 1, section: 'Image'),
                        tooltip: 'Image Settings',
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),

              // Editing Bottom Panel
              if (_isEditing && isVisible)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildEditingPanel(),
                ),

              // Zoom Level Indicator (Bottom Right)
              if (_showZoomIndicator)
                Positioned(
                  bottom: 32,
                  right: 32,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _showZoomIndicator ? 1.0 : 0.0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Text(
                            '${(_currentScale * 100).toInt()}%',
                            style: GoogleFonts.outfit(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
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
      ),
    );
  }

  Widget _buildTopBarButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
    bool active = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: active ? const Color(0xFF00E5FF).withOpacity(0.2) : Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: active ? Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5)) : null,
      ),
      child: IconButton(
        icon: Icon(icon, color: active ? const Color(0xFF00E5FF) : Colors.white, size: 20),
        onPressed: onPressed,
        tooltip: tooltip,
        splashRadius: 24,
      ),
    );
  }

  Widget _buildEditingPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 200, // Increased height to prevent overflow
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView( // Add scroll view as extra safety
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildControlLabel(Icons.rotate_right, "Rotation: ${_rotationAngle.toInt()}°"),
            Slider(
              value: _rotationAngle,
              min: -180,
              max: 180,
              activeColor: const Color(0xFF00E5FF),
              inactiveColor: Colors.white10,
              onChanged: (val) => setState(() => _rotationAngle = val),
            ),
            const SizedBox(height: 8),
            _buildControlLabel(Icons.brightness_6, "Brightness"),
            Slider(
              value: _brightness,
              min: -1.0,
              max: 1.0,
              activeColor: const Color(0xFF00E5FF),
              inactiveColor: Colors.white10,
              onChanged: (val) => setState(() => _brightness = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlLabel(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 14),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildOverlayButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
        tooltip: tooltip,
        splashRadius: 24,
      ),
    );
  }
}
