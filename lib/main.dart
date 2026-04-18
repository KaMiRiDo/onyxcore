import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'features/settings/presentation/providers/settings_providers.dart';

/// Application entry point.
///
/// Initializes SharedPreferences before launching the app wrapped
/// in Riverpod's ProviderScope for global state management.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
