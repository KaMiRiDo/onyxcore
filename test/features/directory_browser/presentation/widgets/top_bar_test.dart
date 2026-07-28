import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/tab_state.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/device_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/top_bar.dart';
import 'package:onyxcore/features/settings/domain/entities/app_settings.dart';
import 'package:onyxcore/features/settings/presentation/providers/settings_providers.dart';

class MockTabManager extends TabManager {
  @override
  TabManagerState build() {
    return TabManagerState(
      tabs: [
        TabState(
          id: '1',
          currentPath: '/home/user/docs',
        ),
      ],
      activeTabIndex: 0,
    );
  }

  @override
  void setSearchActive(String tabId, bool value) {
    state = TabManagerState(
      tabs: state.tabs.map((tab) {
        if (tab.id == tabId) {
          return tab.copyWith(isSearchActive: value);
        }
        return tab;
      }).toList(),
      activeTabIndex: state.activeTabIndex,
    );
  }
}

class MockSettingsNotifier extends SettingsNotifier {
  @override
  Future<AppSettings> build() async {
    return const AppSettings();
  }
}

void main() {
  testWidgets('TopBar renders correctly, toggles search and visibility', (tester) async {
    final container = ProviderContainer(
      overrides: [
        tabManagerProvider.overrideWith(MockTabManager.new),
        deviceProvider.overrideWith((ref) => Stream.value([])),
        settingsProvider.overrideWith(MockSettingsNotifier.new),
        tabIdProvider.overrideWith((ref) => '1'),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
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
    
    // Trigger search active state manually to verify notifier works
    container.read(isSearchActiveProvider.notifier).set(true);
    await tester.pumpAndSettle();

    expect(container.read(isSearchActiveProvider), isTrue);

    // Find the search TextField specifically
    final searchTextField = find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == 'Search in docs...',
    );
    expect(searchTextField, findsOneWidget);

    // Enter search text
    await tester.enterText(searchTextField, 'test_query');
    await tester.pumpAndSettle();

    expect(container.read(searchQueryProvider), 'test_query');

    // Trigger search inactive state manually
    container.read(isSearchActiveProvider.notifier).set(false);
    await tester.pumpAndSettle();

    expect(container.read(isSearchActiveProvider), isFalse);
    expect(container.read(searchQueryProvider), isEmpty);
  });
}
