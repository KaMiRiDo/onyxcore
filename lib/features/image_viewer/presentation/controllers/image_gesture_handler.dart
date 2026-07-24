import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_zoom_controller.dart';

class ImageGestureHandler {
  ImageGestureHandler({required this.zoomController});

  final ImageZoomController zoomController;

  void handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final ctrl = HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.logicalKeysPressed
              .contains(LogicalKeyboardKey.controlLeft) ||
          HardwareKeyboard.instance.logicalKeysPressed
              .contains(LogicalKeyboardKey.controlRight);
      
      if (ctrl) {
        final delta = event.scrollDelta.dy;
        if (delta != 0) {
          final zoomFactor = delta > 0 ? 1.05 : 0.95;
          zoomController.setZoom(
            zoomController.currentScale * zoomFactor,
            focalPoint: event.localPosition,
            animate: false,
          );
        }
      } else if (zoomController.currentScale > 1.05) {
        // Handle trackpad two-finger drag (panning via scroll)
        final delta = event.scrollDelta;
        const sensitivity = 5;
        zoomController.applyTranslation(
          Offset(-delta.dx * sensitivity, -delta.dy * sensitivity)
        );
      }
    }
  }

  void handlePanZoomStart(PointerPanZoomStartEvent event) {
    zoomController.startPanZoomGesture(event.localPosition);
  }

  void handlePanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final ctrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.logicalKeysPressed
            .contains(LogicalKeyboardKey.controlLeft) ||
        HardwareKeyboard.instance.logicalKeysPressed
            .contains(LogicalKeyboardKey.controlRight);

    if (ctrl) {
      // Zoom via trackpad pinch while holding ctrl (often maps to panDelta)
      final dy = event.panDelta.dy;
      if (dy != 0) {
        zoomController.updateScrubGesture(dy, event.localPosition);
      }
    } else {
      if (event.scale != 1.0) {
        zoomController.updatePinchGesture(event.scale, event.localPosition);
      } else if (event.panDelta != Offset.zero && zoomController.currentScale > 1.05) {
        zoomController.applyTranslation(event.panDelta);
      }
    }
  }

  void handlePanZoomEnd(PointerPanZoomEndEvent event) {
    zoomController.endPanZoomGesture();
  }
}
