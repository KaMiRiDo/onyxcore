import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/gnome_tab_bar.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/tab_state.dart';

class MockTabManager extends TabManager {
  final TabManagerState _initialState;
  MockTabManager(this._initialState);
  
  @override
  TabManagerState build() => _initialState;
}

void main() {
  testWidgets('GnomeTabBar does not render if only one tab exists', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tabManagerProvider.overrideWith(() => MockTabManager(TabManagerState(
            tabs: [TabState(id: '1', currentPath: '/home/user')],
            activeTabIndex: 0,
          ))),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: GnomeTabBar(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(GnomeTabBar), findsOneWidget);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('GnomeTabBar renders tabs if multiple exist', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tabManagerProvider.overrideWith(() => MockTabManager(TabManagerState(
            tabs: [
              TabState(id: '1', currentPath: '/home/user'),
              TabState(id: '2', currentPath: '/home/user/Downloads'),
            ],
            activeTabIndex: 0,
          ))),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: GnomeTabBar(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('user'), findsOneWidget);
    expect(find.text('Downloads'), findsOneWidget);
    
    // Test close button presence
    expect(find.byIcon(Icons.close), findsWidgets);
  });
}
