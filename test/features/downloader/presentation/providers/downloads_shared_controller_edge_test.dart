import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_panel_provider.dart';
import 'package:onyxcore/features/downloader/presentation/providers/downloads_shared_controller.dart';


void main() {
  group('importListFromFile Edge Cases', () {
    late ProviderContainer container;
    late DownloadsSharedController controller;
    late DownloadsListCache cache;
    late Directory tempDir;

    setUp(() {
      container = ProviderContainer();
      controller = container.read(downloadsSharedControllerProvider);
      cache = container.read(downloadsListCacheProvider);
      tempDir = Directory.systemTemp.createTempSync('onyxcore_import_test');
    });

    tearDown(() {
      container.dispose();
      tempDir.deleteSync(recursive: true);
    });

    test('reloads from file if cached state is empty', () async {
      final exportPath = '${tempDir.path}/test_export.json';
      final file = File(exportPath);
      await file.writeAsString('{"items":[{"originalUrl":"https://example.com"}]}');

      // Prime the cache with an empty state manually
      cache.switchList(exportPath);
      cache.parsedItems = null; // empty state

      // Now attempt to import
      await controller.importListFromFile(exportPath, 'test_export');

      // The parsed items should NOT be null because it should bypass the hasCache check
      // and reload from the file!
      expect(cache.parsedItems, isNotNull);
      expect(cache.parsedItems!.length, 1);
    });
  });
}
