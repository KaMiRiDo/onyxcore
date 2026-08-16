import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/custom_extractor.dart';
import 'package:onyxcore/features/downloader/presentation/providers/custom_extractor_provider.dart';
import 'package:onyxcore/features/settings/presentation/widgets/components/extractor_list_tile.dart';

class MockCustomExtractorNotifier extends AsyncNotifier<List<CustomExtractor>> implements CustomExtractorNotifier {
  @override
  Future<List<CustomExtractor>> build() async {
    return [
      CustomExtractor(
        id: '1',
        name: 'Test Extractor 1',
        script: 'console.log("hello");',
        createdAt: DateTime(2025),
        modifiedAt: DateTime(2025),
      ),
      CustomExtractor(
        id: '2',
        name: 'Test Extractor 2',
        script: 'console.log("world");',
        createdAt: DateTime(2025, 1, 2),
        modifiedAt: DateTime(2025, 1, 2),
      ),
    ];
  }

  @override
  Future<void> addExtractor(CustomExtractor extractor) async {}

  @override
  Future<void> deleteExtractor(String id) async {}

  @override
  Future<void> updateExtractor(CustomExtractor extractor) async {}
}

void main() {
  testWidgets('ExtractorListTile renders list of extractors', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customExtractorsProvider.overrideWith(MockCustomExtractorNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ExtractorListTile()),
        ),
      ),
    );

    // Initial loading state
    await tester.pumpAndSettle();

    expect(find.text('Test Extractor 1'), findsOneWidget);
    expect(find.text('Test Extractor 2'), findsOneWidget);
    expect(find.byIcon(Icons.edit_rounded), findsNWidgets(2));
    expect(find.byIcon(Icons.delete_rounded), findsNWidgets(2));
  });
}
