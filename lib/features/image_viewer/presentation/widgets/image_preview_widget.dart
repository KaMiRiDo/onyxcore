import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/widgets/viewer_top_bar.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/dialogs.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_gesture_handler.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_hud_controller.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_keyboard_handler.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_navigation_controller.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_preparation_controller.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_viewer_lifecycle.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_zoom_controller.dart';
import 'package:onyxcore/features/image_viewer/presentation/engines/zoom_animation_engine.dart';
import 'package:onyxcore/features/image_viewer/presentation/providers/image_playlist_providers.dart';
import 'package:onyxcore/features/image_viewer/presentation/services/image_metadata_loader.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_canvas.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_editing_panel.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_empty_state.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_playlist_sidebar.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_zoom_indicator.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/interactive_image_viewport.dart';
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
  late final ImagePreparationController _preparationController;

  final FocusNode _focusNode = FocusNode();
  Offset _mousePosition = Offset.zero;

  late AnimationController _zoomAnimationController;
  late ZoomAnimationEngine _zoomAnimationEngine;
  late ImageZoomController _imageZoomController;
  late ImageGestureHandler _imageGestureHandler;

  late ImageNavigationController _navigationController;
  late ImageKeyboardHandler _keyboardHandler;
  late ImageViewerLifecycle _lifecycle;
  Size? _imageSize;

  // Image Edit State
  double _rotationAngle = 0;
  double _brightness = 0;

  bool _isGlobalHudVisible = true;
  Offset? _lastMousePos;
  bool _isReadyForInteraction = false;

  late FileItem _currentItem;



  void _onWindowFocus() {
    if (mounted) _focusNode.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    _hudController = ImageHudController()
      ..addListener(() {
        if (mounted) setState(() {});
      });
    _preparationController = ImagePreparationController()
      ..addListener(() {
        if (mounted) {
          setState(() {});
          if (!_preparationController.isConverting && _preparationController.preparedPath != null) {
            _loadMetadata();
          }
        }
      });
    _navigationController =
        ImageNavigationController(
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
      onDelete: _handleDelete,
      onToggleSidebar: () {
        final isOpen = ref.read(imagePlaylistSidebarVisibleProvider);
        ref.read(imagePlaylistSidebarVisibleProvider.notifier).state = !isOpen;
      },
      onZoomIn: () => _imageZoomController.setZoom(
        _imageZoomController.currentScale + 0.2,
        focalPoint: _getFocalPoint(),
      ),
      onZoomOut: () => _imageZoomController.setZoom(
        _imageZoomController.currentScale - 0.2,
        focalPoint: _getFocalPoint(),
      ),
      onResetZoom: () =>
          _imageZoomController.setZoom(1, focalPoint: _getFocalPoint()),
      onNavigateForward: ({required bool isKeyRepeat}) => _navigateMedia(true),
      onNavigateBackward: ({required bool isKeyRepeat}) =>
          _navigateMedia(false),
      onNavigateHistoryForward: () =>
          _navigationController.navigatePlaylistHistoryForward(),
      onNavigateHistoryBackward: () =>
          _navigationController.navigatePlaylistHistoryBack(),
      onToggleFullscreen: _toggleFullscreen,
      isSidebarOpen: () => ref.read(imagePlaylistSidebarVisibleProvider),
      isStandalone: widget.isStandalone,
      isWindowed: widget.windowId != null,
    );

    _currentItem = widget.item;
    _zoomAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _zoomAnimationEngine = ZoomAnimationEngine(
      animationController: _zoomAnimationController,
      onTick: (matrix) {
        _imageZoomController.onAnimationTick(matrix);
      },
    );

    _imageZoomController = ImageZoomController(
      animationEngine: _zoomAnimationEngine,
      onZoomChanged: _onZoomChanged,
    );

    _imageGestureHandler = ImageGestureHandler(
      zoomController: _imageZoomController,
    );

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
    _preparationController.prepare(_currentItem.path);

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

  void _onZoomChanged() {
    if (!mounted) return;
    setState(() {
      if (_imageZoomController.currentScale > 1.0) {
        _hudController
          ..showZoomIndicatorForDuration()
          ..hideControls();
      }
    });
  }

  Offset _getFocalPoint() {
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
    final path = _preparationController.preparedPath ?? _currentItem.path;
    final result = await ImageMetadataLoader.load(
      path,
      context,
      _lifecycle.firstFrame,
    );

    if (mounted) {
      setState(() {
        if (result.metadataString != null) {
          _metadata = result.metadataString;
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
    _zoomAnimationEngine.dispose();
    _zoomAnimationController.dispose();
    _imageZoomController.dispose();
    _focusNode.dispose();
    _preparationController.dispose();
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
    _imageZoomController.reset();
    setState(() {
      _currentItem = item;
      _isEmpty = false;
      _rotationAngle = 0.0;
      _brightness = 0.0;
      _mousePosition = Offset.zero;
      _hudController.hideControls();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(imageIsEmptyProvider.notifier).state = false;
        ref.read(previewFileProvider.notifier).state = item;
      }
    });
    _preparationController.prepare(item.path);
    _loadMetadata();
    _navigationController.updateIndexData(item);
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
            preloadPaths
              ..add(mediaItems[(currentIndex + i) % mediaItems.length].path)
              ..add(
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
        // Evict from flutter image cache to prevent stale views
        final provider = _currentItem.path.startsWith('http') 
            ? NetworkImage(_currentItem.path) 
            : FileImage(File(_currentItem.path)) as ImageProvider;
        await provider.evict();
        await ResizeImage(provider, width: 3840).evict();

        repo.invalidateCache(currentPath);
        ref.read(refreshCountProvider.notifier).state =
            ref.read(refreshCountProvider) + 1;
        unawaited(ref.read(directoryItemsProvider.notifier).refresh());
      }

      _navigationController.navigateAfterDeletion(_currentItem);
    }
  }

  KeyEventResult _handleKeyEvent(KeyEvent event) {
    if (_imageZoomController.isInteracting) return KeyEventResult.ignored;
    return _keyboardHandler.handleKeyEvent(event);
  }

  @override
  Widget build(BuildContext context) {
    _imageZoomController.updateConstraints(
      MediaQuery.of(context).size,
      _imageSize,
    );

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
              _imageZoomController.setIsInteracting(true);
            },
            onPointerUp: (event) {
              _imageZoomController.setIsInteracting(false);
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
                              child: InteractiveImageViewport(
                                zoomController: _imageZoomController,
                                gestureHandler: _imageGestureHandler,
                                hudController: _hudController,
                                isStandalone: widget.isStandalone,
                                windowId: widget.windowId == null
                                    ? null
                                    : int.tryParse(widget.windowId!),
                                onDoubleTapPopOut: _openInNewWindow,
                                focusNode: _focusNode,
                                isReadyForInteraction: _isReadyForInteraction,
                                child: ImageCanvas(
                                  imagePath: _preparationController.preparedPath ?? _currentItem.path,
                                  heroTag: _currentItem.path,
                                  isConverting: _preparationController.isConverting,
                                  rotationAngle: _rotationAngle,
                                  brightness: _brightness,
                                  isHighFrequencyInteractionActive: _imageZoomController.isInteracting ||
                                      _imageZoomController.isPanZoomGesture ||
                                      _zoomAnimationController.isAnimating,
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
                                metadata:
                                    _navigationController.indexString != null
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
                                onRotationChanged: (val) =>
                                    setState(() => _rotationAngle = val),
                                onBrightnessChanged: (val) =>
                                    setState(() => _brightness = val),
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
                                opacity: _hudController.showZoomIndicator
                                    ? 1.0
                                    : 0.0,
                                child: ImageZoomIndicator(
                                  scale: _imageZoomController.currentScale,
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
}
