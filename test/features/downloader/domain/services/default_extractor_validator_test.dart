import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/services/default_extractor_validator.dart';

void main() {
  group('DefaultExtractorValidator', () {
    // ── Extractor Name ──────────────────────────────────────────────────────

    group('validateExtractorName', () {
      test('accepts a valid name', () {
        expect(
          DefaultExtractorValidator.validateExtractorName('ABC Image Extractor'),
          isNull,
        );
      });

      test('accepts a single character name', () {
        expect(DefaultExtractorValidator.validateExtractorName('A'), isNull);
      });

      test('accepts a name with special characters', () {
        expect(
          DefaultExtractorValidator.validateExtractorName('My-Site_Extractor 2.0'),
          isNull,
        );
      });

      test('rejects an empty name', () {
        expect(
          DefaultExtractorValidator.validateExtractorName(''),
          isNotNull,
        );
      });

      test('rejects a whitespace-only name (spaces)', () {
        expect(
          DefaultExtractorValidator.validateExtractorName('   '),
          isNotNull,
        );
      });

      test('rejects a whitespace-only name (tabs)', () {
        expect(
          DefaultExtractorValidator.validateExtractorName('\t\t'),
          isNotNull,
        );
      });

      test('rejects a name exceeding 255 characters', () {
        final tooLong = 'a' * 256;
        expect(
          DefaultExtractorValidator.validateExtractorName(tooLong),
          isNotNull,
        );
      });

      test('accepts a name of exactly 255 characters', () {
        final maxLen = 'a' * 255;
        expect(
          DefaultExtractorValidator.validateExtractorName(maxLen),
          isNull,
        );
      });
    });

    // ── CSS Selector ────────────────────────────────────────────────────────

    group('validateCssSelector', () {
      test('accepts a simple class selector', () {
        expect(
          DefaultExtractorValidator.validateCssSelector('.article-content img'),
          isNull,
        );
      });

      test('accepts a complex valid selector', () {
        expect(
          DefaultExtractorValidator.validateCssSelector(
            'div.container > a[href]',
          ),
          isNull,
        );
      });

      test('accepts a selector with balanced attribute brackets', () {
        expect(
          DefaultExtractorValidator.validateCssSelector('img[data-src]'),
          isNull,
        );
      });

      test('accepts a selector with balanced parentheses', () {
        expect(
          DefaultExtractorValidator.validateCssSelector(':not(.hidden)'),
          isNull,
        );
      });

      test('accepts a tag selector', () {
        expect(DefaultExtractorValidator.validateCssSelector('video'), isNull);
      });

      test('accepts id selector', () {
        expect(
          DefaultExtractorValidator.validateCssSelector('#gallery img'),
          isNull,
        );
      });

      test('rejects an empty selector', () {
        expect(
          DefaultExtractorValidator.validateCssSelector(''),
          isNotNull,
        );
      });

      test('rejects a whitespace-only selector', () {
        expect(
          DefaultExtractorValidator.validateCssSelector('   '),
          isNotNull,
        );
      });

      test('rejects a selector containing a null byte', () {
        expect(
          DefaultExtractorValidator.validateCssSelector('.class\x00name'),
          isNotNull,
        );
      });

      test('rejects a selector with opening block brace', () {
        expect(
          DefaultExtractorValidator.validateCssSelector('div { color: red }'),
          isNotNull,
        );
      });

      test('rejects a selector with unbalanced opening bracket', () {
        expect(
          DefaultExtractorValidator.validateCssSelector('img[data-src'),
          isNotNull,
        );
      });

      test('rejects a selector with unbalanced closing bracket', () {
        expect(
          DefaultExtractorValidator.validateCssSelector('img]'),
          isNotNull,
        );
      });

      test('rejects a selector with extra closing bracket', () {
        expect(
          DefaultExtractorValidator.validateCssSelector('img[src]]'),
          isNotNull,
        );
      });

      test('rejects a selector with unbalanced opening parenthesis', () {
        expect(
          DefaultExtractorValidator.validateCssSelector(':not(.hidden'),
          isNotNull,
        );
      });

      test('rejects a selector with unbalanced closing parenthesis', () {
        expect(
          DefaultExtractorValidator.validateCssSelector('div)'),
          isNotNull,
        );
      });
    });

    // ── Attribute Name ──────────────────────────────────────────────────────

    group('validateAttributeName', () {
      test('accepts "src"', () {
        expect(DefaultExtractorValidator.validateAttributeName('src'), isNull);
      });

      test('accepts "href"', () {
        expect(DefaultExtractorValidator.validateAttributeName('href'), isNull);
      });

      test('accepts "data-src"', () {
        expect(
          DefaultExtractorValidator.validateAttributeName('data-src'),
          isNull,
        );
      });

      test('accepts "data-original"', () {
        expect(
          DefaultExtractorValidator.validateAttributeName('data-original'),
          isNull,
        );
      });

      test('accepts "poster"', () {
        expect(
          DefaultExtractorValidator.validateAttributeName('poster'),
          isNull,
        );
      });

      test('accepts "data-lazy-src"', () {
        expect(
          DefaultExtractorValidator.validateAttributeName('data-lazy-src'),
          isNull,
        );
      });

      test('rejects an empty attribute', () {
        expect(
          DefaultExtractorValidator.validateAttributeName(''),
          isNotNull,
        );
      });

      test('rejects a whitespace-only attribute', () {
        expect(
          DefaultExtractorValidator.validateAttributeName('   '),
          isNotNull,
        );
      });

      test('rejects attribute with leading whitespace', () {
        expect(
          DefaultExtractorValidator.validateAttributeName(' src'),
          isNotNull,
        );
      });

      test('rejects attribute with trailing whitespace', () {
        expect(
          DefaultExtractorValidator.validateAttributeName('src '),
          isNotNull,
        );
      });

      test('rejects attribute with internal space', () {
        expect(
          DefaultExtractorValidator.validateAttributeName('data src'),
          isNotNull,
        );
      });

      test('rejects attribute with tab character', () {
        expect(
          DefaultExtractorValidator.validateAttributeName('data\tsrc'),
          isNotNull,
        );
      });

      test('rejects attribute with newline', () {
        expect(
          DefaultExtractorValidator.validateAttributeName('data\nsrc'),
          isNotNull,
        );
      });

      test('rejects attribute with double quote', () {
        expect(
          DefaultExtractorValidator.validateAttributeName('data"src'),
          isNotNull,
        );
      });

      test('rejects attribute with single quote', () {
        expect(
          DefaultExtractorValidator.validateAttributeName("data'src"),
          isNotNull,
        );
      });

      test('rejects attribute with greater-than character', () {
        expect(
          DefaultExtractorValidator.validateAttributeName('data>src'),
          isNotNull,
        );
      });

      test('rejects attribute with forward slash', () {
        expect(
          DefaultExtractorValidator.validateAttributeName('data/src'),
          isNotNull,
        );
      });

      test('rejects attribute with equals sign', () {
        expect(
          DefaultExtractorValidator.validateAttributeName('data=src'),
          isNotNull,
        );
      });

      test('rejects attribute with null byte', () {
        expect(
          DefaultExtractorValidator.validateAttributeName('data\x00src'),
          isNotNull,
        );
      });

      test('rejects attribute with SOH control character', () {
        expect(
          DefaultExtractorValidator.validateAttributeName('data\x01src'),
          isNotNull,
        );
      });

      test('rejects attribute with US control character (\\x1F)', () {
        expect(
          DefaultExtractorValidator.validateAttributeName('data\x1Fsrc'),
          isNotNull,
        );
      });

      // Malicious JS-like payloads — must be treated as data, not code
      test('rejects JS-injection attempt: double-quote breakout', () {
        // While validator rejects these, the template service also escapes
        // them regardless, so injection cannot succeed even if validated.
        expect(
          DefaultExtractorValidator.validateAttributeName('");alert(1);//'),
          isNotNull,
        );
      });
    });
  });
}
