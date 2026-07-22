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

  testWidgets('Error state resets when navigating to a new valid video', (WidgetTester tester) async {
    final invalidFile = FileItem(path: '/test/invalid_video.mp4', name: 'invalid.mp4', type: FileItemType.video, modified: DateTime.now());
    final validFile = FileItem(path: '/test/valid_video.mp4', name: 'valid.mp4', type: FileItemType.video, modified: DateTime.now());
    
    final playlist = [invalidFile, validFile];
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
              item: invalidFile,
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


    final widgetState = tester.state(find.byType(VideoPreviewWidget)) as dynamic;
    
    // Force error state
    // ignore: avoid_dynamic_calls
    widgetState.setErrorForTest('Failed to play video');
    await tester.pump();
    
    // Verify error is shown
    expect(find.textContaining('Failed to play'), findsWidgets, reason: 'Error overlay should be visible');
    
    // Now navigate to the next (valid) video
    final nextButton = find.byIcon(Icons.skip_next);
    expect(nextButton, findsOneWidget);
    
    await tester.tap(nextButton);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    // The error should be gone because the state was reset
    expect(find.textContaining('Failed to play'), findsNothing, reason: 'Error should be cleared on new media load');

    // Cleanup
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Non-fatal error decoding audio does not block playback', (WidgetTester tester) async {
    final validFile = FileItem(path: '/test/valid_video.mp4', name: 'valid.mp4', type: FileItemType.video, modified: DateTime.now());
    final playlist = [validFile];
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
              item: validFile,
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

    final widgetState = tester.state(find.byType(VideoPreviewWidget)) as dynamic;
    
    // Force non-fatal error state
    // ignore: avoid_dynamic_calls
    widgetState.setErrorForTest('Error decoding audio.');
    await tester.pump();
    
    // Verify error is NOT shown because it's non-fatal
    expect(find.textContaining('Error decoding audio.'), findsNothing, reason: 'Non-fatal error overlay should NOT be visible');
    
    // Cleanup
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
