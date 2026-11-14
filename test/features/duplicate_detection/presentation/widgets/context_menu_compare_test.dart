import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/window_management/persistent_viewer_manager.dart';
import 'package:onyxcore/core/window_management/window_params.dart';
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
  _MockSelectionNotifier([this._state]);
  final SelectionState? _state;

  @override
  SelectionState build() => _state ?? SelectionState.empty;
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
  _MockDirectoryItemsNotifier([this._items = const []]);
  final List<FileItem> _items;

  @override
  Future<List<FileItem>> build() async {
    state = AsyncData(_items);
    return _items;
  }
}

class _MockDirectoryRepository implements DirectoryRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PersistentViewerManager.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('onyxcore/window_manager'),
      (call) async {
        if (call.method == 'create_window') {
          return 42;
        }
        return null;
      },
    );
  });

  tearDown(() {
    PersistentViewerManager.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('onyxcore/window_manager'),
      null,
    );
  });

  Widget buildTestCard({
    required FileItem item,
    SelectionState? selectionState,
    List<FileItem> directoryItems = const [],
    bool isSelected = false,
  }) {
    return ProviderScope(
      overrides: [
        directoryRepositoryProvider.overrideWithValue(
          _MockDirectoryRepository(),
        ),
        selectionProvider.overrideWith(
          () => _MockSelectionNotifier(selectionState),
        ),
        currentPathProvider.overrideWith(_MockCurrentPathNotifier.new),
        pinnedItemsProvider.overrideWith(_MockPinnedItemsNotifier.new),
        clipboardProvider.overrideWith(_FakeClipboardNotifier.new),
        taskProvider.overrideWith(_MockTaskNotifier.new),
        directoryItemsProvider.overrideWith(
          () => _MockDirectoryItemsNotifier(directoryItems),
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 150,
            height: 200,
            child: ItemCard(
              item: item,
              zoom: 1,
              isSelected: isSelected,
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

  testWidgets(
    'Folder ItemCard context menu has Compare with action when single folder is selected',
    (tester) async {
      final folderItem = FileItem(
        path: '/home/user/FolderA',
        name: 'FolderA',
        type: FileItemType.folder,
        sizeBytes: 0,
        modified: DateTime.now(),
      );

      await tester.pumpWidget(
        buildTestCard(
          item: folderItem,
          selectionState: SelectionState(
            selectedPaths: {'/home/user/FolderA'},
            isSelectionMode: true,
          ),
          isSelected: true,
          directoryItems: [folderItem],
        ),
      );
      await tester.pumpAndSettle();

      // Right-click the folder card
      await tester.tap(find.byType(ItemCard), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('Compare with'), findsOneWidget);
      expect(find.text('Compare Folders'), findsNothing);
      expect(find.text('Compare Folders...'), findsNothing);

      await tester.tap(find.text('Compare with'));
      await tester.pumpAndSettle();

      final params = PersistentViewerManager.getParamsForView(42);
      expect(params, isNotNull);
      expect(params!.viewerType, ViewerType.duplicateCompare);
      expect(params.initParams['sourceFolder'], '/home/user/FolderA');
      expect(params.initParams['destinationFolder'], isNull);
    },
  );

  testWidgets(
    'Folder ItemCard context menu has Compare Folders action when two folders are selected in order [FolderA, FolderB]',
    (tester) async {
      final folderA = FileItem(
        path: '/home/user/FolderA',
        name: 'FolderA',
        type: FileItemType.folder,
        sizeBytes: 0,
        modified: DateTime.now(),
      );
      final folderB = FileItem(
        path: '/home/user/FolderB',
        name: 'FolderB',
        type: FileItemType.folder,
        sizeBytes: 0,
        modified: DateTime.now(),
      );

      final selectionOrder = {'/home/user/FolderA', '/home/user/FolderB'};

      await tester.pumpWidget(
        buildTestCard(
          item: folderB,
          selectionState: SelectionState(
            selectedPaths: selectionOrder,
            isSelectionMode: true,
          ),
          isSelected: true,
          directoryItems: [folderA, folderB],
        ),
      );
      await tester.pumpAndSettle();

      // Right-click on FolderB (the 2nd folder)
      await tester.tap(find.byType(ItemCard), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('Compare Folders'), findsOneWidget);
      expect(find.text('Compare with'), findsNothing);

      await tester.tap(find.text('Compare Folders'));
      await tester.pumpAndSettle();

      final params = PersistentViewerManager.getParamsForView(42);
      expect(params, isNotNull);
      expect(params!.viewerType, ViewerType.duplicateCompare);
      // Source must be the first selected, destination must be second selected
      expect(params.initParams['sourceFolder'], '/home/user/FolderA');
      expect(params.initParams['destinationFolder'], '/home/user/FolderB');
    },
  );

  testWidgets(
    'Folder ItemCard context menu preserves reversed selection order [FolderB, FolderA]',
    (tester) async {
      final folderA = FileItem(
        path: '/home/user/FolderA',
        name: 'FolderA',
        type: FileItemType.folder,
        sizeBytes: 0,
        modified: DateTime.now(),
      );
      final folderB = FileItem(
        path: '/home/user/FolderB',
        name: 'FolderB',
        type: FileItemType.folder,
        sizeBytes: 0,
        modified: DateTime.now(),
      );

      // Selected FolderB first, then FolderA
      final selectionOrder = {'/home/user/FolderB', '/home/user/FolderA'};

      await tester.pumpWidget(
        buildTestCard(
          item: folderA,
          selectionState: SelectionState(
            selectedPaths: selectionOrder,
            isSelectionMode: true,
          ),
          isSelected: true,
          directoryItems: [folderA, folderB],
        ),
      );
      await tester.pumpAndSettle();

      // Right-click on FolderA
      await tester.tap(find.byType(ItemCard), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('Compare Folders'), findsOneWidget);
      expect(find.text('Compare with'), findsNothing);

      await tester.tap(find.text('Compare Folders'));
      await tester.pumpAndSettle();

      final params = PersistentViewerManager.getParamsForView(42);
      expect(params, isNotNull);
      expect(params!.initParams['sourceFolder'], '/home/user/FolderB');
      expect(params.initParams['destinationFolder'], '/home/user/FolderA');
    },
  );

  testWidgets(
    'Folder ItemCard context menu omits compare action when more than two folders selected',
    (tester) async {
      final folderA = FileItem(
        path: '/home/user/FolderA',
        name: 'FolderA',
        type: FileItemType.folder,
        sizeBytes: 0,
        modified: DateTime.now(),
      );
      final folderB = FileItem(
        path: '/home/user/FolderB',
        name: 'FolderB',
        type: FileItemType.folder,
        sizeBytes: 0,
        modified: DateTime.now(),
      );
      final folderC = FileItem(
        path: '/home/user/FolderC',
        name: 'FolderC',
        type: FileItemType.folder,
        sizeBytes: 0,
        modified: DateTime.now(),
      );

      final selectionOrder = {
        '/home/user/FolderA',
        '/home/user/FolderB',
        '/home/user/FolderC',
      };

      await tester.pumpWidget(
        buildTestCard(
          item: folderA,
          selectionState: SelectionState(
            selectedPaths: selectionOrder,
            isSelectionMode: true,
          ),
          isSelected: true,
          directoryItems: [folderA, folderB, folderC],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ItemCard), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('Compare with'), findsNothing);
      expect(find.text('Compare Folders'), findsNothing);
      expect(find.text('Compare Folders...'), findsNothing);
    },
  );

  testWidgets(
    'Non-folder ItemCard context menu does NOT have compare action',
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

      await tester.tap(find.byType(ItemCard), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('Compare with'), findsNothing);
      expect(find.text('Compare Folders'), findsNothing);
      expect(find.text('Compare Folders...'), findsNothing);
    },
  );

  testWidgets(
    'Mixed selection (folder + file) does NOT have compare action',
    (tester) async {
      final folderItem = FileItem(
        path: '/home/user/FolderA',
        name: 'FolderA',
        type: FileItemType.folder,
        sizeBytes: 0,
        modified: DateTime.now(),
      );
      final docItem = FileItem(
        path: '/home/user/document.txt',
        name: 'document.txt',
        type: FileItemType.document,
        sizeBytes: 1024,
        modified: DateTime.now(),
      );

      final selectionOrder = {'/home/user/FolderA', '/home/user/document.txt'};

      await tester.pumpWidget(
        buildTestCard(
          item: folderItem,
          selectionState: SelectionState(
            selectedPaths: selectionOrder,
            isSelectionMode: true,
          ),
          isSelected: true,
          directoryItems: [folderItem, docItem],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ItemCard), buttons: kSecondaryMouseButton);
      await tester.pumpAndSettle();

      expect(find.text('Compare with'), findsNothing);
      expect(find.text('Compare Folders'), findsNothing);
      expect(find.text('Compare Folders...'), findsNothing);
    },
  );
}
