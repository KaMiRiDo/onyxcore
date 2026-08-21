import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/entities/extractor_runtime_config.dart';
import 'package:onyxcore/features/downloader/domain/services/extractor_output_validator.dart';
import 'package:onyxcore/features/downloader/domain/services/extractor_runtime_service.dart';

void main() {
  group('ExtractorOutputValidator Tests', () {
    const config = ExtractorRuntimeConfig(maxResults: 5);

    test('validates and deduplicates valid URLs', () {
      final input = [
        'https://example.com/video.mp4',
        'http://example.com/image.jpg',
        'https://example.com/video.mp4', // Duplicate
        '  https://example.com/spaced.mp4  ', // Whitespace
      ];
      final result = ExtractorOutputValidator.validate(input, config: config);
      expect(result, [
        'https://example.com/video.mp4',
        'http://example.com/image.jpg',
        'https://example.com/spaced.mp4',
      ]);
    });

    test('throws ExtractorException if result exceeds max limit', () {
      final input = [
        'https://example.com/1',
        'https://example.com/2',
        'https://example.com/3',
        'https://example.com/4',
        'https://example.com/5',
        'https://example.com/6',
      ];
      expect(
        () => ExtractorOutputValidator.validate(input, config: config),
        throwsA(isA<ExtractorException>().having((e) => e.message, 'message', contains('exceeds the maximum allowed'))),
      );
    });

    test('throws ExtractorException if result contains non-string types', () {
      final input = ['https://example.com/1', 123, 'https://example.com/2'];
      expect(
        () => ExtractorOutputValidator.validate(input, config: config),
        throwsA(isA<ExtractorException>().having((e) => e.message, 'message', contains('must be an array of URL strings'))),
      );
    });

    test('throws ExtractorException for empty strings', () {
      final input = ['https://example.com/1', '   ', 'https://example.com/2'];
      expect(
        () => ExtractorOutputValidator.validate(input, config: config),
        throwsA(isA<ExtractorException>().having((e) => e.message, 'message', contains('empty URL string'))),
      );
    });

    test('throws ExtractorException for invalid URLs', () {
      final input = ['https://example.com/1', 'not_a_url', 'https://example.com/2'];
      expect(
        () => ExtractorOutputValidator.validate(input, config: config),
        throwsA(isA<ExtractorException>().having((e) => e.message, 'message', contains('invalid URL string'))),
      );
    });

    test('throws ExtractorException for unsupported schemes', () {
      final schemes = [
        'javascript:alert(1)',
        'data:text/html,<html>',
        'file:///etc/passwd',
        'blob:https://example.com/1234',
        'chrome://settings',
        'devtools://devtools/bundled/inspector.html',
      ];
      for (final scheme in schemes) {
        expect(
          () => ExtractorOutputValidator.validate([scheme], config: config),
          throwsA(isA<ExtractorException>().having((e) => e.message, 'message', contains('unsupported URL scheme'))),
          reason: 'Should reject $scheme',
        );
      }
    });

    test('throws FormatException if raw input is not a list', () {
      expect(
        () => ExtractorOutputValidator.validateRaw({'url': 'https://example.com'}, config: config),
        throwsA(isA<ExtractorException>().having((e) => e.message, 'message', contains('must be an array'))),
      );
    });
  });
}
