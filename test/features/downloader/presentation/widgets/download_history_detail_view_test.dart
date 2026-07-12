// ignore_for_file: undefined_getter, use_named_constants
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/navigation_state.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/selection_state.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/navigation_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_history_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_history_detail_view.dart';

class MockDownloadHistoryNotifier extends Notifier<List<DownloadHistoryEntry>> with Mock implements DownloadHistoryNotifier {
  @override
  List<DownloadHistoryEntry> build() => [];
}

class MockNavigationNotifier extends Notifier<NavigationState> with Mock implements NavigationNotifier {
  @override
  NavigationState build() => const NavigationState();
}

class MockSelectionNotifier extends Notifier<SelectionState> with Mock implements SelectionNotifier {
  @override
  SelectionState build() => const SelectionState();
}

void main() {
  late MockDownloadHistoryNotifier mockHistoryNotifier;
  late MockNavigationNotifier mockNavigationNotifier;
  late MockSelectionNotifier mockSelectionNotifier;

  setUp(() {
    mockHistoryNotifier = MockDownloadHistoryNotifier();
    mockNavigationNotifier = MockNavigationNotifier();
    mockSelectionNotifier = MockSelectionNotifier();
  });

  Widget createWidget({
    String? selectedId,
    DownloadHistoryEntry? entryToReturn,
    Exception? entryError,
  }) {
    when(() => mockHistoryNotifier.getEntry(any())).thenAnswer((_) async {
      if (entryError != null) throw entryError;
      return entryToReturn;
    });

    return ProviderScope(
      key: UniqueKey(),
      overrides: [
        selectedDownloadHistoryIdProvider.overrideWith((ref) => selectedId),
        downloadHistoryProvider.overrideWith(() => mockHistoryNotifier),
        navigationProvider.overrideWith(() => mockNavigationNotifier),
        selectionProvider.overrideWith(() => mockSelectionNotifier),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: DownloadHistoryDetailView(),
        ),
      ),
    );
  }

  testWidgets('W-DL-HDT-01: render an empty box when no history id is selected', (tester) async {
    await tester.pumpWidget(createWidget());
    
    expect(find.byType(SizedBox), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Download Details'), findsNothing);
  });

  testWidgets('W-DL-HDT-02: show a centered progress indicator while entry lookup is in flight', (tester) async {
    // Return a Future that never completes to stay in loading state
    when(() => mockHistoryNotifier.getEntry(any())).thenAnswer((_) => Completer<DownloadHistoryEntry?>().future);

    await tester.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        selectedDownloadHistoryIdProvider.overrideWith((ref) => 'id1'),
        downloadHistoryProvider.overrideWith(() => mockHistoryNotifier),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: DownloadHistoryDetailView(),
        ),
      ),
    ));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('W-DL-HDT-03a: show History not found for null entries', (tester) async {
    await tester.pumpWidget(createWidget(selectedId: 'id1'));
    await tester.pumpAndSettle();
    expect(find.text('History not found'), findsOneWidget);
  });

  testWidgets('W-DL-HDT-03b: show History not found for provider errors', (tester) async {
    await tester.pumpWidget(createWidget(selectedId: 'id2', entryError: Exception('Database error')));
    await tester.pumpAndSettle();
    expect(find.text('History not found'), findsOneWidget);
  });

  testWidgets('W-DL-HDT-04: header back action', (tester) async {
    final entry = DownloadHistoryEntry(
      id: 'id1',
      title: 'Test',
      url: 'url',
      destination: 'dest',
      statusName: 'Completed',
      createdAt: DateTime.now(),
    );

    final container = ProviderContainer(
      overrides: [
        selectedDownloadHistoryIdProvider.overrideWith((ref) => 'id1'),
        downloadHistoryProvider.overrideWith(() => mockHistoryNotifier),
      ],
    );

    when(() => mockHistoryNotifier.getEntry(any())).thenAnswer((_) async => entry);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: DownloadHistoryDetailView(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Download Details'), findsOneWidget);
    
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    expect(container.read(selectedDownloadHistoryIdProvider), null);
    expect(container.read(downloadsPanelViewProvider), DownloadsPanelView.history);
  });

  testWidgets('W-DL-HDT-05: header delete action', (tester) async {
    final entry = DownloadHistoryEntry(
      id: 'id1',
      title: 'Test',
      url: 'url',
      destination: 'dest',
      statusName: 'Completed',
      createdAt: DateTime.now(),
    );

    when(() => mockHistoryNotifier.deleteEntry(any())).thenAnswer((_) async {});

    final container = ProviderContainer(
      overrides: [
        selectedDownloadHistoryIdProvider.overrideWith((ref) => 'id1'),
        downloadHistoryProvider.overrideWith(() => mockHistoryNotifier),
      ],
    );

    when(() => mockHistoryNotifier.getEntry(any())).thenAnswer((_) async => entry);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: DownloadHistoryDetailView(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    verify(() => mockHistoryNotifier.deleteEntry('id1')).called(1);
    expect(container.read(selectedDownloadHistoryIdProvider), null);
    expect(container.read(downloadsPanelViewProvider), DownloadsPanelView.history);
  });

  testWidgets('W-DL-HDT-06: header close action', (tester) async {
    final entry = DownloadHistoryEntry(
      id: 'id1',
      title: 'Test',
      url: 'url',
      destination: 'dest',
      statusName: 'Completed',
      createdAt: DateTime.now(),
    );

    final container = ProviderContainer(
      overrides: [
        selectedDownloadHistoryIdProvider.overrideWith((ref) => 'id1'),
        downloadHistoryProvider.overrideWith(() => mockHistoryNotifier),
      ],
    );

    when(() => mockHistoryNotifier.getEntry(any())).thenAnswer((_) async => entry);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: DownloadHistoryDetailView(),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();

    expect(container.read(selectedDownloadHistoryIdProvider), null);
    expect(container.read(downloadsPanelViewProvider), DownloadsPanelView.tasks);
  });

  testWidgets('W-DL-HDT-07a: title/status card (Completed)', (tester) async {
    final completedEntry = DownloadHistoryEntry(
      id: '1', title: 'Vid 1', url: 'u', destination: 'd', statusName: 'Completed', createdAt: DateTime.now(),
    );
    await tester.pumpWidget(createWidget(selectedId: '1', entryToReturn: completedEntry));
    await tester.pumpAndSettle();
    expect(find.text('Vid 1'), findsOneWidget);
    expect(find.text('COMPLETED'), findsOneWidget);
  });

  testWidgets('W-DL-HDT-07b: title/status card (Error)', (tester) async {
    final errorEntry = DownloadHistoryEntry(
      id: '2', title: 'Vid 2', url: 'u', destination: 'd', statusName: 'Error', createdAt: DateTime.now(),
    );
    await tester.pumpWidget(createWidget(selectedId: '2', entryToReturn: errorEntry));
    await tester.pumpAndSettle();
    expect(find.text('Vid 2'), findsOneWidget);
    expect(find.text('ERROR'), findsOneWidget);
  });

  testWidgets('W-DL-HDT-07c: title/status card (Cancelled)', (tester) async {
    final cancelledEntry = DownloadHistoryEntry(
      id: '3', title: 'Vid 3', url: 'u', destination: 'd', statusName: 'Cancelled', createdAt: DateTime.now(),
    );
    await tester.pumpWidget(createWidget(selectedId: '3', entryToReturn: cancelledEntry));
    await tester.pumpAndSettle();
    expect(find.text('Vid 3'), findsOneWidget);
    expect(find.text('CANCELLED'), findsOneWidget);
  });

  testWidgets('W-DL-HDT-08a: error banner visible', (tester) async {
    final entryWithError = DownloadHistoryEntry(
      id: '1', title: 'T', url: 'u', destination: 'd', statusName: 'Error', createdAt: DateTime.now(),
      errorMessage: 'Network failed',
    );
    
    await tester.pumpWidget(createWidget(selectedId: '1', entryToReturn: entryWithError));
    await tester.pumpAndSettle();
    
    expect(find.text('Network failed'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
  });

  testWidgets('W-DL-HDT-08b: error banner hidden', (tester) async {
    final entryWithoutError = DownloadHistoryEntry(
      id: '2', title: 'T', url: 'u', destination: 'd', statusName: 'Completed', createdAt: DateTime.now(),
    );

    await tester.pumpWidget(createWidget(selectedId: '2', entryToReturn: entryWithoutError));
    await tester.pumpAndSettle();

    expect(find.text('Network failed'), findsNothing);
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
  });

  testWidgets('W-DL-HDT-09: source URL path item', (tester) async {
    const longUrl = 'https://www.example.com/some/very/long/path/that/needs/to/be/truncated/because/it/is/too/long/for/the/screen.mp4';
    final entry = DownloadHistoryEntry(
      id: '1', title: 'T', url: longUrl, destination: 'd', statusName: 'Completed', createdAt: DateTime.now(),
    );

    await tester.pumpWidget(createWidget(selectedId: '1', entryToReturn: entry));
    await tester.pumpAndSettle();

    expect(find.text('Source URL'), findsOneWidget);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    // Should be truncated
    final urlTextFinder = find.descendant(
      of: find.widgetWithText(Row, 'Source URL'),
      matching: find.byType(Text),
    );
    final urlTextWidget = tester.widget<Text>(urlTextFinder.last);
    expect(urlTextWidget.data, contains('...'));
  });

  testWidgets('W-DL-HDT-10: source URL copy action', (tester) async {
    final entry = DownloadHistoryEntry(
      id: '1', title: 'T', url: 'https://example.com/video', destination: 'd', statusName: 'Completed', createdAt: DateTime.now(),
    );

    await tester.pumpWidget(createWidget(selectedId: '1', entryToReturn: entry));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.copy_rounded));
    await tester.pump();

    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    
    await tester.pump(const Duration(seconds: 3));
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
  });

  testWidgets('W-DL-HDT-11: destination path item visibility', (tester) async {
    final entry = DownloadHistoryEntry(
      id: '1', title: 'T', url: 'u', destination: '/non/existent/path/file.mp4', statusName: 'Completed', createdAt: DateTime.now(),
    );

    await tester.pumpWidget(createWidget(selectedId: '1', entryToReturn: entry));
    await tester.pumpAndSettle();

    expect(find.text('Destination'), findsOneWidget);
    expect(find.text('/non/existent/path/file.mp4'), findsOneWidget);
  });

  testWidgets('W-DL-HDT-13: processed-items extraction', (tester) async {
    final entry = DownloadHistoryEntry(
      id: '1', title: 'T', url: 'u', destination: 'd', statusName: 'Completed', createdAt: DateTime.now(),
      logs: [
        '[download] Destination: /tmp/file1.mp4',
        '[Merger] Merging formats into "/tmp/file2.mkv"',
        '[download] /tmp/file3.webm has already been downloaded',
        '/tmp/file4.jpg',
        '/tmp/info.json',
      ]
    );

    await tester.pumpWidget(createWidget(selectedId: '1', entryToReturn: entry));
    await tester.pumpAndSettle();

    expect(find.text('PROCESSED ITEMS'), findsOneWidget);
    expect(find.text('file1.mp4'), findsOneWidget);
    expect(find.text('file2.mkv'), findsOneWidget);
    expect(find.text('file3.webm'), findsOneWidget);
    expect(find.text('file4.jpg'), findsOneWidget);
    expect(find.text('info.json'), findsNothing);
  });

  testWidgets('W-DL-HDT-15: statistics grid', (tester) async {
    final entry = DownloadHistoryEntry(
      id: '1', title: 'T', url: 'u', destination: 'd', statusName: 'Completed', createdAt: DateTime.now(),
      completedAt: DateTime.now().add(const Duration(seconds: 150)),
    );

    await tester.pumpWidget(createWidget(selectedId: '1', entryToReturn: entry));
    await tester.pumpAndSettle();

    expect(find.text('STATISTICS'), findsOneWidget);
    expect(find.text('DURATION'), findsOneWidget);
    expect(find.text('2m 30s'), findsOneWidget);
    expect(find.text('ITEMS'), findsOneWidget);
    expect(find.text('SIZE'), findsOneWidget);
  });

  testWidgets('W-DL-HDT-16: timeline', (tester) async {
    final createdAt = DateTime(2023, 1, 1, 12);
    final completedAt = DateTime(2023, 1, 1, 12, 5);
    final entry = DownloadHistoryEntry(
      id: '1', title: 'T', url: 'u', destination: 'd', statusName: 'Completed', 
      createdAt: createdAt, completedAt: completedAt,
    );

    await tester.pumpWidget(createWidget(selectedId: '1', entryToReturn: entry));
    await tester.pumpAndSettle();

    expect(find.text('TIMELINE'), findsOneWidget);
    expect(find.text('Created'), findsOneWidget);
    expect(find.text('Finished'), findsOneWidget);
  });

  testWidgets('W-DL-HDT-17: logs section hidden path', (tester) async {
    final entry = DownloadHistoryEntry(
      id: '1', title: 'T', url: 'u', destination: 'd', statusName: 'Completed', createdAt: DateTime.now(),
      logs: [],
    );

    await tester.pumpWidget(createWidget(selectedId: '1', entryToReturn: entry));
    await tester.pumpAndSettle();

    expect(find.text('Execution Logs'), findsNothing);
  });

  testWidgets('W-DL-HDT-18: logs accordion', (tester) async {
    final entry = DownloadHistoryEntry(
      id: '1', title: 'T', url: 'u', destination: 'd', statusName: 'Completed', createdAt: DateTime.now(),
      logs: ['Log line 1', 'Log line 2'],
    );

    await tester.pumpWidget(createWidget(selectedId: '1', entryToReturn: entry));
    await tester.pumpAndSettle();

    expect(find.text('Execution Logs'), findsOneWidget);
    expect(find.text('2 entries recorded'), findsOneWidget);
    expect(find.text('Log line 1'), findsNothing);

    await tester.tap(find.text('Execution Logs'));
    await tester.pumpAndSettle();

    expect(find.text('Log line 1'), findsOneWidget);
    expect(find.text('Log line 2'), findsOneWidget);
  });

  testWidgets('W-DL-HDT-20: logs copy action', (tester) async {
    final entry = DownloadHistoryEntry(
      id: '1', title: 'T', url: 'u', destination: 'd', statusName: 'Completed', createdAt: DateTime.now(),
      logs: ['Log line 1', 'Log line 2'],
    );

    await tester.pumpWidget(createWidget(selectedId: '1', entryToReturn: entry));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Execution Logs'));
    await tester.pumpAndSettle();

    final copyButton = find.byIcon(Icons.copy_rounded).last; // First one is Source URL
    await tester.ensureVisible(copyButton);
    await tester.tap(copyButton);
    await tester.pump();
    
    // Test passes if it pumps successfully without crashing
  }, skip: true);
}
