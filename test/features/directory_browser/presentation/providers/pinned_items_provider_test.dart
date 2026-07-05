import 'package:drift/drift.dart' hide Column, isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/database/app_database.dart';
import 'package:onyxcore/core/database/database_provider.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/pinned_items_provider.dart';

void main() {
  group('PinnedItemsNotifier', () {
    late ProviderContainer container;
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(DatabaseConnection(NativeDatabase.memory()));
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

    test('initial state loads from database', () async {
      // Pre-populate database
      await db.into(db.pinnedItems).insert(
        PinnedItemsCompanion.insert(itemPath: '/test/path', pinnedAt: 12345),
      );

      final state = await container.read(pinnedItemsProvider.future);
      expect(state.length, 1);
      expect(state.containsKey('/test/path'), isTrue);
    });

    test('pinItem adds item to database and state', () async {
      final notifier = container.read(pinnedItemsProvider.notifier);
      
      // Wait for initial load
      await container.read(pinnedItemsProvider.future);

      await notifier.pinItem('/new/pinned/path');

      final state = await container.read(pinnedItemsProvider.future);
      expect(state.containsKey('/new/pinned/path'), isTrue);

      final dbItems = await db.select(db.pinnedItems).get();
      expect(dbItems.any((e) => e.itemPath == '/new/pinned/path'), isTrue);
    });

    test('unpinItem removes item from database and state', () async {
      await db.into(db.pinnedItems).insert(
        PinnedItemsCompanion.insert(itemPath: '/to/unpin', pinnedAt: DateTime.now().millisecondsSinceEpoch),
      );

      final notifier = container.read(pinnedItemsProvider.notifier);
      
      // Wait for initial load
      await container.read(pinnedItemsProvider.future);
      expect(container.read(pinnedItemsProvider).value!.containsKey('/to/unpin'), isTrue);

      await notifier.unpinItem('/to/unpin');

      final state = await container.read(pinnedItemsProvider.future);
      expect(state.containsKey('/to/unpin'), isFalse);

      final dbItems = await db.select(db.pinnedItems).get();
      expect(dbItems.any((e) => e.itemPath == '/to/unpin'), isFalse);
    });
  });
}
