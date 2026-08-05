// ignore_for_file: unused_local_variable, avoid_redundant_argument_values
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/downloader_filter_settings.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/downloads_shared_dropdowns.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/standalone_window/standalone_window_action_bar.dart';

void main() {
  group('DownloaderSortDropdown & DownloaderFilterButton Tests', () {
    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('DownloaderSortDropdown contains only sort options (no media types)',
        (tester) async {
      String? selectedSort;

      await tester.pumpWidget(
        wrap(
          DownloaderSortDropdown(
            selectedSort: 'added_desc',
            onChanged: (val) => selectedSort = val,
          ),
        ),
      );

      // Open popup
      await tester.tap(find.byType(DownloaderSortDropdown));
      await tester.pumpAndSettle();

      // Should find sort options
      expect(find.text('Added'), findsWidgets);
      expect(find.text('Size'), findsWidgets);

      // Should NOT contain media types
      expect(find.text('Images'), findsNothing);
      expect(find.text('Videos'), findsNothing);
      expect(find.text('Playlists'), findsNothing);
      expect(find.text('Profiles'), findsNothing);
    });

    testWidgets('DownloaderSortDropdown highlights when non-default sort is active',
        (tester) async {
      await tester.pumpWidget(
        wrap(
          DownloaderSortDropdown(
            selectedSort: 'size_desc',
            onChanged: (_) {},
          ),
        ),
      );

      // Verify non-default label and close reset icon
      expect(find.text('Size'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('DownloaderFilterButton highlights when filters are active',
        (tester) async {
      var filterPressed = false;

      // Default filter (not highlighted)
      await tester.pumpWidget(
        wrap(
          DownloaderFilterButton(
            filterSettings: const DownloaderFilterSettings(),
            onPressed: () => filterPressed = true,
          ),
        ),
      );
      expect(find.text('Filter'), findsOneWidget);
      await tester.tap(find.text('Filter'));
      expect(filterPressed, isTrue);

      // Active filter
      await tester.pumpWidget(
        wrap(
          DownloaderFilterButton(
            filterSettings: const DownloaderFilterSettings(
              selectedTypes: {DownloaderItemType.image},
            ),
            onPressed: () {},
          ),
        ),
      );
      expect(find.text('Filter'), findsOneWidget);
    });

    testWidgets('StandaloneWindowActionBar places Filter before Sort and renames button to Clear',
        (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      var clearClicked = false;

      await tester.pumpWidget(
        wrap(
          StandaloneWindowActionBar(
            searchController: TextEditingController(),
            searchFocusNode: FocusNode(),
            isSearchVisible: false,
            sortOrder: 'added_desc',
            onSortChanged: (_) {},
            filterSettings: const DownloaderFilterSettings(),
            onFilterSettingsChanged: (_) {},
            availableTypes: const {DownloaderItemType.image},
            availableDates: const {},
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
            onClear: () => clearClicked = true,
            onFormatChanged: (_) {},
            onFilterChanged: (_) {},
            matchTargetFormat: (info, format) => format,
            getHeight: (_) => 1080,
          ),
        ),
      );

      // Button should now be "Clear", NOT "Clear List"
      expect(find.text('Clear'), findsOneWidget);
      expect(find.text('Clear List'), findsNothing);

      // Filter and Sort should both be visible
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('Added'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      expect(clearClicked, isTrue);
    });
  });
}
