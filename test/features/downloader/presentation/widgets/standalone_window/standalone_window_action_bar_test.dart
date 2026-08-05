import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_action_bar.dart';

void main() {
  testWidgets('StandaloneWindowActionBar renders breadcrumbs and buttons in default view', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var clearTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StandaloneWindowActionBar(
            searchController: TextEditingController(),
            searchFocusNode: FocusNode(),
            isSearchVisible: false,
            listFilter: '',
            onListFilterChanged: (v) {},
            isTrashView: false,
            trashNotEmpty: false,
            hasItems: true,
            currentGroup: null,
            importedListName: null,
            config: null,
            rootIndex: null,
            onRestoreAll: () {},
            onEmptyTrash: () {},
            onBackToRoot: () {},
            onClear: () => clearTapped = true,
            onFormatChanged: (v) {},
            onFilterChanged: (v) {},
            matchTargetFormat: (info, format) => format,
            getHeight: (res) => 1080,
          ),
        ),
      ),
    );

    expect(find.text('Default List'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    expect(clearTapped, isTrue);
  });

  testWidgets('StandaloneWindowActionBar renders trash view with buttons', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var restoreAllTapped = false;
    var emptyTrashTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StandaloneWindowActionBar(
            searchController: TextEditingController(),
            searchFocusNode: FocusNode(),
            isSearchVisible: false,
            listFilter: '',
            onListFilterChanged: (v) {},
            isTrashView: true,
            trashNotEmpty: true,
            hasItems: false,
            currentGroup: null,
            importedListName: null,
            config: null,
            rootIndex: null,
            onRestoreAll: () => restoreAllTapped = true,
            onEmptyTrash: () => emptyTrashTapped = true,
            onBackToRoot: () {},
            onClear: () {},
            onFormatChanged: (v) {},
            onFilterChanged: (v) {},
            matchTargetFormat: (info, format) => format,
            getHeight: (res) => 1080,
          ),
        ),
      ),
    );

    expect(find.text('Trash'), findsOneWidget);
    expect(find.text('Restore All'), findsOneWidget);
    expect(find.text('Empty'), findsOneWidget);

    await tester.tap(find.text('Restore All'));
    expect(restoreAllTapped, isTrue);

    await tester.tap(find.text('Empty'));
    expect(emptyTrashTapped, isTrue);
  });

  testWidgets('StandaloneWindowActionBar renders trash view without buttons when empty', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StandaloneWindowActionBar(
            searchController: TextEditingController(),
            searchFocusNode: FocusNode(),
            isSearchVisible: false,
            listFilter: '',
            onListFilterChanged: (v) {},
            isTrashView: true,
            trashNotEmpty: false,
            hasItems: false,
            currentGroup: null,
            importedListName: null,
            config: null,
            rootIndex: null,
            onRestoreAll: () {},
            onEmptyTrash: () {},
            onBackToRoot: () {},
            onClear: () {},
            onFormatChanged: (v) {},
            onFilterChanged: (v) {},
            matchTargetFormat: (info, format) => format,
            getHeight: (res) => 1080,
          ),
        ),
      ),
    );

    expect(find.text('Trash'), findsOneWidget);
    expect(find.text('Restore All'), findsNothing);
    expect(find.text('Empty'), findsNothing);
  });

  testWidgets('StandaloneWindowActionBar renders breadcrumbs for currentGroup', (tester) async {
    var backToRootTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StandaloneWindowActionBar(
            searchController: TextEditingController(),
            searchFocusNode: FocusNode(),
            isSearchVisible: false,
            listFilter: '',
            onListFilterChanged: (v) {},
            isTrashView: false,
            trashNotEmpty: false,
            hasItems: true,
            currentGroup: const MediaGroup(originalUrl: 'url', items: [MediaInfo(id: '1', title: 'Group Title', originalUrl: 'url')]),
            importedListName: 'My Custom List',
            config: null,
            rootIndex: null,
            onRestoreAll: () {},
            onEmptyTrash: () {},
            onBackToRoot: () => backToRootTapped = true,
            onClear: () {},
            onFormatChanged: (v) {},
            onFilterChanged: (v) {},
            matchTargetFormat: (info, format) => format,
            getHeight: (res) => 1080,
          ),
        ),
      ),
    );

    expect(find.text('My Custom List'), findsOneWidget);
    expect(find.text('Group Title'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    expect(backToRootTapped, isTrue);
  });
}
