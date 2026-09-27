// Tests for Bug 2: Image viewer delete fixes
// 1. navigateAfterDeletion should go to next item when NOT at last, or quit when AT last item.
// 2. _sessionSkipConfirm pattern for "don't ask again" in image viewer.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/platform/directory_watcher.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/repositories/directory_repository.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_navigation_controller.dart';
import 'package:onyxcore/features/image_viewer/presentation/providers/image_playlist_providers.dart';

class FakeDirectoryRepository implements DirectoryRepository {
  FakeDirectoryRepository(this.initialItems);
  final List<FileItem> initialItems;

  @override
  Stream<FileChangeEvent> watchDirectory(String path) => const Stream.empty();

  @override
  Future<List<FileItem>> listDirectory(String path) async => initialItems;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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
          directoryRepositoryProvider.overrideWithValue(
            FakeDirectoryRepository([]),
          ),
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

  group('Bug Fix: navigateAfterDeletion last-image behavior', () {
    testWidgets(
        'navigateAfterDeletion: when NOT at last image, navigates to next item',
        (tester) async {
      await pumpController(tester);
      // item2 is at index 1, next should be item3
      controller.navigateAfterDeletion(item2);
      expect(navigatedItem, item3);
      expect(clearCalled, isFalse);
      controller.dispose();
    });

    testWidgets(
        'navigateAfterDeletion: when deleting LAST image, calls onClearNavigation (quit)',
        (tester) async {
      await pumpController(tester);
      // item3 is the last item - should quit (clearNavigation) not wrap
      controller.navigateAfterDeletion(item3);
      expect(clearCalled, isTrue);
      expect(navigatedItem, isNull);
      controller.dispose();
    });

    testWidgets(
        'navigateAfterDeletion: when deleting FIRST image of 2, navigates to second',
        (tester) async {
      await pumpController(tester, customPlaylist: [item1, item2]);
      controller.navigateAfterDeletion(item1);
      expect(navigatedItem, item2);
      expect(clearCalled, isFalse);
      controller.dispose();
    });

    testWidgets(
        'navigateAfterDeletion: when deleting LAST image of 2, calls onClearNavigation',
        (tester) async {
      await pumpController(tester, customPlaylist: [item1, item2]);
      controller.navigateAfterDeletion(item2);
      expect(clearCalled, isTrue);
      expect(navigatedItem, isNull);
      controller.dispose();
    });

    testWidgets(
        'navigateAfterDeletion: when only 1 item in playlist, calls onClearNavigation',
        (tester) async {
      await pumpController(tester, customPlaylist: [item1]);
      controller.navigateAfterDeletion(item1);
      expect(clearCalled, isTrue);
      expect(navigatedItem, isNull);
      controller.dispose();
    });

    testWidgets(
        'navigateAfterDeletion: deleting middle image navigates forward correctly',
        (tester) async {
      await pumpController(tester);
      // item1 is at index 0, next should be item2
      controller.navigateAfterDeletion(item1);
      expect(navigatedItem, item2);
      expect(clearCalled, isFalse);
      controller.dispose();
    });

    testWidgets(
        'navigateAfterDeletion: item not found in playlist calls onClearNavigation',
        (tester) async {
      await pumpController(tester);
      final missingItem = FileItem(
        path: '/missing.jpg',
        sizeBytes: 100,
        modified: DateTime(0),
        name: 'missing.jpg',
        type: FileItemType.image,
      );
      controller.navigateAfterDeletion(missingItem);
      expect(clearCalled, isTrue);
      expect(navigatedItem, isNull);
      controller.dispose();
    });
  });
}
