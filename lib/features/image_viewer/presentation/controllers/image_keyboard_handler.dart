import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class ImageKeyboardHandler {

  ImageKeyboardHandler({
    required this.onClose,
    required this.onDelete,
    required this.onToggleSidebar,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetZoom,
    required this.onNavigateForward,
    required this.onNavigateBackward,
    required this.onNavigateHistoryForward,
    required this.onNavigateHistoryBackward,
    required this.onToggleFullscreen,
    required this.isSidebarOpen,
    required this.isStandalone,
    required this.isWindowed,
  });
  final VoidCallback onClose;
  final void Function({required bool permanent}) onDelete;
  final VoidCallback onToggleSidebar;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetZoom;
  final void Function({required bool isKeyRepeat}) onNavigateForward;
  final void Function({required bool isKeyRepeat}) onNavigateBackward;
  final VoidCallback onNavigateHistoryForward;
  final VoidCallback onNavigateHistoryBackward;
  final VoidCallback onToggleFullscreen;
  final bool Function() isSidebarOpen;
  final bool isStandalone;
  final bool isWindowed;

  DateTime? _lastNavTime;

  KeyEventResult handleKeyEvent(KeyEvent event) {
    final ctrl = HardwareKeyboard.instance.isControlPressed;
    final alt = HardwareKeyboard.instance.isAltPressed;
    final shift = HardwareKeyboard.instance.isShiftPressed;

    final isCloseShortcut = 
        (ctrl && event.logicalKey == LogicalKeyboardKey.keyW) ||
        event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.backspace ||
        (alt && event.logicalKey == LogicalKeyboardKey.arrowLeft);

    if (event.logicalKey == LogicalKeyboardKey.keyF) {
      if (isWindowed && event is KeyDownEvent) {
        onToggleFullscreen();
        return KeyEventResult.handled;
      }
    }

    if (isCloseShortcut) {
      if (!isWindowed && event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.backspace ||
            (alt && (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                event.logicalKey == LogicalKeyboardKey.arrowRight))) {
          if (isSidebarOpen() && alt) {
            if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              onNavigateHistoryBackward();
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              onNavigateHistoryForward();
            }
            return KeyEventResult.handled; // Consume to prevent navigation
          }
        }
        
        if (event.logicalKey == LogicalKeyboardKey.escape || 
            (event.logicalKey == LogicalKeyboardKey.backspace && !alt)) {
          onClose();
          return KeyEventResult.handled;
        }
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.delete &&
        event is KeyDownEvent) {
      onDelete(permanent: shift);
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.keyP && ctrl && shift) {
      if (event is KeyDownEvent) {
        onToggleSidebar();
      }
      return KeyEventResult.handled;
    }

    if (ctrl) {
      if (event.logicalKey == LogicalKeyboardKey.equal ||
          event.logicalKey == LogicalKeyboardKey.add) {
        onZoomIn();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.minus ||
          event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
        onZoomOut();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.digit0) {
        onResetZoom();
        return KeyEventResult.handled;
      }
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft && alt) {
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
          if (forward) {
            onNavigateForward(isKeyRepeat: true);
          } else {
            onNavigateBackward(isKeyRepeat: true);
          }
        } else if (event is KeyDownEvent) {
          _lastNavTime = DateTime.now();
          if (forward) {
            onNavigateForward(isKeyRepeat: false);
          } else {
            onNavigateBackward(isKeyRepeat: false);
          }
        }
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }
}
