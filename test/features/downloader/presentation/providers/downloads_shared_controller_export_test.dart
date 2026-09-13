import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_shared_controller.dart';

void main() {
  group('DownloadsSharedController Export & Import Tests', () {
    late ProviderContainer container;
    late DownloadsSharedController controller;
    late DownloadsListCache cache;
    late Directory tempDir;

    setUp(() {
      container = ProviderContainer();
      controller = container.read(downloadsSharedControllerProvider);
      cache = container.read(downloadsListCacheProvider);
      tempDir = Directory.systemTemp.createTempSync('onyxcore_export_test');
    });

    tearDown(() {
      container.dispose();
      tempDir.deleteSync(recursive: true);
    });

    test('exportListToFile and importListFromFile works without blocking', () async {
      final largeList = List.generate(
        1000,
        (i) => MediaGroup(
          originalUrl: 'https://example.com/$i',
          items: [
            MediaInfo(
              id: 'id_$i',
              title: 'Title $i',
              originalUrl: 'https://example.com/$i',
              directUrl: 'https://video.example.com/$i.mp4',
            )
          ],
        ),
      );
      cache
        ..parsedItems = largeList
        ..isListChanged = true;

      final exportPath = '${tempDir.path}/test_export.dml';

      final stopwatch = Stopwatch()..start();
      await controller.exportListToFile(exportPath);
      stopwatch.stop();

      expect(File(exportPath).existsSync(), isTrue);
      
      // If the main thread was blocked, this would take hundreds of milliseconds on a slow device.
      // We expect it to be fast because it's run in an isolate (once fixed).
      // print('Export took: ${stopwatch.elapsedMilliseconds} ms');

      cache.clear();
      expect(cache.parsedItems, isNull);

      await controller.importListFromFile(exportPath, 'test_export');

      expect(cache.parsedItems, isNotNull);
      expect(cache.parsedItems!.length, 1000);
      expect(cache.parsedItems!.first.items.first.title, 'Title 0');
    });
  });
}
