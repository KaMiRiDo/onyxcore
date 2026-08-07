import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/filter_settings.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/selection_state.dart';
import 'package:onyxcore/features/directory_browser/domain/repositories/directory_repository.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/conflict_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/pinned_items_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/conflict_dialog.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/empty_state_view.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/file_grid.dart';
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
  void select(String path) {
    state = SelectionState(
      selectedPaths: Set<String>.from(state.selectedPaths)..add(path),
      isSelectionMode: true,
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
  @override
  Future<Map<String, int>> build() async => {};
}

class MockIsSearchActiveNotifier extends IsSearchActiveNotifier {
  MockIsSearchActiveNotifier({this.initial = false});
  final bool initial;

  @override
  bool build() => initial;

  @override
  void set(bool value) {
    state = value;
  }
}

class MockSearchQueryNotifier extends SearchQueryNotifier {
  MockSearchQueryNotifier({this.initial = ''});
  final String initial;

  @override
  String build() => initial;
}

class FakeConflictNotifier extends ConflictNotifier {
  FakeConflictNotifier(this.resolution);
  final ConflictResolution resolution;

  @override
  List<ConflictRequest> build() => [];

  @override
  Future<ConflictResolution> resolveConflict({
    required String fileName,
    required String destinationPath,
    required bool isFolder,
    required BuildContext context,
  }) async {
    return resolution;
  }

  @override
  void clearGlobalResolution() {}
}

class MockDirectoryRepository implements DirectoryRepository {
  List<String>? restoreFromTrashPaths;
  List<String>? moveItemsSources;
  String? moveItemsDestination;
  String? movedSourcePath;
  String? movedDestinationPath;

  @override
  Future<void> restoreFromTrash(
    List<String> paths, {
    String? taskId,
    void Function(int processed, int total)? onProgress,
    void Function(String message)? onLog,
  }) async {
    restoreFromTrashPaths = paths;
  }

  @override
  Future<void> moveItems(List<String> sources, String destination) async {
    moveItemsSources = sources;
    moveItemsDestination = destination;
  }

  @override
  Future<void> moveItemTo(
    String sourcePath,
    String destinationPath, {
    void Function(int bytesCopied)? onProgress,
    void Function()? onSyncing,
    String? taskId,
    void Function(SendPort port, Isolate? isolate)? onPort,
  }) async {
    movedSourcePath = sourcePath;
    movedDestinationPath = destinationPath;
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
    required ProviderContainer container,
    required Widget child,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  testWidgets('FileGrid shows BubbleLoader when loading', (tester) async {
    final container = ProviderContainer(
      overrides: [
        filteredDirectoryItemsProvider.overrideWithValue(
          const AsyncValue<List<FileItem>>.loading(),
        ),
        sortedDirectoryItemsProvider.overrideWithValue(
          const AsyncValue<List<FileItem>>.loading(),
        ),
        currentPathProvider.overrideWith(MockCurrentPathNotifier.new),
        pinnedItemsProvider.overrideWith(MockPinnedItemsNotifier.new),
        selectionProvider.overrideWith(MockSelectionNotifier.new),
      ],
    );

    await tester.pumpWidget(
      buildTestApp(
        container: container,
        child: const FileGrid(),
      ),
    );

    expect(find.byType(BubbleLoader), findsOneWidget);
  });

  testWidgets('FileGrid shows EmptyStateView when empty', (tester) async {
    final container = ProviderContainer(
      overrides: [
        filteredDirectoryItemsProvider.overrideWithValue(
          const AsyncValue<List<FileItem>>.data([]),
        ),
        sortedDirectoryItemsProvider.overrideWithValue(
          const AsyncValue<List<FileItem>>.data([]),
        ),
        currentPathProvider.overrideWith(MockCurrentPathNotifier.new),
        pinnedItemsProvider.overrideWith(MockPinnedItemsNotifier.new),
        selectionProvider.overrideWith(MockSelectionNotifier.new),
        isSearchActiveProvider.overrideWith(MockIsSearchActiveNotifier.new),
        searchQueryProvider.overrideWith(MockSearchQueryNotifier.new),
        filterSettingsProvider.overrideWith((ref) => const FilterSettings()),
      ],
    );

    await tester.pumpWidget(
      buildTestApp(
        container: container,
        child: const FileGrid(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(EmptyStateView), findsOneWidget);
    expect(find.text('Empty Folder'), findsOneWidget);
  });

  testWidgets('FileGrid renders grid items when data is loaded', (tester) async {
    final item = FileItem(
      path: '/home/user/document.pdf',
      name: 'document.pdf',
      type: FileItemType.document,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    final container = ProviderContainer(
      overrides: [
        filteredDirectoryItemsProvider.overrideWithValue(
          AsyncValue<List<FileItem>>.data([item]),
        ),
        sortedDirectoryItemsProvider.overrideWithValue(
          AsyncValue<List<FileItem>>.data([item]),
        ),
        currentPathProvider.overrideWith(MockCurrentPathNotifier.new),
        pinnedItemsProvider.overrideWith(MockPinnedItemsNotifier.new),
        selectionProvider.overrideWith(MockSelectionNotifier.new),
        isSearchActiveProvider.overrideWith(MockIsSearchActiveNotifier.new),
        searchQueryProvider.overrideWith(MockSearchQueryNotifier.new),
        filterSettingsProvider.overrideWith((ref) => const FilterSettings()),
      ],
    );

    await tester.pumpWidget(
      buildTestApp(
        container: container,
        child: const FileGrid(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(ItemCard), findsOneWidget);
    expect(find.text('document.pdf'), findsOneWidget);
  });

  testWidgets('FileGrid behaves as drag target for moving files', (tester) async {
    final item = FileItem(
      path: '/home/user/document.pdf',
      name: 'document.pdf',
      type: FileItemType.document,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    final container = ProviderContainer(
      overrides: [
        filteredDirectoryItemsProvider.overrideWithValue(
          AsyncValue<List<FileItem>>.data([item]),
        ),
        sortedDirectoryItemsProvider.overrideWithValue(
          AsyncValue<List<FileItem>>.data([item]),
        ),
        currentPathProvider.overrideWith(MockCurrentPathNotifier.new),
        pinnedItemsProvider.overrideWith(MockPinnedItemsNotifier.new),
        selectionProvider.overrideWith(MockSelectionNotifier.new),
        isSearchActiveProvider.overrideWith(MockIsSearchActiveNotifier.new),
        searchQueryProvider.overrideWith(MockSearchQueryNotifier.new),
        filterSettingsProvider.overrideWith((ref) => const FilterSettings()),
        directoryRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );

    await tester.pumpWidget(
      buildTestApp(
        container: container,
        child: const FileGrid(),
      ),
    );

    await tester.pumpAndSettle();

    final dragTarget = tester.widget<DragTarget<List<String>>>(find.byType(DragTarget<List<String>>));
    dragTarget.onAcceptWithDetails?.call(
      DragTargetDetails(
        data: const ['/home/external/file.txt'],
        offset: Offset.zero,
      ),
    );
    await tester.pumpAndSettle();

    expect(mockRepo.movedSourcePath, '/home/external/file.txt');
    expect(mockRepo.movedDestinationPath, '/home/user/file.txt');

    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('FileGrid handles lifecycle state change and conflict resolution rename', (tester) async {
    final item = FileItem(
      path: '/home/user/document.pdf',
      name: 'document.pdf',
      type: FileItemType.document,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    final container = ProviderContainer(
      overrides: [
        filteredDirectoryItemsProvider.overrideWithValue(AsyncValue<List<FileItem>>.data([item])),
        sortedDirectoryItemsProvider.overrideWithValue(AsyncValue<List<FileItem>>.data([item])),
        currentPathProvider.overrideWith(MockCurrentPathNotifier.new),
        pinnedItemsProvider.overrideWith(MockPinnedItemsNotifier.new),
        selectionProvider.overrideWith(MockSelectionNotifier.new),
        isSearchActiveProvider.overrideWith(MockIsSearchActiveNotifier.new),
        searchQueryProvider.overrideWith(MockSearchQueryNotifier.new),
        filterSettingsProvider.overrideWith((ref) => const FilterSettings()),
        directoryRepositoryProvider.overrideWithValue(mockRepo),
        conflictProvider.overrideWith(() => FakeConflictNotifier(ConflictResolution.rename)),
      ],
    );

    await tester.pumpWidget(
      buildTestApp(
        container: container,
        child: const FileGrid(),
      ),
    );

    await tester.pumpAndSettle();

    // Trigger AppLifecycleState change
    (tester.state(find.byType(FileGrid)) as WidgetsBindingObserver)
        .didChangeAppLifecycleState(AppLifecycleState.detached);

    await tester.pumpAndSettle();
  });

  group('calculateGridViewportIndices', () {
    test('computes exact column count and visible range at scroll offset 0', () {
      final indices = calculateGridViewportIndices(
        gridWidth: 1200,
        gridHeight: 800,
        scrollOffset: 0,
        itemCount: 100,
        zoom: 1,
      );

      // Available width: 1200 - 64 = 1136
      // (1136 / (180 + 24)).ceil() = ceil(5.568) = 6 columns
      expect(indices.cols, 6);
      expect(indices.firstVisibleIndex, 0);
      expect(indices.lastVisibleIndex, 30); // 5 rows * 6 cols = 30
      expect(indices.firstBufferIndex, 0);
      expect(indices.lastBufferIndex, 42); // 7 rows * 6 cols = 42
    });

    test('computes visible range accurately when scrolled down', () {
      final indices = calculateGridViewportIndices(
        gridWidth: 1200,
        gridHeight: 800,
        scrollOffset: 462, // 2 rows down (2 * 231)
        itemCount: 100,
        zoom: 1,
      );

      expect(indices.cols, 6);
      expect(indices.firstVisibleIndex, 6); // Row 1 starts at index 6
      expect(indices.lastVisibleIndex, 42); // Up to row 6 (7 rows * 6 cols = 42)
      expect(indices.firstBufferIndex, 0); // 2 rows above clamped to 0
      expect(indices.lastBufferIndex, 54); // Row 8 * 6 cols = 54
    });

    test('handles empty item list gracefully', () {
      final indices = calculateGridViewportIndices(
        gridWidth: 1200,
        gridHeight: 800,
        scrollOffset: 0,
        itemCount: 0,
        zoom: 1,
      );

      expect(indices.firstVisibleIndex, 0);
      expect(indices.lastVisibleIndex, 0);
    });

    test('scales columns and item boundaries correctly with zoom', () {
      final indicesZoomed = calculateGridViewportIndices(
        gridWidth: 1200,
        gridHeight: 800,
        scrollOffset: 0,
        itemCount: 100,
        zoom: 1.5,
      );

      // (1136 / (180*1.5 + 24*1.5)).ceil() = ceil(1136 / 306) = 4 cols
      expect(indicesZoomed.cols, 4);
      expect(indicesZoomed.firstVisibleIndex, 0);
      expect(indicesZoomed.lastVisibleIndex, lessThanOrEqualTo(100));
    });

    test('clamps indices when total items is smaller than visible capacity', () {
      final indicesFewItems = calculateGridViewportIndices(
        gridWidth: 1200,
        gridHeight: 800,
        scrollOffset: 0,
        itemCount: 5,
        zoom: 1,
      );

      expect(indicesFewItems.firstVisibleIndex, 0);
      expect(indicesFewItems.lastVisibleIndex, 5);
      expect(indicesFewItems.lastBufferIndex, 5);
    });
  });
}
