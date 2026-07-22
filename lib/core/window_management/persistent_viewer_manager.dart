import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/audio_player/presentation/pages/audio_player_view.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/document_viewer/presentation/widgets/markdown_preview_widget.dart';
import 'package:onyxcore/features/downloader/presentation/pages/standalone_downloader_window.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_preview_widget.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/video_preview_widget.dart';

/// Manages multi-view state and IPC for spawning new native windows using Flutter's Multi-View API.
class PersistentViewerManager {
  static const MethodChannel _channel = MethodChannel(
    'onyxcore/window_manager',
  );

  // Maps view ID to the parameters for that window
  static final Map<int, ValueNotifier<WindowParams?>> _viewParams = {};

  // Tracks active view IDs by ViewerType to enforce single instance per type
  static final Map<ViewerType, int> _activeWindowsByType = {};

  static final ValueNotifier<int> updates = ValueNotifier(0);

  static final Map<int, ValueNotifier<int>> _focusTriggers = {};

  static void init() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'on_window_focus') {
        final args = call.arguments as Map;
        final viewId = args['view_id'] as int;

        // If a tracked secondary window got focus, trigger its specific focus node
        if (_activeWindowsByType.containsValue(viewId)) {
          _focusTriggers[viewId]?.value++;
        } else {
          // If an untracked window (the main window) regains OS focus (e.g. via Alt+Tab),
          // clear the global primary focus so keystrokes don't leak to the secondary window!
          FocusManager.instance.primaryFocus?.unfocus();
        }
      } else if (call.method == 'on_window_close') {
        final args = call.arguments as Map;
        final viewId = args['view_id'] as int;
        
        await closeWindow(viewId);
      }
    });
  }

  static ValueNotifier<int> getFocusTrigger(int viewId) {
    return _focusTriggers.putIfAbsent(viewId, () => ValueNotifier(0));
  }

  static Future<void> openMedia(WindowParams params) async {
    try {
      final type = params.viewerType;

      // Cleanup any dead windows from our tracking before checking
      _activeWindowsByType.removeWhere((k, v) => !isViewActive(v));

      // If we already have a window open for this viewer type, reuse it!
      if (_activeWindowsByType.containsKey(type)) {
        final existingViewId = _activeWindowsByType[type]!;

        // Update the reactive params. The ValueListenableBuilder in buildView will automatically rebuild.
        _viewParams[existingViewId]?.value = params;

        // Tell the OS to bring the existing window to the front and focus it
        await _channel.invokeMethod('present_window', {
          'view_id': existingViewId,
        });
        return;
      }

      var width = 800;
      var height = 600;
      var maximize = false;

      if (params.initParams.isNotEmpty) {
        if (params.initParams['width'] != null) {
          width = params.initParams['width'] as int;
        }
        if (params.initParams['height'] != null) {
          height = params.initParams['height'] as int;
        }
        if (params.initParams['maximize'] != null) {
          maximize = params.initParams['maximize'] as bool;
        }
      }

      final viewId =
          (await _channel.invokeMethod<int>('create_window', {
            'width': width,
            'height': height,
            'maximize': maximize,
          })) ??
          0;

      // Notify listeners to build the new window content
      _viewParams[viewId] = ValueNotifier(params);
      _activeWindowsByType[type] = viewId;
      updates.value++;
    } catch (e) {
      debugPrint('[PersistentViewerManager] Error opening media: $e');
    }
  }

  /// Toggles fullscreen for a specific view ID
  // ignore: avoid_positional_boolean_parameters
  static Future<void> setFullScreen(int viewId, bool isFullScreen) async {
    try {
      await _channel.invokeMethod('set_fullscreen', {
        'view_id': viewId,
        'is_fullscreen': isFullScreen,
      });
    } catch (e) {
      debugPrint('[PersistentViewerManager] Error setting fullscreen: $e');
    }
  }

  /// Closes a specific view ID window safely by unmounting Flutter widgets first
  static Future<void> closeWindow(int viewId) async {
    try {
      // Hide the window instantly so the user doesn't perceive any lag
      // while we wait for the background GL teardown
      await _channel.invokeMethod('hide_window', {'view_id': viewId});

      // Remove from tracking so Flutter doesn't try to render it during destruction
      _viewParams.remove(viewId);
      _activeWindowsByType.removeWhere((k, v) => v == viewId);
      updates.value++;
      
      // Wait for Flutter to unmount the widget and for media_kit to release GL contexts.
      // Use a longer delay for systems with slow GPU teardown (e.g. Linux Mint with software Mesa).
      // Increased to 1500ms to avoid GLib-GObject-CRITICAL crashes during fast open/close.
      await Future<void>.delayed(const Duration(milliseconds: 1500));

      await _channel.invokeMethod('close_window', {'view_id': viewId});
    } catch (e) {
      debugPrint('[PersistentViewerManager] Error closing window: $e');
    }
  }

  /// Minimizes a specific view ID window
  static Future<void> minimizeWindow(int viewId) async {
    try {
      await _channel.invokeMethod('minimize_window', {'view_id': viewId});
    } catch (e) {
      debugPrint('[PersistentViewerManager] Error minimizing window: $e');
    }
  }

  /// Brings a specific view ID window to the foreground and forces OS focus
  static Future<void> presentWindow(int viewId) async {
    try {
      await _channel.invokeMethod('present_window', {'view_id': viewId});
      // Explicitly trigger the focus event to ensure the Flutter widget tree
      // regains focus immediately after the native window is brought to front.
      _focusTriggers[viewId]?.value++;
    } catch (e) {
      debugPrint('[PersistentViewerManager] Error presenting window: $e');
    }
  }

  static bool isViewActive(int viewId) {
    return WidgetsBinding.instance.platformDispatcher.views.any(
      (v) => v.viewId == viewId,
    );
  }

  static Widget buildView(int viewId) {
    final notifier = _viewParams.putIfAbsent(viewId, () => ValueNotifier(null));

    return ValueListenableBuilder<WindowParams?>(
      valueListenable: notifier,
      builder: (context, params, child) {
        if (params == null) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.theme,
            home: const Scaffold(
              backgroundColor: Colors.black,
              body: SizedBox.shrink(),
            ),
          );
        }

        Widget content;
        switch (params.viewerType) {
          case ViewerType.video:
            final startMs = params.initParams['startPositionMs'] as int?;
            final rate = params.initParams['playbackRate'] as double?;
            final audioId = params.initParams['audioTrackId'] as String?;
            final subtitleId = params.initParams['subtitleTrackId'] as String?;
            content = VideoPreviewWidget(
              key: ValueKey(viewId),
              item: params.file,
              initialPosition: startMs != null
                  ? Duration(milliseconds: startMs)
                  : null,
              initialRate: rate,
              initialAudioTrackId: audioId,
              initialSubtitleTrackId: subtitleId,
              isStandalone: true,
              windowId: viewId.toString(),
              parentWindowId: params.parentWindowId,
              initParams: params.initParams,
            );
          case ViewerType.image:
            content = ImagePreviewWidget(
              key: ValueKey(viewId),
              item: params.file,
              isStandalone: true,
              windowId: viewId.toString(),
              parentWindowId: params.parentWindowId,
              initParams: params.initParams,
            );
          case ViewerType.audio:
            content = AudioPlayerView(
              key: ValueKey(viewId),
              item: params.file,
              isStandalone: true,
              windowId: viewId.toString(),
              parentWindowId: params.parentWindowId,
            );
          case ViewerType.markdown:
            content = MarkdownPreviewWidget(
              key: ValueKey(viewId),
              item: params.file,
              isStandalone: true,
              windowId: viewId.toString(),
              parentWindowId: params.parentWindowId,
            );
          case ViewerType.downloader:
            content = StandaloneDownloaderWindow(
              key: const ValueKey('downloader'),
              windowId: viewId,
              initParams: params.initParams,
            );
          case ViewerType.unsupported:
            content = Center(
              child: Text(
                'Unsupported preview type for ${params.file.name}',
                style: const TextStyle(color: Colors.white),
              ),
            );
        }

        return ProviderScope(
          overrides: [previewFileProvider.overrideWith((ref) => params.file)],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.theme,
            home: Scaffold(backgroundColor: Colors.black, body: content),
          ),
        );
      },
    );
  }
}
