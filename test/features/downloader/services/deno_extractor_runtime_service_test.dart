import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/utils/browser_detector.dart';
import 'package:onyxcore/features/downloader/domain/entities/browser_capability.dart';
import 'package:onyxcore/features/downloader/domain/entities/custom_extractor.dart';
import 'package:onyxcore/features/downloader/domain/services/extractor_runtime_service.dart';
import 'package:onyxcore/features/downloader/services/deno_extractor_runtime_service.dart';

void main() {
  group('DenoExtractorRuntimeService Output Validation Tests', () {
    late DenoExtractorRuntimeService service;

    setUp(() {
      service = DenoExtractorRuntimeService();
    });

    Future<ExtractorResult> executeWithScript(String scriptContent) {
      final extractor = CustomExtractor(
        id: 'test_id',
        name: 'test',
        script: scriptContent,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
      );
      const browser = BrowserInfo(
        id: 'google-chrome',
        name: 'Google Chrome',
        capability: BrowserCapability.chromium,
      );
      return service.execute(extractor, 'https://example.com', browser: browser);
    }

    test('valid array of URL strings', () async {
      final result = await executeWithScript('''
        export async function extract(url) {
          return ["https://example.com/video.mp4", "https://example.com/image.jpg"];
        }
      ''');
      expect(result.urls, equals(['https://example.com/video.mp4', 'https://example.com/image.jpg']));
    });

    test('single URL', () async {
      final result = await executeWithScript('''
        export async function extract(url) {
          return ["https://example.com/single.mp4"];
        }
      ''');
      expect(result.urls, equals(['https://example.com/single.mp4']));
    });

    test('empty array', () async {
      final result = await executeWithScript('''
        export async function extract(url) {
          return [];
        }
      ''');
      expect(result.urls, isEmpty);
    });

    test('invalid non-array result is rejected', () async {
      expect(
        () => executeWithScript('''
          export async function extract(url) {
            return "https://example.com/video.mp4";
          }
        '''),
        throwsA(isA<ExtractorException>()),
      );
    });

    test('array containing non-string values is rejected', () async {
      expect(
        () => executeWithScript('''
          export async function extract(url) {
            return ["https://example.com/video.mp4", 123];
          }
        '''),
        throwsA(isA<ExtractorException>()),
      );
    });

    test('empty URL strings are rejected', () async {
      expect(
        () => executeWithScript('''
          export async function extract(url) {
            return ["https://example.com/video.mp4", ""];
          }
        '''),
        throwsA(isA<ExtractorException>()),
      );
    });

    test('invalid URL values are rejected', () async {
      expect(
        () => executeWithScript('''
          export async function extract(url) {
            return ["https://example.com/video.mp4", "not_a_valid_url"];
          }
        '''),
        throwsA(isA<ExtractorException>()),
      );
    });

    test('old object-based output rejected', () async {
      expect(
        () => executeWithScript('''
          export async function extract(url) {
            return [{
              "url": "https://example.com/video.mp4",
              "title": "My Video"
            }];
          }
        '''),
        throwsA(isA<ExtractorException>()),
      );
    });
    test('browser DOM API document is available', () async {
      final result = await executeWithScript('''
        export async function extract(url) {
          // A real extractor might use document.querySelectorAll etc.
          // We just verify document exists and can be accessed.
          if (typeof document === "undefined") {
            throw new Error("document is not defined");
          }
          return ["https://example.com/dom"];
        }
      ''');
      expect(result.urls, equals(['https://example.com/dom']));
    });

    test('browser DOM API window is available', () async {
      final result = await executeWithScript('''
        export async function extract(url) {
          if (typeof window === "undefined") {
            throw new Error("window is not defined");
          }
          return ["https://example.com/window"];
        }
      ''');
      expect(result.urls, equals(['https://example.com/window']));
    });

    test('Deno specific APIs are unavailable', () async {
      expect(
        () => executeWithScript('''
          export async function extract(url) {
            // Should throw ReferenceError or similar in browser context
            const args = Deno.args;
            return ["https://example.com/deno"];
          }
        '''),
        throwsA(isA<ExtractorException>().having(
          (e) => e.message,
          'message',
          contains('Deno is not defined'),
        )),
      );
    });
  });
}
