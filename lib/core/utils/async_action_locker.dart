import 'dart:async';
import 'package:flutter/foundation.dart';

class AsyncActionLocker {
  bool _isLocked = false;
  bool get isLocked => _isLocked;

  Future<void> execute(Future<void> Function() action, {VoidCallback? onLockStateChanged}) async {
    if (_isLocked) return;
    _isLocked = true;
    onLockStateChanged?.call();
    try {
      await action();
    } finally {
      _isLocked = false;
      onLockStateChanged?.call();
    }
  }
}
