import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_shared_controller.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/domain/entities/download_config.dart';

void main() {
  group('DownloadsSharedController Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state', () {
      final controller = container.read(downloadsSharedControllerProvider);
      
      expect(controller.selectedEngine, 'auto');
      expect(controller.totalListSize, 0);
      expect(controller.backgroundLoadingProfiles, isEmpty);
      expect(controller.activeHydrationPids, isEmpty);
    });

    test('recalculateFilteredStatistics with empty cache', () {
      final controller = container.read(downloadsSharedControllerProvider);
      controller.recalculateFilteredStatistics();
      
      expect(controller.totalListSize, 0);
      expect(controller.totalListVideos, 0);
      expect(controller.totalListImages, 0);
    });

    test('recalculateFilteredStatistics with items', () {
      final controller = container.read(downloadsSharedControllerProvider);
      final cache = container.read(downloadsListCacheProvider);
      
      cache.parsedItems = [
        MediaGroup(
          originalUrl: 'https://test.com',
          items: [
            MediaInfo(
              id: '1',
              title: 'Video 1',
              originalUrl: 'https://test.com',
              isVideo: true,
              filesize: 1024,
            ),
            MediaInfo(
              id: '2',
              title: 'Image 1',
              originalUrl: 'https://test.com',
              isVideo: false,
              filesize: 2048,
            ),
          ],
        )
      ];
      cache.configs[0] = DownloadConfig(mode: DownloadMode.normal, groupFilter: GroupDownloadType.all, engine: 'auto');
      
      controller.recalculateFilteredStatistics();
      
      expect(controller.totalListSize, 1024 + 2048);
      expect(controller.totalListVideos, 1);
      expect(controller.totalListImages, 1);
    });
  });
}
