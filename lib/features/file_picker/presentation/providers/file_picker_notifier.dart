import 'dart:async';
import 'dart:io';
import 'package:file/file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../services/file_system_service.dart';

/// State for the Custom File Picker.
class FilePickerState {
  final String currentDirectory;
  final bool showHiddenFiles;
  final List<String>? allowedExtensions;
  final List<FileSystemEntity> contents;
  final Set<String> selection;
  final String? error;
  final bool pickDirectory;

  FilePickerState({
    required this.currentDirectory,
    this.showHiddenFiles = false,
    this.allowedExtensions,
    this.contents = const [],
    this.selection = const {},
    this.error,
    this.pickDirectory = false,
  });

  FilePickerState copyWith({
    String? currentDirectory,
    bool? showHiddenFiles,
    List<String>? allowedExtensions,
    List<FileSystemEntity>? contents,
    Set<String>? selection,
    String? error,
    bool? pickDirectory,
  }) {
    return FilePickerState(
      currentDirectory: currentDirectory ?? this.currentDirectory,
      showHiddenFiles: showHiddenFiles ?? this.showHiddenFiles,
      allowedExtensions: allowedExtensions ?? this.allowedExtensions,
      contents: contents ?? this.contents,
      selection: selection ?? this.selection,
      error: error,
      pickDirectory: pickDirectory ?? this.pickDirectory,
    );
  }
}

/// Provider for the FileSystemService.
final fileSystemServiceProvider = Provider<FileSystemService>((ref) {
  return FileSystemService();
});

/// Notifier for the File Picker state.
class FilePickerNotifier extends AsyncNotifier<FilePickerState> {
  final List<String> _history = [];
  int _historyIndex = -1;
  int? _anchorIndex;

  @override
  FutureOr<FilePickerState> build() {
    // Return a dummy state initially. The actual loading will happen in initialize().
    return FilePickerState(currentDirectory: _getHomeDirectory());
  }

  Future<void> initialize({
    List<String>? allowedExtensions,
    String? initialDirectory,
    bool pickDirectory = false,
  }) async {
    final home = initialDirectory ?? _getHomeDirectory();

    _history.clear();
    _history.add(home);
    _historyIndex = 0;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final initialState = FilePickerState(
        currentDirectory: home,
        allowedExtensions: allowedExtensions,
        pickDirectory: pickDirectory,
      );
      return await _loadDirectoryContents(initialState);
    });
  }

  String _getHomeDirectory() {
    // Basic home directory detection for Linux/macOS/Windows
    if (Platform.isWindows) {
      return Platform.environment['USERPROFILE'] ?? 'C:\\';
    }
    return Platform.environment['HOME'] ?? '/';
  }

  Future<FilePickerState> _loadDirectoryContents(
    FilePickerState currentState,
  ) async {
    final service = ref.read(fileSystemServiceProvider);
    try {
      final entities = await service.listDirectory(
        currentState.currentDirectory,
      );

      var filtered = currentState.showHiddenFiles
          ? entities
          : entities.where((e) => !p.basename(e.path).startsWith('.')).toList();

      if (currentState.pickDirectory) {
        filtered = filtered.where((e) => e is Directory).toList();
      } else if (currentState.allowedExtensions != null &&
          currentState.allowedExtensions!.isNotEmpty) {
        filtered = filtered.where((e) {
          if (e is Directory) return true;
          final ext = p.extension(e.path).toLowerCase().replaceFirst('.', '');
          return currentState.allowedExtensions!.contains(ext);
        }).toList();
      }

      // Sort: Directories first, then Files, alphabetically
      filtered.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return p
            .basename(a.path)
            .toLowerCase()
            .compareTo(p.basename(b.path).toLowerCase());
      });

      return currentState.copyWith(
        contents: filtered,
        selection: {},
        error: null,
      );
    } catch (e) {
      // If access denied or other error, return state with error but keep current path if possible
      // In a real app, you'd probably want to show a snackbar.
      return currentState.copyWith(error: e.toString());
    }
  }

  Future<void> goToDirectory(String path) async {
    final currentState = await future;
    if (currentState.currentDirectory == path) return;

    // Update history
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(path);
    _historyIndex++;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final newState = currentState.copyWith(currentDirectory: path);
      return await _loadDirectoryContents(newState);
    });
  }

  Future<void> goUp() async {
    final currentState = state.value;
    if (currentState == null) return;

    final parent = p.dirname(currentState.currentDirectory);
    if (parent == currentState.currentDirectory) return; // Already at root

    await goToDirectory(parent);
  }

  Future<void> goBack() async {
    if (_historyIndex <= 0) return;
    _historyIndex--;
    final path = _history[_historyIndex];

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final currentState = state.value;
      return await _loadDirectoryContents(
        FilePickerState(
          currentDirectory: path,
          showHiddenFiles: currentState?.showHiddenFiles ?? false,
          allowedExtensions: currentState?.allowedExtensions,
          pickDirectory: currentState?.pickDirectory ?? false,
        ),
      );
    });
  }

  Future<void> goForward() async {
    if (_historyIndex >= _history.length - 1) return;
    _historyIndex++;
    final path = _history[_historyIndex];

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final currentState = state.value;
      return await _loadDirectoryContents(
        FilePickerState(
          currentDirectory: path,
          showHiddenFiles: currentState?.showHiddenFiles ?? false,
          allowedExtensions: currentState?.allowedExtensions,
        ),
      );
    });
  }

  Future<void> toggleHiddenFiles() async {
    final currentState = state.value;
    if (currentState == null) return;

    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final newState = currentState.copyWith(
        showHiddenFiles: !currentState.showHiddenFiles,
      );
      return await _loadDirectoryContents(newState);
    });
  }

  void toggleSelection(
    String path, {
    bool isCtrl = false,
    bool isShift = false,
  }) {
    final currentState = state.value;
    if (currentState == null) return;

    final currentIndex = currentState.contents.indexWhere(
      (e) => e.path == path,
    );
    if (currentIndex == -1) return;

    final newSelection = Set<String>.from(
      (isCtrl || (isShift && _anchorIndex == null))
          ? currentState.selection
          : {},
    );

    if (isShift && _anchorIndex != null) {
      if (!isCtrl)
        newSelection
            .clear(); // Shift+Click replaces selection unless Ctrl is held

      final start = _anchorIndex! < currentIndex ? _anchorIndex! : currentIndex;
      final end = _anchorIndex! > currentIndex ? _anchorIndex! : currentIndex;

      for (var i = start; i <= end; i++) {
        newSelection.add(currentState.contents[i].path);
      }
    } else {
      if (isCtrl) {
        if (newSelection.contains(path)) {
          newSelection.remove(path);
          if (newSelection.isEmpty) _anchorIndex = null;
        } else {
          newSelection.add(path);
          _anchorIndex = currentIndex;
        }
      } else {
        newSelection.clear();
        newSelection.add(path);
        _anchorIndex = currentIndex;
      }
    }

    state = AsyncValue.data(currentState.copyWith(selection: newSelection));
  }

  void clearError() {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncValue.data(currentState.copyWith(error: null));
  }
}

final filePickerProvider =
    AsyncNotifierProvider<FilePickerNotifier, FilePickerState>(() {
      return FilePickerNotifier();
    });
