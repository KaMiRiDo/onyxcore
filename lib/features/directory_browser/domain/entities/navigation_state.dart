import 'package:equatable/equatable.dart';

/// Immutable state representing the navigation history.
class NavigationState extends Equatable {
  const NavigationState({
    this.history = const [],
    this.historyIndex = -1,
  });

  final List<String> history;
  final int historyIndex;

  /// Whether the user can navigate back.
  bool get canGoBack => historyIndex > 0;

  /// Whether the user can navigate forward.
  bool get canGoForward => historyIndex < history.length - 1;

  /// The current path from the history stack.
  String get currentPath =>
      history.isNotEmpty && historyIndex >= 0 ? history[historyIndex] : '';

  NavigationState copyWith({
    List<String>? history,
    int? historyIndex,
  }) {
    return NavigationState(
      history: history ?? this.history,
      historyIndex: historyIndex ?? this.historyIndex,
    );
  }

  @override
  List<Object?> get props => [history, historyIndex];
}
