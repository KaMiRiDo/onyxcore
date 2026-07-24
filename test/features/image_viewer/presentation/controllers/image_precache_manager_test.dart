import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_precache_manager.dart';

void main() {
  group('ImagePrecacheManager', () {
    late ImagePrecacheManager manager;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      manager = ImagePrecacheManager();
    });

    tearDown(() {
      manager.clearSession();
    });

    test('enqueues and processes items sequentially', () async {
      final processed = <String>[];
      
      Future<void> dummyPrecache(String path, BuildContext? context) async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        processed.add(path);
      }

      manager
        ..enqueuePrecache(
          path: 'image1.jpg',
          level: 1,
          precacheAction: (ctx) => dummyPrecache('image1.jpg', ctx),
        )
        ..enqueuePrecache(
          path: 'image2.jpg',
          level: 2,
          precacheAction: (ctx) => dummyPrecache('image2.jpg', ctx),
        );

      expect(processed, isEmpty);
      
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(processed, ['image1.jpg', 'image2.jpg']);
    });

    test('prioritizes level 1 over level 2', () async {
      final processed = <String>[];
      
      Future<void> dummyPrecache(String path, BuildContext? context) async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        processed.add(path);
      }

      // Start a slow task that blocks the queue
      manager
        ..enqueuePrecache(
          path: 'blocker.jpg',
          level: 1,
          precacheAction: (ctx) => dummyPrecache('blocker.jpg', ctx),
        )
        // Enqueue Level 2 first
        ..enqueuePrecache(
          path: 'level2.jpg',
          level: 2,
          precacheAction: (ctx) => dummyPrecache('level2.jpg', ctx),
        )
        // Enqueue Level 1 later
        ..enqueuePrecache(
          path: 'level1.jpg',
          level: 1,
          precacheAction: (ctx) => dummyPrecache('level1.jpg', ctx),
        );

      await Future<void>.delayed(const Duration(milliseconds: 100));
      
      // Blocker was running, then level1 (higher priority), then level2
      expect(processed, ['blocker.jpg', 'level1.jpg', 'level2.jpg']);
    });

    test('tracks LRU eviction based on item count to prevent memory bloat', () async {
      // Assuming a max items cap for simplicity in unit test logic.
      // In practice, we will use a soft limit on the number of items or estimated bytes.
      manager.maxCachedItems = 3;

      Future<void> dummyPrecache(String path, BuildContext? context) async {}

      for (var i = 1; i <= 5; i++) {
        manager.enqueuePrecache(
          path: 'image$i.jpg',
          level: 1,
          precacheAction: (ctx) => dummyPrecache('image$i.jpg', ctx),
        );
      }

      await Future<void>.delayed(const Duration(milliseconds: 20));
      
      // Should only retain the last 3 in its internal tracking structure
      expect(manager.cachedPaths.length, equals(3));
      expect(manager.cachedPaths.contains('image1.jpg'), isFalse);
      expect(manager.cachedPaths.contains('image2.jpg'), isFalse);
      expect(manager.cachedPaths.contains('image3.jpg'), isTrue);
      expect(manager.cachedPaths.contains('image4.jpg'), isTrue);
      expect(manager.cachedPaths.contains('image5.jpg'), isTrue);
    });

    test('clearSession empties queue and cache tracking', () async {
      Future<void> dummyPrecache(String path, BuildContext? context) async {}

      manager.enqueuePrecache(
        path: 'image1.jpg',
        level: 1,
        precacheAction: (ctx) => dummyPrecache('image1.jpg', ctx),
      );
      
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(manager.cachedPaths.length, equals(1));
      
      manager.clearSession();
      expect(manager.cachedPaths, isEmpty);
      expect(manager.isProcessing, isFalse);
    });
  });
}
