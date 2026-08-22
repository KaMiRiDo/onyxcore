import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/downloader/domain/entities/custom_extractor.dart';
import 'package:onyxcore/features/downloader/presentation/providers/custom_extractor_provider.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('CustomExtractorNotifier tests', () {
    // ── Existing Phase 1 tests (regression) ─────────────────────────────────

    test('Provider yields an empty list initially', () async {
      final value = await container.read(customExtractorsProvider.future);
      expect(value, isEmpty);
    });

    test('addExtractor persists and updates state', () async {
      final extractor = CustomExtractor(
        id: '1',
        name: 'Test',
        script: 'console.log("hello");',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      final notifier = container.read(customExtractorsProvider.notifier);
      await notifier.addExtractor(extractor);

      final value = await container.read(customExtractorsProvider.future);
      expect(value.length, 1);
      expect(value.first.id, '1');
      expect(value.first.name, 'Test');

      final dbEntries = await db.getAllExtractors();
      expect(dbEntries.length, 1);
      expect(dbEntries.first.id, '1');
    });

    test('updateExtractor persists and updates state', () async {
      final extractor = CustomExtractor(
        id: '1',
        name: 'Test',
        script: 'script',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      final notifier = container.read(customExtractorsProvider.notifier);
      await notifier.addExtractor(extractor);

      final updated = extractor.copyWith(name: 'Updated Test');
      await notifier.updateExtractor(updated);

      final value = await container.read(customExtractorsProvider.future);
      expect(value.length, 1);
      expect(value.first.name, 'Updated Test');

      final dbEntries = await db.getAllExtractors();
      expect(dbEntries.length, 1);
      expect(dbEntries.first.name, 'Updated Test');
    });

    test('deleteExtractor persists and updates state', () async {
      final extractor = CustomExtractor(
        id: '1',
        name: 'Test',
        script: 'script',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      final notifier = container.read(customExtractorsProvider.notifier);
      await notifier.addExtractor(extractor);

      await notifier.deleteExtractor('1');

      final value = await container.read(customExtractorsProvider.future);
      expect(value, isEmpty);

      final dbEntries = await db.getAllExtractors();
      expect(dbEntries, isEmpty);
    });

    // ── Phase 2: metadata persistence ───────────────────────────────────────

    test('addExtractor persists metadata for a default extractor', () async {
      const metadata =
          '{"extractorKind":"html","cssSelector":".article img","attributeName":"src"}';
      final extractor = CustomExtractor(
        id: '2',
        name: 'HTML Extractor',
        script: 'async function extract(url) { return []; }',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        metadata: metadata,
      );

      final notifier = container.read(customExtractorsProvider.notifier);
      await notifier.addExtractor(extractor);

      final value = await container.read(customExtractorsProvider.future);
      expect(value.first.metadata, metadata);
    });

    test(
        'existing Phase 1 extractor without metadata continues to work (metadata is null)',
        () async {
      final extractor = CustomExtractor(
        id: '1',
        name: 'Legacy Script Extractor',
        script: 'async function extract(url) { return []; }',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        // No metadata
      );

      final notifier = container.read(customExtractorsProvider.notifier);
      await notifier.addExtractor(extractor);

      final value = await container.read(customExtractorsProvider.future);
      expect(value.first.metadata, isNull);
    });

    test('updateExtractor updates metadata (editing a default extractor)',
        () async {
      const originalMeta =
          '{"extractorKind":"html","cssSelector":".img","attributeName":"src"}';
      final extractor = CustomExtractor(
        id: '1',
        name: 'HTML Extractor',
        script: 'async function extract(url) { return []; }',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        metadata: originalMeta,
      );

      final notifier = container.read(customExtractorsProvider.notifier);
      await notifier.addExtractor(extractor);

      const updatedMeta =
          '{"extractorKind":"html","cssSelector":".article img","attributeName":"data-src"}';
      final updated = extractor.copyWith(
        metadata: updatedMeta,
        modifiedAt:
            DateTime.fromMillisecondsSinceEpoch(1700000001000),
      );
      await notifier.updateExtractor(updated);

      final value = await container.read(customExtractorsProvider.future);
      expect(value.first.metadata, updatedMeta);
    });

    test('metadata is reloaded correctly on subsequent provider build',
        () async {
      const metadata =
          '{"extractorKind":"html","cssSelector":".gallery img","attributeName":"data-original"}';
      final extractor = CustomExtractor(
        id: '3',
        name: 'Gallery Extractor',
        script: 'async function extract(url) { return []; }',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        metadata: metadata,
      );

      // Insert directly via DB to simulate a fresh load
      await db.upsertExtractor(
        extractor.id,
        extractor.name,
        extractor.script,
        extractor.createdAt.millisecondsSinceEpoch,
        extractor.modifiedAt.millisecondsSinceEpoch,
        metadata: extractor.metadata,
      );

      final value = await container.read(customExtractorsProvider.future);
      expect(value.first.metadata, metadata);
    });

    test('mixed: script extractor and default extractor coexist', () async {
      final scriptExtractor = CustomExtractor(
        id: '1',
        name: 'Script Extractor',
        script: 'async function extract(url) { return []; }',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      const metadata =
          '{"extractorKind":"html","cssSelector":".img","attributeName":"src"}';
      final defaultExtractor = CustomExtractor(
        id: '2',
        name: 'HTML Extractor',
        script: 'async function extract(url) { return []; }',
        createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        modifiedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        metadata: metadata,
      );

      final notifier = container.read(customExtractorsProvider.notifier);
      await notifier.addExtractor(scriptExtractor);
      await notifier.addExtractor(defaultExtractor);

      final value = await container.read(customExtractorsProvider.future);
      expect(value.length, 2);
      final script = value.firstWhere((e) => e.id == '1');
      final html = value.firstWhere((e) => e.id == '2');
      expect(script.metadata, isNull);
      expect(html.metadata, metadata);
    });
  });
}
