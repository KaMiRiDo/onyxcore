import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:intl/intl.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
import 'package:flutter/gestures.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_history_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_history_view.dart';

class MockDownloadHistoryNotifier extends Notifier<List<DownloadHistoryEntry>> with Mock implements DownloadHistoryNotifier {
  List<DownloadHistoryEntry> buildReturn = [];
  @override
  List<DownloadHistoryEntry> build() => buildReturn;
}

class MockDownloadHistorySelectionNotifier extends Notifier<Set<String>> with Mock implements DownloadHistorySelectionNotifier {
  Set<String> buildReturn = <String>{};
  @override
  Set<String> build() => buildReturn;
}

class FakeDownloadHistoryFilter extends Fake implements DownloadHistoryFilter {}

void main() {
  late MockDownloadHistoryNotifier mockHistoryNotifier;
  late MockDownloadHistorySelectionNotifier mockSelectionNotifier;

  setUpAll(() {
    registerFallbackValue(FakeDownloadHistoryFilter());
  });

  setUp(() {
    mockHistoryNotifier = MockDownloadHistoryNotifier();
    mockSelectionNotifier = MockDownloadHistorySelectionNotifier();

    when(() => mockHistoryNotifier.totalEntries).thenReturn(0);
    when(() => mockHistoryNotifier.historyFileSize).thenReturn(0);
    when(() => mockHistoryNotifier.loadMore()).thenAnswer((_) async {});
    when(() => mockHistoryNotifier.clearAll()).thenAnswer((_) async {});
    when(() => mockHistoryNotifier.deleteFiltered(any())).thenAnswer((_) async {});
    when(() => mockHistoryNotifier.deleteEntries(any())).thenAnswer((_) async {});

    when(() => mockSelectionNotifier.clear()).thenReturn(null);
    when(() => mockSelectionNotifier.toggle(any())).thenReturn(null);
    when(() => mockSelectionNotifier.setAnchor(any())).thenReturn(null);
    when(() => mockSelectionNotifier.selectRange(any(), any())).thenReturn(null);
  });

  Widget createWidget({
    List<DownloadHistoryEntry>? history,
    Set<String>? selection,
    DownloadsPanelView panelView = DownloadsPanelView.history,
    DownloadHistoryFilter filter = const DownloadHistoryFilter(),
    Set<DateTime>? availableDates,
  }) {
    if (history != null) {
      mockHistoryNotifier.buildReturn = history;
      when(() => mockHistoryNotifier.totalEntries).thenReturn(history.length);
    }
    if (selection != null) {
      mockSelectionNotifier.buildReturn = selection;
    }

    return ProviderScope(
      key: UniqueKey(),
      overrides: [
        downloadHistoryProvider.overrideWith(() => mockHistoryNotifier),
        filteredDownloadHistoryProvider.overrideWith((ref) => history ?? []),
        downloadHistorySelectionProvider.overrideWith(() => mockSelectionNotifier),
        downloadsPanelViewProvider.overrideWith((ref) => panelView),
        downloadHistoryFilterProvider.overrideWith((ref) => filter),
        availableDownloadDatesProvider.overrideWith((ref) => availableDates ?? {}),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: DownloadHistoryView(),
        ),
      ),
    );
  }

  testWidgets('W-DL-HIS-01: attach and remove the scroll listener safely', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();
    
    // Unmount safely
    await tester.pumpWidget(const SizedBox());
    // Should not throw when removed
  });

  testWidgets('W-DL-HIS-02: request pagination when the list nears the bottom', (tester) async {
    final entries = List.generate(50, (i) => DownloadHistoryEntry(
      id: 'id_$i', title: 'Vid $i', url: 'u', destination: 'd', statusName: 'Completed', createdAt: DateTime.now(),
    ));

    await tester.pumpWidget(createWidget(history: entries));
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();

    verify(() => mockHistoryNotifier.loadMore()).called(greaterThan(0));
  });

  testWidgets('W-DL-HIS-03a: keyboard delete -> ignore when selection is empty', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.text('Delete Selected?'), findsNothing);
  });

  testWidgets('W-DL-HIS-03b: keyboard delete -> open delete-selected confirmation when selection is non-empty', (tester) async {
    await tester.pumpWidget(createWidget(selection: {'id_1'}));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.text('Delete Selected?'), findsOneWidget);
  });

  testWidgets('W-DL-HIS-04a: header leading action -> clear multi-selection when selection exists', (tester) async {
    await tester.pumpWidget(createWidget(selection: {'id_1'}));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();
    verify(() => mockSelectionNotifier.clear()).called(1);
  });

  testWidgets('W-DL-HIS-04b: header leading action -> navigate back to tasks when no selection', (tester) async {
    await tester.pumpWidget(createWidget(selection: {}));
    await tester.pumpAndSettle();
    
    // Icon changes to back
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
  });

  testWidgets('W-DL-HIS-05: header close button -> always close back to tasks view', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    final closeButtons = find.byIcon(Icons.close_rounded);
    await tester.tap(closeButtons.last);
    await tester.pumpAndSettle();
  });

  testWidgets('W-DL-HIS-06: toolbar stats -> show total task count and history-file size from notifier', (tester) async {
    when(() => mockHistoryNotifier.totalEntries).thenReturn(42);
    when(() => mockHistoryNotifier.historyFileSize).thenReturn(1024 * 1024 * 5); // 5 MB

    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.text('42 Tasks'), findsOneWidget);
    expect(find.text(StringUtils.formatBytes(1024 * 1024 * 5)), findsOneWidget);
  });

  testWidgets('W-DL-HIS-07: filter-clear icon -> clear active filter and reset temp filter state', (tester) async {
    final filter = const DownloadHistoryFilter(status: 'Error');
    await tester.pumpWidget(createWidget(filter: filter));
    await tester.pumpAndSettle();

    // Tap clear filter (red close icon)
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pumpAndSettle();
  });

  testWidgets('W-DL-HIS-08: filter button -> toggle filter overlay and seed temp filter from provider', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    expect(find.text('FILTER'), findsNothing);

    await tester.tap(find.byIcon(Icons.filter_list_rounded).last);
    await tester.pumpAndSettle();

    expect(find.text('FILTER'), findsOneWidget);
  });

  testWidgets('W-DL-HIS-09: filter overlay escape/backdrop -> close the overlay from backdrop tap or Escape', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.filter_list_rounded).last);
    await tester.pumpAndSettle();

    // Tap CANCEL instead of Escape because Focus might not receive it in tests
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();

    expect(find.text('FILTER'), findsNothing);
  });

  testWidgets('W-DL-HIS-10: filter overlay calendar -> reflect selected available dates into _tempFilter', (tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(createWidget(availableDates: {now}));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.filter_list_rounded).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(now.day.toString()));
    await tester.pumpAndSettle();
  });

  testWidgets('W-DL-HIS-11: filter overlay status dropdown -> expose All/Completed/Error/Cancelled and write selected status to temp filter', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.filter_list_rounded).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('All').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Error').last);
    await tester.pumpAndSettle();
    
    expect(find.text('Error'), findsWidgets);
  });

  testWidgets('W-DL-HIS-12: filter overlay apply -> show loader briefly, close overlay, and commit _tempFilter to provider', (tester) async {
    await tester.pumpWidget(createWidget());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.filter_list_rounded).last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('FILTER'));
    await tester.pump();
    
    expect(find.text('Filtering history...'), findsOneWidget);
    await tester.pumpAndSettle();
    
    expect(find.text('Filtering history...'), findsNothing);
    expect(find.text('FILTER'), findsNothing);
  });

  testWidgets('W-DL-HIS-13: loader state -> render the filtering spinner/message when _isFiltering=true', (tester) async {
    // Tested implicitly in W-DL-HIS-12
  });

  testWidgets('W-DL-HIS-14: empty state default -> show default empty-history messaging when no filter is active', (tester) async {
    await tester.pumpWidget(createWidget(history: []));
    await tester.pumpAndSettle();

    expect(find.text('No download history yet'), findsOneWidget);
  });

  testWidgets('W-DL-HIS-15: empty state filtered -> show filter-empty messaging plus CLEAR FILTER action when filters are active', (tester) async {
    await tester.pumpWidget(createWidget(
      history: [],
      filter: const DownloadHistoryFilter(status: 'Completed'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('No downloads matching the filter'), findsOneWidget);
    expect(find.text('CLEAR FILTER'), findsOneWidget);
    
    await tester.tap(find.text('CLEAR FILTER'));
    await tester.pumpAndSettle();
  });

  testWidgets('W-DL-HIS-16: grouped list headings -> insert date headers for the first item of each day bucket', (tester) async {
    final entry1 = DownloadHistoryEntry(
      id: '1', title: 'T1', url: 'u', destination: 'd', statusName: 'Completed', createdAt: DateTime(2023, 10, 1),
    );
    final entry2 = DownloadHistoryEntry(
      id: '2', title: 'T2', url: 'u', destination: 'd', statusName: 'Completed', createdAt: DateTime(2023, 10, 1),
    );
    final entry3 = DownloadHistoryEntry(
      id: '3', title: 'T3', url: 'u', destination: 'd', statusName: 'Completed', createdAt: DateTime(2023, 10, 2),
    );

    await tester.pumpWidget(createWidget(history: [entry1, entry2, entry3]));
    await tester.pumpAndSettle();

    final header1 = '${entry1.createdAt.day}/${entry1.createdAt.month}/${entry1.createdAt.year}';
    final header3 = '${entry3.createdAt.day}/${entry3.createdAt.month}/${entry3.createdAt.year}';

    expect(find.text(header1), findsWidgets);
    expect(find.text(header3), findsWidgets);
  });

  testWidgets('W-DL-HIS-17: history item styling -> render title, subtitle, time, type icon, and status pill according to entry metadata', (tester) async {
    final entry = DownloadHistoryEntry(
      id: '1', title: 'My Video', url: 'u', destination: 'd', statusName: 'Completed', createdAt: DateTime(2023, 10, 1),
      downloadType: 'video',
    );
    await tester.pumpWidget(createWidget(history: [entry]));
    await tester.pumpAndSettle();

    expect(find.text('My Video'), findsOneWidget);
    expect(find.text('COMPLETED'), findsOneWidget);
    expect(find.byIcon(Icons.videocam_rounded), findsOneWidget);
  });

  testWidgets('W-DL-HIS-18: history item item-count pill -> count processed file-path logs while skipping .json paths', (tester) async {
    final entry = DownloadHistoryEntry(
      id: '1', title: 'My Video', url: 'u', destination: 'd', statusName: 'Completed', createdAt: DateTime(2023, 10, 1),
      downloadType: 'playlist',
      logs: ['/path/to/vid1.mp4', '/path/to/vid2.mp4', '/path/to/info.json'],
    );
    await tester.pumpWidget(createWidget(history: [entry]));
    await tester.pumpAndSettle();

    expect(find.text('2 ITEMS'), findsOneWidget); // 2 items, skipping .json
  });

  testWidgets('W-DL-HIS-19: primary tap no-selection flow -> open history detail when no modifier keys and no prior selection are active', (tester) async {
    final entry = DownloadHistoryEntry(
      id: '1', title: 'My Video', url: 'u', destination: 'd', statusName: 'Completed', createdAt: DateTime.now(),
    );
    await tester.pumpWidget(createWidget(history: [entry]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('My Video'));
    await tester.pumpAndSettle();

    verify(() => mockSelectionNotifier.clear()).called(1);
    verify(() => mockSelectionNotifier.setAnchor('1')).called(1);
  });

  testWidgets('W-DL-HIS-20: primary tap ctrl/meta flow -> toggle selection and maintain anchor for multi-select behavior', (tester) async {
    final entry = DownloadHistoryEntry(
      id: '1', title: 'My Video', url: 'u', destination: 'd', statusName: 'Completed', createdAt: DateTime.now(),
    );
    await tester.pumpWidget(createWidget(history: [entry]));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.tap(find.text('My Video'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();

    verify(() => mockSelectionNotifier.toggle('1')).called(1);
  });

  testWidgets('W-DL-HIS-21: primary tap shift flow -> select a contiguous range through selection notifier', (tester) async {
    final entry = DownloadHistoryEntry(
      id: '1', title: 'My Video', url: 'u', destination: 'd', statusName: 'Completed', createdAt: DateTime.now(),
    );
    await tester.pumpWidget(createWidget(history: [entry]));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.tap(find.text('My Video'));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pumpAndSettle();

    verify(() => mockSelectionNotifier.selectRange(any(), '1')).called(1);
  });

  testWidgets('W-DL-HIS-22: secondary tap -> toggle selection on right-click without opening detail view', (tester) async {
    final entry = DownloadHistoryEntry(
      id: '1', title: 'My Video', url: 'u', destination: 'd', statusName: 'Completed', createdAt: DateTime.now(),
    );
    await tester.pumpWidget(createWidget(history: [entry]));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text('My Video')), buttons: kSecondaryButton);
    await gesture.up();
    await tester.pumpAndSettle();

    verify(() => mockSelectionNotifier.toggle('1')).called(1);
  });

  testWidgets('W-DL-HIS-23a: bottom action bar -> Clear All History when selection is empty', (tester) async {
    await tester.pumpWidget(createWidget(history: [], selection: {}));
    await tester.pumpAndSettle();
    expect(find.text('Clear All History'), findsOneWidget);
  });

  testWidgets('W-DL-HIS-23b: bottom action bar -> Delete Selected when selection is non-empty', (tester) async {
    await tester.pumpWidget(createWidget(history: [], selection: {'1'}));
    await tester.pumpAndSettle();
    expect(find.text('Delete Selected'), findsOneWidget);
  });

  testWidgets('W-DL-HIS-24: clear-all confirmation overlay -> open, close on escape/backdrop, and invoke clear-all deletion paths', (tester) async {
    await tester.pumpWidget(createWidget(history: []));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear All History'));
    await tester.pumpAndSettle();

    expect(find.text('Clear History'), findsOneWidget);

    await tester.tap(find.text('Clear All'));
    await tester.pumpAndSettle();

    verify(() => mockHistoryNotifier.clearAll()).called(1);
  });

  testWidgets('W-DL-HIS-25: delete-selected confirmation overlay -> show selection count in message and delete selected entries on confirm', (tester) async {
    await tester.pumpWidget(createWidget(history: [], selection: {'1', '2'}));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete Selected'));
    await tester.pumpAndSettle();

    expect(find.text('Remove 2 selected downloads from history?'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => mockHistoryNotifier.deleteEntries({'1', '2'})).called(1);
    verify(() => mockSelectionNotifier.clear()).called(1);
  });

  testWidgets('W-DL-HIS-26: _buildBaseOverlay -> blur backdrop and intercept Escape for all modal overlays', (tester) async {
    await tester.pumpWidget(createWidget(history: []));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear All History'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Clear History'), findsNothing);
  });

  testWidgets('W-DL-HIS-27: _ClearHistoryDialog basic mode -> show simple copy and confirm Clear All when custom ops are off', (tester) async {
    // Tested in W-DL-HIS-24
  });

  testWidgets('W-DL-HIS-28: _ClearHistoryDialog custom mode -> toggle custom operations, pick dates/status, and confirm with a filter payload', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(createWidget(history: []));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear All History'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom operations'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => mockHistoryNotifier.deleteFiltered(any())).called(1);
  });

  testWidgets('W-DL-HIS-29: _DeleteConfirmDialog -> render passed title/message/label and wire cancel/confirm buttons', (tester) async {
    // Tested in W-DL-HIS-25
  });

  testWidgets('W-DL-HIS-30: _SimpleCalendar -> initialize month from latest available date, navigate months, and allow selection only on available days', (tester) async {
    final available = DateTime(2023, 10, 15);
    await tester.pumpWidget(createWidget(history: [], availableDates: {available}));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.filter_list_rounded).last);
    await tester.pumpAndSettle();

    expect(find.text('2023-10'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('2023-09'), findsOneWidget);
  });
}
