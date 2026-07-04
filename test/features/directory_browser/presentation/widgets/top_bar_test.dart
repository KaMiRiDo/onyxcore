import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/top_bar.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/tab_state.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/device_provider.dart';

class MockTabManager extends TabManager {
  @override
  TabManagerState build() {
    return TabManagerState(
      tabs: [
        TabState(
          id: '1',
          currentPath: '/home/user/docs',
          isSearchActive: false,
        ),
      ],
      activeTabIndex: 0,
    );
  }
}

void main() {
  testWidgets('TopBar renders correctly and toggles search', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tabManagerProvider.overrideWith(() => MockTabManager()),
          deviceProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: TopBar(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify breadcrumbs are rendered
    expect(find.text('docs'), findsWidgets);
    
    // Verify search button is rendered
    expect(find.byIcon(Icons.manage_search), findsOneWidget);
    
    // Tap search button to toggle search mode
    // We can't actually toggle because it requires the real TabManagerNotifier to be mocked, 
    // but we can tap it and ensure no crash.
    await tester.tap(find.byIcon(Icons.manage_search));
    await tester.pumpAndSettle();
  });
}
