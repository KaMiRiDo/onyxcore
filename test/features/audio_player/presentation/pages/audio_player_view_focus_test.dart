import 'dart:io';

import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/audio_player/presentation/pages/audio_player_view.dart';
import 'package:onyxcore/features/audio_player/presentation/providers/audio_player_providers.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late AppDatabase db;

  /// Returns a mock [MethodCall] handler that silently accepts any native call.
  Future<dynamic> _nullHandler(MethodCall call) async => null;

  void _stubNativeChannels() {
    for (final channel in const [
      'com.alexmercerind/media_kit_video',
      'com.alexmercerind/media_kit',
      'onyxcore/window_manager',
      'plugins.flutter.io/window_manager',
    ]) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(MethodChannel(channel), _nullHandler);
    }
  }

  setUpAll(() {
    MediaKit.ensureInitialized();
    tempDir = Directory.systemTemp.createTempSync('audio_player_focus_test_');
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
    _stubNativeChannels();
  });

  tearDownAll(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('AudioPlayerView requests focus and triggers presentWindow when standalone', (WidgetTester tester) async {
    final windowLogs = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('onyxcore/window_manager'),
      (MethodCall methodCall) async {
        windowLogs.add(methodCall);
        return null;
      },
    );

    final filePath = '${tempDir.path}/test_audio.mp3';
    File(filePath).createSync();

    final fileItem = FileItem(
      path: filePath,
      name: 'test_audio.mp3',
      type: FileItemType.audio,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: AudioPlayerView(
            item: fileItem,
            isStandalone: true,
            windowId: '200',
          ),
        ),
      ),
    ));

    // Wait for the widget to build and the async Future<void>.delayed(300ms) to fire
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));

    expect(
      windowLogs,
      contains(
        isA<MethodCall>().having((call) => call.method, 'method', 'present_window')
                         .having((call) => call.arguments['view_id'], 'view_id', 200),
      ),
    );

    // Verify focus is acquired
    expect(FocusManager.instance.primaryFocus, isNotNull);

    // Cleanup and swallow unmount exceptions from mocked native dependencies
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    while (tester.takeException() != null) {}
  });
}
