import 'package:flutter/material.dart';
import 'ui/theme.dart';
import 'ui/pages/gallery_page.dart';
import 'services/settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize settings
  final settingsService = SettingsService();
  await settingsService.init();
  
  runApp(const OnyxCoreApp());
}

class OnyxCoreApp extends StatelessWidget {
  const OnyxCoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OnyxCore Multimedia Manager',
      theme: AppTheme.theme,
      home: const GalleryPage(),
    );
  }
}
