import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onyxcore/features/downloader/domain/entities/media_info.dart';
import 'package:onyxcore/features/downloader/services/downloader_process_wrapper.dart';
import 'package:onyxcore/features/downloader/services/engines/download_engine.dart';
import 'package:onyxcore/features/downloader/services/engines/engine_registry.dart';

class MockEngine extends Mock implements DownloadEngine {}

void main() {
  late MockEngine mockEngine;

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  setUp(() {
    mockEngine = MockEngine();
    
    when(() => mockEngine.id).thenReturn('mock_engine');
    when(() => mockEngine.displayName).thenReturn('Mock Engine');
    when(() => mockEngine.priority).thenReturn(100);
    when(() => mockEngine.urlPatterns).thenReturn([RegExp(r'.*')]);
    when(() => mockEngine.isInstalled).thenReturn(true);
    
    when(() => mockEngine.fetchMetadata(
      url: any(named: 'url'),
      browser: any(named: 'browser'),
      fetchDeep: any(named: 'fetchDeep'),
      isPlaylist: any(named: 'isPlaylist'),
    )).thenAnswer((invocation) async {
      final url = invocation.namedArguments[#url] as String;
      return [MediaInfo(id: url, title: 'Item for $url', originalUrl: url)];
    });

    EngineRegistry.clearAllEnginesForTesting();
    EngineRegistry.register(mockEngine);
  });

  tearDown(() {
    EngineRegistry.clearRegisteredEngines();
  });

  group('MediaDownloaderBackend Tests', () {
    test('analyzeUrls processes all URLs when not cancelled', () async {
      final urls = ['url1', 'url2', 'url3'];
      final results = await MediaDownloaderBackend.analyzeUrls(
        urls,
        isCancelled: () => false,
      );

      expect(results.length, 3);
      expect(results[0].originalUrl, 'url1');
      expect(results[1].originalUrl, 'url2');
      expect(results[2].originalUrl, 'url3');
    });

    test('analyzeUrls halts processing early when cancelled', () async {
      final urls = ['url1', 'url2', 'url3'];
      int count = 0;
      
      final results = await MediaDownloaderBackend.analyzeUrls(
        urls,
        isCancelled: () {
          return count++ >= 1;
        },
      );

      // Should only process 'url1' and then halt before fetching 'url2'
      expect(results.length, 1);
      expect(results[0].originalUrl, 'url1');
    });
  });
}
