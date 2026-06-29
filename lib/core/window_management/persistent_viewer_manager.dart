import 'package:flutter/foundation.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:onyxcore/core/window_management/window_params.dart';

/// Manages a single persistent secondary window for all media viewing.
/// This prevents expensive and unstable GTK engine destruction on Linux.
class PersistentViewerManager {
  static String? _viewerWindowId;

  /// Opens the specified media in the persistent secondary window.
  /// If the window doesn't exist, it creates it; otherwise, it sends an IPC reload signal.
  static Future<void> openMedia(WindowParams params) async {
    try {
      // 1. Fetch current window ID as String
      String? currentId;
      try {
        final currentController = await WindowController.fromCurrentEngine();
        currentId = currentController.windowId;
      } catch (e) {
        debugPrint(
          '[PersistentViewerManager] Could not fetch current window ID: $e',
        );
      }

      // Ensure params has the parent ID
      final effectiveParams = WindowParams(
        viewerType: params.viewerType,
        file: params.file,
        parentWindowId: currentId ?? params.parentWindowId,
        initParams: params.initParams,
      );

      // 1. Check if we already have a window that is still alive
      bool needsCreation = true;
      if (_viewerWindowId != null) {
        final allWindows = await WindowController.getAll();
        if (allWindows.any((w) => w.windowId == _viewerWindowId)) {
          needsCreation = false;
        }
      }

      if (needsCreation) {
        debugPrint('[PersistentViewerManager] Creating new viewer window...');
        final window = await WindowController.create(
          WindowConfiguration(
            arguments: effectiveParams.encode(),
          ),
        );
        _viewerWindowId = window.windowId;
        await window.show();
      } else {
        debugPrint(
          '[PersistentViewerManager] Reusing existing viewer: $_viewerWindowId',
        );
        final controller = WindowController.fromWindowId(_viewerWindowId!);

        // Signal the existing window to load new media
        await controller.invokeMethod('load_media', effectiveParams.toJson());

        // Ensure it comes to foreground
        await controller.show();
      }
    } catch (e) {
      debugPrint('[PersistentViewerManager] Error opening media: $e');
      // On failure, reset state and try one more time by creating fresh
      _viewerWindowId = null;
    }
  }
}
