import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_navigation_controller.dart';
import 'package:onyxcore/features/image_viewer/presentation/providers/image_playlist_providers.dart';
import 'package:path/path.dart' as p;

void main() {
  late ImageNavigationController controller;
  late List<FileItem> playlist;
  late FileItem? navigatedItem;
  late bool clearCalled;
  late WidgetRef actualRef;

  final item1 = FileItem(
    path: '/test1.jpg',
    sizeBytes: 100,
    modified: DateTime(0),
    name: 'test1.jpg',
    type: FileItemType.image,
  );
  final item2 = FileItem(
    path: '/test2.jpg',
    sizeBytes: 100,
    modified: DateTime(0),
    name: 'test2.jpg',
    type: FileItemType.image,
  );
  final item3 = FileItem(
    path: '/test3.jpg',
    sizeBytes: 100,
    modified: DateTime(0),
    name: 'test3.jpg',
    type: FileItemType.image,
  );

  setUp(() {
    playlist = [item1, item2, item3];
    navigatedItem = null;
    clearCalled = false;
  });

  Future<void> pumpController(
    WidgetTester tester, {
    List<FileItem>? customPlaylist,
    bool isStandalone = false,
    Map<String, dynamic>? initParams,
    String? windowId,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filteredAndSortedImageQueueProvider.overrideWith(
            (ref) => customPlaylist ?? playlist,
          ),
          sortedDirectoryItemsProvider.overrideWith((ref) => <FileItem>[]),
        ],
        child: Consumer(
          builder: (context, ref, child) {
            actualRef = ref;
            return Container();
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    controller = ImageNavigationController(
      isStandalone: isStandalone,
      initParams: initParams,
      windowId: windowId,
      ref: actualRef,
      onNavigate: (item) => navigatedItem = item,
      onClearNavigation: () => clearCalled = true,
    );
  }

  testWidgets('navigateForward moves to next item', (tester) async {
    await pumpController(tester);
    controller.navigateForward(item1);
    expect(navigatedItem, item2);
    expect(controller.isEmpty, false);
    controller.dispose();
  });

  testWidgets('navigateForward stops at end and sets empty state', (
    tester,
  ) async {
    await pumpController(tester);
    controller.navigateForward(item3);
    expect(navigatedItem, null);
    expect(controller.isEmpty, true);
    expect(controller.isEmptyAtEnd, true);
    controller.dispose();
  });

  testWidgets('navigateBackward moves to previous item', (tester) async {
    await pumpController(tester);
    controller.navigateBackward(item2);
    expect(navigatedItem, item1);
    expect(controller.isEmpty, false);
    controller.dispose();
  });

  testWidgets('navigateBackward stops at start and sets empty state', (
    tester,
  ) async {
    await pumpController(tester);
    controller.navigateBackward(item1);
    expect(navigatedItem, null);
    expect(controller.isEmpty, true);
    expect(controller.isEmptyAtEnd, false);
    controller.dispose();
  });

  testWidgets('navigateForward recovers from empty state at start', (
    tester,
  ) async {
    await pumpController(tester);
    // Set to empty at start
    controller.navigateBackward(item1);
    expect(controller.isEmpty, true);

    await tester.pump(const Duration(milliseconds: 350));

    // Navigating forward should recover to item1
    controller.navigateForward(item1);
    expect(navigatedItem, item1);
    expect(controller.isEmpty, false);
    controller.dispose();
  });

  testWidgets('navigateAfterDeletion navigates to next item (wrap around)', (
    tester,
  ) async {
    await pumpController(tester);
    controller.navigateAfterDeletion(item3);
    expect(navigatedItem, item1);
    controller.dispose();
  });

  testWidgets('navigateAfterDeletion clears navigation if only 1 item', (
    tester,
  ) async {
    await pumpController(tester, customPlaylist: [item1]);
    controller.navigateAfterDeletion(item1);
    expect(navigatedItem, null);
    expect(clearCalled, true);
    controller.dispose();
  });

  testWidgets(
    'navigateAfterDeletion clears navigation if item not found and multiple items',
    (tester) async {
      await pumpController(tester);
      controller.navigateAfterDeletion(
        FileItem(
          path: '/missing.jpg',
          sizeBytes: 100,
          modified: DateTime(0),
          name: 'missing.jpg',
          type: FileItemType.image,
        ),
      );
      expect(navigatedItem, null);
      expect(clearCalled, true);
      controller.dispose();
    },
  );

  testWidgets('navigation is debounced', (tester) async {
    await pumpController(tester);
    controller.navigateForward(item1);
    expect(navigatedItem, item2);

    // Immediate second call should be ignored due to debounce timer
    controller.navigateForward(item2);
    expect(navigatedItem, item2); // Still item2, not item3

    controller.dispose();
  });

  testWidgets('initStandalonePlaylist with playlistPaths', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('onyxcore_test_init1');
    final file1 = File(p.join(tempDir.path, 'img1.jpg'))..writeAsBytesSync([]);
    final file2 = File(p.join(tempDir.path, 'img2.jpg'))..writeAsBytesSync([]);
    
    await pumpController(tester, customPlaylist: [], initParams: {
      'playlistPaths': [file1.path, file2.path]
    });

    await tester.runAsync(() async {
      await controller.initStandalonePlaylist(FileItem(path: file1.path, sizeBytes: 0, modified: DateTime.now(), name: 'img1.jpg', type: FileItemType.image));
    });
    
    expect(controller.standalonePlaylist.length, 2);
    expect(controller.standalonePlaylist[0].path, file1.path);

    file1.deleteSync();
    file2.deleteSync();
    tempDir.deleteSync();
    controller.dispose();
  });

  testWidgets('initStandalonePlaylist with directory listing', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('onyxcore_test_init2');
    final file1 = File(p.join(tempDir.path, 'img1.jpg'))..writeAsBytesSync([]);
    final file2 = File(p.join(tempDir.path, 'img2.jpg'))..writeAsBytesSync([]);
    
    await pumpController(tester, customPlaylist: []);

    await tester.runAsync(() async {
      await controller.initStandalonePlaylist(FileItem(path: file1.path, sizeBytes: 0, modified: DateTime.now(), name: 'img1.jpg', type: FileItemType.image));
    });
    
    expect(controller.standalonePlaylist.length, 2);

    file1.deleteSync();
    file2.deleteSync();
    tempDir.deleteSync();
    controller.dispose();
  });

  testWidgets('precacheAdjacentImages computes adjacent from playlist', (tester) async {
    final tempDir = Directory.systemTemp.createTempSync('onyxcore_test_precache1');
    final validPng = [
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1,
      8, 6, 0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 96, 0, 0,
      0, 2, 0, 1, 226, 38, 5, 163, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130
    ];
    final f1 = File(p.join(tempDir.path, 'f1.jpg'))..writeAsBytesSync(validPng);
    final f2 = File(p.join(tempDir.path, 'f2.jpg'))..writeAsBytesSync(validPng);
    
    final i1 = FileItem(path: f1.path, sizeBytes: 100, modified: DateTime(0), name: 'f1.jpg', type: FileItemType.image);
    final i2 = FileItem(path: f2.path, sizeBytes: 100, modified: DateTime(0), name: 'f2.jpg', type: FileItemType.image);

    await pumpController(tester, customPlaylist: [i1, i2]); 
    final buildContext = tester.element(find.byType(Container));
    
    await tester.runAsync(() async {
      controller.precacheAdjacentImages(buildContext, i1); 
      await Future<void>.delayed(const Duration(milliseconds: 1100));
    });
    
    f1.deleteSync();
    f2.deleteSync();
    tempDir.deleteSync();
    controller.dispose();
  });

  testWidgets('updateIndexData updates provider state', (tester) async {
    await pumpController(tester);
    await tester.runAsync(() async {
      await controller.updateIndexData(item1);
    });
    expect(controller.indexString, isNotEmpty);
    
    // With initParams
    await pumpController(tester, windowId: '1', initParams: {
      'currentIndex': 5,
      'totalCount': 10,
    });
    
    await tester.runAsync(() async {
      await controller.updateIndexData(item1);
    });
    expect(controller.indexString, '5/10');
    
    controller.dispose();
  });

  testWidgets('navigatePlaylistHistory updates ref state', (tester) async {
    await pumpController(tester);
    actualRef.read(imagePathHistoryProvider.notifier).state = ['/folder1', '/folder2'];
    actualRef.read(imagePathForwardHistoryProvider.notifier).state = [];
    actualRef.read(imageCurrentPathProvider.notifier).state = '/current';
    
    await tester.runAsync(() async {
      controller.navigatePlaylistHistoryBack();
      await Future<void>.delayed(const Duration(milliseconds: 100)); // allow async operation to finish
    });
    
    expect(actualRef.read(imagePathHistoryProvider), ['/folder1']);
    expect(actualRef.read(imagePathForwardHistoryProvider), ['/current']);
    expect(actualRef.read(imageCurrentPathProvider), '/folder2');
    
    await tester.runAsync(() async {
      controller.navigatePlaylistHistoryForward();
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    
    expect(actualRef.read(imagePathHistoryProvider), ['/folder1', '/folder2']);
    expect(actualRef.read(imagePathForwardHistoryProvider), <String>[]);
    expect(actualRef.read(imageCurrentPathProvider), '/current');
    
    controller.dispose();
  });

  testWidgets('initStandalonePlaylist loads network playlist from playlistJson', (
    tester,
  ) async {
    final netItem1 = FileItem(
      path: 'https://example.com/img1.jpg',
      sizeBytes: 1024,
      modified: DateTime(2025),
      name: 'img1.jpg',
      type: FileItemType.image,
    );
    final netItem2 = FileItem(
      path: 'https://example.com/img2.jpg',
      sizeBytes: 2048,
      modified: DateTime(2025, 1, 2),
      name: 'img2.jpg',
      type: FileItemType.image,
    );

    final playlistJson = jsonEncode([netItem1.toJson(), netItem2.toJson()]);

    await pumpController(
      tester,
      isStandalone: true,
      initParams: {
        'playlistJson': playlistJson,
        'playlistPath': netItem1.path,
      },
    );

    await tester.runAsync(() async {
      await controller.initStandalonePlaylist(netItem1);
    });

    expect(controller.standalonePlaylist.length, equals(2));
    expect(controller.standalonePlaylist[0].path, equals(netItem1.path));
    expect(controller.standalonePlaylist[1].path, equals(netItem2.path));
    expect(actualRef.read(imageQueueProvider).length, equals(2));

    controller.navigateForward(netItem1);
    expect(navigatedItem?.path, equals(netItem2.path));

    controller.dispose();
  });
}
