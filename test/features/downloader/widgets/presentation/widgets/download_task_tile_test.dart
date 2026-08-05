import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/drift.dart' hide Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_task_tile.dart';

void main() {
  late AppDatabase appDb;

  setUp(() {
    appDb = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDown(() async {
    // await appDb.close();
  });

  GoogleFonts.config.allowRuntimeFetching = false;

  Widget createTestWidget(DownloadTask task) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(appDb),
      ],
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
      final richText = tester.widget<RichText>(richTextFinder);
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
      final richText = tester.widget<RichText>(richTextFinder);
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
      final richText = tester.widget<RichText>(richTextFinder);
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
      final richText = tester.widget<RichText>(richTextFinder);
      expect(richText.text.toPlainText(), contains('15 MB'));
      expect(richText.text.toPlainText(), contains('500 KB/s'));
    });


    testWidgets('W-DL-TIL-11: Very long title truncation', (tester) async {
      final task = DownloadTask(
        id: '1',
        url: 'http://test',
        destination: '/test',
        title: 'A' * 200,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(task));
      
      final textFinder = find.text('A' * 200);
      expect(textFinder, findsOneWidget);
      final titleText = tester.widget<Text>(textFinder);
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

    testWidgets('W-DL-TIL-15: Render size ratio and calculated ETA accurately', (tester) async {
      final task = DownloadTask(
        id: '1',
        url: 'http://test',
        destination: '/test',
        title: 'Grouped Download',
        status: DownloadStatus.running,
        totalItems: 3,
        completedItems: 1,
        expectedBytes: 10 * 1024 * 1024, // 10 MB
        downloadedBytes: 3 * 1024 * 1024, // 3 MB
        progress: 0.3,
        speed: '1.5 MB/s',
        eta: '5s',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(createTestWidget(task));

      final richTextFinder = find.byType(RichText).last;
      final richText = tester.widget<RichText>(richTextFinder);
      final text = richText.text.toPlainText();

      expect(text, contains('1/3'));
      expect(text, contains('3.0 MB / 10.0 MB'));
      expect(text, contains('1.5 MB/s'));
      expect(text, contains('ETA 5s'));
    });

    testWidgets('W-DL-TIL-16: Compute ETA from size ratio when task.eta is empty', (tester) async {
      final task = DownloadTask(
        id: '1',
        url: 'http://test',
        destination: '/test',
        title: 'Single Video',
        status: DownloadStatus.running,
        expectedBytes: 100 * 1024 * 1024, // 100 MB
        downloadedBytes: 50 * 1024 * 1024, // 50 MB
        progress: 0.5,
        speed: '10 MB/s',
        createdAt: DateTime.now().subtract(const Duration(seconds: 5)),
      );

      await tester.pumpWidget(createTestWidget(task));

      final richTextFinder = find.byType(RichText).last;
      final richText = tester.widget<RichText>(richTextFinder);
      final text = richText.text.toPlainText();

      expect(text, contains('50.0 MB / 100.0 MB'));
      expect(text, contains('10 MB/s'));
      expect(text, contains('ETA 5s'));
    });
  });
}
