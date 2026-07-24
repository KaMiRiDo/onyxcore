import 'dart:async';
import 'package:flutter/foundation.dart';

/// Manages the visibility of the heads-up display (HUD) elements in the image viewer.
/// Handles auto-hide timers, zoom indicator visibility, and edit mode state.
class ImageHudController extends ChangeNotifier {
  bool _isControlsVisible = false;
  bool _isClosing = false;
  bool _showZoomIndicator = false;

  Timer? _hideTimer;
  Timer? _zoomTimer;

  bool get isControlsVisible => _isControlsVisible;
  bool get isClosing => _isClosing;
  bool get showZoomIndicator => _showZoomIndicator;

  void showControls() {
    if (!_isControlsVisible) {
      _isControlsVisible = true;
      notifyListeners();
    }
  }

  void hideControls() {
    if (_isControlsVisible) {
      _isControlsVisible = false;
      notifyListeners();
    }
  }

  void toggleControls() {
    _isControlsVisible = !_isControlsVisible;
    if (_isControlsVisible) {
      startHideTimer();
    }
    notifyListeners();
  }

  void startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (_isControlsVisible) {
        _isControlsVisible = false;
        notifyListeners();
      }
    });
  }

  void showZoomIndicatorForDuration() {
    if (!_showZoomIndicator) {
      _showZoomIndicator = true;
      notifyListeners();
    }

    _zoomTimer?.cancel();
    _zoomTimer = Timer(const Duration(seconds: 2), () {
      if (_showZoomIndicator) {
        _showZoomIndicator = false;
        notifyListeners();
      }
    });
  }

  void startClosing() {
    _isClosing = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _zoomTimer?.cancel();
    super.dispose();
  }
}
