import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

/// Type of file system change event.
enum FileChangeType { create, modify, delete }

/// Represents a single file system change event.
class FileChangeEvent {
  const FileChangeEvent({required this.type, required this.path});

  final FileChangeType type;
  final String path;

  @override
  String toString() => 'FileChangeEvent($type, $path)';
}

/// Watches a directory for file system changes using Linux inotify.
///
/// Uses [FileSystemEntity.watch()] which maps to inotify on Linux,
/// providing kernel-pushed notifications instead of polling.
/// Events are debounced to prevent rapid rebuilds during batch operations.
class DirectoryWatcher {
  DirectoryWatcher({this.debounceDuration = const Duration(milliseconds: 500)});

  final Duration debounceDuration;

  StreamSubscription<FileSystemEvent>? _subscription;
  final _controller = StreamController<FileChangeEvent>.broadcast();
  Timer? _debounceTimer;
  String? _currentPath;

  /// Stream of debounced file change events for the watched directory.
  Stream<FileChangeEvent> get events => _controller.stream;

  /// The currently watched directory path, or null if not watching.
  String? get currentPath => _currentPath;

  /// Start watching [path] for changes.
  ///
  /// Cancels any previous watch. Only one directory can be watched at a time.
  void watch(String path) {
    stop();
    _currentPath = path;

    try {
      final dir = Directory(path);
      if (!dir.existsSync()) return;

      _subscription = dir.watch().listen(
        (event) {
          final changeType = _mapEventType(event.type);
          if (changeType == null) return;

          // Fire CREATE and DELETE immediately for instant UI feedback
          if (changeType == FileChangeType.create || changeType == FileChangeType.delete) {
            _controller.add(FileChangeEvent(type: changeType, path: event.path));
            return;
          }

          // Debounce MODIFY events (like file writes) to prevent rapid rebuilds
          _debounceTimer?.cancel();
          _debounceTimer = Timer(debounceDuration, () {
            if (!_controller.isClosed) {
              _controller.add(
                FileChangeEvent(type: changeType, path: event.path),
              );
            }
          });
        },
        onError: (Object error) {
          debugPrint('DirectoryWatcher error: $error');
        },
      );
    } catch (e) {
      debugPrint('DirectoryWatcher: Failed to watch $path: $e');
    }
  }

  /// Stop watching the current directory.
  void stop() {
    _debounceTimer?.cancel();
    _subscription?.cancel();
    _subscription = null;
    _currentPath = null;
  }

  /// Dispose the watcher and close the event stream.
  void dispose() {
    stop();
    _controller.close();
  }

  FileChangeType? _mapEventType(int type) {
    if (type == FileSystemEvent.create) return FileChangeType.create;
    if (type == FileSystemEvent.modify) return FileChangeType.modify;
    if (type == FileSystemEvent.delete) return FileChangeType.delete;
    if (type == FileSystemEvent.move) return FileChangeType.modify;
    return null;
  }
}
