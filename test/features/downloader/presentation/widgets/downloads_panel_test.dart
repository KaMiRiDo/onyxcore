import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/download_task_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_history_detail_view.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_history_view.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/download_task_tile.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/downloads_panel.dart';

void main() {
  late AppDatabase appDb;

  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    appDb = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDownAll(() async {
    await appDb.close();
  });

  Widget createWidget({
    DownloadsPanelView initialView = DownloadsPanelView.tasks,
    List<DownloadTask>? activeTasks,
    bool panelOpen = true,
  }) {
    return ProviderScope(
      overrides: [
        downloadsPanelViewProvider.overrideWith((ref) => initialView),
        downloadsPanelOpenProvider.overrideWith((ref) => panelOpen),
        databaseProvider.overrideWithValue(appDb),
        if (activeTasks != null)
          activeDownloadTaskProvider.overrideWithValue(activeTasks),
      ],
      child: const MaterialApp(
        home: Scaffold(body: DownloadsPanel()),
      ),
    );
  }

  group('DownloadsPanel - Simplified Monitoring Panel', () {
    testWidgets('W-DL-PAN-NEW-01: renders DownloadsPanel widget', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidget());
      await tester.pump();

      expect(find.byType(DownloadsPanel), findsOneWidget);
    });

    testWidgets('W-DL-PAN-NEW-02: shows DownloadHistoryView when view=history', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidget(initialView: DownloadsPanelView.history));
      await tester.pump();
      await tester.pump();

      expect(find.byType(DownloadHistoryView, skipOffstage: false), findsOneWidget);
    });

    testWidgets('W-DL-PAN-NEW-03: shows DownloadHistoryDetailView when view=historyDetail', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidget(initialView: DownloadsPanelView.historyDetail));
      await tester.pump();
      await tester.pump();

      expect(find.byType(DownloadHistoryDetailView, skipOffstage: false), findsOneWidget);
    });

    testWidgets('W-DL-PAN-NEW-04: shows task tiles when active downloads are present', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tasks = [
        DownloadTask(
          id: 'task-1',
          url: 'https://example.com/video.mp4',
          destination: '/downloads',
          title: 'My Test Video',
          createdAt: DateTime.now(),
          status: DownloadStatus.running,
          progress: 0.5,
        ),
      ];

      await tester.pumpWidget(createWidget(activeTasks: tasks));
      await tester.pump();
      await tester.pump();

      expect(find.byType(DownloadTaskTile), findsOneWidget);
      expect(find.text('My Test Video'), findsOneWidget);
    });

    testWidgets('W-DL-PAN-NEW-05: shows empty state icon when no active downloads', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidget(activeTasks: []));
      await tester.pump();
      await tester.pump();

      expect(find.byType(DownloadTaskTile), findsNothing);
      expect(find.byIcon(Icons.cloud_done_rounded), findsOneWidget);
    });

    testWidgets('W-DL-PAN-NEW-06: does NOT render URL input TextField', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createWidget(activeTasks: []));
      await tester.pump();
      await tester.pump();

      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('W-DL-PAN-NEW-07: shows Cancel All button when tasks are present', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final tasks = [
        DownloadTask(
          id: 'task-2',
          url: 'https://example.com/img.jpg',
          destination: '/downloads',
          title: 'My Image',
          createdAt: DateTime.now(),
          status: DownloadStatus.running,
          progress: 0.2,
        ),
      ];

      await tester.pumpWidget(createWidget(activeTasks: tasks));
      await tester.pump();
      await tester.pump();

      expect(find.text('Cancel All'), findsOneWidget);
    });
  });
}
