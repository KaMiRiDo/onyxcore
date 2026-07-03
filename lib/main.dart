import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:media_kit/media_kit.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:onyxcore/app.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:window_manager/window_manager.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Increase image cache to 500MB to support pre-caching of high-res files without compromising resolution
  PaintingBinding.instance.imageCache.maximumSizeBytes = 1024 * 1024 * 500;

  // Unified initialization
  await windowManager.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<dynamic>('ui_settings');
  MediaKit.ensureInitialized();
  PersistentViewerManager.init();

  final prefs = await SharedPreferences.getInstance();

  // Configure window options for a seamless, titlebar-less experience for the main window
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.maximize();
    await windowManager.focus();
  });

  runWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const OnyxCoreMultiViewApp(),
    ),
  );
}

class OnyxCoreMultiViewApp extends StatefulWidget {
  const OnyxCoreMultiViewApp({super.key});

  @override
  State<OnyxCoreMultiViewApp> createState() => _OnyxCoreMultiViewAppState();
}

class _OnyxCoreMultiViewAppState extends State<OnyxCoreMultiViewApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PersistentViewerManager.updates.addListener(_onUpdates);
  }

  void _onUpdates() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    PersistentViewerManager.updates.removeListener(_onUpdates);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    // Rebuild when a new view is spawned or removed by the platform dispatcher
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ViewCollection(
      views: PlatformDispatcher.instance.views.map((FlutterView view) {
        return View(
          view: view,
          child: _buildChildForView(view),
        );
      }).toList(),
    );
  }

  Widget _buildChildForView(FlutterView view) {
    if (view == PlatformDispatcher.instance.implicitView || view.viewId == 0) {
      return const OnyxCoreApp();
    }
    return PersistentViewerManager.buildView(view.viewId);
  }
}
