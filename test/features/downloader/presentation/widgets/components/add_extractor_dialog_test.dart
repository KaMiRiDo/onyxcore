import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/widgets/onyx_switch.dart';
import 'package:onyxcore/features/downloader/domain/entities/custom_extractor.dart';
import 'package:onyxcore/features/downloader/presentation/providers/custom_extractor_provider.dart';
import 'package:onyxcore/features/downloader/presentation/widgets/components/add_extractor_dialog.dart';

class MockCustomExtractorNotifier
    extends AsyncNotifier<List<CustomExtractor>>
    implements CustomExtractorNotifier {
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

Widget _buildTestApp({
  CustomExtractor? extractor,
  List<Object> overrides = const [],
}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      home: Scaffold(body: AddExtractorDialog(extractor: extractor)),
    ),
  );
}

void main() {
  // ── Tab structure ──────────────────────────────────────────────────────────

  group('Tab structure', () {
    testWidgets('Dialog shows Script Mode toggle', (WidgetTester tester) async { await tester.pumpWidget(_buildTestApp()); expect(find.text('Script Mode'), findsOneWidget); });

    testWidgets('Default Extractor fields are shown by default', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestApp());
      // Verify Default fields are visible
      expect(find.byKey(const ValueKey('extractor_name_field')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('extractor_selector_field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('extractor_attribute_field')),
        findsOneWidget,
      );
    });

    testWidgets('Script mode is accessible and shows script editor', (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestApp());
      await tester.tap(find.byType(OnyxSwitch)); // OnyxSwitch uses Switch inside
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('extractor_script_field')), findsOneWidget);
    });
  });

  // ── Dialog title ──────────────────────────────────────────────────────────

  group('Dialog title', () {
    testWidgets('shows Add title for new extractor',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestApp());
      expect(find.text('Add Custom Extractor'), findsOneWidget);
    });

    testWidgets('shows Edit title for existing extractor',
        (WidgetTester tester) async {
      final extractor = CustomExtractor(
        id: '1',
        name: 'Test Extractor',
        script: 'console.log();',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );
      await tester.pumpWidget(_buildTestApp(extractor: extractor));
      expect(find.text('Edit Custom Extractor'), findsOneWidget);
    });
  });

  // ── Default Extractor tab — fields ────────────────────────────────────────

  group('Default Extractor tab fields', () {
    testWidgets('shows Extractor Name, CSS Selector, Attribute Name fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestApp());

      expect(find.byKey(const ValueKey('extractor_name_field')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('extractor_selector_field')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('extractor_attribute_field')),
        findsOneWidget,
      );
    });

    testWidgets('shows HTML Extractor type dropdown',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestApp());
      // The extractor type dropdown shows 'HTML Extractor' by default
      expect(find.text('HTML Extractor'), findsOneWidget);
    });
  });

  // ── Default Extractor — validation ────────────────────────────────────────

  group('Default Extractor — inline validation', () {
    testWidgets('Save is blocked when name is empty',
        (WidgetTester tester) async {
      final mockNotifier = MockCustomExtractorNotifier();
      await tester.pumpWidget(_buildTestApp(
        overrides: [
          customExtractorsProvider.overrideWith(() => mockNotifier),
        ],
      ));

      // Leave name empty, fill selector and attribute
      await tester.enterText(
        find.byKey(const ValueKey('extractor_selector_field')),
        '.article img',
      );
      await tester.enterText(
        find.byKey(const ValueKey('extractor_attribute_field')),
        'src',
      );

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(mockNotifier.addedExtractor, isNull);
    });

    testWidgets('Save is blocked when CSS selector is empty',
        (WidgetTester tester) async {
      final mockNotifier = MockCustomExtractorNotifier();
      await tester.pumpWidget(_buildTestApp(
        overrides: [
          customExtractorsProvider.overrideWith(() => mockNotifier),
        ],
      ));

      await tester.enterText(
        find.byKey(const ValueKey('extractor_name_field')),
        'My Extractor',
      );
      await tester.enterText(
        find.byKey(const ValueKey('extractor_attribute_field')),
        'src',
      );
      // Leave selector empty

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(mockNotifier.addedExtractor, isNull);
    });

    testWidgets('Save is blocked when attribute name is empty',
        (WidgetTester tester) async {
      final mockNotifier = MockCustomExtractorNotifier();
      await tester.pumpWidget(_buildTestApp(
        overrides: [
          customExtractorsProvider.overrideWith(() => mockNotifier),
        ],
      ));

      await tester.enterText(
        find.byKey(const ValueKey('extractor_name_field')),
        'My Extractor',
      );
      await tester.enterText(
        find.byKey(const ValueKey('extractor_selector_field')),
        '.article img',
      );
      // Leave attribute empty

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(mockNotifier.addedExtractor, isNull);
    });

    testWidgets('validation error appears inline below name field',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestApp());

      await tester.tap(find.text('Create'));
      await tester.pump();

      // An error message should appear somewhere in the tree
      expect(
        find.textContaining('cannot be empty', findRichText: true),
        findsWidgets,
      );
    });
  });

  // ── Default Extractor — Save flow ─────────────────────────────────────────

  group('Default Extractor — Save flow', () {
    testWidgets('saves a new default HTML extractor successfully',
        (WidgetTester tester) async {
      final mockNotifier = MockCustomExtractorNotifier();
      await tester.pumpWidget(_buildTestApp(
        overrides: [
          customExtractorsProvider.overrideWith(() => mockNotifier),
        ],
      ));

      await tester.enterText(
        find.byKey(const ValueKey('extractor_name_field')),
        'ABC Image Extractor',
      );
      await tester.enterText(
        find.byKey(const ValueKey('extractor_selector_field')),
        '.article-content img',
      );
      await tester.enterText(
        find.byKey(const ValueKey('extractor_attribute_field')),
        'src',
      );

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(mockNotifier.addedExtractor, isNotNull);
      expect(mockNotifier.addedExtractor!.name, 'ABC Image Extractor');
    });

    testWidgets('generated script is stored in the extractor',
        (WidgetTester tester) async {
      final mockNotifier = MockCustomExtractorNotifier();
      await tester.pumpWidget(_buildTestApp(
        overrides: [
          customExtractorsProvider.overrideWith(() => mockNotifier),
        ],
      ));

      await tester.enterText(
        find.byKey(const ValueKey('extractor_name_field')),
        'Test Extractor',
      );
      await tester.enterText(
        find.byKey(const ValueKey('extractor_selector_field')),
        '.gallery img',
      );
      await tester.enterText(
        find.byKey(const ValueKey('extractor_attribute_field')),
        'src',
      );

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(mockNotifier.addedExtractor, isNotNull);
      final script = mockNotifier.addedExtractor!.script;
      expect(script, contains('querySelectorAll(".gallery img")'));
      expect(script, contains('getAttribute("src")'));
      expect(script, contains('async function extract(url)'));
    });

    testWidgets('metadata is persisted with extractorKind=html',
        (WidgetTester tester) async {
      final mockNotifier = MockCustomExtractorNotifier();
      await tester.pumpWidget(_buildTestApp(
        overrides: [
          customExtractorsProvider.overrideWith(() => mockNotifier),
        ],
      ));

      await tester.enterText(
        find.byKey(const ValueKey('extractor_name_field')),
        'Test Extractor',
      );
      await tester.enterText(
        find.byKey(const ValueKey('extractor_selector_field')),
        '.gallery img',
      );
      await tester.enterText(
        find.byKey(const ValueKey('extractor_attribute_field')),
        'src',
      );

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(mockNotifier.addedExtractor, isNotNull);
      final metadata = mockNotifier.addedExtractor!.metadata;
      expect(metadata, isNotNull);
      expect(metadata, contains('"extractorKind":"html"'));
      expect(metadata, contains('"cssSelector":".gallery img"'));
      expect(metadata, contains('"attributeName":"src"'));
    });
  });

  // ── Script tab — regression ────────────────────────────────────────────────

  group('Script mode — existing behavior preserved (regression)', () {
    testWidgets('Script mode shows name and script editor fields',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestApp());

      await tester.tap(find.byType(OnyxSwitch));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('extractor_name_script_field')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('extractor_script_field')),
        findsOneWidget,
      );
    });

    testWidgets('saves a script extractor from Script mode',
        (WidgetTester tester) async {
      final mockNotifier = MockCustomExtractorNotifier();
      await tester.pumpWidget(_buildTestApp(
        overrides: [
          customExtractorsProvider.overrideWith(() => mockNotifier),
        ],
      ));

      await tester.tap(find.byType(OnyxSwitch));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('extractor_name_script_field')),
        'Manual Script Extractor',
      );
      await tester.enterText(
        find.byKey(const ValueKey('extractor_script_field')),
        'async function extract(url) { return []; }',
      );

      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(mockNotifier.addedExtractor, isNotNull);
      expect(mockNotifier.addedExtractor!.name, 'Manual Script Extractor');
      expect(
        mockNotifier.addedExtractor!.script,
        contains('async function extract'),
      );
      // Script extractor must have no metadata
      expect(mockNotifier.addedExtractor!.metadata, isNull);
    });
  });

  // ── Edit mode ─────────────────────────────────────────────────────────────

  group('Edit mode', () {
    testWidgets('pre-fills Default fields when editing a default extractor',
        (WidgetTester tester) async {
      const metadata =
          '{"extractorKind":"html","cssSelector":".article img","attributeName":"data-src"}';
      final extractor = CustomExtractor(
        id: '1',
        name: 'My HTML Extractor',
        script: 'async function extract(url) { return []; }',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        metadata: metadata,
      );

      await tester.pumpWidget(_buildTestApp(extractor: extractor));

      // Should be in default mode
      expect(
        find.byKey(const ValueKey('extractor_selector_field')),
        findsOneWidget,
      );

      final nameField = tester.widget<TextField>(
        find.byKey(const ValueKey('extractor_name_field')),
      );
      expect(nameField.controller!.text, 'My HTML Extractor');

      final selectorField = tester.widget<TextField>(
        find.byKey(const ValueKey('extractor_selector_field')),
      );
      expect(selectorField.controller!.text, '.article img');

      final attributeField = tester.widget<TextField>(
        find.byKey(const ValueKey('extractor_attribute_field')),
      );
      expect(attributeField.controller!.text, 'data-src');
    });

    testWidgets('opens Script mode when editing a manual script extractor',
        (WidgetTester tester) async {
      final extractor = CustomExtractor(
        id: '1',
        name: 'Manual Extractor',
        script: 'async function extract(url) { return []; }',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        // No metadata = script extractor
      );

      await tester.pumpWidget(_buildTestApp(extractor: extractor));
      await tester.pumpAndSettle();

      // Script field should be visible (Script mode active)
      expect(
        find.byKey(const ValueKey('extractor_script_field')),
        findsOneWidget,
      );
    });

    testWidgets('updates existing default extractor and regenerates script',
        (WidgetTester tester) async {
      final mockNotifier = MockCustomExtractorNotifier();
      const metadata =
          '{"extractorKind":"html","cssSelector":".img","attributeName":"src"}';
      final extractor = CustomExtractor(
        id: '1',
        name: 'HTML Extractor',
        script: 'old script',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        metadata: metadata,
      );

      await tester.pumpWidget(_buildTestApp(
        extractor: extractor,
        overrides: [
          customExtractorsProvider.overrideWith(() => mockNotifier),
        ],
      ));

      // Update the selector
      await tester.enterText(
        find.byKey(const ValueKey('extractor_selector_field')),
        '.new-gallery img',
      );

      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      expect(mockNotifier.updatedExtractor, isNotNull);
      final updatedScript = mockNotifier.updatedExtractor!.script;
      // Script is regenerated with the new selector
      expect(updatedScript, contains('querySelectorAll(".new-gallery img")'));
      // Metadata is updated
      expect(
        mockNotifier.updatedExtractor!.metadata,
        contains('.new-gallery img'),
      );
    });
  });

  // ── Cancel button ─────────────────────────────────────────────────────────

  group('Cancel button', () {
    testWidgets('Cancel closes dialog without saving',
        (WidgetTester tester) async {
      final mockNotifier = MockCustomExtractorNotifier();
      await tester.pumpWidget(_buildTestApp(
        overrides: [
          customExtractorsProvider.overrideWith(() => mockNotifier),
        ],
      ));

      await tester.enterText(
        find.byKey(const ValueKey('extractor_name_field')),
        'Some Name',
      );

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(mockNotifier.addedExtractor, isNull);
    });
  });
}
