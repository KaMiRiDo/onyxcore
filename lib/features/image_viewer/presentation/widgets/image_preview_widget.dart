import 'dart:io';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
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
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;
import 'package:onyxcore/features/directory_browser/presentation/widgets/dialogs.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/directory_browser/domain/repositories/directory_repository.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';

class ImagePreviewWidget extends ConsumerStatefulWidget {
  const ImagePreviewWidget({
    required this.item, 
    this.windowId,
    this.parentWindowId,
    this.isStandalone = false,
    this.initParams,
    super.key,
  });

  final FileItem item;
  final String? windowId;
  final String? parentWindowId;
  final bool isStandalone;
  final Map<String, dynamic>? initParams;

  @override
  ConsumerState<ImagePreviewWidget> createState() => _ImagePreviewWidgetState();
}

class _ImagePreviewWidgetState extends ConsumerState<ImagePreviewWidget> with WindowListener, TickerProviderStateMixin {
  bool _isClosing = false;
  String? _metadata;
  String? _indexString;
  bool _isControlsVisible = true;
  bool _isEditing = false;
  Timer? _hideTimer;
  Timer? _zoomTimer;
  final FocusNode _focusNode = FocusNode();
  final TransformationController _transformationController = TransformationController();
  Offset _mousePosition = Offset.zero;
  double _currentScale = 1.0;
  double _initialScale = 1.0;
  Matrix4 _gestureStartMatrix = Matrix4.identity();
  double _scrubAccumulatedScale = 1.0;
  bool _isPanZoomGesture = false;
  bool _isInteracting = false;
  bool _showZoomIndicator = false;

  late AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;
  
  // Image Edit State
  double _rotationAngle = 0.0;
  double _brightness = 0.0;

  bool _isGlobalHudVisible = true;
  bool _isLoading = true;
  Size? _imageSize;
  Offset? _lastMousePos;
  final Completer<void> _firstFrameCompleter = Completer<void>();
  DateTime? _lastNavTime;
  bool _isReadyForInteraction = false;

  void initState() {
    super.initState();
    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        if (_zoomAnimation != null) {
          _transformationController.value = _zoomAnimation!.value;
          _onTransformationChanged();
        }
      });

    _isGlobalHudVisible = ref.read(previewHudVisibleProvider);
    if (widget.windowId != null) {
      windowManager.addListener(this);
      windowManager.setPreventClose(true);
      // Ensure true fullscreen to hide OS bars
      windowManager.setFullScreen(true);
      windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    }
    _loadMetadata();
    _updateIndexData();
    _startHideTimer();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _precacheAdjacentImages();
        _focusNode.requestFocus();
        if (!_firstFrameCompleter.isCompleted) {
          _firstFrameCompleter.complete();
        }
      }
    });

    // Wait for Hero animation to complete before enabling pinch-to-zoom to avoid matrix corruption
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _isReadyForInteraction = true);
    });
  }

  void _onTransformationChanged() {
    final scale = _transformationController.value.getMaxScaleOnAxis();
    if (scale != _currentScale) {
      setState(() {
        _currentScale = scale;
        // Show indicator if zoomed in, otherwise hide it after a short delay
        if (_currentScale > 1.0) {
          _showZoomIndicator = true;
          _zoomTimer?.cancel();
        } else {
          _startZoomTimer();
        }
        
        if (_currentScale > 1.0) {
          _isControlsVisible = false;
        }
      });
    }
  }

  void _startZoomTimer() {
    _zoomTimer?.cancel();
    _zoomTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted) {
        setState(() => _showZoomIndicator = false);
      }
    });
  }

  void _precacheAdjacentImages() {
    List<String> pathsToPreload = [];

    if (widget.isStandalone && widget.initParams != null && widget.initParams!['preloadPaths'] != null) {
      final List<dynamic> preloadList = widget.initParams!['preloadPaths'] as List<dynamic>;
      pathsToPreload = preloadList.map((e) => e.toString()).toList();
    } else if (!widget.isStandalone && widget.windowId == null) {
      final items = ref.read(sortedDirectoryItemsProvider).value ?? [];
      final mediaItems = items.where((i) => i.type == FileItemType.image).toList();
      if (mediaItems.isNotEmpty) {
        final currentIndex = mediaItems.indexWhere((i) => i.path == widget.item.path);
        if (currentIndex != -1) {
          for (int i = 1; i <= 2; i++) {
            pathsToPreload.add(mediaItems[(currentIndex + i) % mediaItems.length].path);
            pathsToPreload.add(mediaItems[(currentIndex - i + mediaItems.length) % mediaItems.length].path);
          }
        }
      }
    }

    for (final path in pathsToPreload) {
      if (path != widget.item.path && !path.toLowerCase().endsWith('.svg')) {
        precacheImage(_getImageProvider(path), context, onError: (e, s) {
          debugPrint('Failed to precache image $path: $e');
        });
      }
    }
  }

  ImageProvider _getImageProvider(String path) {
    return FileImage(File(path));
  }

  void _setZoom(double newScale, {Offset? focalPoint, bool animate = true}) {
    final clampedScale = newScale.clamp(1.0, 15.0);
    
    final P = focalPoint ?? _mousePosition;
    
    if (clampedScale == 1.0) {
      if (animate) {
        _animateMatrix(_transformationController.value, Matrix4.identity());
      } else {
        _transformationController.value = Matrix4.identity();
        _onTransformationChanged();
      }
      return;
    }

    final Matrix4 currentMatrix = _transformationController.value.clone();
    final double oldScale = currentMatrix.getMaxScaleOnAxis();
    
    if ((clampedScale - oldScale).abs() < 0.001) return;

    final double scaleRatio = clampedScale / oldScale;

    try {
      // Convert the viewport focal point to scene coordinates using the
      // inverse of the current transformation matrix. This ensures the
      // content point under the cursor stays pinned during zoom.
      final Matrix4 inverseMatrix = Matrix4.inverted(currentMatrix);
      final Offset scenePoint = MatrixUtils.transformPoint(inverseMatrix, P);

      // Build the new matrix: translate so that scenePoint is at origin,
      // apply uniform scale, then translate back — all in scene space,
      // then compose with the existing transform.
      final Matrix4 newMatrix = currentMatrix.clone()
        ..translate(scenePoint.dx, scenePoint.dy)
        ..scale(scaleRatio, scaleRatio)
        ..translate(-scenePoint.dx, -scenePoint.dy);
        
      if (newMatrix.storage.any((v) => !v.isFinite)) {
        return;
      }

      if (animate) {
        _animateMatrix(currentMatrix, newMatrix);
      } else {
        _transformationController.value = newMatrix;
        _onTransformationChanged();
      }
    } catch (e) {
      debugPrint('[ImagePreview] Error calculating zoom: $e');
      if (!animate) {
        _transformationController.value = Matrix4.identity();
        _onTransformationChanged();
      }
    }
  }

  /// Non-incremental zoom for pinch-to-zoom gestures.
  /// Computes the target matrix directly from [_gestureStartMatrix] to avoid
  /// cumulative drift from repeated incremental applications.
  void _setZoomFromGesture(double targetScale, Offset viewportFocalPoint) {
    final clampedScale = targetScale.clamp(1.0, 15.0);

    if (clampedScale == 1.0) {
      _transformationController.value = Matrix4.identity();
      _onTransformationChanged();
      return;
    }

    final double startScale = _gestureStartMatrix.getMaxScaleOnAxis();
    if (startScale < 0.001) return;
    final double scaleRatio = clampedScale / startScale;

    try {
      // Map viewport focal point to scene coordinates using the INITIAL matrix
      // (not the current one), so the anchor stays fixed across the gesture.
      final Matrix4 inverseStart = Matrix4.inverted(_gestureStartMatrix);
      final Offset scenePoint = MatrixUtils.transformPoint(inverseStart, viewportFocalPoint);

      final Matrix4 newMatrix = _gestureStartMatrix.clone()
        ..translate(scenePoint.dx, scenePoint.dy)
        ..scale(scaleRatio, scaleRatio)
        ..translate(-scenePoint.dx, -scenePoint.dy);

      if (newMatrix.storage.any((v) => !v.isFinite)) return;

      _transformationController.value = newMatrix;
      _onTransformationChanged();
    } catch (e) {
      debugPrint('[ImagePreview] Error in gesture zoom: $e');
    }
  }

  void _animateMatrix(Matrix4 start, Matrix4 end) {
    _zoomAnimationController.stop();
    _zoomAnimation = Matrix4Tween(
      begin: start,
      end: end,
    ).animate(CurvedAnimation(
      parent: _zoomAnimationController,
      curve: Curves.easeOutCubic,
    ));
    _zoomAnimationController.forward(from: 0);
  }

  Offset _lastFocalPoint = Offset.zero;

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isEditing) {
        setState(() => _isControlsVisible = false);
      }
    });
  }

  void _onInteraction({Offset? focalPoint, Offset? eventDelta}) {
    if (widget.windowId == null && !ref.read(previewHudVisibleProvider)) {
      ref.read(previewHudVisibleProvider.notifier).state = true;
    }

    // Ignore synthetic hover events caused by layout changes
    if (eventDelta != null && eventDelta == Offset.zero) {
      return;
    }

    if (focalPoint != null && _lastMousePos != null) {
      final delta = (focalPoint - _lastMousePos!).distance;
      // Only reveal if mouse actually moved significantly (avoid jitter or navigation-induced hover)
      if (delta < 2.0) {
        _startHideTimer();
        return;
      }
    }
    
    if (focalPoint != null) {
      _lastMousePos = focalPoint;
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

  Future<void> _updateIndexData() async {
    if (widget.windowId != null) {
      if (widget.initParams != null && widget.initParams!['currentIndex'] != null) {
        if (mounted) {
          setState(() {
            _indexString = '${widget.initParams!['currentIndex']}/${widget.initParams!['totalCount']}';
          });
        }
      } else {
        try {
          final payload = jsonEncode({
            'currentPath': widget.item.path,
            'type': 'image',
          });
          final response = await WindowController.fromWindowId(widget.parentWindowId ?? '0')
              .invokeMethod('get_next_prev_media', payload);
          if (response != null && response is String) {
            final data = jsonDecode(response);
            if (mounted && data['currentIndex'] != null) {
              setState(() {
                _indexString = '${data['currentIndex']}/${data['totalCount']}';
              });
            }
          }
        } catch (e) {
          debugPrint('Error getting index from IPC: $e');
        }
      }
    } else {
      final items = ref.read(sortedDirectoryItemsProvider).value ?? [];
      final mediaItems = items.where((i) => i.type == FileItemType.image).toList();
      final currentIndex = mediaItems.indexWhere((i) => i.path == widget.item.path) + 1;
      final totalCount = mediaItems.length;
      if (currentIndex > 0 && mounted) {
        setState(() {
          _indexString = '$currentIndex/$totalCount';
        });
      }
    }
  }

  Future<void> _loadMetadata() async {
    try {
      final isSvg = widget.item.path.toLowerCase().endsWith('.svg');
      if (isSvg) {
        setState(() {
          _metadata = 'Vector Graphic • Scalable';
          _isLoading = false;
        });
        return;
      }

      if (!_firstFrameCompleter.isCompleted) {
        await _firstFrameCompleter.future;
      }
      
      if (!mounted) return;

      final imageProvider = FileImage(File(widget.item.path));
      final completer = Completer<ImageInfo>();
      final stream = imageProvider.resolve(createLocalImageConfiguration(context));
      
      final listener = ImageStreamListener((info, _) {
        if (!completer.isCompleted) completer.complete(info);
      }, onError: (dynamic error, StackTrace? stackTrace) {
        if (!completer.isCompleted) completer.completeError(error as Object, stackTrace);
      });
      
      stream.addListener(listener);
      final info = await completer.future;
      stream.removeListener(listener);

      final image = info.image;
      
      if (mounted) {
        final mp = (image.width * image.height / 1000000).toStringAsFixed(1);
        setState(() {
          _imageSize = Size(image.width.toDouble(), image.height.toDouble());
          _metadata = '${image.width}x${image.height} px • $mp MP';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading image metadata: $e');
      if (mounted) setState(() => _isLoading = false);
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
    _zoomAnimationController.dispose();
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (_isClosing) return;
    await windowManager.hide();
  }

  @override
  void didUpdateWidget(ImagePreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path) {
      _transformationController.value = Matrix4.identity();
      setState(() {
        _isLoading = true;
        _rotationAngle = 0.0;
        _brightness = 0.0;
        _currentScale = 1.0;
        _isControlsVisible = false;
      });
      _loadMetadata();
      _updateIndexData();
      if (mounted) {
        _focusNode.requestFocus();
      }
      _precacheAdjacentImages();
    }
  }

  Future<void> _openInNewWindow() async {
    List<String> preloadPaths = [];
    if (!widget.isStandalone && widget.windowId == null) {
      final items = ref.read(sortedDirectoryItemsProvider).value ?? [];
      final mediaItems = items.where((i) => i.type == FileItemType.image).toList();
      if (mediaItems.isNotEmpty) {
        final currentIndex = mediaItems.indexWhere((i) => i.path == widget.item.path);
        if (currentIndex != -1) {
          for (int i = 1; i <= 2; i++) {
            preloadPaths.add(mediaItems[(currentIndex + i) % mediaItems.length].path);
            preloadPaths.add(mediaItems[(currentIndex - i + mediaItems.length) % mediaItems.length].path);
          }
        }
      }
    }

    final windowParams = WindowParams(
      viewerType: ViewerType.image,
      file: widget.item,
      initParams: {
        'preloadPaths': preloadPaths,
      },
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
      final payload = jsonEncode({
        'direction': forward ? 'next' : 'prev',
        'currentPath': widget.item.path,
        'type': 'image',
        'targetWindowId': widget.windowId!,
      });
      WindowController.fromWindowId(widget.parentWindowId ?? '0').invokeMethod('request_navigation', payload);
    } else {
      final items = ref.read(sortedDirectoryItemsProvider).value ?? [];
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

  Future<void> _handleDelete({required bool permanent}) async {
    final settings = ref.read(settingsProvider).value;
    final confirm = permanent || (settings?.confirmDeleteImage ?? true);
    
    if (confirm) {
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => ViewerDeleteDialog(
          fileName: widget.item.name,
          permanent: permanent,
        ),
      );
      if (shouldDelete != true) return;
    }
    
    FileItem? nextItem;
    bool hasMultiple = false;
    
    if (widget.windowId != null) {
      try {
        final payload = jsonEncode({
          'currentPath': widget.item.path,
          'type': 'image',
        });
        final response = await WindowController.fromWindowId(widget.parentWindowId ?? '0')
            .invokeMethod('get_next_prev_media', payload);
        if (response != null && response is String) {
          final data = jsonDecode(response);
          final String? nextPath = data['nextPath'];
          if (nextPath != null && nextPath != widget.item.path) {
            hasMultiple = true;
            nextItem = FileItem(
              name: (data['nextName'] as String?) ?? '',
              path: nextPath,
              type: FileItemType.image,
              sizeBytes: 0,
              modified: DateTime.now(),
              hasWritePermission: true,
            );
          }
        }
      } catch (e) {
        debugPrint('Error getting next media in standalone deletion: $e');
      }
    } else {
      final items = ref.read(sortedDirectoryItemsProvider).value ?? [];
      final mediaItems = items.where((i) => i.type == FileItemType.image).toList();
      if (mediaItems.length > 1) {
        hasMultiple = true;
        final currentIndex = mediaItems.indexWhere((i) => i.path == widget.item.path);
        if (currentIndex != -1) {
          final nextIndex = (currentIndex + 1) % mediaItems.length;
          nextItem = mediaItems[nextIndex];
        }
      }
    }
    
    if (widget.windowId != null) {
      final payload = jsonEncode({
        'path': widget.item.path,
        'permanent': permanent,
      });
      
      if (hasMultiple && nextItem != null) {
        _navigateMedia(true);
        // Delay slightly to let the navigate IPC execute first
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      await WindowController.fromWindowId(widget.parentWindowId ?? '0').invokeMethod('delete_item', payload);
      
      if (!hasMultiple) {
        await windowManager.hide();
      }
    } else {
      final repo = ref.read(directoryRepositoryProvider);
      final currentPath = ref.read(currentPathProvider);
      final taskId = ref.read(taskProvider.notifier).addTask(
        title: permanent ? 'Deleting image permanently' : 'Moving image to Trash',
        subtitle: permanent ? 'Delete' : 'Trash',
        sourcePaths: [widget.item.path],
        isLight: true,
      );
      
      try {
        await repo.deleteItems(
          [widget.item.path],
          permanent: permanent,
          taskId: taskId,
          onLog: (msg) => ref.read(taskProvider.notifier).addLog(taskId, msg),
        );
        ref.read(taskProvider.notifier).completeTask(taskId);
      } catch (e) {
        ref.read(taskProvider.notifier).addLog(taskId, 'Error: $e');
        ref.read(taskProvider.notifier).failTask(taskId, e.toString());
      } finally {
        repo.invalidateCache(currentPath);
        ref.read(refreshCountProvider.notifier).state = ref.read(refreshCountProvider) + 1;
        ref.read(directoryItemsProvider.notifier).refresh();
      }
      
      if (hasMultiple && nextItem != null) {
        ref.read(previewFileProvider.notifier).state = nextItem;
      } else {
        ref.read(previewFileProvider.notifier).state = null;
        ref.read(mainFocusNodeProvider).requestFocus();
      }
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

    final isVisible = _isControlsVisible && (widget.windowId != null || widget.isStandalone || _isGlobalHudVisible);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final ctrl = HardwareKeyboard.instance.isControlPressed;
          
          if (event.logicalKey == LogicalKeyboardKey.keyF) {
            if (widget.windowId != null && event is KeyDownEvent) {
              _toggleFullscreen();
              return KeyEventResult.handled;
            }
          }
          
          if (ctrl && event.logicalKey == LogicalKeyboardKey.keyW) {
            if (widget.windowId == null && event is KeyDownEvent) {
              ref.read(previewFileProvider.notifier).state = null;
              return KeyEventResult.handled;
            }
          }

          if (event.logicalKey == LogicalKeyboardKey.delete && event is KeyDownEvent) {
            final shift = HardwareKeyboard.instance.isShiftPressed;
            _handleDelete(permanent: shift);
            return KeyEventResult.handled;
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

          if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft && HardwareKeyboard.instance.isAltPressed) {
              // Ignore Alt+Left as it's used for back navigation
            } else {
              final forward = event.logicalKey == LogicalKeyboardKey.arrowRight;
              if (event is KeyRepeatEvent) {
                final now = DateTime.now();
                if (_lastNavTime != null && now.difference(_lastNavTime!).inMilliseconds < 300) {
                  return KeyEventResult.handled;
                }
                _lastNavTime = now;
                _navigateMedia(forward);
              } else if (event is KeyDownEvent) {
                _lastNavTime = DateTime.now();
                _navigateMedia(forward);
              }
              return KeyEventResult.handled;
            }
          }

          if (widget.windowId == null && event is KeyDownEvent) {
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
          onEnter: (event) {
            _mousePosition = event.localPosition;
            _onInteraction(focalPoint: event.localPosition, eventDelta: event.delta);
          },
          onHover: (event) {
            _onInteraction(focalPoint: event.localPosition, eventDelta: event.delta);
            _mousePosition = event.localPosition;
          },
          child: Listener(
            onPointerDown: (event) {
              _mousePosition = event.localPosition;
              setState(() => _isInteracting = true);
              if (_zoomAnimationController.isAnimating) {
                _zoomAnimationController.stop();
              }
            },
            onPointerUp: (event) {
              setState(() => _isInteracting = false);
            },
            onPointerMove: (event) {
              _mousePosition = event.localPosition;
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerSignal: (pointerSignal) {
                      if (pointerSignal is PointerScrollEvent) {
                        final ctrl = HardwareKeyboard.instance.isControlPressed ||
                            HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlLeft) ||
                            HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlRight);
                        if (ctrl) {
                          final double delta = pointerSignal.scrollDelta.dy;
                          if (delta != 0) {
                            final double zoomFactor = delta > 0 ? 1.05 : 0.95;
                            _setZoom(_currentScale * zoomFactor, focalPoint: pointerSignal.localPosition);
                          }
                        } else if (_currentScale > 1.05) {
                          // Handle trackpad two-finger drag (panning via scroll)
                          final delta = pointerSignal.scrollDelta;
                          const double sensitivity = 5.0;
                          final translation = Matrix4.translationValues(-delta.dx * sensitivity, -delta.dy * sensitivity, 0);
                          final Matrix4 nextMatrix = (translation * _transformationController.value) as Matrix4;
                          
                          if (nextMatrix.storage.any((v) => !v.isFinite)) return;
                          
                          _transformationController.value = nextMatrix;
                          _onTransformationChanged();
                        }
                      }
                    },
                    onPointerPanZoomStart: (event) {
                      // Use gesture localPosition as fallback if _mousePosition
                      if (_mousePosition == Offset.zero) {
                        _mousePosition = event.localPosition;
                      }
                      _initialScale = _currentScale;
                      _gestureStartMatrix = _transformationController.value.clone();
                      _scrubAccumulatedScale = 1.0;
                      setState(() => _isPanZoomGesture = true);
                    },
                    onPointerPanZoomEnd: (event) {
                      setState(() => _isPanZoomGesture = false);
                    },
                    onPointerPanZoomUpdate: (event) {
                      final ctrl = HardwareKeyboard.instance.isControlPressed ||
                          HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlLeft) ||
                          HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlRight);
                      
                      if (ctrl) {
                        final double dy = event.panDelta.dy;
                        if (dy != 0) {
                          // Accumulate the scrub scale from gesture start
                          // dy positive (scrub down) -> zoom in, negative -> zoom out
                          _scrubAccumulatedScale *= 1.0 + (dy * 0.005);
                          _setZoomFromGesture(_initialScale * _scrubAccumulatedScale, _mousePosition);
                        }
                      } else {
                        if (event.scale != 1.0) {
                          _setZoomFromGesture(_initialScale * event.scale, _mousePosition);
                        } else if (event.panDelta != Offset.zero && _currentScale > 1.05) {
                          final delta = event.panDelta;
                          final translation = Matrix4.translationValues(delta.dx, delta.dy, 0);
                          final Matrix4 nextMatrix = (translation * _transformationController.value) as Matrix4;
                          if (nextMatrix.storage.any((v) => !v.isFinite)) return;
                          _transformationController.value = nextMatrix;
                          _onTransformationChanged();
                        }
                      }
                    },
                    child: InteractiveViewer(
                      transformationController: _transformationController,
                      minScale: 1.0,
                      maxScale: 15.0,
                      panEnabled: !_isPanZoomGesture && (_isReadyForInteraction || widget.isStandalone),
                      scaleEnabled: false, // Handled customly above for perfect cursor-centered zoom
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
                        child: Builder(
                          builder: (context) {
                            Widget _buildImageWidget() {
                              return widget.item.path.toLowerCase().endsWith('.svg')
                                  ? SvgPicture.file(
                                      File(widget.item.path),
                                      fit: BoxFit.contain,
                                    )
                                  : Image.file(
                                      File(widget.item.path),
                                      fit: BoxFit.contain,
                                      filterQuality: (_isInteracting || _isPanZoomGesture || _zoomAnimationController.isAnimating) 
                                          ? FilterQuality.low 
                                          : FilterQuality.high,
                                    );
                            }
                            
                            return Center(
                              child: Hero(
                                tag: widget.item.path,
                                child: Transform.rotate(
                                  angle: _rotationAngle * 3.14159 / 180,
                                  child: _brightness != 0.0 
                                    ? ColorFiltered(
                                        colorFilter: ColorFilter.matrix([
                                          1, 0, 0, 0, _brightness * 255,
                                          0, 1, 0, 0, _brightness * 255,
                                          0, 0, 1, 0, _brightness * 255,
                                          0, 0, 0, 1, 0,
                                        ]),
                                        child: _buildImageWidget(),
                                      )
                                    : _buildImageWidget(),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                if (_isLoading)
                  const IgnorePointer(child: Center(child: BubbleLoader(size: 80))),

                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: isVisible ? 1.0 : 0.0,
                    child: ViewerTopBar(
                      title: widget.item.name,
                      metadata: _indexString != null ? '$_indexString • ${_metadata ?? ''}' : _metadata,
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

                if (_isEditing && isVisible)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: _buildEditingPanel(),
                  ),

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
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
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
