import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/theme/app_theme.dart';
import 'features/directory_browser/presentation/pages/gallery_page.dart';

/// Root widget of the OnyxCore application.
class OnyxCoreApp extends StatefulWidget {
  const OnyxCoreApp({super.key});

  @override
  State<OnyxCoreApp> createState() => _OnyxCoreAppState();
}

class _OnyxCoreAppState extends State<OnyxCoreApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // Prevent immediate close to allow for clean process termination
    windowManager.setPreventClose(true);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    debugPrint('[OnyxCoreApp] Main window closing. Terminating process...');
    // Forcefully kill the entire process tree to clean up all secondary windows.
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OnyxCore',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const GalleryPage(),
    );
  }
}
