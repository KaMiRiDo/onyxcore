import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';

import '../../domain/entities/navigation_state.dart';

/// Notifier managing the browser navigation history, scoped to the current tab.
class NavigationNotifier extends Notifier<NavigationState> {
  @override
  NavigationState build() {
    final tabId = ref.watch(tabIdProvider);
    final tab = ref.watch(
      tabManagerProvider.select((s) => s.tabs.firstWhere((t) => t.id == tabId)),
    );
    return NavigationState(
      history: tab.history,
      historyIndex: tab.historyIndex,
    );
  }

  /// Initialize is now handled by TabManager.
  void initialize(String initialPath) {
    // No-op, managed by TabManager
  }

  /// Navigate to a new path, updating the history stack.
  void navigateTo(String path) {
    final tabId = ref.read(tabIdProvider);
    ref.read(tabManagerProvider.notifier).updateTabPath(tabId, path);
  }

  /// Go back in history.
  void goBack() {
    final tabId = ref.read(tabIdProvider);
    ref.read(tabManagerProvider.notifier).navigateBack(tabId);
  }

  /// Go forward in history.
  void goForward() {
    final tabId = ref.read(tabIdProvider);
    ref.read(tabManagerProvider.notifier).navigateForward(tabId);
  }

  /// Handle device ejection.
  String? handleEject(String ejectedDevicePath) {
    // This needs logic in TabManager if we want to support it per-tab.
    // For now, let's just use current tab.
    final tabId = ref.read(tabIdProvider);
    final tab = ref.read(
      tabManagerProvider.select((s) => s.tabs.firstWhere((t) => t.id == tabId)),
    );

    final history = tab.history;
    int targetIndex = -1;

    for (int i = tab.historyIndex - 1; i >= 0; i--) {
      if (!history[i].startsWith(ejectedDevicePath)) {
        targetIndex = i;
        break;
      }
    }

    if (targetIndex != -1) {
      // We'd need a special method in TabManager to jump to an index.
      // For simplicity, let's just navigate to the found path.
      ref
          .read(tabManagerProvider.notifier)
          .updateTabPath(tabId, history[targetIndex]);
      return history[targetIndex];
    }
    return null;
  }
}

/// Provider for the navigation notifier.
final navigationProvider =
    NotifierProvider<NavigationNotifier, NavigationState>(
      NavigationNotifier.new,
    );
