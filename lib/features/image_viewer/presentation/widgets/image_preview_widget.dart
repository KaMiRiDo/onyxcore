import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/core/widgets/viewer_top_bar.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/dialogs.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_hud_controller.dart';
import 'package:onyxcore/features/image_viewer/presentation/providers/image_playlist_providers.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_navigation_controller.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_keyboard_handler.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_viewer_lifecycle.dart';
import 'package:onyxcore/features/image_viewer/presentation/services/image_metadata_loader.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_editing_panel.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_empty_state.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_playlist_sidebar.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_zoom_indicator.dart';
import 'package:onyxcore/features/image_viewer/utils/special_image_converter.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/settings/presentation/widgets/settings_dialog.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

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

class _ImagePreviewWidgetState extends ConsumerState<ImagePreviewWidget>
    with WindowListener, TickerProviderStateMixin {
  late final ImageHudController _hudController;
  bool _isEmpty = false;

  bool get _isNetworkStream => widget.initParams?['is_network_stream'] == true;

  String? _metadata;
  bool _isConvertingHeic = false;
  String? _convertedHeicPath;

  final FocusNode _focusNode = FocusNode();
  final TransformationController _transformationController =
      TransformationController();
  Offset _mousePosition = Offset.zero;
  double _currentScale = 1;
  double _initialScale = 1;
  Matrix4 _gestureStartMatrix = Matrix4.identity();
  double _scrubAccumulatedScale = 1;
  bool _isPanZoomGesture = false;
  bool _isInteracting = false;

  late AnimationController _zoomAnimationController;
  late ImageNavigationController _navigationController;
  late ImageKeyboardHandler _keyboardHandler;
  late ImageViewerLifecycle _lifecycle;
  Animation<Matrix4>? _zoomAnimation;
  Size? _imageSize;

  // Image Edit State
  double _rotationAngle = 0;
  double _brightness = 0;

  bool _isGlobalHudVisible = true;
  Offset? _lastMousePos;
  bool _isReadyForInteraction = false;

  late FileItem _currentItem;


  Future<void> _loadSpecialImageIfNecessary() async {
    final ext = _currentItem.path.toLowerCase();
    final isSpecial =
        ext.endsWith('.heic') ||
        ext.endsWith('.heif') ||
        ext.endsWith('.avif') ||
        ext.endsWith('.dng') ||
        ext.endsWith('.raw');

    if (isSpecial) {
      setState(() => _isConvertingHeic = true);

      final resultPath = await SpecialImageConverter.convertIfNecessary(
        _currentItem.path,
      );

      if (mounted) {
        setState(() {
          _convertedHeicPath = resultPath;
          _isConvertingHeic = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _convertedHeicPath = null;
          _isConvertingHeic = false;
        });
      }
    }
  }

  void _onWindowFocus() {
    if (mounted) _focusNode.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    _hudController = ImageHudController()..addListener(() {
      if (mounted) setState(() {});
    });
    _navigationController = ImageNavigationController(
      isStandalone: widget.isStandalone,
      initParams: widget.initParams,
      windowId: widget.windowId,
      ref: ref,
      onNavigate: _openFile,
      onClearNavigation: _onClearNavigation,
    )..addListener(() {
        if (mounted) {
          setState(() {
            _isEmpty = _navigationController.isEmpty;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(imageIsEmptyProvider.notifier).state = _isEmpty;
            }
          });
        }
    });
    
    _keyboardHandler = ImageKeyboardHandler(
      onClose: () => ref.read(previewFileProvider.notifier).state = null,
      onDelete: ({required bool permanent}) => _handleDelete(permanent: permanent),
      onToggleSidebar: () {
        final isOpen = ref.read(imagePlaylistSidebarVisibleProvider);
        ref.read(imagePlaylistSidebarVisibleProvider.notifier).state = !isOpen;
      },
      onZoomIn: () => _setZoom(_currentScale + 0.2),
      onZoomOut: () => _setZoom(_currentScale - 0.2),
      onResetZoom: () => _setZoom(1),
      onNavigateForward: ({required bool isKeyRepeat}) => _navigateMedia(true),
      onNavigateBackward: ({required bool isKeyRepeat}) => _navigateMedia(false),
      onNavigateHistoryForward: () => _navigationController.navigatePlaylistHistoryForward(),
      onNavigateHistoryBackward: () => _navigationController.navigatePlaylistHistoryBack(),
      onToggleFullscreen: _toggleFullscreen,
      isSidebarOpen: () => ref.read(imagePlaylistSidebarVisibleProvider),
      isStandalone: widget.isStandalone,
      isWindowed: widget.windowId != null,
    );

    _currentItem = widget.item;
    _zoomAnimationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 200),
        )..addListener(() {
          if (_zoomAnimation != null) {
            _transformationController.value = _zoomAnimation!.value;
            _onTransformationChanged();
          }
        });

    _lifecycle = ImageViewerLifecycle(
      windowId: widget.windowId,
      isStandalone: widget.isStandalone,
      focusNode: _focusNode,
      zoomAnimationController: _zoomAnimationController,
      onWindowFocus: _onWindowFocus,
      onReadyForInteraction: () {
        if (mounted) {
          setState(() {
            _isReadyForInteraction = true;
          });
        }
      },
      onFirstFrame: () {
        if (mounted) {
          _navigationController.precacheAdjacentImages(context, _currentItem);
          _focusNode.requestFocus();
        }
      },
    );

    _isGlobalHudVisible = ref.read(previewHudVisibleProvider);
    _loadMetadata();
    _navigationController.updateIndexData(_currentItem);
    _hudController.startHideTimer();
    _loadSpecialImageIfNecessary();

    if (widget.isStandalone) {
      _navigationController.initStandalonePlaylist(_currentItem);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(previewFileProvider.notifier).state = _currentItem;
      });
    }

    _lifecycle.initialize(
      context: context,
      ref: ref,
      item: _currentItem,
      isMounted: mounted,
    );
  }

  void _onTransformationChanged() {
    if (!mounted) return;

    final viewportSize = MediaQuery.of(context).size;
    final clamped = _clampMatrix(_transformationController.value, viewportSize);

    final currentTx = _transformationController.value.getTranslation().x;
    final currentTy = _transformationController.value.getTranslation().y;
    final clampedTx = clamped.getTranslation().x;
    final clampedTy = clamped.getTranslation().y;

    if ((currentTx - clampedTx).abs() > 0.1 ||
        (currentTy - clampedTy).abs() > 0.1) {
      _transformationController.value = clamped;
      return;
    }

    final scale = _transformationController.value.getMaxScaleOnAxis();
    if (scale != _currentScale) {
      setState(() {
        _currentScale = scale;
        // Show indicator if zoomed in, otherwise hide it after a short delay
        if (_currentScale > 1.0) {
          _hudController.showZoomIndicatorForDuration();
        }

        if (_currentScale > 1.0) {
          _hudController.hideControls();
        }
      });
    }
  }


  Matrix4 _clampMatrix(Matrix4 matrix, Size viewportSize) {
    if (_imageSize == null) return matrix;

    final scaleX = viewportSize.width / _imageSize!.width;
    final scaleY = viewportSize.height / _imageSize!.height;
    final double fitScale = math.min(scaleX, scaleY);

    final fittedWidth = _imageSize!.width * fitScale;
    final fittedHeight = _imageSize!.height * fitScale;

    final currentZoom = matrix.getMaxScaleOnAxis();
    final scaledWidth = fittedWidth * currentZoom;
    final scaledHeight = fittedHeight * currentZoom;

    final padX = (viewportSize.width - fittedWidth) / 2;
    final padY = (viewportSize.height - fittedHeight) / 2;

    double minTx;
    double maxTx;
    if (scaledWidth > viewportSize.width) {
      minTx = viewportSize.width - scaledWidth - padX * currentZoom;
      maxTx = -padX * currentZoom;
    } else {
      minTx = maxTx = viewportSize.width * (1 - currentZoom) / 2;
    }

    double minTy;
    double maxTy;
    if (scaledHeight > viewportSize.height) {
      minTy = viewportSize.height - scaledHeight - padY * currentZoom;
      maxTy = -padY * currentZoom;
    } else {
      minTy = maxTy = viewportSize.height * (1 - currentZoom) / 2;
    }

    final clampedTx = matrix.getTranslation().x.clamp(minTx, maxTx);
    final clampedTy = matrix.getTranslation().y.clamp(minTy, maxTy);

    final clampedMatrix = matrix.clone();
    clampedMatrix.setTranslationRaw(clampedTx, clampedTy, 0);
    return clampedMatrix;
  }

  void _setZoom(double newScale, {Offset? focalPoint, bool animate = true}) {
    final clampedScale = newScale.clamp(1.0, 15.0);

    Offset getFocalPoint() {
      if (focalPoint != null) return focalPoint;
      final isSidebarOpen = ref.read(imagePlaylistSidebarVisibleProvider);
      if (!isSidebarOpen) return _mousePosition;
      final screenWidth = MediaQuery.of(context).size.width;
      const minWidth = 240.0;
      final maxWidth = screenWidth * 0.40;
      var panelWidth =
          ref.read(imagePlaylistSidebarWidthProvider) ?? (screenWidth * 0.25);
      panelWidth = panelWidth.clamp(minWidth, maxWidth);
      return Offset(_mousePosition.dx - panelWidth, _mousePosition.dy);
    }

    final P = getFocalPoint();

    if (clampedScale == 1.0) {
      if (animate) {
        _animateMatrix(_transformationController.value, Matrix4.identity());
      } else {
        _transformationController.value = Matrix4.identity();
        _onTransformationChanged();
      }
      return;
    }

    final currentMatrix = _transformationController.value.clone();
    final oldScale = currentMatrix.getMaxScaleOnAxis();

    if ((clampedScale - oldScale).abs() < 0.001) return;

    final scaleRatio = clampedScale / oldScale;

    try {
      // Convert the viewport focal point to scene coordinates using the
      // inverse of the current transformation matrix. This ensures the
      // content point under the cursor stays pinned during zoom.
      final inverseMatrix = Matrix4.inverted(currentMatrix);
      final scenePoint = MatrixUtils.transformPoint(inverseMatrix, P);

      // Build the new matrix: translate so that scenePoint is at origin,
      // apply uniform scale, then translate back — all in scene space,
      // then compose with the existing transform.
      final newMatrix = currentMatrix.clone()
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

    final startScale = _gestureStartMatrix.getMaxScaleOnAxis();
    if (startScale < 0.001) return;
    final scaleRatio = clampedScale / startScale;

    try {
      // Map viewport focal point to scene coordinates using the INITIAL matrix
      // (not the current one), so the anchor stays fixed across the gesture.
      final inverseStart = Matrix4.inverted(_gestureStartMatrix);
      final scenePoint = MatrixUtils.transformPoint(
        inverseStart,
        viewportFocalPoint,
      );

      final newMatrix = _gestureStartMatrix.clone()
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
    _zoomAnimation = Matrix4Tween(begin: start, end: end).animate(
      CurvedAnimation(
        parent: _zoomAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _zoomAnimationController.forward(from: 0);
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
        _hudController.startHideTimer();
        return;
      }
    }

    if (focalPoint != null) {
      _lastMousePos = focalPoint;
    }

    if (mounted && !_hudController.isControlsVisible) {
      _hudController.showControls();
    }
    _hudController.startHideTimer();
  }

  bool _isStandaloneFullscreen = false; // It starts maximized, not fullscreen

  Future<void> _toggleFullscreen() async {
    if (widget.windowId != null) {
      final willBeFullScreen = !_isStandaloneFullscreen;
      _isStandaloneFullscreen = willBeFullScreen;
      await PersistentViewerManager.setFullScreen(
        int.parse(widget.windowId!),
        willBeFullScreen,
      );
      _onInteraction();
      return;
    }

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
      final path = _convertedHeicPath ?? _currentItem.path;
      final result = await ImageMetadataLoader.load(
        path,
        context,
        _lifecycle.firstFrame,
      );

    if (mounted) {
      setState(() {
        if (result.metadataString != null) {
          _metadata = result.metadataString!;
        }
        if (result.imageSize != null) {
          _imageSize = result.imageSize;
        }
      });
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _hudController.dispose();
    _navigationController.dispose();
    _zoomAnimationController.dispose();
    _focusNode.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    if (_hudController.isClosing) return;
    _hudController.startClosing();

    // Delegate to PersistentViewerManager which will:
    // 1. Remove the view from the widget tree (unmount Flutter widgets)
    // 2. Wait 150ms for resources to be released
    // 3. Destroy the native GTK window
    if (widget.windowId != null) {
      await PersistentViewerManager.closeWindow(int.parse(widget.windowId!));
    }
  }

  @override
  void didUpdateWidget(ImagePreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.path != widget.item.path) {
      _loadMedia(widget.item);
    }
  }

  void _loadMedia(FileItem item) {
    _zoomAnimationController.stop();
    _transformationController.value = Matrix4.identity();
    setState(() {
      _currentItem = item;
      _isEmpty = false;
      _rotationAngle = 0.0;
      _brightness = 0.0;
      _currentScale = 1.0;
      _isPanZoomGesture = false;
      _mousePosition = Offset.zero;
      _hudController.hideControls();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(imageIsEmptyProvider.notifier).state = false;
        ref.read(previewFileProvider.notifier).state = item;
      }
    });
    _loadMetadata();
    _navigationController.updateIndexData(item);
    _loadSpecialImageIfNecessary();
    if (mounted) {
      _focusNode.requestFocus();
      final parentPath = p.dirname(item.path);
      final currentRoot = ref.read(imageRootPathProvider);
      if (currentRoot.isEmpty || !parentPath.startsWith(currentRoot)) {
        ref.read(imageRootPathProvider.notifier).state = parentPath;
      }
      ref.read(imageCurrentPathProvider.notifier).state = parentPath;
    }
    _navigationController.precacheAdjacentImages(context, item);
  }

  void _openFile(FileItem item) {
    if (widget.isStandalone) {
      _loadMedia(item);
    } else {
      ref.read(previewFileProvider.notifier).state = item;
    }
  }

  Future<void> _openInNewWindow() async {
    final preloadPaths = <String>[];
    if (!widget.isStandalone && widget.windowId == null) {
      var mediaItems = ref
          .read(filteredAndSortedImageQueueProvider)
          .where((i) => i.type == FileItemType.image)
          .toList();
      if (mediaItems.isEmpty) {
        final items = ref.read(sortedDirectoryItemsProvider).value ?? [];
        mediaItems = items.where((i) => i.type == FileItemType.image).toList();
      }
      if (mediaItems.isNotEmpty) {
        final currentIndex = mediaItems.indexWhere(
          (i) => i.path == _currentItem.path,
        );
        if (currentIndex != -1) {
          for (var i = 1; i <= 2; i++) {
            preloadPaths.add(
              mediaItems[(currentIndex + i) % mediaItems.length].path,
            );
            preloadPaths.add(
              mediaItems[(currentIndex - i + mediaItems.length) %
                      mediaItems.length]
                  .path,
            );
          }
        }
      }
    }

    final windowParams = WindowParams(
      viewerType: ViewerType.image,
      file: _currentItem,
      initParams: {'preloadPaths': preloadPaths},
    );

    try {
      ref.read(previewFileProvider.notifier).state = null;
      await PersistentViewerManager.openMedia(windowParams);
    } catch (e) {
      debugPrint('Error opening persistent image viewer: $e');
    }
  }



  void _onClearNavigation() {
    if (widget.isStandalone) {
      windowManager.hide();
    } else {
      ref.read(previewFileProvider.notifier).state = null;
      ref.read(mainFocusNodeProvider).requestFocus();
    }
  }

  void _navigateMedia(bool forward) {
    if (forward) {
      _navigationController.navigateForward(_currentItem);
    } else {
      _navigationController.navigateBackward(_currentItem);
    }
  }

  Future<void> _handleDelete({required bool permanent}) async {
    final settings = ref.read(settingsProvider).value;
    final confirm = permanent || (settings?.confirmDeleteImage ?? true);

    if (confirm) {
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (context) => ViewerDeleteDialog(
          fileName: _currentItem.name,
          permanent: permanent,
        ),
      );
      if (shouldDelete != true) return;
    }

    if (widget.isStandalone) {
      _navigationController.navigateAfterDeletion(_currentItem);
    } else {
      final repo = ref.read(directoryRepositoryProvider);
      final currentPath = ref.read(currentPathProvider);
      final taskId = ref
          .read(taskProvider.notifier)
          .addTask(
            title: permanent
                ? 'Deleting image permanently'
                : 'Moving image to Trash',
            subtitle: permanent ? 'Delete' : 'Trash',
            sourcePaths: [_currentItem.path],
            isLight: true,
          );

      try {
        await repo.deleteItems(
          [_currentItem.path],
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
        ref.read(refreshCountProvider.notifier).state =
            ref.read(refreshCountProvider) + 1;
        unawaited(ref.read(directoryItemsProvider.notifier).refresh());
      }
      
      _navigationController.navigateAfterDeletion(_currentItem);
    }
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (_isInteracting) return KeyEventResult.ignored;
    return _keyboardHandler.handleKeyEvent(event);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(imageRestartSignalProvider, (previous, next) {
      _navigationController.resetEmptyState();
    });

    if (widget.windowId == null && !widget.isStandalone) {
      ref.listen(previewHudVisibleProvider, (previous, next) {
        if (mounted) {
          setState(() => _isGlobalHudVisible = next);
        }
      });
    }

    final isVisible =
        _hudController.isControlsVisible &&
        (widget.windowId != null || widget.isStandalone || _isGlobalHudVisible);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) => _handleKeyEvent(event),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: MouseRegion(
          onEnter: (event) {
            _mousePosition = event.localPosition;
            _onInteraction(
              focalPoint: event.localPosition,
              eventDelta: event.delta,
            );
          },
          onHover: (event) {
            _onInteraction(
              focalPoint: event.localPosition,
              eventDelta: event.delta,
            );
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
            child: Consumer(
              builder: (context, sidebarRef, _) {
                final isSidebarOpen = sidebarRef.watch(
                  imagePlaylistSidebarVisibleProvider,
                );
                final screenWidth = MediaQuery.of(context).size.width;
                const minWidth = 240.0;
                final maxWidth = screenWidth * 0.40;
                final savedWidth = sidebarRef.watch(
                  imagePlaylistSidebarWidthProvider,
                );
                var panelWidth = savedWidth ?? (screenWidth * 0.25);
                panelWidth = panelWidth.clamp(minWidth, maxWidth);
                final sidebarWidth = isSidebarOpen ? panelWidth : 0.0;

                return Row(
                  children: [
                    SizedBox(
                      width: sidebarWidth,
                      child: isSidebarOpen
                          ? ImagePlaylistSidebar(
                              onImageSelected: _openFile,
                              onDelete: (paths) =>
                                  _handleDelete(permanent: false),
                            )
                          : const SizedBox.shrink(),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          if (_isEmpty)
                            Positioned.fill(child: const ImageEmptyState())
                          else
                            Positioned.fill(
                              child: Listener(
                                behavior: HitTestBehavior.translucent,
                                onPointerSignal: (pointerSignal) {
                                  if (pointerSignal is PointerScrollEvent) {
                                    final ctrl =
                                        HardwareKeyboard
                                            .instance
                                            .isControlPressed ||
                                        HardwareKeyboard
                                            .instance
                                            .logicalKeysPressed
                                            .contains(
                                              LogicalKeyboardKey.controlLeft,
                                            ) ||
                                        HardwareKeyboard
                                            .instance
                                            .logicalKeysPressed
                                            .contains(
                                              LogicalKeyboardKey.controlRight,
                                            );
                                    if (ctrl) {
                                      final delta =
                                          pointerSignal.scrollDelta.dy;
                                      if (delta != 0) {
                                        final zoomFactor = delta > 0
                                            ? 1.05
                                            : 0.95;
                                        _setZoom(
                                          _currentScale * zoomFactor,
                                          focalPoint:
                                              pointerSignal.localPosition,
                                        );
                                      }
                                    } else if (_currentScale > 1.05) {
                                      // Handle trackpad two-finger drag (panning via scroll)
                                      final delta = pointerSignal.scrollDelta;
                                      const sensitivity = 5;
                                      final translation =
                                          Matrix4.translationValues(
                                            -delta.dx * sensitivity,
                                            -delta.dy * sensitivity,
                                            0,
                                          );
                                      final nextMatrix =
                                          (translation *
                                                  _transformationController
                                                      .value)
                                              as Matrix4;

                                      if (nextMatrix.storage.any(
                                        (v) => !v.isFinite,
                                      )) {
                                        return;
                                      }

                                      _transformationController.value =
                                          nextMatrix;
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
                                  _gestureStartMatrix =
                                      _transformationController.value.clone();
                                  _scrubAccumulatedScale = 1.0;
                                  setState(() => _isPanZoomGesture = true);
                                },
                                onPointerPanZoomEnd: (event) {
                                  setState(() => _isPanZoomGesture = false);
                                },
                                onPointerPanZoomUpdate: (event) {
                                  final ctrl =
                                      HardwareKeyboard
                                          .instance
                                          .isControlPressed ||
                                      HardwareKeyboard
                                          .instance
                                          .logicalKeysPressed
                                          .contains(
                                            LogicalKeyboardKey.controlLeft,
                                          ) ||
                                      HardwareKeyboard
                                          .instance
                                          .logicalKeysPressed
                                          .contains(
                                            LogicalKeyboardKey.controlRight,
                                          );

                                  if (ctrl) {
                                    final dy = event.panDelta.dy;
                                    if (dy != 0) {
                                      // Accumulate the scrub scale from gesture start
                                      // dy positive (scrub down) -> zoom in, negative -> zoom out
                                      _scrubAccumulatedScale *=
                                          1.0 + (dy * 0.005);
                                      _setZoomFromGesture(
                                        _initialScale * _scrubAccumulatedScale,
                                        event.localPosition,
                                      );
                                    }
                                  } else {
                                    if (event.scale != 1.0) {
                                      _setZoomFromGesture(
                                        _initialScale * event.scale,
                                        event.localPosition,
                                      );
                                    } else if (event.panDelta != Offset.zero &&
                                        _currentScale > 1.05) {
                                      final delta = event.panDelta;
                                      final translation =
                                          Matrix4.translationValues(
                                            delta.dx,
                                            delta.dy,
                                            0,
                                          );
                                      final nextMatrix =
                                          (translation *
                                                  _transformationController
                                                      .value)
                                              as Matrix4;
                                      if (nextMatrix.storage.any(
                                        (v) => !v.isFinite,
                                      )) {
                                        return;
                                      }

                                      _transformationController.value =
                                          nextMatrix;
                                      _onTransformationChanged();
                                    }
                                  }
                                },
                                child: InteractiveViewer(
                                  transformationController:
                                      _transformationController,
                                  minScale: 1,
                                  maxScale: 15,
                                  panEnabled:
                                      !_isPanZoomGesture &&
                                      (_isReadyForInteraction ||
                                          widget.isStandalone),
                                  scaleEnabled:
                                      false, // Handled customly above for perfect cursor-centered zoom
                                  onInteractionUpdate: (_) =>
                                      _onTransformationChanged(),
                                  child: GestureDetector(
                                    onTap: () {
                                      _focusNode.requestFocus();
                                        _hudController.toggleControls();
                                    },
                                    onDoubleTap: widget.windowId == null
                                        ? _openInNewWindow
                                        : () => _setZoom(1),
                                    child: Builder(
                                      builder: (context) {
                                        Widget buildImageWidget() {
                                          if (_isConvertingHeic) {
                                            return const Center(
                                              child: BubbleLoader(size: 60),
                                            );
                                          }

                                          final imagePath =
                                              _convertedHeicPath ??
                                              _currentItem.path;
                                          final isNetwork =
                                              imagePath.startsWith('http://') ||
                                              imagePath.startsWith('https://');

                                          if (imagePath.toLowerCase().endsWith(
                                            '.svg',
                                          )) {
                                            return isNetwork
                                                ? SvgPicture.network(
                                                    imagePath,
                                                    placeholderBuilder: (_) => const Center(child: BubbleLoader(size: 60)),
                                                  )
                                                : SvgPicture.file(
                                                    File(imagePath),
                                                    placeholderBuilder: (_) => const Center(child: BubbleLoader(size: 60)),
                                                  );
                                          } else {
                                            return isNetwork
                                                ? Image.network(
                                                    imagePath,
                                                    fit: BoxFit.contain,
                                                    cacheWidth: 3840,
                                                    filterQuality:
                                                        (_isInteracting ||
                                                                _isPanZoomGesture ||
                                                                _zoomAnimationController
                                                                    .isAnimating)
                                                            ? FilterQuality.low
                                                            : FilterQuality.high,
                                                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                                      if (wasSynchronouslyLoaded || frame != null) return child;
                                                      return const Center(child: BubbleLoader(size: 60));
                                                    },
                                                  )
                                                : Image.file(
                                                    File(imagePath),
                                                    fit: BoxFit.contain,
                                                    cacheWidth: 3840,
                                                    filterQuality:
                                                        (_isInteracting ||
                                                                _isPanZoomGesture ||
                                                                _zoomAnimationController
                                                                    .isAnimating)
                                                            ? FilterQuality.low
                                                            : FilterQuality.high,
                                                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                                      if (wasSynchronouslyLoaded || frame != null) return child;
                                                      return const Center(child: BubbleLoader(size: 60));
                                                    },
                                                  );
                                          }
                                        }

                                        return Center(
                                          child: Hero(
                                            tag: _currentItem.path,
                                            child: Transform.rotate(
                                              angle:
                                                  _rotationAngle *
                                                  3.14159 /
                                                  180,
                                              child: _brightness != 0.0
                                                  ? ColorFiltered(
                                                      colorFilter:
                                                          ColorFilter.matrix([
                                                            1,
                                                            0,
                                                            0,
                                                            0,
                                                            _brightness * 255,
                                                            0,
                                                            1,
                                                            0,
                                                            0,
                                                            _brightness * 255,
                                                            0,
                                                            0,
                                                            1,
                                                            0,
                                                            _brightness * 255,
                                                            0,
                                                            0,
                                                            0,
                                                            1,
                                                            0,
                                                          ]),
                                                      child: buildImageWidget(),
                                                    )
                                                  : buildImageWidget(),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),



                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 300),
                              opacity: isVisible ? 1.0 : 0.0,
                              child: ViewerTopBar(
                                title: _currentItem.name,
                                metadata: _navigationController.indexString != null
                                    ? '${_navigationController.indexString} • ${_metadata ?? ''}'
                                    : _metadata,
                                isStandalone:
                                    widget.isStandalone ||
                                    widget.windowId != null,
                                onPopOut: _openInNewWindow,
                                onClose: () =>
                                    ref
                                            .read(previewFileProvider.notifier)
                                            .state =
                                        null,
                                extraActions: [
                                  if (!_isEmpty) ...[
                                    if (!_isNetworkStream)
                                      Consumer(
                                        builder: (context, ref, _) {
                                          final favorites = ref.watch(
                                            imageFavoritesProvider,
                                          );
                                          final isFavorite = favorites.contains(
                                            _currentItem.path,
                                          );
                                          return _buildTopBarButton(
                                            icon: isFavorite
                                                ? Icons.favorite_rounded
                                                : Icons.favorite_border_rounded,
                                            onPressed: () {
                                              ref
                                                  .read(
                                                    imageFavoritesProvider
                                                        .notifier,
                                                  )
                                                  .toggleFavorite(
                                                    _currentItem.path,
                                                  );
                                            },
                                            tooltip: 'Toggle Favorite',
                                            active: isFavorite,
                                          );
                                        },
                                      ),
                                    if (!_isNetworkStream)
                                      const SizedBox(width: 8),
                                    if (!_isNetworkStream)
                                      _buildTopBarButton(
                                        icon: _hudController.isEditing
                                            ? Icons.edit_rounded
                                            : Icons.edit_outlined,
                                        onPressed: _hudController.toggleEditing,
                                        tooltip: 'Edit Image',
                                        active: _hudController.isEditing,
                                      ),
                                    if (!_isNetworkStream)
                                      const SizedBox(width: 8),
                                    _buildTopBarButton(
                                      icon: Icons.settings_rounded,
                                      onPressed: () => SettingsDialog.show(
                                        context,
                                        initialTab: 1,
                                        section: 'Image',
                                      ),
                                      tooltip: 'Image Settings',
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                ],
                              ),
                            ),
                          ),

                          if (_hudController.isEditing && isVisible)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: ImageEditingPanel(
                                rotationAngle: _rotationAngle,
                                brightness: _brightness,
                                onRotationChanged: (val) => setState(() => _rotationAngle = val),
                                onBrightnessChanged: (val) => setState(() => _brightness = val),
                              ),
                            ),

                          if (isVisible)
                            Positioned(
                              bottom: 32,
                              left: 32,
                              child: Consumer(
                                builder: (context, sidebarRef, _) {
                                  final isSidebarOpen = sidebarRef.watch(
                                    imagePlaylistSidebarVisibleProvider,
                                  );
                                  return AnimatedOpacity(
                                    duration: const Duration(milliseconds: 200),
                                    opacity: isVisible ? 1.0 : 0.0,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.playlist_play,
                                        size: 24,
                                      ),
                                      color: _isNetworkStream
                                          ? Colors.white30
                                          : (isSidebarOpen
                                                ? AppColors.magenta
                                                : Colors.white),
                                      onPressed: _isNetworkStream
                                          ? null
                                          : () {
                                              sidebarRef
                                                      .read(
                                                        imagePlaylistSidebarVisibleProvider
                                                            .notifier,
                                                      )
                                                      .state =
                                                  !isSidebarOpen;
                                            },
                                      tooltip: 'Playlist',
                                    ),
                                  );
                                },
                              ),
                            ),

                          if (_hudController.showZoomIndicator)
                            Positioned(
                              bottom: 32,
                              right: 32,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: _hudController.showZoomIndicator ? 1.0 : 0.0,
                                child: ImageZoomIndicator(scale: _currentScale),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
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
        color: active
            ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
            : Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: active
            ? Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5))
            : null,
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: active ? const Color(0xFF00E5FF) : Colors.white,
          size: 20,
        ),
        onPressed: onPressed,
        tooltip: tooltip,
        splashRadius: 24,
      ),
    );
  }




}
