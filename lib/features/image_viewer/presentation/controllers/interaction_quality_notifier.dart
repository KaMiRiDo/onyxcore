import 'dart:async';
import 'package:flutter/material.dart';

class InteractionQualityNotifier extends ChangeNotifier {
  bool _isActive = false;
  bool get isActive => _isActive;
  
  Timer? _settleTimer;
  static const _settleDelay = Duration(milliseconds: 200);

  void onInteractionStart() {
    _settleTimer?.cancel();
    if (!_isActive) {
      _isActive = true;
      notifyListeners();
    }
  }

  void onInteractionEnd() {
    _settleTimer?.cancel();
    if (_isActive) {
      _settleTimer = Timer(_settleDelay, () {
        _isActive = false;
        notifyListeners();
      });
    }
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    super.dispose();
  }
}
