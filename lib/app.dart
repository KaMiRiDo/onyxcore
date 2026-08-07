import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/theme/app_theme.dart';
import 'package:onyxcore/features/archive_manager/services/archive_service.dart';
import 'package:onyxcore/features/directory_browser/presentation/pages/gallery_page.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/thumbnail_session_manager.dart';
import 'package:onyxcore/features/downloader/services/downloader_update_service.dart';
import 'package:window_manager/window_manager.dart';

/// Global navigator key for accessing context outside widgets.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Root widget of the OnyxCore application.
class OnyxCoreApp extends ConsumerStatefulWidget {
  const OnyxCoreApp({super.key});

  @override
  ConsumerState<OnyxCoreApp> createState() => _OnyxCoreAppState();
}

class _OnyxCoreAppState extends ConsumerState<OnyxCoreApp> with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager
      ..addListener(this)
      ..setPreventClose(true);

    Future.microtask(() async {
      if (mounted) {
        final notifier = ref.read(downloaderUpdateProvider.notifier);
        await notifier.checkForUpdates();
        if (mounted) {
          unawaited(notifier.updateAll(defaultOnly: true));
        }
      }
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Future<void> onWindowClose() async {
    // If a dialog is open (like properties or rename), close the dialog instead of the app
    final context = appNavigatorKey.currentContext;
    if (context != null && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      debugPrint('[OnyxCoreApp] Main window closing. Terminating process...');
      try {
        ref.read(activeThumbnailSessionProvider.notifier).disposeCurrentSession();
      } catch (_) {}
      ArchiveService.killZombies(); // Cleanup 7z processes
      // Forcefully kill the entire process tree to clean up all secondary windows.
      exit(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'OnyxCore',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const GalleryPage(),
    );
  }
}
