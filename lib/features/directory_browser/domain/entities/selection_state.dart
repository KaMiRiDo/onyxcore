import 'package:equatable/equatable.dart';

/// Immutable state representing the current multi-selection.
class SelectionState extends Equatable {
  const SelectionState({
    this.selectedPaths = const {},
    this.isSelectionMode = false,
    this.anchorIndex,
  });

  final Set<String> selectedPaths;
  final bool isSelectionMode;
  final int? anchorIndex;

  static const empty = SelectionState();

  SelectionState copyWith({
    Set<String>? selectedPaths,
    bool? isSelectionMode,
    int? anchorIndex,
  }) {
    return SelectionState(
      selectedPaths: selectedPaths ?? this.selectedPaths,
      isSelectionMode: isSelectionMode ?? this.isSelectionMode,
      anchorIndex: anchorIndex ?? this.anchorIndex,
    );
  }

  @override
  List<Object?> get props => [selectedPaths, isSelectionMode, anchorIndex];
}
