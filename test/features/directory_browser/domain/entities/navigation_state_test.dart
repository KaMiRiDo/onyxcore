import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/navigation_state.dart';

void main() {
  group('NavigationState', () {
    test('default constructor initializes correctly', () {
      const state = NavigationState();
      
      expect(state.history, isEmpty);
      expect(state.historyIndex, -1);
      expect(state.canGoBack, isFalse);
      expect(state.canGoForward, isFalse);
      expect(state.currentPath, isEmpty);
    });

    test('canGoBack is true when index > 0', () {
      const state = NavigationState(
        history: ['/a', '/b', '/c'],
        historyIndex: 1,
      );
      
      expect(state.canGoBack, isTrue);
    });

    test('canGoBack is false when index is 0', () {
      const state = NavigationState(
        history: ['/a', '/b', '/c'],
        historyIndex: 0,
      );
      
      expect(state.canGoBack, isFalse);
    });

    test('canGoForward is true when index < history length - 1', () {
      const state = NavigationState(
        history: ['/a', '/b', '/c'],
        historyIndex: 1,
      );
      
      expect(state.canGoForward, isTrue);
    });

    test('canGoForward is false when index is at the end', () {
      const state = NavigationState(
        history: ['/a', '/b', '/c'],
        historyIndex: 2,
      );
      
      expect(state.canGoForward, isFalse);
    });

    test('currentPath returns correct path', () {
      const state = NavigationState(
        history: ['/a', '/b', '/c'],
        historyIndex: 1,
      );
      
      expect(state.currentPath, '/b');
    });

    test('currentPath returns empty string if history is empty or index invalid', () {
      const emptyState = NavigationState();
      expect(emptyState.currentPath, isEmpty);

      const invalidState = NavigationState(history: ['/a']);
      expect(invalidState.currentPath, isEmpty);
    });

    test('supports value equality (Equatable)', () {
      const state1 = NavigationState(history: ['/a'], historyIndex: 0);
      const state2 = NavigationState(history: ['/a'], historyIndex: 0);
      const state3 = NavigationState(history: ['/a', '/b'], historyIndex: 1);

      expect(state1, equals(state2));
      expect(state1, isNot(equals(state3)));
    });

    test('copyWith updates fields correctly', () {
      const state = NavigationState();
      
      final updated = state.copyWith(
        history: ['/home'],
        historyIndex: 0,
      );

      expect(updated.history, ['/home']);
      expect(updated.historyIndex, 0);
    });

    test('copyWith retains old fields when null is passed', () {
      const state = NavigationState(
        history: ['/home'],
        historyIndex: 0,
      );
      
      final updated = state.copyWith();

      expect(updated.history, state.history);
      expect(updated.historyIndex, state.historyIndex);
    });
  });
}
