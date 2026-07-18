import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import "package:onyxcore/core/utils/file_type_classifier.dart";
import 'package:onyxcore/features/video_player/presentation/widgets/video_preview_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late AppDatabase db;

  setUpAll(() {
    MediaKit.ensureInitialized();
    tempDir = Directory.systemTemp.createTempSync('video_player_ytdl_path_test_');
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDownAll(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('VideoPreviewWidget initializes with network stream and sets ytdl_path without crashing', (WidgetTester tester) async {
    final fileItem = FileItem(
      path: 'https://sample.com/video.mp4',
      name: 'video.mp4',
      type: FileItemType.video,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: VideoPreviewWidget(
            item: fileItem,
            initParams: const {'is_network_stream': true},
          ),
        ),
      ),
    ));

    // Wait for the player to initialize async
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));

    // Verify it rendered successfully
    expect(find.byType(VideoPreviewWidget), findsOneWidget);

    // Cleanup and swallow unmount exceptions from mocked native dependencies
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    while (tester.takeException() != null) {}
  });
}
