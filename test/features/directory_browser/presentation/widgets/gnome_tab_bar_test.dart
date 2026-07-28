import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/tab_state.dart';
import 'package:onyxcore/features/directory_browser/domain/repositories/directory_repository.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/tab_manager.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/gnome_tab_bar.dart';

class MockTabManager extends TabManager {
  MockTabManager(this._initialState);
  final TabManagerState _initialState;
  
  String? switchedToId;
  String? closedTabId;

  @override
  TabManagerState build() => _initialState;

  @override
  void switchTab(int index) {
    switchedToId = state.tabs[index].id;
    state = state.copyWith(activeTabIndex: index);
  }

  @override
  void closeTab(String id) {
    closedTabId = id;
    final newTabs = state.tabs.where((t) => t.id != id).toList();
    state = state.copyWith(tabs: newTabs, activeTabIndex: 0);
  }
}

class MockDirectoryRepository implements DirectoryRepository {
  List<String>? moveItemsSources;
  String? moveItemsDestination;

  @override
  Future<void> moveItems(List<String> sources, String destination) async {
    moveItemsSources = sources;
    moveItemsDestination = destination;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late MockDirectoryRepository mockRepo;

  setUp(() {
    mockRepo = MockDirectoryRepository();
  });

  testWidgets('GnomeTabBar does not render if only one tab exists', (tester) async {
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
    expect(find.text('user'), findsNothing);
  });

  testWidgets('GnomeTabBar renders tabs and switches on tap', (tester) async {
    final mockTabManager = MockTabManager(TabManagerState(
      tabs: [
        TabState(id: '1', currentPath: '/home/user/downloads'),
        TabState(id: '2', currentPath: '/home/user/music'),
        TabState(id: '3', currentPath: '/home/user/videos'),
        TabState(id: '4', currentPath: '/home/user/desktop'),
        TabState(id: '5', currentPath: '/'), // title will be Root
        TabState(id: '6', currentPath: '/home/user/documents'),
      ],
      activeTabIndex: 0,
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tabManagerProvider.overrideWith(() => mockTabManager),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: GnomeTabBar(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('downloads'), findsOneWidget);
    expect(find.text('music'), findsOneWidget);
    expect(find.text('videos'), findsOneWidget);
    expect(find.text('desktop'), findsOneWidget);
    expect(find.text('Root'), findsOneWidget);
    expect(find.text('documents'), findsOneWidget);

    // Switch tab on tap
    await tester.tap(find.text('music'));
    await tester.pumpAndSettle();
    expect(mockTabManager.switchedToId, '2');
  });

  testWidgets('GnomeTabBar closes tab on close button tap', (tester) async {
    final mockTabManager = MockTabManager(TabManagerState(
      tabs: [
        TabState(id: '1', currentPath: '/home/user/downloads'),
        TabState(id: '2', currentPath: '/home/user/music'),
      ],
      activeTabIndex: 0,
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tabManagerProvider.overrideWith(() => mockTabManager),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: GnomeTabBar(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Hover over music tab to show its close button
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    await gesture.moveTo(tester.getCenter(find.text('music')));
    await tester.pumpAndSettle();

    final closeButtons = find.byIcon(Icons.close);
    expect(closeButtons, findsNWidgets(2)); // Both active and hovered inactive tab have close buttons

    await tester.tap(closeButtons.last);
    await tester.pumpAndSettle();

    expect(mockTabManager.closedTabId, '2');
  });

  testWidgets('GnomeTabBar drag and drop accepts dropped items', (tester) async {
    final mockTabManager = MockTabManager(TabManagerState(
      tabs: [
        TabState(id: '1', currentPath: '/home/user/downloads'),
        TabState(id: '2', currentPath: '/home/user/music'),
      ],
      activeTabIndex: 0,
    ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tabManagerProvider.overrideWith(() => mockTabManager),
          directoryRepositoryProvider.overrideWithValue(mockRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: GnomeTabBar(),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final dragTarget = tester.widget<DragTarget<List<String>>>(find.byType(DragTarget<List<String>>).last);
    dragTarget.onAcceptWithDetails?.call(
      DragTargetDetails(
        data: const ['/home/user/downloads/song.mp3'],
        offset: Offset.zero,
      ),
    );
    await tester.pumpAndSettle();

    expect(mockRepo.moveItemsSources, contains('/home/user/downloads/song.mp3'));
    expect(mockRepo.moveItemsDestination, '/home/user/music');

    // Test will accept hover timer triggers switchTab
    dragTarget.onWillAcceptWithDetails?.call(
      DragTargetDetails(
        data: const ['/home/user/downloads/song.mp3'],
        offset: Offset.zero,
      ),
    );
    // Wait for the hover timer of 1000ms
    await tester.pump(const Duration(milliseconds: 1100));
    expect(mockTabManager.switchedToId, '2');
  });
}
