import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/app.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

/// Application entry point.
///
/// Initializes SharedPreferences and MediaKit before launching the app wrapped
/// in Riverpod's ProviderScope for global state management.
import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:onyxcore/features/video_player/presentation/pages/standalone_video_player.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  MediaKit.ensureInitialized();

  final windowController = await WindowController.fromCurrentEngine();
  final String? arguments = windowController.arguments;

  if (arguments != null && arguments.isNotEmpty) {
    debugPrint('[Main] Received window arguments: $arguments');
    try {
      final map = jsonDecode(arguments) as Map<String, dynamic>;
      if (map.containsKey('file')) {
        runApp(
          StandaloneVideoPlayerApp(
            windowId: windowController.windowId,
            arguments: map,
          ),
        );
        return;
      }
    } catch (e) {
      debugPrint('Error parsing window arguments: $e');
    }
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const OnyxCoreApp(),
    ),
  );
}
