import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/widgets/bubble_loader.dart';
import 'package:onyxcore/features/directory_browser/domain/entities/file_item.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/directory_providers.dart';
import 'package:onyxcore/features/directory_browser/presentation/widgets/file_grid.dart';

class FakeCurrentPathNotifier extends CurrentPathNotifier {
  @override
  String build() => '/home';
}

void main() {
  testWidgets('FileGrid shows BubbleLoader when loading', (tester) async {
    final container = ProviderContainer(
      overrides: [
        filteredDirectoryItemsProvider.overrideWithValue(
          const AsyncValue<List<FileItem>>.loading(),
        ),
        sortedDirectoryItemsProvider.overrideWithValue(
          const AsyncValue<List<FileItem>>.loading(),
        ),
        currentPathProvider.overrideWith(FakeCurrentPathNotifier.new),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: FileGrid(),
          ),
        ),
      ),
    );

    expect(find.byType(BubbleLoader), findsOneWidget);
  });
}
