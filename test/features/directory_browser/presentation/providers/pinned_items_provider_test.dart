import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:onyxcore/features/directory_browser/presentation/providers/pinned_items_provider.dart';

void main() {
  group('PinnedItemsNotifier', () {
    late ProviderContainer container;
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_test');
      Hive.init(tempDir.path);
      container = ProviderContainer();
    });

    tearDown(() async {
      container.dispose();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('initial state loads from Hive box', () async {
      // Pre-populate Hive box
      final box = await Hive.openBox(PinnedItemsNotifier.boxName);
      await box.put('/test/path', 12345);
      await box.put('/test/path2', 'invalid_type'); // should be ignored

      final state = await container.read(pinnedItemsProvider.future);
      expect(state.length, 1);
      expect(state['/test/path'], 12345);
      expect(state.containsKey('/test/path2'), isFalse);
    });

    test('pinItem adds item to Hive and state', () async {
      final notifier = container.read(pinnedItemsProvider.notifier);
      
      // Wait for initial load
      await container.read(pinnedItemsProvider.future);

      await notifier.pinItem('/new/pinned/path');

      final state = await container.read(pinnedItemsProvider.future);
      expect(state.containsKey('/new/pinned/path'), isTrue);

      final box = await Hive.openBox(PinnedItemsNotifier.boxName);
      expect(box.containsKey('/new/pinned/path'), isTrue);
    });

    test('unpinItem removes item from Hive and state', () async {
      final box = await Hive.openBox(PinnedItemsNotifier.boxName);
      await box.put('/to/unpin', 99999);

      final notifier = container.read(pinnedItemsProvider.notifier);
      
      // Wait for initial load
      await container.read(pinnedItemsProvider.future);
      expect(container.read(pinnedItemsProvider).value!.containsKey('/to/unpin'), isTrue);

      await notifier.unpinItem('/to/unpin');

      final state = await container.read(pinnedItemsProvider.future);
      expect(state.containsKey('/to/unpin'), isFalse);

      final boxAfter = await Hive.openBox(PinnedItemsNotifier.boxName);
      expect(boxAfter.containsKey('/to/unpin'), isFalse);
    });
  });
}
