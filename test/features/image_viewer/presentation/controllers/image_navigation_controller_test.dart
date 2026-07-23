import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_navigation_controller.dart';
import 'package:onyxcore/features/image_viewer/presentation/providers/image_playlist_providers.dart';

void main() {
  late ImageNavigationController controller;
  late List<FileItem> playlist;
  late FileItem? navigatedItem;
  late bool clearCalled;
  late WidgetRef actualRef;

  final item1 = FileItem(path: '/test1.jpg', sizeBytes: 100, modified: DateTime(0), name: 'test1.jpg', type: FileItemType.image);
  final item2 = FileItem(path: '/test2.jpg', sizeBytes: 100, modified: DateTime(0), name: 'test2.jpg', type: FileItemType.image);
  final item3 = FileItem(path: '/test3.jpg', sizeBytes: 100, modified: DateTime(0), name: 'test3.jpg', type: FileItemType.image);

  setUp(() {
    playlist = [item1, item2, item3];
    navigatedItem = null;
    clearCalled = false;
  });

  Future<void> pumpController(WidgetTester tester, {List<FileItem>? customPlaylist}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          filteredAndSortedImageQueueProvider.overrideWith((ref) => customPlaylist ?? playlist),
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
      isStandalone: false,
      initParams: null,
      windowId: null,
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

  testWidgets('navigateForward stops at end and sets empty state', (tester) async {
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

  testWidgets('navigateBackward stops at start and sets empty state', (tester) async {
    await pumpController(tester);
    controller.navigateBackward(item1);
    expect(navigatedItem, null);
    expect(controller.isEmpty, true);
    expect(controller.isEmptyAtEnd, false);
    controller.dispose();
  });

  testWidgets('navigateForward recovers from empty state at start', (tester) async {
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

  testWidgets('navigateAfterDeletion navigates to next item (wrap around)', (tester) async {
    await pumpController(tester);
    controller.navigateAfterDeletion(item3);
    expect(navigatedItem, item1);
    controller.dispose();
  });

  testWidgets('navigateAfterDeletion clears navigation if only 1 item', (tester) async {
    await pumpController(tester, customPlaylist: [item1]);
    controller.navigateAfterDeletion(item1);
    expect(navigatedItem, null);
    expect(clearCalled, true);
    controller.dispose();
  });

  testWidgets('navigateAfterDeletion clears navigation if item not found and multiple items', (tester) async {
    await pumpController(tester);
    controller.navigateAfterDeletion(FileItem(path: '/missing.jpg', sizeBytes: 100, modified: DateTime(0), name: 'missing.jpg', type: FileItemType.image));
    expect(navigatedItem, null);
    expect(clearCalled, true);
    controller.dispose();
  });

  testWidgets('navigation is debounced', (tester) async {
    await pumpController(tester);
    controller.navigateForward(item1);
    expect(navigatedItem, item2);

    // Immediate second call should be ignored due to debounce timer
    controller.navigateForward(item2);
    expect(navigatedItem, item2); // Still item2, not item3
    
    controller.dispose();
  });
}
