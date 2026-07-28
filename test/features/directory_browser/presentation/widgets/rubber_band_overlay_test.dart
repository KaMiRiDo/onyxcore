import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/selection_state.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/pinned_items_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/item_card.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/rubber_band_overlay.dart';

class FakeSelectionNotifier extends SelectionNotifier {
  FakeSelectionNotifier({this.initialPaths = const {}});
  final Set<String> initialPaths;
  List<String>? selectedPathsCaptured;

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
    selectedPathsCaptured = paths;
  }
}

class MockCurrentPathNotifier extends CurrentPathNotifier {
  @override
  String build() => '/home/user';
}

class MockPinnedItemsNotifier extends PinnedItemsNotifier {
  @override
  Future<Map<String, int>> build() async => {};
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestWidget({
    required Widget child,
    required ProviderContainer container,
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

  testWidgets('RubberBandOverlay builds successfully', (tester) async {
    final container = ProviderContainer(
      overrides: [
        selectionProvider.overrideWith(FakeSelectionNotifier.new),
      ],
    );

    await tester.pumpWidget(
      buildTestWidget(
        container: container,
        child: RubberBandOverlay(
          child: Container(
            width: 500,
            height: 500,
            color: Colors.transparent,
          ),
        ),
      ),
    );

    expect(find.byType(RubberBandOverlay), findsOneWidget);
  });

  testWidgets('RubberBandOverlay drag selects overlapping ItemCards', (tester) async {
    final fakeSelectionNotifier = FakeSelectionNotifier();
    final container = ProviderContainer(
      overrides: [
        selectionProvider.overrideWith(() => fakeSelectionNotifier),
        currentPathProvider.overrideWith(MockCurrentPathNotifier.new),
        pinnedItemsProvider.overrideWith(MockPinnedItemsNotifier.new),
      ],
    );

    final item1 = FileItem(
      path: '/home/user/file1.txt',
      name: 'file1.txt',
      type: FileItemType.document,
      sizeBytes: 100,
      modified: DateTime.now(),
    );

    final item2 = FileItem(
      path: '/home/user/file2.txt',
      name: 'file2.txt',
      type: FileItemType.document,
      sizeBytes: 200,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(
      buildTestWidget(
        container: container,
        child: RubberBandOverlay(
          child: ColoredBox(
            color: Colors.transparent, // Ensure full hit-test coverage
            child: Stack(
              children: [
                Positioned(
                  left: 50,
                  top: 50,
                  width: 180,
                  height: 215,
                  child: ItemCard(
                    item: item1,
                    zoom: 1,
                    isSelected: false,
                    isHovered: false,
                    onTap: () {},
                    onDoubleTap: () {},
                    onHoverChanged: (_) {},
                  ),
                ),
                Positioned(
                  left: 250,
                  top: 250,
                  width: 180,
                  height: 215,
                  child: ItemCard(
                    item: item2,
                    zoom: 1,
                    isSelected: false,
                    isHovered: false,
                    onTap: () {},
                    onDoubleTap: () {},
                    onHoverChanged: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Drag 1: Select only file1 (overlaps box from 40,40 to 120,120)
    await tester.dragFrom(const Offset(40, 40), const Offset(80, 80));
    await tester.pumpAndSettle();

    final activeNotifier = container.read(selectionProvider.notifier) as FakeSelectionNotifier;

    // Verify that selection notifier received only file1.txt
    expect(activeNotifier.selectedPathsCaptured, contains('/home/user/file1.txt'));
    expect(activeNotifier.selectedPathsCaptured, isNot(contains('/home/user/file2.txt')));

    // Drag 2: Select both (from 40,40 to 300,300)
    await tester.dragFrom(const Offset(40, 40), const Offset(260, 260));
    await tester.pumpAndSettle();

    expect(activeNotifier.selectedPathsCaptured, contains('/home/user/file1.txt'));
    expect(activeNotifier.selectedPathsCaptured, contains('/home/user/file2.txt'));
  });

  testWidgets('RubberBandOverlay with Ctrl key preserves initial selection', (tester) async {
    final fakeSelectionNotifier = FakeSelectionNotifier(
      initialPaths: {'/home/user/file2.txt'},
    );

    final container = ProviderContainer(
      overrides: [
        selectionProvider.overrideWith(() => fakeSelectionNotifier),
        currentPathProvider.overrideWith(MockCurrentPathNotifier.new),
        pinnedItemsProvider.overrideWith(MockPinnedItemsNotifier.new),
      ],
    );

    final item1 = FileItem(
      path: '/home/user/file1.txt',
      name: 'file1.txt',
      type: FileItemType.document,
      sizeBytes: 100,
      modified: DateTime.now(),
    );

    final item2 = FileItem(
      path: '/home/user/file2.txt',
      name: 'file2.txt',
      type: FileItemType.document,
      sizeBytes: 200,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(
      buildTestWidget(
        container: container,
        child: RubberBandOverlay(
          child: ColoredBox(
            color: Colors.transparent, // Ensure full hit-test coverage
            child: Stack(
              children: [
                Positioned(
                  left: 50,
                  top: 50,
                  width: 180,
                  height: 215,
                  child: ItemCard(
                    item: item1,
                    zoom: 1,
                    isSelected: false,
                    isHovered: false,
                    onTap: () {},
                    onDoubleTap: () {},
                    onHoverChanged: (_) {},
                  ),
                ),
                Positioned(
                  left: 250,
                  top: 250,
                  width: 180,
                  height: 215,
                  child: ItemCard(
                    item: item2,
                    zoom: 1,
                    isSelected: true,
                    isHovered: false,
                    onTap: () {},
                    onDoubleTap: () {},
                    onHoverChanged: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Simulate key down of Control
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);

    // Drag: Select only file1 (overlaps box from 40,40 to 120,120)
    await tester.dragFrom(const Offset(40, 40), const Offset(80, 80));
    await tester.pumpAndSettle();

    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

    final activeNotifier = container.read(selectionProvider.notifier) as FakeSelectionNotifier;

    // Verify selection contains both file1 (from drag) and file2 (retained via Ctrl)
    expect(activeNotifier.selectedPathsCaptured, contains('/home/user/file1.txt'));
    expect(activeNotifier.selectedPathsCaptured, contains('/home/user/file2.txt'));
  });
}
