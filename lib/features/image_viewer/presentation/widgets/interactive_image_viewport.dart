import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_gesture_handler.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_hud_controller.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_zoom_controller.dart';

class InteractiveImageViewport extends ConsumerWidget {
  const InteractiveImageViewport({
    required this.zoomController,
    required this.gestureHandler,
    required this.hudController,
    required this.isStandalone,
    required this.onDoubleTapPopOut,
    required this.focusNode,
    required this.isReadyForInteraction,
    required this.child,
    super.key,
    this.windowId,
  });

  final ImageZoomController zoomController;
  final ImageGestureHandler gestureHandler;
  final ImageHudController hudController;
  final bool isStandalone;
  final int? windowId;
  final VoidCallback onDoubleTapPopOut;
  final FocusNode focusNode;
  final bool isReadyForInteraction;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListenableBuilder(
      listenable: zoomController,
      builder: (context, _) {
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerSignal: gestureHandler.handlePointerSignal,
          onPointerPanZoomStart: gestureHandler.handlePanZoomStart,
          onPointerPanZoomEnd: gestureHandler.handlePanZoomEnd,
          onPointerPanZoomUpdate: gestureHandler.handlePanZoomUpdate,
          child: InteractiveViewer(
            transformationController: zoomController.transformationController,
            minScale: 1,
            maxScale: 15,
            panEnabled: !zoomController.isPanZoomGesture && (isReadyForInteraction || isStandalone),
            scaleEnabled: false,
            child: GestureDetector(
              onTap: () {
                focusNode.requestFocus();
                hudController.toggleControls();
              },
              onDoubleTap: windowId == null
                  ? onDoubleTapPopOut
                  : () => zoomController.setZoom(1, focalPoint: Offset.zero),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
