import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sidebar/sidebar.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sidebar/sidebar_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/sidebar/storage_indicator.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/device_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';

import 'dart:async';
import 'package:onyxcore/features/directory_browser/domain/entities/device.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Widget buildTestWidget() {
    final streamController = StreamController<List<Device>>();
    return ProviderScope(
      overrides: [
        deviceProvider.overrideWith((ref) => streamController.stream),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: Sidebar(),
        ),
      ),
    );
  }

  testWidgets('Sidebar renders and handles Cloud Storage tap', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget());
    await tester.pump();
    
    // Check if Sidebar exists
    expect(find.byType(Sidebar), findsOneWidget);
    
    // Tap each standard navigation item to cover `_navigate` method branches
    final itemsToTap = [
      'Home', 'Desktop', 'Documents', 'Music', 'Pictures', 
      'Videos', 'Downloads', 'Recent', 'Trash'
    ];
    
    for (final item in itemsToTap) {
      final widgetFinder = find.widgetWithText(SidebarItem, item, skipOffstage: false);
      if (tester.any(widgetFinder)) {
        await tester.tap(widgetFinder);
        await tester.pump();
      }
    }

    // Tap 'Add Account' via Icon
    final addAccount = find.byIcon(Icons.add_circle_outline, skipOffstage: false);
    expect(addAccount, findsOneWidget);
    await tester.tap(addAccount);
    await tester.pump();
    
    // Check if snackbar is shown
    expect(find.byType(SnackBar), findsOneWidget);
    
    // Wait for the SnackBar to disappear to avoid pending timers
    await tester.pump(const Duration(seconds: 5));
    
    // Dispose the widget tree to cancel StorageIndicator periodic timers
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
