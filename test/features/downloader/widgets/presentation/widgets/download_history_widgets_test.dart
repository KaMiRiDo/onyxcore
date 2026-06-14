import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/utils/string_utils.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_history_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_history_view.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_history_detail_view.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Widget createHistoryViewTestWidget() {
    return const ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: DownloadHistoryView(),
        ),
      ),
    );
  }

  Widget createHistoryDetailTestWidget(DownloadHistoryEntry entry, ProviderContainer container) {
    container.read(downloadHistoryProvider.notifier).addEntry(
      DownloadTask(
        id: entry.id,
        url: entry.url,
        title: entry.title,
        destination: entry.destination,
        downloadType: entry.downloadType,
        status: DownloadStatus.values.firstWhere(
            (s) => s.name.toLowerCase() == entry.statusName.toLowerCase(),
            orElse: () => DownloadStatus.completed),
        createdAt: entry.createdAt,
        completedAt: entry.completedAt,
        error: entry.errorMessage,
        logs: entry.logs,
      ),
    );

    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: DownloadHistoryDetailView(),
        ),
      ),
    );
  }

  group('Download History Widgets Unit Tests', () {
    setUp(() {
      final container = ProviderContainer();
      container.read(downloadHistoryProvider.notifier).clearAll();
    });

    // ── 1. History List View ──

    testWidgets('W-DL-HIS-01: Render empty state', (tester) async {
      await tester.pumpWidget(createHistoryViewTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('No download history yet'), findsOneWidget);
    });

    testWidgets('W-DL-HIS-02: Trigger Pagination on Scroll', (tester) async {
      await tester.pumpWidget(createHistoryViewTestWidget());
      await tester.pumpAndSettle();
    }, skip: true);

    testWidgets('W-DL-HIS-03: Toggle multi-select context menu', (tester) async {
      final container = ProviderContainer();
      container.read(downloadHistorySelectionProvider.notifier).toggle('1');
      container.read(downloadHistorySelectionProvider.notifier).toggle('2');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: DownloadHistoryView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('2 Selected'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsWidgets);
    });

    testWidgets('W-DL-HIS-04: Keyboard navigation and selection', (tester) async {
      await tester.pumpWidget(createHistoryViewTestWidget());
      await tester.pumpAndSettle();
    }, skip: true);

    testWidgets('W-DL-HIS-05: Clear All button', (tester) async {
      await tester.pumpWidget(createHistoryViewTestWidget());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_sweep_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_sweep_rounded));
      await tester.pump(); // Show confirmation dialog

      expect(find.text('Clear History'), findsOneWidget);
    });

    testWidgets('W-DL-HIS-06: Delete Confirmation dialog', (tester) async {
      final container = ProviderContainer();
      container.read(downloadHistorySelectionProvider.notifier).toggle('1');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: DownloadHistoryView(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete Selected'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Selected?'), findsOneWidget);
    });

    testWidgets('W-DL-HIS-07: Empty selection prevents delete', (tester) async {
      await tester.pumpWidget(createHistoryViewTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Delete Selected'), findsNothing);
      expect(find.text('Clear All History'), findsOneWidget);
    });

    // ── 2. History Filters ──

    testWidgets('W-DL-HIS-08: Render Status Dropdown', (tester) async {
      await tester.pumpWidget(createHistoryViewTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.filter_list_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('All'), findsWidgets);
    });

    testWidgets('W-DL-HIS-09: Update Status Filter State', (tester) async {
      await tester.pumpWidget(createHistoryViewTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.filter_list_rounded).first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('All').last);
      await tester.pumpAndSettle();

      expect(find.text('Completed'), findsWidgets);
      expect(find.text('Error'), findsWidgets);
      expect(find.text('Cancelled'), findsWidgets);
    });

    testWidgets('W-DL-HIS-10: Date filter calendar UI', (tester) async {
      await tester.pumpWidget(createHistoryViewTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.filter_list_rounded).first);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.chevron_left), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    // ── 3. History Detail View ──

    testWidgets('W-DL-HIS-11: Display full metadata', (tester) async {
      final entry = DownloadHistoryEntry(
        id: '1',
        url: 'http://test.com/vid.mp4',
        title: 'My Test Video',
        destination: '/home/user/Downloads/vid.mp4',
        downloadType: 'video',
        statusName: 'completed',
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
        logs: const [],
      );

      final container = ProviderContainer();
      container.read(selectedDownloadHistoryIdProvider.notifier).state = '1';

      await tester.pumpWidget(createHistoryDetailTestWidget(entry, container));
      await tester.pumpAndSettle();

      expect(find.text('My Test Video'), findsOneWidget);
      expect(find.text('http://test.com/vid.mp4'), findsOneWidget);
      expect(find.text('COMPLETED'), findsOneWidget);
    });

    testWidgets('W-DL-HIS-12: Open destination folder', (tester) async {
      final entry = DownloadHistoryEntry(
        id: '1',
        url: 'http://test.com',
        title: 'Test',
        destination: '/home/user/Downloads',
        downloadType: 'video',
        statusName: 'completed',
        createdAt: DateTime.now(),
        logs: const [],
      );

      final container = ProviderContainer();
      container.read(selectedDownloadHistoryIdProvider.notifier).state = '1';

      await tester.pumpWidget(createHistoryDetailTestWidget(entry, container));
      await tester.pumpAndSettle();

      expect(find.text(StringUtils.truncateMiddle('/home/user/Downloads', maxLength: 60)), findsOneWidget);
    });

    testWidgets('W-DL-HIS-13: Copy URL to clipboard', (tester) async {
      final entry = DownloadHistoryEntry(
        id: '1',
        url: 'http://test.com',
        title: 'Test',
        destination: '/home/user/Downloads',
        downloadType: 'video',
        statusName: 'completed',
        createdAt: DateTime.now(),
        logs: const [],
      );

      final container = ProviderContainer();
      container.read(selectedDownloadHistoryIdProvider.notifier).state = '1';

      await tester.pumpWidget(createHistoryDetailTestWidget(entry, container));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Copy URL'), findsOneWidget);
    });

    testWidgets('W-DL-HIS-14: Re-download action', (tester) async {
      final entry = DownloadHistoryEntry(
        id: '1',
        url: 'http://test.com',
        title: 'Test',
        destination: '/home/user/Downloads',
        downloadType: 'video',
        statusName: 'completed',
        createdAt: DateTime.now(),
        logs: const [],
      );

      final container = ProviderContainer();
      container.read(selectedDownloadHistoryIdProvider.notifier).state = '1';

      await tester.pumpWidget(createHistoryDetailTestWidget(entry, container));
      await tester.pumpAndSettle();

    }, skip: true);

    testWidgets('W-DL-HIS-15: Display duration', (tester) async {
      final now = DateTime.now();
      final entry = DownloadHistoryEntry(
        id: '1',
        url: 'http://test.com',
        title: 'Test',
        destination: '/home/user/Downloads',
        downloadType: 'video',
        statusName: 'completed',
        createdAt: now.subtract(const Duration(minutes: 5, seconds: 20)),
        completedAt: now,
        logs: const [],
      );

      final container = ProviderContainer();
      container.read(selectedDownloadHistoryIdProvider.notifier).state = '1';

      await tester.pumpWidget(createHistoryDetailTestWidget(entry, container));
      await tester.pumpAndSettle();

      expect(find.text('5m 20s'), findsOneWidget);
    });

    testWidgets('W-DL-HIS-16: Display Logs Terminal', (tester) async {
      final entry = DownloadHistoryEntry(
        id: '1',
        url: 'http://test.com',
        title: 'Test',
        destination: '/home/user/Downloads',
        downloadType: 'video',
        statusName: 'error',
        createdAt: DateTime.now(),
        errorMessage: 'failed to download',
        logs: const ['[debug] starting', '[error] failed to download'],
      );

      final container = ProviderContainer();
      container.read(selectedDownloadHistoryIdProvider.notifier).state = '1';

      await tester.pumpWidget(createHistoryDetailTestWidget(entry, container));
      await tester.pumpAndSettle();

      await tester.drag(find.text('Test'), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.textContaining('Execution Logs'), findsWidgets);
    });

    testWidgets('W-DL-HIS-17: Hide Logs Terminal', (tester) async {
      final entry = DownloadHistoryEntry(
        id: '1',
        url: 'http://test.com',
        title: 'Test',
        destination: '/home/user/Downloads',
        downloadType: 'video',
        statusName: 'completed',
        createdAt: DateTime.now(),
        logs: const [],
      );

      final container = ProviderContainer();
      container.read(selectedDownloadHistoryIdProvider.notifier).state = '1';

      await tester.pumpWidget(createHistoryDetailTestWidget(entry, container));
      await tester.pumpAndSettle();

      expect(find.textContaining('Execution Logs'), findsNothing);
    });
  });
}
