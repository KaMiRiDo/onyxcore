import 'dart:async';
import 'package:flutter/material.dart';

class PrecacheTask {
  PrecacheTask({
    required this.path,
    required this.level,
    required this.precacheAction,
  });

  final String path;
  final int level; // 1 is highest priority (adjacent), 2 is lower (next-next)
  final Future<void> Function(BuildContext? context) precacheAction;
}

class ImagePrecacheManager {
  factory ImagePrecacheManager() => instance;
  ImagePrecacheManager._internal();
  static final ImagePrecacheManager instance = ImagePrecacheManager._internal();

  final List<PrecacheTask> _queue = [];
  final List<String> _cachedPaths = [];
  
  bool _isProcessing = false;
  
  // Custom limit on cached items to approximate 300MB
  // E.g., 20 items of FHD (1920x1920x4 bytes ~ 14MB each) is ~280MB.
  int maxCachedItems = 20; 

  bool get isProcessing => _isProcessing;
  List<String> get cachedPaths => List.unmodifiable(_cachedPaths);

  void enqueuePrecache({
    required String path,
    required int level,
    required Future<void> Function(BuildContext? context) precacheAction,
  }) {
    if (_cachedPaths.contains(path)) return; // Already cached
    
    // Check if already in queue
    final existingIndex = _queue.indexWhere((t) => t.path == path);
    if (existingIndex != -1) {
      if (_queue[existingIndex].level > level) {
        // Upgrade priority
        final task = _queue.removeAt(existingIndex);
        _queue.add(PrecacheTask(
          path: task.path,
          level: level,
          precacheAction: task.precacheAction,
        ));
        _sortQueue();
      }
      return;
    }

    _queue.add(PrecacheTask(
      path: path,
      level: level,
      precacheAction: precacheAction,
    ));
    _sortQueue();
    _processNext();
  }

  void _sortQueue() {
    _queue.sort((a, b) => a.level.compareTo(b.level));
  }

  Future<void> _processNext() async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;
    final task = _queue.removeAt(0);

    try {
      await task.precacheAction(null);
      
      _cachedPaths.add(task.path);
      
      // LRU Eviction
      if (_cachedPaths.length > maxCachedItems) {
        _cachedPaths.removeAt(0);
        // Note: Flutter's native PaintingBinding.instance.imageCache handles actual memory eviction.
        // We just evict from our tracker. If we wanted, we could explicitly call PaintingBinding.instance.imageCache.evict(provider).
        // But the global cache limit of 300MB already handles it. We track this for the unit test logic.
      }
    } catch (e) {
      debugPrint('[ImagePrecacheManager] Error precaching ${task.path}: $e');
    } finally {
      _isProcessing = false;
      unawaited(_processNext());
    }
  }

  void clearSession() {
    _queue.clear();
    _cachedPaths.clear();
    _isProcessing = false;
    // We could manually evict from PaintingBinding.instance.imageCache here,
    // but the system clears them if memory is needed, or we explicitly evict providers in the UI layer.
    PaintingBinding.instance.imageCache.clear();
  }
}
