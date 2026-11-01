import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/selection_state.dart';
import 'package:onyxcore/features/directory_browser/domain/repositories/directory_repository.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/clipboard_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/pinned_items_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/task_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/item_card.dart';

class _MockSelectionNotifier extends SelectionNotifier {
  @override
  SelectionState build() => SelectionState.empty;
}

class _MockCurrentPathNotifier extends CurrentPathNotifier {
  @override
  String build() => '/home/user';
}

class _MockPinnedItemsNotifier extends PinnedItemsNotifier {
  @override
  Future<Map<String, int>> build() async => {};
}

class _FakeClipboardNotifier extends ClipboardNotifier {
  @override
  ClipboardState build() => const ClipboardState();
}

class _MockTaskNotifier extends TaskNotifier {
  @override
  List<FileTask> build() => [];
}

class _MockDirectoryItemsNotifier extends DirectoryItemsNotifier {
  @override
  Future<List<FileItem>> build() async => [];
}

class _MockDirectoryRepository implements DirectoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestCard({required FileItem item}) {
    return ProviderScope(
      overrides: [
        directoryRepositoryProvider.overrideWithValue(
          _MockDirectoryRepository(),
        ),
        selectionProvider.overrideWith(_MockSelectionNotifier.new),
        currentPathProvider.overrideWith(_MockCurrentPathNotifier.new),
        pinnedItemsProvider.overrideWith(_MockPinnedItemsNotifier.new),
        clipboardProvider.overrideWith(_FakeClipboardNotifier.new),
        taskProvider.overrideWith(_MockTaskNotifier.new),
        directoryItemsProvider.overrideWith(_MockDirectoryItemsNotifier.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 150,
            height: 200,
            child: ItemCard(
              item: item,
              zoom: 1,
              isSelected: false,
              isHovered: false,
              onHoverChanged: (_) {},
              onTap: () {},
              onDoubleTap: () {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('Folder ItemCard context menu has Compare Folders action', (
    tester,
  ) async {
    final folderItem = FileItem(
      path: '/home/user/FolderA',
      name: 'FolderA',
      type: FileItemType.folder,
      sizeBytes: 0,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(buildTestCard(item: folderItem));
    await tester.pumpAndSettle();

    // Right-click the folder card
    await tester.tap(find.byType(ItemCard), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();

    expect(find.text('Compare Folders...'), findsOneWidget);
  });

  testWidgets(
    'Non-folder ItemCard context menu does NOT have Compare Folders action',
    (tester) async {
      final docItem = FileItem(
        path: '/home/user/document.txt',
        name: 'document.txt',
        type: FileItemType.document,
        sizeBytes: 1024,
        modified: DateTime.now(),
      );

      await tester.pumpWidget(buildTestCard(item: docItem));
      await tester.pumpAndSettle();

      // Right-click the image card
      await tester.tap(find.byType(ItemCard), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('Compare Folders...'), findsNothing);
    },
  );
}
