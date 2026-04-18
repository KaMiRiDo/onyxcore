import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../widgets/image_editor_overlay.dart';

/// Image viewer page — migrated from original with Android-specific APIs removed.
///
/// Removed: SystemChrome.setEnabledSystemUIMode (Android-only),
/// Removed: SafeArea widgets (no status bars on Linux desktop).
class ImageViewerPage extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;

  const ImageViewerPage({
    Key? key,
    required this.imagePaths,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late PageController _pageController;
  late int _currentIndex;
  bool _showOverlays = true;
  bool _deleted = false;
  bool _isEditing = false;
  int _editTimestamp = DateTime.now().millisecondsSinceEpoch;

  // Zoom state per-page
  final Map<int, TransformationController> _transformControllers = {};
  final Map<int, int> _doubleTapZoomState = {}; // 0 = 1x, 1 = 2x, 2 = 3x
  final Map<int, String> _resolutions = {};
  bool _isZoomed = false;
  double _currentScale = 1.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _fetchResolution(_currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final ctrl in _transformControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  TransformationController _getTransformController(int index) {
    if (!_transformControllers.containsKey(index)) {
      final ctrl = TransformationController();
      ctrl.addListener(() {
        final scale = ctrl.value.getMaxScaleOnAxis();
        final zoomed = scale > 1.05;
        if (index == _currentIndex) {
          if (zoomed != _isZoomed || (scale - _currentScale).abs() > 0.05) {
            setState(() {
              _isZoomed = zoomed;
              _currentScale = scale;
            });
          }
        }
      });
      _transformControllers[index] = ctrl;
    }
    return _transformControllers[index]!;
  }

  int _getDoubleTapState(int index) {
    return _doubleTapZoomState[index] ?? 0;
  }

  void _handleDoubleTap(int index, TapDownDetails? tapDetails) {
    final ctrl = _getTransformController(index);
    final currentState = _getDoubleTapState(index);

    double targetScale;
    int nextState;

    if (currentState == 0) {
      targetScale = 2.0;
      nextState = 1;
    } else if (currentState == 1) {
      targetScale = 4.0;
      nextState = 2;
    } else {
      targetScale = 1.0;
      nextState = 0;
    }

    _doubleTapZoomState[index] = nextState;

    if (targetScale == 1.0) {
      ctrl.value = Matrix4.identity();
    } else {
      final renderBox = context.findRenderObject() as RenderBox;
      final screenSize = renderBox.size;
      final focalPoint = tapDetails?.localPosition ?? Offset(screenSize.width / 2, screenSize.height / 2);

      final dx = (1 - targetScale) * focalPoint.dx;
      final dy = (1 - targetScale) * focalPoint.dy;

      ctrl.value = Matrix4.identity()
        ..translate(dx, dy)
        ..scale(targetScale);
    }

    setState(() {
      _isZoomed = targetScale > 1.05;
      _currentScale = targetScale;
    });
  }

  void _restoreZoom() {
    final ctrl = _getTransformController(_currentIndex);
    ctrl.value = Matrix4.identity();
    _doubleTapZoomState[_currentIndex] = 0;
    setState(() {
      _isZoomed = false;
      _currentScale = 1.0;
    });
  }

  void _onPageChanged(int index) {
    final prevCtrl = _transformControllers[_currentIndex];
    if (prevCtrl != null) {
      prevCtrl.value = Matrix4.identity();
      _doubleTapZoomState[_currentIndex] = 0;
    }

    final keysToRemove = _transformControllers.keys.where((k) => (k - index).abs() > 2).toList();
    for (final k in keysToRemove) {
      _transformControllers[k]?.dispose();
      _transformControllers.remove(k);
      _doubleTapZoomState.remove(k);
    }

    setState(() {
      _currentIndex = index;
      _isZoomed = false;
      _currentScale = 1.0;
    });
    _fetchResolution(index);
  }

  Future<void> _fetchResolution(int index) async {
    if (_resolutions.containsKey(index)) return;
    try {
      final path = widget.imagePaths[index];
      final bytes = await File(path).readAsBytes();
      final codec = await instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final int w = frame.image.width;
      final int h = frame.image.height;
      frame.image.dispose();
      codec.dispose();

      final double mp = (w * h) / 1000000.0;
      final String mpStr = mp.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');

      if (mounted) {
        setState(() {
          _resolutions[index] = "$w x $h ( ${mpStr}MP )";
        });
      }
    } catch (_) {}
  }

  Future<void> _deleteCurrentImage() async {
    final path = widget.imagePaths[_currentIndex];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Image?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("CANCEL")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Image deleted")),
          );
        }

        widget.imagePaths.removeAt(_currentIndex);
        if (widget.imagePaths.isEmpty) {
          if (mounted) Navigator.pop(context, true);
          return;
        }

        if (_currentIndex >= widget.imagePaths.length) {
          _currentIndex = widget.imagePaths.length - 1;
        }

        setState(() {
          _deleted = true;
          _pageController = PageController(initialPage: _currentIndex);
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Delete failed: $e")),
          );
        }
      }
    }
  }

  Future<void> _pickCurrentImage() async {
    final path = widget.imagePaths[_currentIndex];
    final file = File(path);
    final directory = file.parent;

    final sortDir = Directory("${directory.path}/Sort");

    try {
      if (!await sortDir.exists()) {
        await sortDir.create(recursive: true);
      }

      final fileName = path.split('/').last;
      final destPath = "${sortDir.path}/$fileName";

      await file.rename(destPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Moved to Sort folder"),
            duration: Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      widget.imagePaths.removeAt(_currentIndex);

      if (widget.imagePaths.isEmpty) {
        if (mounted) Navigator.pop(context, true);
        return;
      }

      if (_currentIndex >= widget.imagePaths.length) {
        _currentIndex = widget.imagePaths.length - 1;
      }

      setState(() {
        _deleted = true;
        _pageController = PageController(initialPage: _currentIndex);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Pick failed: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imagePaths.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text("No images", style: TextStyle(color: Colors.white))),
      );
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop && result == null) { }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
        fit: StackFit.expand,
        children: [
          _buildPageView(),

          if (_showOverlays) _buildTopBanner(),

          if (_showOverlays) _buildResolutionBadge(),

          if (_showOverlays) _buildBottomActions(),

          _buildFloatingButtons(),

          if (_isEditing)
            Positioned.fill(
              child: ImageEditorOverlay(
                imagePath: widget.imagePaths[_currentIndex],
                onCancel: () => setState(() => _isEditing = false),
                onSave: (newPath, replaced) {
                  if (newPath != null) {
                    if (replaced) {
                      setState(() {
                        _isEditing = false;
                        _editTimestamp = DateTime.now().millisecondsSinceEpoch;
                        PaintingBinding.instance.imageCache.evict(FileImage(File(newPath)));
                      });
                    } else {
                      setState(() {
                         widget.imagePaths.insert(_currentIndex + 1, newPath);
                         _currentIndex++;
                         _isEditing = false;
                         _editTimestamp = DateTime.now().millisecondsSinceEpoch;
                         _pageController = PageController(initialPage: _currentIndex);
                      });
                    }
                  } else {
                    setState(() => _isEditing = false);
                  }
                },
              ),
            ),
        ],
      ),
    ),
  );
  }

  Widget _buildResolutionBadge() {
    final label = _resolutions[_currentIndex];
    if (label == null) return const SizedBox.shrink();

    return Positioned(
      top: 70,
      left: 16,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.cyan,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildPageView() {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.imagePaths.length,
      onPageChanged: _onPageChanged,
      physics: _isZoomed ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        return _buildZoomableImage(index);
      },
    );
  }

  TapDownDetails? _lastTapDown;

  Widget _buildZoomableImage(int index) {
    final ctrl = _getTransformController(index);
    final path = widget.imagePaths[index];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        setState(() => _showOverlays = !_showOverlays);
      },
      onDoubleTapDown: (details) {
        _lastTapDown = details;
      },
      onDoubleTap: () {
        _handleDoubleTap(index, _lastTapDown);
      },
      child: InteractiveViewer(
        transformationController: ctrl,
        minScale: 1.0,
        maxScale: 10.0,
        panEnabled: true,
        scaleEnabled: true,
        child: Center(
          child: Image.file(
            File(path),
            key: ValueKey("$path-$_editTimestamp"),
            fit: BoxFit.contain,
            cacheWidth: 1600,
            errorBuilder: (ctx, err, stack) => const Center(
              child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBanner() {
    final path = widget.imagePaths[_currentIndex];
    final fileName = path.split('/').last;
    final file = File(path);
    DateTime date = DateTime.now();
    try {
      date = file.statSync().modified;
    } catch (_) {}
    final dateStr = DateFormat("MMM dd, yyyy").format(date).toUpperCase();
    final sizeBytes = file.existsSync() ? file.lengthSync() : 0;
    final sizeText = bytesToHumanReadable(sizeBytes);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xCC000000),
              Color(0x80000000),
              Colors.transparent,
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context, _deleted),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateStr  •  $sizeText  •  ${_currentIndex + 1}/${widget.imagePaths.length}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Color(0xCC000000),
              Color(0x80000000),
              Colors.transparent,
            ],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
          child: Row(
            children: [
              _buildBlurredButton(
                onTap: _deleteCurrentImage,
                color: Colors.red.withOpacity(0.2),
                borderColor: Colors.red.withOpacity(0.4),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Delete",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildBlurredButton(
                onTap: () => setState(() => _isEditing = true),
                color: Colors.white.withOpacity(0.05),
                borderColor: Colors.white.withOpacity(0.1),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit_outlined, color: AppColors.cyan, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      "Edit",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingButtons() {
    return Positioned(
      bottom: 24,
      right: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isZoomed) ...[
             _buildRestoreButton(),
             const SizedBox(height: 16),
          ],
          _buildBlurredButton(
            onTap: _pickCurrentImage,
            isCircle: true,
            padding: const EdgeInsets.all(14),
            color: AppColors.teal.withOpacity(0.6),
            borderColor: AppColors.teal.withOpacity(0.8),
            child: const Icon(Icons.check_circle_outline, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildBlurredButton({
    required VoidCallback? onTap,
    required Widget child,
    EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    Color? color,
    Color? borderColor,
    bool isCircle = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isCircle ? 100 : 12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(isCircle ? 100 : 12),
              border: Border.all(
                color: borderColor ?? Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildRestoreButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Text(
            "${_currentScale.toStringAsFixed(1)}X",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _restoreZoom,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.teal.withOpacity(0.6), width: 1),
            ),
            child: const Icon(Icons.zoom_out_map, color: AppColors.cyan, size: 18),
          ),
        ),
      ],
    );
  }
}
