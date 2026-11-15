import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Manages multi-selection of file paths (both source and destination candidates)
/// within the duplicate comparison window.
class CompareSelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  /// Toggles selection of an individual [path].
  void toggle(String path) {
    if (!ref.mounted) return;
    if (state.contains(path)) {
      state = Set<String>.from(state)..remove(path);
    } else {
      state = Set<String>.from(state)..add(path);
    }
  }

  /// Selects an individual [path].
  void select(String path) {
    if (!ref.mounted) return;
    if (!state.contains(path)) {
      state = Set<String>.from(state)..add(path);
    }
  }

  /// Deselects an individual [path].
  void deselect(String path) {
    if (!ref.mounted) return;
    if (state.contains(path)) {
      state = Set<String>.from(state)..remove(path);
    }
  }

  /// Selects all [paths].
  void selectAll(Iterable<String> paths) {
    if (!ref.mounted) return;
    state = Set<String>.from(state)..addAll(paths);
  }

  /// Clears all selection.
  void deselectAll() {
    if (!ref.mounted) return;
    state = const {};
  }

  /// Toggles all [paths] in a group:
  /// if all are selected, deselects them all; otherwise selects all.
  void toggleGroup(Iterable<String> paths) {
    if (!ref.mounted) return;
    final pathList = paths.toList();
    if (pathList.isEmpty) return;

    final allSelected = pathList.every(state.contains);
    if (allSelected) {
      state = Set<String>.from(state)..removeAll(pathList);
    } else {
      state = Set<String>.from(state)..addAll(pathList);
    }
  }

  /// Returns `true` if [path] is selected.
  bool isSelected(String path) => state.contains(path);

  /// Returns `true` if all [paths] are selected, `null` if some are selected,
  /// and `false` if none are selected.
  bool? isGroupSelected(Iterable<String> paths) {
    final pathList = paths.toList();
    if (pathList.isEmpty) return false;

    var selectedCount = 0;
    for (final p in pathList) {
      if (state.contains(p)) {
        selectedCount++;
      }
    }

    if (selectedCount == 0) return false;
    if (selectedCount == pathList.length) return true;
    return null;
  }

  /// Removes the given [paths] from selection (e.g. after deletion or move).
  void removePaths(Iterable<String> paths) {
    if (!ref.mounted || state.isEmpty) return;
    state = Set<String>.from(state)..removeAll(paths);
  }

  /// Resets selection state to empty.
  void reset() {
    if (!ref.mounted) return;
    state = const {};
  }
}

final compareSelectionProvider =
    NotifierProvider<CompareSelectionNotifier, Set<String>>(
      CompareSelectionNotifier.new,
    );
