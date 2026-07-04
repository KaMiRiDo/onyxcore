import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/selection_state.dart';

void main() {
  group('SelectionState', () {
    test('default constructor initializes correctly', () {
      const state = SelectionState();
      
      expect(state.selectedPaths, isEmpty);
      expect(state.isSelectionMode, isFalse);
      expect(state.anchorIndex, isNull);
    });

    test('static empty constant is correct', () {
      expect(SelectionState.empty.selectedPaths, isEmpty);
      expect(SelectionState.empty.isSelectionMode, isFalse);
      expect(SelectionState.empty.anchorIndex, isNull);
    });

    test('supports value equality (Equatable)', () {
      const state1 = SelectionState(
        selectedPaths: {'/a'},
        isSelectionMode: true,
        anchorIndex: 1,
      );
      const state2 = SelectionState(
        selectedPaths: {'/a'},
        isSelectionMode: true,
        anchorIndex: 1,
      );
      const state3 = SelectionState(
        selectedPaths: {'/a', '/b'},
      );

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('copyWith updates fields correctly', () {
      const state = SelectionState();
      
      final updated = state.copyWith(
        selectedPaths: {'/new'},
        isSelectionMode: true,
        anchorIndex: 5,
      );

      expect(updated.selectedPaths, {'/new'});
      expect(updated.isSelectionMode, isTrue);
      expect(updated.anchorIndex, 5);
    });

    test('copyWith retains old fields when null is passed', () {
      const state = SelectionState(
        selectedPaths: {'/new'},
        isSelectionMode: true,
        anchorIndex: 5,
      );
      
      final updated = state.copyWith();

      expect(updated.selectedPaths, state.selectedPaths);
      expect(updated.isSelectionMode, state.isSelectionMode);
      expect(updated.anchorIndex, state.anchorIndex);
    });
  });
}
