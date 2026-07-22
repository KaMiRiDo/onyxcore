// ignore_for_file: avoid_dynamic_calls
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
import 'package:onyxcore/features/image_viewer/presentation/providers/image_playlist_providers.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;
  late AppDatabase db;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('image_viewer_standalone_test_');
    db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
  });

  tearDownAll(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('ImagePreviewWidget populates imageCurrentPathProvider in standalone mode', (WidgetTester tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('onyxcore/window_manager'),
      (MethodCall methodCall) async {
        return null;
      },
    );

    final imagePath = '${tempDir.path}/test_image.png';
    File(imagePath).writeAsBytesSync([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]); // Dummy PNG header
    
    final fileItem = FileItem(
      path: imagePath,
      name: 'test_image.png',
      type: FileItemType.image,
      modified: DateTime.now(),
    );

    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ImagePreviewWidget(
              item: fileItem,
              isStandalone: true,
              windowId: '400',
            ),
          ),
        ),
      ),
    );

    // Wait for the post frame callback in initState to execute
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));

    final currentPath = container.read(imageCurrentPathProvider);
    final rootPath = container.read(imageRootPathProvider);

    expect(currentPath, p.dirname(imagePath), reason: 'currentPathProvider should be set in standalone mode');
    expect(rootPath, p.dirname(imagePath), reason: 'rootPathProvider should be set in standalone mode');

    // Cleanup
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
    while (tester.takeException() != null) {}
  });
}
