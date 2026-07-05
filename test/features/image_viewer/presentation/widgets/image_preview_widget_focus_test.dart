import 'dart:io';

import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_preview_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late AppDatabase db;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('image_viewer_focus_test_');
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDownAll(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('ImagePreviewWidget requests focus and triggers presentWindow when standalone', (WidgetTester tester) async {
    final windowLogs = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('onyxcore/window_manager'),
      (MethodCall methodCall) async {
        windowLogs.add(methodCall);
        return null;
      },
    );

    final fileItem = FileItem(
      path: '${tempDir.path}/test_image.png',
      name: 'test_image.png',
      type: FileItemType.image,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: ImagePreviewWidget(
            item: fileItem,
            isStandalone: true,
            windowId: '400',
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
                         .having((call) => call.arguments['view_id'], 'view_id', 400),
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
