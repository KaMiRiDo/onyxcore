import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/video_preview_widget.dart';
import 'package:onyxcore/features/audio_player/presentation/pages/audio_player_view.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_preview_widget.dart';
import 'package:onyxcore/features/document_viewer/presentation/widgets/markdown_preview_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

/// Generic entry point for secondary viewer windows.
///
/// This app routes to the correct viewer based on [WindowParams]
/// and handles high-level window lifecycle events.
class SecondaryWindowApp extends StatefulWidget {
  final String windowId;
  final Map<String, dynamic> arguments;

  const SecondaryWindowApp({
    super.key,
    required this.windowId,
    required this.arguments,
  });

  @override
  State<SecondaryWindowApp> createState() => _SecondaryWindowAppState();
}

class _SecondaryWindowAppState extends State<SecondaryWindowApp>
    with WindowListener {
  WindowParams? params;
  bool _initialized = false;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // Prevent immediate close to allow persistent hiding behavior
    windowManager.setPreventClose(true);

    _initParams();
    _initSharedPrefs();
    _setupIpc();

    // Standardize secondary window for immersive viewing
    windowManager.setTitleBarStyle(TitleBarStyle.hidden);
    // Ensure the window gains OS-level focus so trackpad events register immediately.
    // Delay ensures the OS compositor has mapped the window before stealing focus.
    Future.delayed(const Duration(milliseconds: 100), () async {
      await windowManager.focus();
    });
  }

  Future<void> _initSharedPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _prefs = prefs;
      });
    }
  }

  void _initParams() {
    try {
      params = WindowParams.fromJson(widget.arguments);
      _initialized = true;
    } catch (e) {
      debugPrint('[SecondaryWindowApp] Error parsing arguments: $e');
    }
  }

  void _setupIpc() async {
    final controller = await WindowController.fromCurrentEngine();
    controller.setWindowMethodHandler((call) async {
      if (call.method == 'load_media') {
        debugPrint(
          '[SecondaryWindowApp] IPC Load requested: ${call.arguments}',
        );
        try {
          // Robustly normalize IPC arguments to Map<String, dynamic>
          final normalizedArgs =
              jsonDecode(jsonEncode(call.arguments)) as Map<String, dynamic>;
          final newParams = WindowParams.fromJson(normalizedArgs);
          setState(() {
            params = newParams;
          });
          // Ensure window regains focus if user navigated while window was somehow blurred
          Future.delayed(const Duration(milliseconds: 100), () async {
            await windowManager.focus();
          });
        } catch (e) {
          debugPrint('[SecondaryWindowApp] Error parsing IPC params: $e');
        }
      }
      return 'ok';
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // Persistent viewer architecture: Hide instead of destroy
    debugPrint('[SecondaryWindowApp] Window close requested. Hiding window.');
    if (mounted) {
      setState(() {
        params = null;
      });
    }
    await windowManager.hide();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _prefs == null) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.black,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_prefs!),
      ],
      child: MaterialApp(
        title: params?.file.name ?? 'OnyxCore Viewer',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: Material(
          color: Colors.black,
          child: _buildViewer(),
        ),
      ),
    );
  }

  Widget _buildViewer() {
    if (params == null) return const SizedBox.shrink();

    switch (params!.viewerType) {
      case ViewerType.video:
        final startMs = params!.initParams['startPositionMs'] as int?;
        final rate = params!.initParams['playbackRate'] as double?;
        final audioId = params!.initParams['audioTrackId'] as String?;
        final subtitleId = params!.initParams['subtitleTrackId'] as String?;

        return VideoPreviewWidget(
          key: ValueKey(params!.file.path),
          item: params!.file,
          initialPosition: startMs != null
              ? Duration(milliseconds: startMs)
              : null,
          initialRate: rate,
          initialAudioTrackId: audioId,
          initialSubtitleTrackId: subtitleId,
          isStandalone: true,
          windowId: widget.windowId,
          parentWindowId: params!.parentWindowId,
          initParams: params!.initParams,
        );
      case ViewerType.image:
        return ImagePreviewWidget(
          item: params!.file,
          isStandalone: true,
          windowId: widget.windowId,
          parentWindowId: params!.parentWindowId,
          initParams: params!.initParams,
        );
      case ViewerType.audio:
        return AudioPlayerView(
          key: ValueKey(params!.file.path),
          item: params!.file,
          isStandalone: true,
          windowId: widget.windowId,
          parentWindowId: params!.parentWindowId,
        );
      case ViewerType.markdown:
        return MarkdownPreviewWidget(
          key: ValueKey(params!.file.path),
          item: params!.file,
          isStandalone: true,
          windowId: widget.windowId,
          parentWindowId: params!.parentWindowId,
        );
      default:
        return Center(
          child: Text(
            'Unsupported viewer type: ${params!.viewerType}',
            style: const TextStyle(color: Colors.white),
          ),
        );
    }
  }
}
