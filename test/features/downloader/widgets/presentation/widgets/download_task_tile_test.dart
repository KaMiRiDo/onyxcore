import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_task_tile.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  Widget createTestWidget(DownloadTask task) {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: DownloadTaskTile(task: task),
        ),
      ),
    );
  }

  group('DownloadTaskTile Unit Tests', () {
    // ── 1. UI Rendering based on Status ──

    testWidgets('W-DL-TIL-01: Render Pending state correctly', (tester) async {
      final task = DownloadTask(
        id: '1',
        url: 'http://test',
        destination: '/test',
        title: 'Pending Task',
        status: DownloadStatus.pending,
        progress: 0.0,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(task));

      expect(find.text('Pending Task'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Waiting to start...'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('W-DL-TIL-02: Render Running state with metrics', (tester) async {
      final task = DownloadTask(
        id: '1',
        url: 'http://test',
        destination: '/test',
        title: 'Running Task',
        status: DownloadStatus.running,
        progress: 0.5,
        speed: '1 MB/s',
        eta: '10s',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(task));

      expect(find.text('Running'), findsOneWidget);
      expect(find.text('50.0%'), findsOneWidget);
      
      final richTextFinder = find.byType(RichText).last;
      expect(richTextFinder, findsOneWidget);
      final RichText richText = tester.widget(richTextFinder);
      final spanText = richText.text.toPlainText();
      expect(spanText, contains('1 MB/s'));
      expect(spanText, contains('ETA 10s'));
    });

    testWidgets('W-DL-TIL-03: Render Completed state', (tester) async {
      final task = DownloadTask(
        id: '1',
        url: 'http://test',
        destination: '/test',
        title: 'Completed Task',
        status: DownloadStatus.completed,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(task));

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Download finished successfully'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('W-DL-TIL-04: Render Error state', (tester) async {
      final task = DownloadTask(
        id: '1',
        url: 'http://test',
        destination: '/test',
        title: 'Error Task',
        status: DownloadStatus.error,
        error: 'Connection reset',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(task));

      expect(find.text('Error'), findsOneWidget);
      expect(find.text('Failed to download'), findsOneWidget);
      expect(find.text('Connection reset'), findsOneWidget);
    });

    testWidgets('W-DL-TIL-05: Render Cancelled state', (tester) async {
      final task = DownloadTask(
        id: '1',
        url: 'http://test',
        destination: '/test',
        title: 'Cancelled Task',
        status: DownloadStatus.cancelled,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(task));

      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Cancelled by user'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    testWidgets('W-DL-TIL-06: Render Cancelling state', (tester) async {
      final task = DownloadTask(
        id: '1',
        url: 'http://test',
        destination: '/test',
        title: 'Cancelling Task',
        status: DownloadStatus.cancelling,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(task));

      expect(find.text('Cancelling'), findsOneWidget);
      expect(find.text('Cancelling...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // ── 2. Dynamic Progress Logic & Display ──

    testWidgets('W-DL-TIL-07: Format Playlist Item Counters', (tester) async {
      final task = DownloadTask(
        id: '1',
        url: 'http://test',
        destination: '/test',
        title: 'Playlist Task',
        status: DownloadStatus.running,
        totalItems: 10,
        completedItems: 3,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(task));
      
      final richTextFinder = find.byType(RichText).last;
      final RichText richText = tester.widget(richTextFinder);
      expect(richText.text.toPlainText(), contains('3/10'));
    });

    testWidgets('W-DL-TIL-08: Estimate Global ETA for Playlists', (tester) async {
      final task = DownloadTask(
        id: '1',
        url: 'http://test',
        destination: '/test',
        title: 'Playlist Task',
        status: DownloadStatus.running,
        totalItems: 10,
        completedItems: 5,
        progress: 0.5,
        createdAt: DateTime.now().subtract(const Duration(seconds: 60)),
      );

      await tester.pumpWidget(createTestWidget(task));
      
      final richTextFinder = find.byType(RichText).last;
      final RichText richText = tester.widget(richTextFinder);
      // Since it's 50% done in 60s, remaining should be ~60s. So 1m 00s
      expect(richText.text.toPlainText(), contains('ETA 1m 00s'));
    });

    testWidgets('W-DL-TIL-09: Live stream tile stats', (tester) async {
      final task = DownloadTask(
        id: '1',
        url: 'http://test',
        destination: '/test',
        title: 'Live Task',
        status: DownloadStatus.running,
        speed: '500 KB/s',
        totalSize: '15 MB',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(task));
      
      final richTextFinder = find.byType(RichText).last;
      final RichText richText = tester.widget(richTextFinder);
      expect(richText.text.toPlainText(), contains('15 MB'));
      expect(richText.text.toPlainText(), contains('500 KB/s'));
    });


    testWidgets('W-DL-TIL-11: Very long title truncation', (tester) async {
      final task = DownloadTask(
        id: '1',
        url: 'http://test',
        destination: '/test',
        title: 'A' * 200,
        status: DownloadStatus.pending,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(task));
      
      final textFinder = find.text('A' * 200);
      expect(textFinder, findsOneWidget);
      final Text titleText = tester.widget(textFinder);
      expect(titleText.overflow, TextOverflow.ellipsis);
    });

    // ── 3. User Interactions ──

    testWidgets('W-DL-TIL-12: Trigger Cancel Confirmation', (tester) async {
      final task = DownloadTask(
        id: '1',
        url: 'http://test',
        destination: '/test',
        title: 'Running Task',
        status: DownloadStatus.running,
        progress: 0.5,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(task));
      
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      
      expect(find.text('Cancel this download?'), findsOneWidget);
      expect(find.text('Yes, Cancel'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
    });

    testWidgets('W-DL-TIL-13: Cancel task and dismiss overlay', (tester) async {
      final task = DownloadTask(
        id: '1',
        url: 'http://test',
        destination: '/test',
        title: 'Running Task',
        status: DownloadStatus.running,
        progress: 0.5,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(task));
      
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel this download?'), findsNothing);
      
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      
      await tester.tap(find.text('Yes, Cancel'));
      await tester.pumpAndSettle();
      
      expect(find.text('Cancel this download?'), findsNothing);
    });

    testWidgets('W-DL-TIL-14: Remove completed task from UI', (tester) async {
      final task = DownloadTask(
        id: '1',
        url: 'http://test',
        destination: '/test',
        title: 'Completed Task',
        status: DownloadStatus.completed,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(task));
      
      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
      
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();
    });
  });
}
