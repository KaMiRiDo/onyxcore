import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_media_list.dart';

void main() {
  testWidgets('StandaloneWindowMediaList shows lock icon and triggers toggle when clicked', (tester) async {
    var toggleTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StandaloneWindowMediaList(
            isTrashView: false,
            trashCount: 0,
            activeListPath: '/list.dml',
            customLists: [
              CustomListInfo(
                path: '/list.dml', 
                name: 'Locked List',
                hasPassword: true,
              )
            ],
            isListChanged: (path) => false,
            onTrashTap: () {},
            onImportTap: () {},
            onListTap: (_) {},
            onCustomListClose: (_) {},
            onCustomListSave: (_) {},
            onCustomListLock: (_) {},
            onCustomListLockToggle: (path) => toggleTapped = true,
          ),
        ),
      ),
    );

    // Verify lock open icon is shown since it's unlocked (isLocked: false)
    expect(find.byIcon(Icons.lock_open_rounded), findsOneWidget);

    // Tap the icon
    await tester.tap(find.byIcon(Icons.lock_open_rounded));
    await tester.pumpAndSettle();

    // Verify callback was triggered
    expect(toggleTapped, isTrue);
  });
}
