// ignore_for_file: use_named_constants
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/selection_state.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/pinned_items_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/item_card.dart';

class MockSelectionNotifier extends SelectionNotifier {
  @override
  SelectionState build() => const SelectionState();
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
  Widget buildTestApp({required Widget child}) {
    return ProviderScope(
      overrides: [
        selectionProvider.overrideWith(MockSelectionNotifier.new),
        currentPathProvider.overrideWith(MockCurrentPathNotifier.new),
        pinnedItemsProvider.overrideWith(MockPinnedItemsNotifier.new),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: child,
        ),
      ),
    );
  }

  testWidgets('ItemCard renders item name and interacts', (tester) async {
    final item = FileItem(
      path: '/home/user/document.pdf',
      name: 'document.pdf',
      type: FileItemType.document,
      sizeBytes: 1024,
      modified: DateTime.now(),
    );

    var tapped = false;

    await tester.pumpWidget(
      buildTestApp(
        child: ItemCard(
          item: item,
          zoom: 1, 
          isHovered: false,
          isSelected: false,
          onHoverChanged: (v) {},
          onTap: () {
            tapped = true;
          },
          onDoubleTap: () {},
        ),
      ),
    );

    expect(find.byType(ItemCard), findsOneWidget);
    
    // Wait for any animations to complete
    await tester.pumpAndSettle();

    // Tap to verify onTap works
    final gestureDetector = tester.widget<GestureDetector>(find.descendant(
      of: find.byType(ItemCard),
      matching: find.byType(GestureDetector),
    ).first);
    gestureDetector.onTap?.call();
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
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
      buildTestApp(
        child: ItemCard(
          item: item,
          zoom: 1,
          isHovered: false,
          isSelected: true,
          onHoverChanged: (v) {},
          onTap: () {},
          onDoubleTap: () {},
        ),
      ),
    );

    expect(find.text('document.pdf'), findsOneWidget);
    
    // Find the Container that changes background color based on isSelected
    final container = tester.widget<Container>(find.descendant(
      of: find.byType(Opacity),
      matching: find.byType(Container),
    ).first);

    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.violet.withValues(alpha: 0.12));
  });
}
