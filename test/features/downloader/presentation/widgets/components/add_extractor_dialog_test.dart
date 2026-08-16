import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/custom_extractor.dart';
import 'package:onyxcore/features/downloader/presentation/providers/custom_extractor_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/add_extractor_dialog.dart';

class MockCustomExtractorNotifier extends AsyncNotifier<List<CustomExtractor>> implements CustomExtractorNotifier {
  CustomExtractor? addedExtractor;
  CustomExtractor? updatedExtractor;

  @override
  Future<List<CustomExtractor>> build() async => [];

  @override
  Future<void> addExtractor(CustomExtractor extractor) async {
    addedExtractor = extractor;
  }

  @override
  Future<void> updateExtractor(CustomExtractor extractor) async {
    updatedExtractor = extractor;
  }

  @override
  Future<void> deleteExtractor(String id) async {}
}

void main() {
  testWidgets('AddExtractorDialog renders correctly for new extractor', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: AddExtractorDialog()),
        ),
      ),
    );

    expect(find.text('Add Custom Extractor'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // Name, Script
  });

  testWidgets('AddExtractorDialog pre-fills data for edit mode', (WidgetTester tester) async {
    final extractor = CustomExtractor(
      id: '1',
      name: 'Test Extractor',
      script: 'console.log();',
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(body: AddExtractorDialog(extractor: extractor)),
        ),
      ),
    );

    expect(find.text('Edit Custom Extractor'), findsOneWidget);
    expect(find.text('Test Extractor'), findsOneWidget);
    expect(find.text('console.log();'), findsOneWidget);
  });

  testWidgets('AddExtractorDialog saves new extractor', (WidgetTester tester) async {
    final mockNotifier = MockCustomExtractorNotifier();
    
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          customExtractorsProvider.overrideWith(() => mockNotifier),
        ],
        child: const MaterialApp(
          home: Scaffold(body: AddExtractorDialog()),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).first, 'New Extractor');
    await tester.enterText(find.byType(TextField).last, 'const x = 1;');
    
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(mockNotifier.addedExtractor, isNotNull);
    expect(mockNotifier.addedExtractor!.name, 'New Extractor');
    expect(mockNotifier.addedExtractor!.script, 'const x = 1;');
  });
}
