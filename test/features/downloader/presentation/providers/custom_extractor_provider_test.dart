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
  });
}
