import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:media_kit/media_kit.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:onyxcore/app.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

/// Application entry point.
///
/// Initializes SharedPreferences and MediaKit before launching the app wrapped
/// in Riverpod's ProviderScope for global state management.
import 'dart:convert';
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:window_manager/window_manager.dart';
import 'package:onyxcore/core/window_management/secondary_window_app.dart';
import 'package:onyxcore/core/window_management/window_controller_extension.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Unified initialization for all engine instances (main and secondary)
  await windowManager.ensureInitialized();
  await Hive.initFlutter();
  MediaKit.ensureInitialized();

  final windowController = await WindowController.fromCurrentEngine();
  final String? arguments = windowController.arguments;

  if (arguments != null && arguments.isNotEmpty) {
    debugPrint('[Main] Received window arguments: $arguments');
    try {
      final map = jsonDecode(arguments) as Map<String, dynamic>;
      runApp(
        SecondaryWindowApp(
          windowId: windowController.windowId,
          arguments: map,
        ),
      );
      return;
    } catch (e) {
      debugPrint('[Main] Error parsing window arguments: $e');
    }
  }

  final prefs = await SharedPreferences.getInstance();
  
  // Configure window options for a seamless, titlebar-less experience
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const OnyxCoreApp(),
    ),
  );
}
