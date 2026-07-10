import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_media_list.dart';

void main() {
  testWidgets('StandaloneWindowMediaList renders basic components and interactions', (tester) async {
    bool trashTapped = false;
    bool importTapped = false;
    bool defaultListTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StandaloneWindowMediaList(
            isTrashView: false,
            importedListName: null,
            isListChanged: false,
            lastCustomListName: null,
            lastCustomListVideos: 0,
            lastCustomListImages: 0,
            lastCustomListSize: 0,
            onTrashTap: () => trashTapped = true,
            onImportTap: () => importTapped = true,
            onDefaultListTap: () => defaultListTapped = true,
            onCustomListTap: () {},
            onCustomListClose: () {},
            onCustomListSave: () {},
          ),
        ),
      ),
    );

    expect(find.text('Media List'), findsOneWidget);
    expect(find.text('Trash'), findsOneWidget);
    expect(find.text('Import'), findsOneWidget);
    expect(find.text('Default List'), findsOneWidget);

    await tester.tap(find.text('Trash'));
    expect(trashTapped, isTrue);

    await tester.tap(find.text('Import'));
    expect(importTapped, isTrue);

    await tester.tap(find.text('Default List'));
    expect(defaultListTapped, isTrue);
  });

  testWidgets('StandaloneWindowMediaList renders custom list and handles close without changes', (tester) async {
    bool customListTapped = false;
    bool customListClosed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StandaloneWindowMediaList(
            isTrashView: false,
            importedListName: 'My List',
            isListChanged: false,
            lastCustomListName: null,
            lastCustomListVideos: 0,
            lastCustomListImages: 0,
            lastCustomListSize: 0,
            onTrashTap: () {},
            onImportTap: () {},
            onDefaultListTap: () {},
            onCustomListTap: () => customListTapped = true,
            onCustomListClose: () => customListClosed = true,
            onCustomListSave: () {},
          ),
        ),
      ),
    );

    expect(find.text('My List'), findsOneWidget);
    
    // Tap custom list
    await tester.tap(find.text('My List'));
    expect(customListTapped, isTrue);

    // Tap close icon
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    
    expect(customListClosed, isTrue);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('StandaloneWindowMediaList handles close with unsaved changes', (tester) async {
    bool customListClosed = false;
    bool customListSaved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StandaloneWindowMediaList(
            isTrashView: false,
            importedListName: 'My Changed List',
            isListChanged: true,
            lastCustomListName: null,
            lastCustomListVideos: 0,
            lastCustomListImages: 0,
            lastCustomListSize: 0,
            onTrashTap: () {},
            onImportTap: () {},
            onDefaultListTap: () {},
            onCustomListTap: () {},
            onCustomListClose: () => customListClosed = true,
            onCustomListSave: () => customListSaved = true,
          ),
        ),
      ),
    );

    // Tap close icon
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // Dialog should appear
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Unsaved Changes'), findsOneWidget);

    // Cancel dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(customListClosed, isFalse);

    // Tap close again and Discard
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(customListClosed, isTrue);

    // Tap close again and Save
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(customListSaved, isTrue);
  });
}
