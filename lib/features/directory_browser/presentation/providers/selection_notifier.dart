import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';

import '../../domain/entities/selection_state.dart';

/// Notifier managing multi-selection state, scoped to the current tab.
class SelectionNotifier extends Notifier<SelectionState> {
  /// The anchor index is tracked locally (not in tab state) because it's
  /// transient UI state that doesn't need to survive tab switches.
  int? _anchorIndex;

  @override
  SelectionState build() {
    final tabId = ref.watch(tabIdProvider);
    final selectedPaths = ref.watch(
      tabManagerProvider.select(
        (s) => s.tabs.firstWhere((t) => t.id == tabId).selectedPaths,
      ),
    );
    return SelectionState(
      selectedPaths: selectedPaths,
      isSelectionMode: selectedPaths.isNotEmpty,
      anchorIndex: _anchorIndex,
    );
  }

  void _update(Set<String> selection) {
    if (selection.isEmpty) {
      _anchorIndex = null;
    }
    final tabId = ref.read(tabIdProvider);
    ref.read(tabManagerProvider.notifier).updateSelection(tabId, selection);
  }

  /// Handle item tap with modifier key state.
  void onItemTap({
    required int currentIndex,
    required List<String> allPaths,
    required bool isShift,
    required bool isCtrl,
  }) {
    final selectedPaths = Set<String>.from(state.selectedPaths);

    if (isShift && _anchorIndex != null) {
      final start = math.min(_anchorIndex!, currentIndex);
      final end = math.max(_anchorIndex!, currentIndex);
      for (var i = start; i <= end; i++) {
        selectedPaths.add(allPaths[i]);
      }
      _update(selectedPaths);
    } else if (isCtrl) {
      final path = allPaths[currentIndex];
      if (selectedPaths.contains(path)) {
        selectedPaths.remove(path);
      } else {
        selectedPaths.add(path);
      }
      _anchorIndex = currentIndex;
      _update(selectedPaths);
    } else {
      _anchorIndex = currentIndex;
      _update({allPaths[currentIndex]});
    }
  }

  /// Select a single path.
  void select(String path) {
    final newSelection = Set<String>.from(state.selectedPaths)..add(path);
    _update(newSelection);
  }

  /// Select multiple paths.
  void selectMultiple(List<String> paths, {bool isCtrl = false}) {
    if (isCtrl) {
      final newSelection = Set<String>.from(state.selectedPaths)..addAll(paths);
      _update(newSelection);
    } else {
      _update(paths.toSet());
    }
  }

  /// Select all items.
  void selectAll(List<String> allPaths) {
    _update(allPaths.toSet());
  }

  /// Clear all selection.
  void deselectAll() {
    _update({});
  }

  /// Remove specific paths from selection.
  void deselect(List<String> paths) {
    final newSelection = Set<String>.from(state.selectedPaths);
    for (final p in paths) {
      newSelection.remove(p);
    }
    _update(newSelection);
  }
}

/// Provider for the selection notifier.
final selectionProvider = NotifierProvider<SelectionNotifier, SelectionState>(
  SelectionNotifier.new,
);
