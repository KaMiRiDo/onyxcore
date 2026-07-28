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

class MockSelectionNotifier extends SelectionNotifier {
  MockSelectionNotifier({this.initialPaths = const {}});
  final Set<String> initialPaths;

  @override
  SelectionState build() => SelectionState(
        selectedPaths: initialPaths,
        isSelectionMode: initialPaths.isNotEmpty,
      );

  @override
  void selectMultiple(List<String> paths, {bool isCtrl = false}) {
    state = SelectionState(
      selectedPaths: paths.toSet(),
      isSelectionMode: paths.isNotEmpty,
    );
  }

  @override
  void deselectAll() {
    state = SelectionState.empty;
  }
}

class MockCurrentPathNotifier extends CurrentPathNotifier {
  MockCurrentPathNotifier({this.initialPath = '/home/user'});
  final String initialPath;

  @override
  String build() => initialPath;
}

class MockPinnedItemsNotifier extends PinnedItemsNotifier {
  MockPinnedItemsNotifier({this.initialPinned = const {}});
  final Map<String, int> initialPinned;

  @override
  Future<Map<String, int>> build() async => initialPinned;
}

class FakeClipboardNotifier extends ClipboardNotifier {
  FakeClipboardNotifier({this.initialState = const ClipboardState()});
  final ClipboardState initialState;

  @override
  ClipboardState build() => initialState;
}

class MockTaskNotifier extends TaskNotifier {
  @override
  List<FileTask> build() => [];

  @override
  String addTask({
    required String title,
    required String subtitle,
    List<String>? sourcePaths,
    String? targetPath,
    int? totalCount,
    int? totalSizeBytes,
    bool isLight = false,
  }) {
    return 'mock_task_id';
  }

  @override
  void completeTask(String id) {}

  @override
  void addLog(String id, String log) {}
}

class MockDirectoryItemsNotifier extends DirectoryItemsNotifier {
  @override
  Future<List<FileItem>> build() async {
    return [];
  }

  @override
  Future<void> refresh() async {}
}

class MockDirectoryRepository implements DirectoryRepository {
  List<String>? restoreFromTrashPaths;
  List<String>? moveItemsSources;
  String? moveItemsDestination;

  @override
  Future<void> restoreFromTrash(
    List<String> paths, {
    String? taskId,
    void Function(int processed, int total)? onProgress,
    void Function(String message)? onLog,
  }) async {
    debugPrint('MOCK REPO restoreFromTrash called with paths: $paths');
    restoreFromTrashPaths = paths;
  }

  @override
  Future<void> moveItems(List<String> sources, String destination) async {
    moveItemsSources = sources;
    moveItemsDestination = destination;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDirectoryRepository mockRepo;

  setUp(() {
    mockRepo = MockDirectoryRepository();
  });

  Widget buildTestApp({
    required Widget child,
    MockSelectionNotifier? selectionNotifier,
    MockPinnedItemsNotifier? pinnedNotifier,
    String currentPath = '/home/user',
  }) {
    return ProviderScope(
      overrides: [
        directoryRepositoryProvider.overrideWithValue(mockRepo),
        selectionProvider.overrideWith(() => selectionNotifier ?? MockSelectionNotifier()),
        currentPathProvider.overrideWith(() => MockCurrentPathNotifier(initialPath: currentPath)),
        pinnedItemsProvider.overrideWith(() => pinnedNotifier ?? MockPinnedItemsNotifier()),
        clipboardProvider.overrideWith(FakeClipboardNotifier.new),
        taskProvider.overrideWith(MockTaskNotifier.new),
        directoryItemsProvider.overrideWith(MockDirectoryItemsNotifier.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  testWidgets('ItemCard renders item name and responds to tap/double tap', (tester) async {
    final item = FileItem(
      path: '/home/user/document.txt',
      name: 'document.txt',
      type: FileItemType.document,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    var tapped = false;
    var doubleTapped = false;

    await tester.pumpWidget(
      buildTestApp(
        child: SizedBox(
          width: 150,
          height: 200,
          child: ItemCard(
            item: item,
            zoom: 1,
            isSelected: false,
            isHovered: false,
            onHoverChanged: (v) {},
            onTap: () => tapped = true,
            onDoubleTap: () => doubleTapped = true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('document.txt'), findsOneWidget);

    final gestureDetector = tester.widget<GestureDetector>(find.descendant(
      of: find.byType(ItemCard),
      matching: find.byType(GestureDetector),
    ).first);

    gestureDetector.onTap?.call();
    await tester.pumpAndSettle();
    expect(tapped, true);

    gestureDetector.onDoubleTap?.call();
    await tester.pumpAndSettle();
    expect(doubleTapped, true);
  });

  testWidgets('ItemCard renders pin icon if item is pinned', (tester) async {
    final item = FileItem(
      path: '/home/user/document.txt',
      name: 'document.txt',
      type: FileItemType.document,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    final pinnedNotifier = MockPinnedItemsNotifier(initialPinned: {'/home/user/document.txt': 1});

    await tester.pumpWidget(
      buildTestApp(
        pinnedNotifier: pinnedNotifier,
        child: SizedBox(
          width: 150,
          height: 200,
          child: ItemCard(
            item: item,
            zoom: 1,
            isSelected: false,
            isHovered: false,
            onHoverChanged: (v) {},
            onTap: () {},
            onDoubleTap: () {},
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.push_pin), findsOneWidget);
  });

  testWidgets('ItemCard renders restore icon when in Trash and triggers restore', (tester) async {
    final item = FileItem(
      path: 'trash://home/user/document.txt',
      name: 'document.txt',
      type: FileItemType.document,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(
      buildTestApp(
        currentPath: 'Trash/files',
        child: SizedBox(
          width: 150,
          height: 200,
          child: ItemCard(
            item: item,
            zoom: 1,
            isSelected: false,
            isHovered: false,
            onHoverChanged: (v) {},
            onTap: () {},
            onDoubleTap: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final restoreFinder = find.byIcon(Icons.history_rounded);
    expect(restoreFinder, findsOneWidget);

    final restoreGestureDetector = tester.widget<GestureDetector>(
      find.descendant(
        of: find.byType(Tooltip),
        matching: find.byType(GestureDetector),
      ).first,
    );
    restoreGestureDetector.onTap?.call();
    await tester.pumpAndSettle();

    expect(mockRepo.restoreFromTrashPaths, contains('trash://home/user/document.txt'));
  });

  testWidgets('ItemCard shows context menu on secondary tap', (tester) async {
    final item = FileItem(
      path: '/home/user/document.txt',
      name: 'document.txt',
      type: FileItemType.document,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(
      buildTestApp(
        child: SizedBox(
          width: 150,
          height: 200,
          child: ItemCard(
            item: item,
            zoom: 1,
            isHovered: false,
            isSelected: false,
            onHoverChanged: (v) {},
            onTap: () {},
            onDoubleTap: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Trigger secondary tap (right-click)
    await tester.tap(find.byType(ItemCard), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    // Verify context menu options are shown
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Cut'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
  });

  testWidgets('ItemCard folder can be a drag target', (tester) async {
    final fileItem = FileItem(
      path: '/home/user/file.txt',
      name: 'file.txt',
      type: FileItemType.document,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    final folderItem = FileItem(
      path: '/home/user/folder',
      name: 'folder',
      type: FileItemType.folder,
      sizeBytes: 0,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(
      buildTestApp(
        child: Column(
          children: [
            SizedBox(
              width: 150,
              height: 200,
              child: ItemCard(
                item: fileItem,
                zoom: 1,
                isSelected: false,
                isHovered: false,
                onHoverChanged: (v) {},
                onTap: () {},
                onDoubleTap: () {},
              ),
            ),
            SizedBox(
              width: 150,
              height: 200,
              child: ItemCard(
                item: folderItem,
                zoom: 1,
                isSelected: false,
                isHovered: false,
                onHoverChanged: (v) {},
                onTap: () {},
                onDoubleTap: () {},
              ),
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Drag file into folder
    final dragGesture = await tester.startGesture(tester.getCenter(find.text('file.txt')));
    await dragGesture.moveTo(tester.getCenter(find.text('folder')));
    await dragGesture.up();
    await tester.pumpAndSettle();

    expect(mockRepo.moveItemsSources, contains('/home/user/file.txt'));
    expect(mockRepo.moveItemsDestination, '/home/user/folder');
  });

  testWidgets('ItemCard handles lock icon and middle-truncation', (tester) async {
    final item = FileItem(
      path: '/home/user/this_is_a_very_very_long_file_name_that_should_be_truncated.txt',
      name: 'this_is_a_very_very_long_file_name_that_should_be_truncated.txt',
      type: FileItemType.document,
      sizeBytes: 1024,
      modified: DateTime.now(),
      hasWritePermission: false,
    );

    await tester.pumpWidget(
      buildTestApp(
        child: SizedBox(
          width: 150,
          height: 200,
          child: ItemCard(
            item: item,
            zoom: 1,
            isSelected: false,
            isHovered: false,
            onHoverChanged: (v) {},
            onTap: () {},
            onDoubleTap: () {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Lock icon should be visible
    expect(find.byIcon(Icons.lock), findsOneWidget);

    // Truncated version of the name should be visible
    expect(find.textContaining('...'), findsOneWidget);
  });
}
