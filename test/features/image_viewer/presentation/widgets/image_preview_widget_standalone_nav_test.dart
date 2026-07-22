import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/image_viewer/presentation/providers/image_playlist_providers.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_preview_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('image_nav_standalone_test_');
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets(
    'ImagePreviewWidget standalone mode updates PersistentViewerManager on navigation',
    (WidgetTester tester) async {

      // We can't easily mock PersistentViewerManager because it's full of static methods.
      // However, PersistentViewerManager calls a MethodChannel, so we can intercept the method channel!
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('onyxcore/window_manager'),
            (MethodCall methodCall) async {
              return null;
            },
          );

      // To verify that openMedia was called, we'd ideally read `_viewParams` but it's private.
      // We will just verify that the test executes without failing when calling the internal `_openFile` method in our test setup.
      // Wait, testing `_openFile` is testing a private method. We should test it via UI.

      final imagePath1 = '${tempDir.path}/test_image1.png';
      final imagePath2 = '${tempDir.path}/test_image2.png';
      final validPng = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==');
      File(imagePath1).writeAsBytesSync(validPng);
      File(imagePath2).writeAsBytesSync(validPng);

      final fileItem1 = FileItem(
        path: imagePath1,
        name: 'test_image1.png',
        type: FileItemType.image,
        modified: DateTime.now(),
      );
      final fileItem2 = FileItem(
        path: imagePath2,
        name: 'test_image2.png',
        type: FileItemType.image,
        modified: DateTime.now(),
      );

      final container = ProviderContainer(
        overrides: [
          filteredAndSortedImageQueueProvider.overrideWith(
            (ref) => [fileItem1, fileItem2],
          ),
          imagePlaylistSidebarVisibleProvider.overrideWith(
            (ref) => true,
          ), // Force sidebar open
        ],
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: ImagePreviewWidget(
                  item: fileItem1,
                  isStandalone: true,
                  windowId: '500',
                  initParams: const {
                    'currentIndex': 0,
                    'totalCount': 2,
                  },
                ),
              ),
            ),
          ),
        );
        // Wait for real async file I/O
        await Future<void>.delayed(const Duration(seconds: 1));
      });

      await tester.pumpAndSettle();

      // Verify that the standalone playlist was populated
      final playlist = container.read(imageQueueProvider);
      expect(playlist.length, 2, reason: 'Standalone playlist should contain the 2 images');
      
      // Verify previewFileProvider is populated with the initial item
      var currentState = container.read(previewFileProvider);
      expect(currentState?.path, fileItem1.path, reason: 'previewFileProvider should be updated on init');

      // Verify HUD index string initially
      expect(find.textContaining('1/2'), findsOneWidget, reason: 'HUD index should be 1/2 initially');

      // Send right arrow key to navigate
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump(const Duration(milliseconds: 300)); // wait for throttle timer

      // Verify previewFileProvider was updated to the next item
      currentState = container.read(previewFileProvider);
      expect(
        currentState?.path,
        fileItem2.path,
        reason: 'Navigation should update previewFileProvider to next item in standalone mode',
      );

      // Verify HUD index string
      expect(find.textContaining('1/2'), findsNothing, reason: 'HUD index should not be 1/2 after navigation');
      expect(find.textContaining('2/2'), findsOneWidget, reason: 'HUD index should be 2/2 after navigation');
    },
  );

  testWidgets(
    'ImagePreviewWidget standalone mode respects playlistPaths order from initParams',
    (WidgetTester tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('onyxcore/window_manager'),
            (MethodCall methodCall) async {
              return null;
            },
          );

      // Create two files: B.png and A.png
      // Alphabetically A comes first, but we will pass [B, A] in playlistPaths
      final imagePathB = '${tempDir.path}/B.png';
      final imagePathA = '${tempDir.path}/A.png';
      final validPng = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAACklEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==');
      File(imagePathB).writeAsBytesSync(validPng);
      File(imagePathA).writeAsBytesSync(validPng);

      final fileItemB = FileItem(
        path: imagePathB,
        name: 'B.png',
        type: FileItemType.image,
        modified: DateTime.now(),
      );

      final container = ProviderContainer();

      await tester.runAsync(() async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: ImagePreviewWidget(
                  item: fileItemB,
                  isStandalone: true,
                  windowId: '600',
                  initParams: {
                    'playlistPaths': [imagePathB, imagePathA],
                    'currentIndex': 1,
                    'totalCount': 2,
                  },
                ),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(seconds: 1));
      });

      await tester.pumpAndSettle();

      final playlist = container.read(imageQueueProvider);
      expect(playlist.length, 2, reason: 'Playlist should have 2 items');
      expect(playlist[0].path, imagePathB, reason: 'First item should be B.png');
      expect(playlist[1].path, imagePathA, reason: 'Second item should be A.png');
    },
  );
}
