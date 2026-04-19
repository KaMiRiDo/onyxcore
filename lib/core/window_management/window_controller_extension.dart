import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';

/// Extension on [WindowController] to provide standard lifecycle methods
/// that are missing in version 0.3.0 but required for the "Plugin-Owned Closure"
/// architecture on Linux.
extension WindowControllerExtension on WindowController {
  /// Closes the window gracefully using the window manager's close sequence.
  /// This is strictly preferred over destroy() to avoid EGL context panics.
  Future<void> close() async {
    // Break the deadlock by allowing the window to actually close
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }
}
