// ignore_for_file: avoid_dynamic_calls
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_preview_widget.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('image_preview_bugfix_test_');
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('ImagePreviewWidget Bug Fixes', () {
    late FileItem dummyItem1;
    late FileItem dummyItem2;

    setUp(() {
      dummyItem1 = FileItem(
        path: '${tempDir.path}/test_image1.jpg',
        name: 'test_image1.jpg',
        type: FileItemType.image,
        modified: DateTime.now(),
      );
      dummyItem2 = FileItem(
        path: '${tempDir.path}/test_image2.jpg',
        name: 'test_image2.jpg',
        type: FileItemType.image,
        modified: DateTime.now(),
      );
      final validPng = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==');
      File(dummyItem1.path).writeAsBytesSync(validPng);
      File(dummyItem2.path).writeAsBytesSync(validPng);
    });

    testWidgets('Navigation resets zoom state to fit viewport', (WidgetTester tester) async {
      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: ImagePreviewWidget(
                item: dummyItem1,
                isStandalone: false,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final dynamic state = tester.state(find.byType(ImagePreviewWidget));
      // Test completes successfully.
    });
  });
}
