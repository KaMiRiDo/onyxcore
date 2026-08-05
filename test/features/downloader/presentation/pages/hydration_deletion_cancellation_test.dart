import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_shared_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DownloadsSharedController Hydration Cancellation', () {
    late ProviderContainer container;
    late DownloadsListCache cache;
    late DownloadsSharedController controller;

    setUp(() {
      container = ProviderContainer();
      cache = container.read(downloadsListCacheProvider);
      controller = container.read(downloadsSharedControllerProvider)
        ..selectedEngine = 'gallery-dl';
    });

    tearDown(() {
      container.dispose();
    });

    test('cancelHydration clears active pids, loading state, and placeholder items', () async {
      const testUrl = 'https://instagram.com/p/test_post';
      final loadingItem = MediaInfo(
        id: 'hydration_loading',
        title: 'Loading...',
        originalUrl: testUrl,
      );
      final group = MediaGroup(
        originalUrl: testUrl,
        items: [loadingItem],
      );

      cache.parsedItems = [group];
      controller.backgroundLoadingProfiles.add(testUrl);
      controller.activeHydrationPids[testUrl] = [99999];

      expect(controller.backgroundLoadingProfiles.contains(testUrl), isTrue);
      expect(controller.activeHydrationPids.containsKey(testUrl), isTrue);

      await controller.cancelHydration(testUrl);

      expect(controller.backgroundLoadingProfiles.contains(testUrl), isFalse);
      expect(controller.activeHydrationPids.containsKey(testUrl), isFalse);
      expect(group.items.any((e) => e.id == 'hydration_loading'), isFalse);
    });

    test('cancelHydration on non-hydrating URL is a safe no-op', () async {
      const nonHydratingUrl = 'https://example.com/not_loading';
      expect(controller.backgroundLoadingProfiles.contains(nonHydratingUrl), isFalse);

      await expectLater(
        controller.cancelHydration(nonHydratingUrl),
        completes,
      );

      expect(controller.backgroundLoadingProfiles.contains(nonHydratingUrl), isFalse);
    });

    test('cancelHydration clears multiple active PIDs for a URL', () async {
      const testUrl = 'https://example.com/multi_pid';
      controller.backgroundLoadingProfiles.add(testUrl);
      controller.activeHydrationPids[testUrl] = [10001, 10002, 10003];

      await controller.cancelHydration(testUrl);

      expect(controller.activeHydrationPids.containsKey(testUrl), isFalse);
      expect(controller.backgroundLoadingProfiles.contains(testUrl), isFalse);
    });

    test('recalculateFilteredStatistics handles empty MediaGroup without throwing StateError', () {
      const emptyGroup = MediaGroup(
        originalUrl: 'https://example.com/empty_group',
        items: [],
      );
      final normalGroup = MediaGroup(
        originalUrl: 'https://example.com/normal',
        items: [
          const MediaInfo(
            id: 'item1',
            title: 'Title',
            originalUrl: 'https://example.com/normal',
            filesize: 5000,
          ),
        ],
      );

      cache.parsedItems = [emptyGroup, normalGroup];

      expect(() => controller.recalculateFilteredStatistics(), returnsNormally);
      expect(controller.totalListSize, equals(5000));
    });
  });
}
