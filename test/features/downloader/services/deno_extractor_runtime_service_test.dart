import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/browser_detector.dart';
import 'package:onyxcore/features/downloader/domain/entities/browser_capability.dart';
import 'package:onyxcore/features/downloader/domain/entities/custom_extractor.dart';
import 'package:onyxcore/features/downloader/domain/entities/extractor_runtime_config.dart';
import 'package:onyxcore/features/downloader/domain/services/extractor_runtime_service.dart';
import 'package:onyxcore/features/downloader/services/deno_extractor_runtime_service.dart';

void main() {
  group('DenoExtractorRuntimeService Tests', () {
    late DenoExtractorRuntimeService service;
    const testConfig = ExtractorRuntimeConfig(
      navigationTimeoutMs: 15000,
      extractorTimeoutMs: 15000,
      settleDelayMs: 0,
      maxResults: 100,
    );

    setUp(() {
      service = DenoExtractorRuntimeService();
    });

    Future<ExtractorResult> executeWithScript(String scriptContent, {
      ExtractorRuntimeConfig? config,
      void Function(int)? onProcessStarted,
    }) {
      final extractor = CustomExtractor(
        id: 'test_id',
        name: 'test',
        script: scriptContent,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );
      // We use chrome/chromium in tests.
      // DenoExtractorRuntimeService will need to resolve this correctly.
      const browser = BrowserInfo(
        id: 'google-chrome',
        name: 'Google Chrome',
        capability: BrowserCapability.chromium,
      );
      return service.execute(
        extractor,
        'https://example.com',
        browser: browser,
        config: config ?? testConfig,
        onProcessStarted: onProcessStarted,
      );
    }

    test('valid array of URL strings is processed', () async {
      final result = await executeWithScript('''
        export async function extract(url) {
          return ["https://example.com/video.mp4", "https://example.com/image.jpg"];
        }
      ''');
      expect(result.urls, equals(['https://example.com/video.mp4', 'https://example.com/image.jpg']));
    });

    test('throws ExtractorException when Deno APIs are accessed', () async {
      expect(
        () => executeWithScript('''
          export async function extract(url) {
            const args = Deno.args;
            return ["https://example.com/deno"];
          }
        '''),
        throwsA(isA<ExtractorException>().having(
          (e) => e.message,
          'message',
          contains('Deno APIs are not available'),
        )),
      );
    });

    test('throws TimeoutException (or ExtractorException) when script hangs (extractorTimeoutMs)', () async {
      expect(
        () => executeWithScript('''
          export async function extract(url) {
            await new Promise(r => setTimeout(r, 10000));
            return ["https://example.com/timeout"];
          }
        ''', config: const ExtractorRuntimeConfig(
          navigationTimeoutMs: 15000,
          extractorTimeoutMs: 2000,
          settleDelayMs: 0,
          maxResults: 100,
        )),
        throwsA(isA<ExtractorException>().having((e) => e.message.toLowerCase(), 'message', contains('timeout'))),
      );
    });

    test('browser unavailability is thrown explicitly', () async {
      final extractor = CustomExtractor(
        id: 'test_id',
        name: 'test',
        script: 'export async function extract(url) { return []; }',
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );
      const invalidBrowser = BrowserInfo(
        id: 'non_existent_browser_12345',
        name: 'Unknown',
        capability: BrowserCapability.chromium,
      );
      expect(
        () => service.execute(extractor, 'https://example.com', browser: invalidBrowser),
        throwsA(isA<ExtractorException>().having((e) => e.message.toLowerCase(), 'message', contains('browser executable not found'))),
      );
    });
    
    test('reports PID immediately when process starts', () async {
      int? reportedPid;
      await executeWithScript('''
        export async function extract(url) {
          return ["https://example.com/pid"];
        }
      ''', onProcessStarted: (pid) => reportedPid = pid);
      
      expect(reportedPid, isNotNull);
      expect(reportedPid, greaterThan(0));
    });

    test('throws on unsupported scheme returned from extractor', () async {
      expect(
        () => executeWithScript('''
          export async function extract(url) {
            return ["javascript:alert(1)"];
          }
        '''),
        throwsA(isA<ExtractorException>()),
      );
    });

  });
}
