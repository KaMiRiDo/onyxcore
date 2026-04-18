import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/selection_state.dart';

/// Notifier managing multi-selection state.
///
/// Handles single-click, Ctrl+Click, Shift+Click selection logic
/// (exact same behavior as original gallery_page.dart).
class SelectionNotifier extends Notifier<SelectionState> {
  @override
  SelectionState build() => SelectionState.empty;

  /// Handle item tap with modifier key state.
  ///
  /// Exactly replicates the original _onItemTap() logic.
  void onItemTap({
    required int currentIndex,
    required List<String> allPaths,
    required bool isShift,
    required bool isCtrl,
  }) {
    final currentState = state;
    final selectedPaths = Set<String>.from(currentState.selectedPaths);

    if (isShift && currentState.anchorIndex != null) {
      // Range selection (additive)
      final start = math.min(currentState.anchorIndex!, currentIndex);
      final end = math.max(currentState.anchorIndex!, currentIndex);
      for (var i = start; i <= end; i++) {
        selectedPaths.add(allPaths[i]);
      }
      state = SelectionState(
        selectedPaths: selectedPaths,
        isSelectionMode: selectedPaths.isNotEmpty,
        anchorIndex: currentState.anchorIndex,
      );
    } else if (isCtrl) {
      // Individual toggle
      final path = allPaths[currentIndex];
      if (selectedPaths.contains(path)) {
        selectedPaths.remove(path);
      } else {
        selectedPaths.add(path);
      }
      state = SelectionState(
        selectedPaths: selectedPaths,
        isSelectionMode: selectedPaths.isNotEmpty,
        anchorIndex: currentIndex,
      );
    } else {
      // Single exclusive select
      state = SelectionState(
        selectedPaths: {allPaths[currentIndex]},
        isSelectionMode: true,
        anchorIndex: currentIndex,
      );
    }
  }

  /// Select all items.
  void selectAll(List<String> allPaths) {
    state = SelectionState(
      selectedPaths: allPaths.toSet(),
      isSelectionMode: true,
    );
  }

  /// Clear all selection.
  void deselectAll() {
    state = SelectionState.empty;
  }
}

/// Provider for the selection notifier.
final selectionProvider =
    NotifierProvider<SelectionNotifier, SelectionState>(SelectionNotifier.new);
