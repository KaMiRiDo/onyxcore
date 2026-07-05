import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/selection_state.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/pinned_items_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/item_card.dart';

class MockSelectionNotifier extends SelectionNotifier {
  @override
  SelectionState build() => const SelectionState(
    
  );
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
  testWidgets('ItemCard renders item name', (tester) async {
    final item = FileItem(
      path: '/home/user/document.pdf',
      name: 'document.pdf',
      type: FileItemType.document,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectionProvider.overrideWith(MockSelectionNotifier.new),
          currentPathProvider.overrideWith(MockCurrentPathNotifier.new),
          pinnedItemsProvider.overrideWith(MockPinnedItemsNotifier.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ItemCard(
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
      ),
    );

    expect(find.text('document.pdf'), findsOneWidget);
  });

  testWidgets('ItemCard handles selection state', (tester) async {
    final item = FileItem(
      path: '/home/user/document.pdf',
      name: 'document.pdf',
      type: FileItemType.document,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          selectionProvider.overrideWith(MockSelectionNotifier.new),
          currentPathProvider.overrideWith(MockCurrentPathNotifier.new),
          pinnedItemsProvider.overrideWith(MockPinnedItemsNotifier.new),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ItemCard(
              item: item,
              zoom: 1,
              isHovered: false,
              isSelected: true,
              onHoverChanged: (v) {},
              onTap: () {},
              onDoubleTap: () {},
            ),
          ),
        ),
      ),
    );

    // Should still render and have the same name, just visual changes
    expect(find.text('document.pdf'), findsOneWidget);
  });
}
