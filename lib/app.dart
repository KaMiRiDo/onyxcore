import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/directory_browser/presentation/pages/gallery_page.dart';

/// Root widget of the OnyxCore application.
class OnyxCoreApp extends StatelessWidget {
  const OnyxCoreApp({super.key});

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
