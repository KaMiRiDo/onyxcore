import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/playlist/media_queue_isolate.dart';
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
import 'package:onyxcore/features/image_viewer/presentation/providers/image_playlist_providers.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_playlist_sidebar.dart';
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
  bool _isClosing = false;
  bool _isEmpty = false;
  bool _isEmptyAtEnd = true;

  bool get _isNetworkStream => widget.initParams?['is_network_stream'] == true;

  String? _metadata;
  String? _indexString;
  bool _isControlsVisible = true;
  bool _isEditing = false;
  Timer? _hideTimer;
  Timer? _zoomTimer;
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
  bool _showZoomIndicator = false;

  late AnimationController _zoomAnimationController;
  Animation<Matrix4>? _zoomAnimation;
  Timer? _navigationThrottleTimer;
  Size? _imageSize;
  ImageStream? _imageStream;

  // Image Edit State
  double _rotationAngle = 0;
  double _brightness = 0;

  bool _isGlobalHudVisible = true;
  bool _isLoading = true;
  Offset? _lastMousePos;
  final Completer<void> _firstFrameCompleter = Completer<void>();
  DateTime? _lastNavTime;
  bool _isReadyForInteraction = false;

  late FileItem _currentItem;

  String? _convertedHeicPath;
  bool _isConvertingHeic = false;

  List<FileItem> _standalonePlaylist = [];

  Future<void> _initStandalonePlaylist() async {
    try {
      final images = <FileItem>[];

      if (widget.initParams != null &&
          widget.initParams!['playlistPaths'] != null) {
        final paths = List<String>.from(
          widget.initParams!['playlistPaths'] as Iterable,
        );
        for (final path in paths) {
          final file = File(path);
          if (file.existsSync()) {
            final name = p.basename(path);
            try {
              final stat = await file.stat();
              images.add(
                FileItem(
                  name: name,
                  path: path,
                  type: FileItemType.image,
                  sizeBytes: stat.size,
                  modified: stat.modified,
                ),
              );
            } catch (e) {
              debugPrint('Error stating file $path: $e');
            }
          }
        }
      } else {
        final absolutePath = File(_currentItem.path).absolute.path;
        final parentDir = File(absolutePath).parent;
        if (!parentDir.existsSync()) return;

        final entities = await parentDir.list().toList();

        for (final entity in entities) {
          debugPrint('Found entity: ${entity.path}');
          if (FileSystemEntity.isFileSync(entity.path)) {
            final name = p.basename(entity.path);
            if (classifyFileType(name) == FileItemType.image) {
              try {
                final stat = await entity.stat();
                images.add(
                  FileItem(
                    name: name,
                    path: entity.path,
                    type: FileItemType.image,
                    sizeBytes: stat.size,
                    modified: stat.modified,
                  ),
                );
              } catch (e) {
                debugPrint('Error stating file ${entity.path}: $e');
              }
            }
          }
        }

        images.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      }

      debugPrint('Added ${images.length} images to standalone playlist');
      if (mounted) {
        setState(() {
          _standalonePlaylist = images;
        });
        ref.read(imageQueueProvider.notifier).state = _standalonePlaylist;
        unawaited(_updateIndexData());
      }
    } catch (e) {
      debugPrint('[ImagePreviewWidget] Error in _initStandalonePlaylist: $e');
    }
  }

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

  void _resolveImageSize() {
    if (_currentItem.path.endsWith('.svg')) return;
    final provider = FileImage(File(_currentItem.path));
    _imageStream?.removeListener(ImageStreamListener(_updateImage));
    _imageStream = provider.resolve(ImageConfiguration.empty);
    _imageStream!.addListener(ImageStreamListener(_updateImage));
  }

  void _updateImage(ImageInfo info, bool synchronousCall) {
    if (mounted) {
      setState(() {
        _imageSize = Size(
          info.image.width.toDouble(),
          info.image.height.toDouble(),
        );
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _currentItem = widget.item;
    _resolveImageSize();
    if (widget.isStandalone && widget.windowId != null) {
      PersistentViewerManager.getFocusTrigger(
        int.parse(widget.windowId!),
      ).addListener(_onWindowFocus);
    }
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

    _isGlobalHudVisible = ref.read(previewHudVisibleProvider);
    if (widget.windowId != null) {
      // In the new Multi-View architecture, we do NOT use window_manager for standalone windows
      // because window_manager only controls the primary application window.
    }
    _loadMetadata();
    _updateIndexData();
    _startHideTimer();
    _loadSpecialImageIfNecessary();

    if (widget.isStandalone) {
      _initStandalonePlaylist();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(previewFileProvider.notifier).state = _currentItem;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(imageIsEmptyProvider.notifier).state = false;
        final parentPath = p.dirname(_currentItem.path);
        final currentRoot = ref.read(imageRootPathProvider);
        if (currentRoot.isEmpty || !parentPath.startsWith(currentRoot)) {
          ref.read(imageRootPathProvider.notifier).state = parentPath;
        }
        ref.read(imageCurrentPathProvider.notifier).state = parentPath;
        _precacheAdjacentImages();
        _focusNode.requestFocus();

        // On Linux/GTK, newly spawned windows may take a moment to be mapped by the OS.
        // A delayed focus request ensures the widget grabs focus after the window is fully active.
        Future.delayed(const Duration(milliseconds: 300), () async {
          if (mounted) {
            if (widget.isStandalone && widget.windowId != null) {
              await PersistentViewerManager.presentWindow(
                int.parse(widget.windowId!),
              );
            }
            if (mounted) _focusNode.requestFocus();
          }
        });

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
    var pathsToPreload = <String>[];

    if (widget.isStandalone &&
        widget.initParams != null &&
        widget.initParams!['preloadPaths'] != null) {
      final preloadList = widget.initParams!['preloadPaths'] as List<dynamic>;
      pathsToPreload = preloadList.map((e) => e.toString()).toList();
    } else if (!widget.isStandalone && widget.windowId == null) {
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
            pathsToPreload.add(
              mediaItems[(currentIndex + i) % mediaItems.length].path,
            );
            pathsToPreload.add(
              mediaItems[(currentIndex - i + mediaItems.length) %
                      mediaItems.length]
                  .path,
            );
          }
        }
      }
    }

    for (final path in pathsToPreload) {
      if (path != _currentItem.path && !path.toLowerCase().endsWith('.svg')) {
        final pLower = path.toLowerCase();
        final isSpecial =
            pLower.endsWith('.heic') ||
            pLower.endsWith('.heif') ||
            pLower.endsWith('.avif') ||
            pLower.endsWith('.dng') ||
            pLower.endsWith('.raw');

        if (isSpecial) {
          // Pre-trigger background conversion for special images, do not natively precache them.
          unawaited(
            SpecialImageConverter.convertIfNecessary(path).then((
              convertedPath,
            ) {
              if (mounted && convertedPath != null) {
                precacheImage(
                  FileImage(File(convertedPath)),
                  context,
                  onError: (e, s) => debugPrint(
                    'Failed to precache converted image $convertedPath: $e',
                  ),
                );
              }
            }),
          );
        } else {
          precacheImage(
            _getImageProvider(path),
            context,
            onError: (e, s) {
              debugPrint('Failed to precache image $path: $e');
            },
          );
        }
      }
    }
  }

  ImageProvider _getImageProvider(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return NetworkImage(path);
    }
    return FileImage(File(path));
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

  Future<void> _updateIndexData() async {
    final useInitParams =
        widget.windowId != null &&
        widget.initParams != null &&
        widget.initParams!['currentIndex'] != null &&
        !(widget.isStandalone && _standalonePlaylist.isNotEmpty);

    if (useInitParams) {
      if (mounted) {
        setState(() {
          _indexString =
              '${widget.initParams!['currentIndex']}/${widget.initParams!['totalCount']}';
        });
      }
    } else {
      var mediaItems = widget.isStandalone
          ? _standalonePlaylist
          : ref
                .read(filteredAndSortedImageQueueProvider)
                .where((i) => i.type == FileItemType.image)
                .toList();
      if (mediaItems.isEmpty && !widget.isStandalone) {
        final items = ref.read(sortedDirectoryItemsProvider).value ?? [];
        mediaItems = items.where((i) => i.type == FileItemType.image).toList();
      }
      final currentIndex =
          mediaItems.indexWhere((i) => i.path == _currentItem.path) + 1;
      final totalCount = mediaItems.length;
      if (currentIndex > 0 && mounted) {
        setState(() {
          _indexString = '$currentIndex/$totalCount';
        });
      }
    }
  }

  Future<void> _loadMetadata() async {
    final file = File(_currentItem.path);
    if (!file.existsSync()) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final isSvg = _currentItem.path.toLowerCase().endsWith('.svg');
      if (isSvg) {
        setState(() {
          _metadata = 'Vector Graphic • Scalable';
          _isLoading = false;
        });
        return;
      }

      if (!_firstFrameCompleter.isCompleted) {
        await _firstFrameCompleter.future;
      } else {
        await Future<void>.delayed(Duration.zero);
      }

      if (!mounted) return;

      final imageProvider = _getImageProvider(_currentItem.path);
      final completer = Completer<ImageInfo>();
      final stream = imageProvider.resolve(
        createLocalImageConfiguration(context),
      );

      final listener = ImageStreamListener(
        (info, _) {
          if (!completer.isCompleted) completer.complete(info);
        },
        onError: (dynamic error, StackTrace? stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(error as Object, stackTrace);
          }
        },
      );

      stream.addListener(listener);
      final info = await completer.future.timeout(const Duration(seconds: 1));
      stream.removeListener(listener);

      final image = info.image;

      if (mounted) {
        final mp = (image.width * image.height / 1000000).toStringAsFixed(1);
        setState(() {
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
    _imageStream?.removeListener(ImageStreamListener(_updateImage));
    _navigationThrottleTimer?.cancel();
    if (widget.windowId != null) {
      windowManager.removeListener(this);
    }
    _hideTimer?.cancel();
    _zoomTimer?.cancel();
    if (widget.isStandalone && widget.windowId != null) {
      PersistentViewerManager.getFocusTrigger(
        int.parse(widget.windowId!),
      ).removeListener(_onWindowFocus);
    }
    _focusNode.dispose();
    _transformationController.dispose();
    _zoomAnimationController.dispose();
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    if (_isClosing) return;
    _isClosing = true;

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
    _resolveImageSize();
    _zoomAnimationController.stop();
    _transformationController.value = Matrix4.identity();
    setState(() {
      _currentItem = item;
      _isLoading = true;
      _isEmpty = false;
      _rotationAngle = 0.0;
      _brightness = 0.0;
      _currentScale = 1.0;
      _isPanZoomGesture = false;
      _mousePosition = Offset.zero;
      _isControlsVisible = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(imageIsEmptyProvider.notifier).state = false;
        ref.read(previewFileProvider.notifier).state = item;
      }
    });
    _loadMetadata();
    _updateIndexData();
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
    _precacheAdjacentImages();
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

  void _navigateMedia(bool forward) {
    if (_navigationThrottleTimer?.isActive ?? false) return;
    _navigationThrottleTimer = Timer(const Duration(milliseconds: 300), () {});

    // IPC removed, falling back to local state
    var mediaItems = widget.isStandalone
        ? _standalonePlaylist
        : ref
              .read(filteredAndSortedImageQueueProvider)
              .where((i) => i.type == FileItemType.image)
              .toList();
    if (mediaItems.isEmpty && !widget.isStandalone) {
      final items = ref.read(sortedDirectoryItemsProvider).value ?? [];
      mediaItems = items.where((i) => i.type == FileItemType.image).toList();
    }
    if (mediaItems.isEmpty) return;

    final currentIndex = mediaItems.indexWhere(
      (i) => i.path == _currentItem.path,
    );
    if (currentIndex == -1) {
      setState(() {
        _isEmpty = true;
        _isEmptyAtEnd = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(imageIsEmptyProvider.notifier).state = true;
      });
      return;
    }

    if (_isEmpty) {
      if (_isEmptyAtEnd && forward) return;
      if (!_isEmptyAtEnd && !forward) return;

      // Recover from empty state
      setState(() => _isEmpty = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(imageIsEmptyProvider.notifier).state = false;
        }
      });
      _openFile(mediaItems[currentIndex]);
      return;
    }

    int nextIndex;
    if (forward) {
      if (currentIndex == mediaItems.length - 1) {
        setState(() {
          _isEmpty = true;
          _isEmptyAtEnd = true;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(imageIsEmptyProvider.notifier).state = true;
        });
        return;
      }
      nextIndex = currentIndex + 1;
    } else {
      if (currentIndex == 0) {
        setState(() {
          _isEmpty = true;
          _isEmptyAtEnd = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(imageIsEmptyProvider.notifier).state = true;
        });
        return;
      }
      nextIndex = currentIndex - 1;
    }

    _openFile(mediaItems[nextIndex]);
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

    FileItem? nextItem;
    var hasMultiple = false;

    if (widget.isStandalone) {
      // Handled natively or safely ignored
    } else {
      var mediaItems = ref
          .read(filteredAndSortedImageQueueProvider)
          .where((i) => i.type == FileItemType.image)
          .toList();
      if (mediaItems.isEmpty) {
        final items = ref.read(sortedDirectoryItemsProvider).value ?? [];
        mediaItems = items.where((i) => i.type == FileItemType.image).toList();
      }
      if (mediaItems.length > 1) {
        hasMultiple = true;
        final currentIndex = mediaItems.indexWhere(
          (i) => i.path == _currentItem.path,
        );
        if (currentIndex != -1) {
          final nextIndex = (currentIndex + 1) % mediaItems.length;
          nextItem = mediaItems[nextIndex];
        }
      }
    }

    if (widget.isStandalone) {
      if (!hasMultiple) {
        await windowManager.hide();
      }
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
    ref.listen(imageRestartSignalProvider, (previous, next) {
      if (_isEmpty) {
        setState(() => _isEmpty = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(imageIsEmptyProvider.notifier).state = false;
        });
      }
    });

    if (widget.windowId == null && !widget.isStandalone) {
      ref.listen(previewHudVisibleProvider, (previous, next) {
        if (mounted) {
          setState(() => _isGlobalHudVisible = next);
        }
      });
    }

    final isVisible =
        _isControlsVisible &&
        (widget.windowId != null || widget.isStandalone || _isGlobalHudVisible);

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent || event is KeyRepeatEvent) {
          final ctrl = HardwareKeyboard.instance.isControlPressed;
          final alt = HardwareKeyboard.instance.isAltPressed;

          if (event.logicalKey == LogicalKeyboardKey.keyF) {
            if (widget.windowId != null && event is KeyDownEvent) {
              _toggleFullscreen();
              return KeyEventResult.handled;
            }
          }

          final isCloseShortcut =
              (ctrl && event.logicalKey == LogicalKeyboardKey.keyW) ||
              event.logicalKey == LogicalKeyboardKey.backspace ||
              (alt && event.logicalKey == LogicalKeyboardKey.arrowLeft);

          if (isCloseShortcut) {
            if (widget.windowId == null && event is KeyDownEvent) {
              ref.read(previewFileProvider.notifier).state = null;
              return KeyEventResult.handled;
            }
          }

          if (event.logicalKey == LogicalKeyboardKey.delete &&
              event is KeyDownEvent) {
            final shift = HardwareKeyboard.instance.isShiftPressed;
            _handleDelete(permanent: shift);
            return KeyEventResult.handled;
          }

          if (event.logicalKey == LogicalKeyboardKey.keyP &&
              HardwareKeyboard.instance.isControlPressed &&
              HardwareKeyboard.instance.isShiftPressed) {
            if (event is KeyDownEvent) {
              final isOpen = ref.read(imagePlaylistSidebarVisibleProvider);
              ref.read(imagePlaylistSidebarVisibleProvider.notifier).state =
                  !isOpen;
            }
            return KeyEventResult.handled;
          }

          if (ctrl) {
            if (event.logicalKey == LogicalKeyboardKey.equal ||
                event.logicalKey == LogicalKeyboardKey.add) {
              _setZoom(_currentScale + 0.2);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.minus ||
                event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
              _setZoom(_currentScale - 0.2);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.digit0) {
              _setZoom(1);
              return KeyEventResult.handled;
            }
          }

          if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
              event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft &&
                HardwareKeyboard.instance.isAltPressed) {
              // Ignore Alt+Left as it's used for back navigation
            } else {
              final forward = event.logicalKey == LogicalKeyboardKey.arrowRight;
              if (event is KeyRepeatEvent) {
                final now = DateTime.now();
                if (_lastNavTime != null &&
                    now.difference(_lastNavTime!).inMilliseconds < 300) {
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
                (isAltPressed &&
                    (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                        event.logicalKey == LogicalKeyboardKey.arrowRight))) {
              final isSidebarOpen = ref.read(
                imagePlaylistSidebarVisibleProvider,
              );
              if (isSidebarOpen && isAltPressed) {
                if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                  _navigatePlaylistHistoryBack(ref);
                } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                  _navigatePlaylistHistoryForward(ref);
                }
              }
              return KeyEventResult.handled; // Consume to prevent navigation
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
                            Positioned.fill(child: _buildEmptyState())
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
                                      setState(() {
                                        _isControlsVisible =
                                            !_isControlsVisible;
                                        if (_isControlsVisible) {
                                          _startHideTimer();
                                        }
                                      });
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
                                                ? SvgPicture.network(imagePath)
                                                : SvgPicture.file(
                                                    File(imagePath),
                                                  );
                                          } else {
                                            return isNetwork
                                                ? Image.network(
                                                    imagePath,
                                                    fit: BoxFit.contain,
                                                    filterQuality:
                                                        (_isInteracting ||
                                                            _isPanZoomGesture ||
                                                            _zoomAnimationController
                                                                .isAnimating)
                                                        ? FilterQuality.low
                                                        : FilterQuality.high,
                                                  )
                                                : Image.file(
                                                    File(imagePath),
                                                    fit: BoxFit.contain,
                                                    filterQuality:
                                                        (_isInteracting ||
                                                            _isPanZoomGesture ||
                                                            _zoomAnimationController
                                                                .isAnimating)
                                                        ? FilterQuality.low
                                                        : FilterQuality.high,
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

                          if (_isLoading)
                            const IgnorePointer(
                              child: Center(child: BubbleLoader()),
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
                                metadata: _indexString != null
                                    ? '$_indexString • ${_metadata ?? ''}'
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
                                        icon: _isEditing
                                            ? Icons.edit_rounded
                                            : Icons.edit_outlined,
                                        onPressed: () => setState(
                                          () => _isEditing = !_isEditing,
                                        ),
                                        tooltip: 'Edit Image',
                                        active: _isEditing,
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

                          if (_isEditing && isVisible)
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: _buildEditingPanel(),
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

                          if (_showZoomIndicator)
                            Positioned(
                              bottom: 32,
                              right: 32,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 200),
                                opacity: _showZoomIndicator ? 1.0 : 0.0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.1,
                                      ),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: BackdropFilter(
                                      filter: ui.ImageFilter.blur(
                                        sigmaX: 10,
                                        sigmaY: 10,
                                      ),
                                      child: Text(
                                        '${(_currentScale * 100).toInt()}%',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white.withValues(
                                            alpha: 0.9,
                                          ),
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

  Widget _buildEditingPanel() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildControlLabel(
              Icons.rotate_right,
              'Rotation: ${_rotationAngle.toInt()}°',
            ),
            Slider(
              value: _rotationAngle,
              min: -180,
              max: 180,
              activeColor: const Color(0xFF00E5FF),
              inactiveColor: Colors.white10,
              onChanged: (val) => setState(() => _rotationAngle = val),
            ),
            const SizedBox(height: 8),
            _buildControlLabel(Icons.brightness_6, 'Brightness'),
            Slider(
              value: _brightness,
              min: -1,
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

  Widget _buildEmptyState() {
    return ColoredBox(
      color: const Color(0xFF121212),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_rounded,
              size: 64,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No more images to view.',
              style: GoogleFonts.manrope(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigatePlaylistHistoryBack(WidgetRef ref) {
    final history = ref.read(imagePathHistoryProvider);
    if (history.isNotEmpty) {
      final newPath = history.last;
      final currentPath = ref.read(imageCurrentPathProvider);

      ref.read(imagePathHistoryProvider.notifier).state = history.sublist(
        0,
        history.length - 1,
      );
      ref
          .read(imagePathForwardHistoryProvider.notifier)
          .update((state) => [...state, currentPath]);

      _openPlaylistFolder(ref, newPath);
    }
  }

  void _navigatePlaylistHistoryForward(WidgetRef ref) {
    final forwardHistory = ref.read(imagePathForwardHistoryProvider);
    if (forwardHistory.isNotEmpty) {
      final newPath = forwardHistory.last;
      final currentPath = ref.read(imageCurrentPathProvider);

      ref.read(imagePathForwardHistoryProvider.notifier).state = forwardHistory
          .sublist(0, forwardHistory.length - 1);
      ref
          .read(imagePathHistoryProvider.notifier)
          .update((state) => [...state, currentPath]);

      _openPlaylistFolder(ref, newPath);
    }
  }

  Future<void> _openPlaylistFolder(WidgetRef ref, String path) async {
    final repo = ref.read(directoryRepositoryProvider);
    final showHidden = ref.read(imageShowHiddenProvider);
    try {
      final items = await repo.listDirectory(path);
      final mediaFiles = await compute(processMediaQueueIsolate, {
        'items': items.map((e) => e.toJson()).toList(),
        'showHidden': showHidden,
        'targetType': FileItemType.image.index,
      });

      if (!mounted) return;
      ref.read(imageQueueProvider.notifier).state = mediaFiles;
      ref.read(imageCurrentPathProvider.notifier).state = path;
    } catch (_) {}
  }
}
