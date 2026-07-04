import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sidebar/storage_indicator.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildTestWidget(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: StorageIndicator(),
        ),
      ),
    );
  }

  testWidgets('StorageIndicator renders correctly and handles timer', (tester) async {
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    await tester.pumpWidget(buildTestWidget(container));
    
    // Pump a few times to allow the Future in getDiskUsage to resolve
    await tester.pumpAndSettle();
    
    expect(find.text('SYSTEM STORAGE'), findsOneWidget);
    
    // Fast forward timer
    await tester.pump(const Duration(seconds: 4));
    
    // Trigger refresh
    container.read(refreshCountProvider.notifier).state++;
    await tester.pumpAndSettle();
  });
}
