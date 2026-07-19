import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/video_preview_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;

  setUpAll(() {
    MediaKit.ensureInitialized();
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDownAll(() async {
    await db.close();
  });

  testWidgets('Next and Prev buttons work in standalone mode', (WidgetTester tester) async {
    final file1 = FileItem(path: '/test/video1.mp4', name: 'video1.mp4', type: FileItemType.video, modified: DateTime.now());
    final file2 = FileItem(path: '/test/video2.mp4', name: 'video2.mp4', type: FileItemType.video, modified: DateTime.now());
    final file3 = FileItem(path: '/test/video3.mp4', name: 'video3.mp4', type: FileItemType.video, modified: DateTime.now());
    
    final playlist = [file1, file2, file3];
    final playlistJson = jsonEncode(playlist.map((e) => e.toJson()).toList());

    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: VideoPreviewWidget(
              item: file2,
              isStandalone: true,
              windowId: '1',
              initParams: {
                'playlistJson': playlistJson,
              },
            ),
          ),
        ),
      ),
    );

    // Initial load
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    
    final element = tester.element(find.byType(VideoPreviewWidget));
    final container = ProviderScope.containerOf(element);

    expect(container.read(previewFileProvider)?.path, '/test/video2.mp4');
    
    final nextButton = find.byIcon(Icons.skip_next);
    expect(nextButton, findsOneWidget);
    
    await tester.tap(nextButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(container.read(previewFileProvider)?.path, '/test/video3.mp4');

    final prevButton = find.byIcon(Icons.skip_previous);
    expect(prevButton, findsOneWidget);
    
    await tester.tap(prevButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    
    expect(container.read(previewFileProvider)?.path, '/test/video2.mp4');
    
    await tester.tap(prevButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    
    expect(container.read(previewFileProvider)?.path, '/test/video1.mp4');
    
    // Cleanup
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    while (tester.takeException() != null) {}
  });
}
