import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/navigation_state.dart';

/// Notifier managing the browser navigation history.
///
/// Handles navigateTo, goBack, goForward logic
/// (exact same behavior as original gallery_page.dart).
class NavigationNotifier extends Notifier<NavigationState> {
  @override
  NavigationState build() => const NavigationState();

  /// Initialize with a starting path (e.g., $HOME).
  void initialize(String initialPath) {
    state = NavigationState(
      history: [initialPath],
      historyIndex: 0,
    );
  }

  /// Navigate to a new path, updating the history stack.
  void navigateTo(String path) {
    if (state.currentPath == path) return;

    final history = List<String>.from(state.history);
    var index = state.historyIndex;

    // Clear forward history and add new path
    if (index < history.length - 1) {
      history.removeRange(index + 1, history.length);
    }
    history.add(path);
    index = history.length - 1;

    state = NavigationState(history: history, historyIndex: index);
  }

  /// Go back in history.
  void goBack() {
    if (!state.canGoBack) return;
    final newIndex = state.historyIndex - 1;
    state = state.copyWith(historyIndex: newIndex);
  }

  /// Go forward in history.
  void goForward() {
    if (!state.canGoForward) return;
    final newIndex = state.historyIndex + 1;
    state = state.copyWith(historyIndex: newIndex);
  }
}

/// Provider for the navigation notifier.
final navigationProvider =
    NotifierProvider<NavigationNotifier, NavigationState>(
  NavigationNotifier.new,
);
