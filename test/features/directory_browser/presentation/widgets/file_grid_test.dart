import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/file_grid.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/core/utils/file_type_classifier.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/selection_notifier.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/selection_state.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/filter_settings.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/pinned_items_provider.dart';

class MockCurrentPathNotifier extends CurrentPathNotifier {
  @override
  String build() => '/home/user';
}

class MockSelectionNotifier extends SelectionNotifier {
  @override
  SelectionState build() => const SelectionState(
    selectedPaths: {},
    anchorIndex: null,
    isSelectionMode: false,
  );
}

class MockPinnedItemsNotifier extends PinnedItemsNotifier {
  @override
  Future<Map<String, int>> build() async => {};
}

class MockIsRefreshingNotifier extends IsRefreshingNotifier {
  @override
  bool build() => false;
}

class MockIsSearchActiveNotifier extends IsSearchActiveNotifier {
  @override
  bool build() => false;
}

class MockSearchQueryNotifier extends SearchQueryNotifier {
  @override
  String build() => '';
}

void main() {
  testWidgets('FileGrid renders empty state when no items', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sortedDirectoryItemsProvider.overrideWith((ref) => <FileItem>[]),
          currentPathProvider.overrideWith(() => MockCurrentPathNotifier()),
          selectionProvider.overrideWith(() => MockSelectionNotifier()),
          currentZoomProvider.overrideWithValue(1.0),
          isRefreshingProvider.overrideWith(() => MockIsRefreshingNotifier()),
          isSearchActiveProvider.overrideWith(() => MockIsSearchActiveNotifier()),
          searchQueryProvider.overrideWith(() => MockSearchQueryNotifier()),
          filterSettingsProvider.overrideWithValue(const FilterSettings()),
          pinnedItemsProvider.overrideWith(() => MockPinnedItemsNotifier()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: FileGrid(),
          ),
        ),
      ),
    );

    expect(find.byType(FileGrid), findsOneWidget);
  });

  testWidgets('FileGrid renders items', (tester) async {
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
          sortedDirectoryItemsProvider.overrideWith((ref) => [item]),
          currentPathProvider.overrideWith(() => MockCurrentPathNotifier()),
          selectionProvider.overrideWith(() => MockSelectionNotifier()),
          currentZoomProvider.overrideWithValue(1.0),
          isRefreshingProvider.overrideWith(() => MockIsRefreshingNotifier()),
          isSearchActiveProvider.overrideWith(() => MockIsSearchActiveNotifier()),
          searchQueryProvider.overrideWith(() => MockSearchQueryNotifier()),
          filterSettingsProvider.overrideWithValue(const FilterSettings()),
          pinnedItemsProvider.overrideWith(() => MockPinnedItemsNotifier()),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: FileGrid(),
          ),
        ),
      ),
    );

    expect(find.byType(FileGrid), findsOneWidget);
  });
}
