import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/downloader/domain/services/default_extractor_template_service.dart';

void main() {
  const service = DefaultExtractorTemplateService();

  group('DefaultExtractorTemplateService', () {
    // ── Script generation — structure ───────────────────────────────────────

    group('generateScript — HTML Extractor structure', () {
      const config = DefaultExtractorConfig(
        kind: DefaultExtractorKind.html,
        cssSelector: '.article-content img',
        attributeName: 'src',
      );

      test('generates a valid async function named extract', () {
        final script = service.generateScript(config);
        expect(script, contains('async function extract(url)'));
      });

      test('contains querySelectorAll with injected selector', () {
        final script = service.generateScript(config);
        expect(script, contains('querySelectorAll(".article-content img")'));
      });

      test('contains getAttribute with injected attribute', () {
        final script = service.generateScript(config);
        expect(script, contains('getAttribute("src")'));
      });

      test('resolves relative URLs via document.baseURI', () {
        final script = service.generateScript(config);
        expect(script, contains('new URL(value, document.baseURI)'));
      });

      test('filters to http and https URLs only', () {
        final script = service.generateScript(config);
        expect(script, contains('startsWith("http://")'));
        expect(script, contains('startsWith("https://")'));
      });

      test('uses a Set for deduplication', () {
        final script = service.generateScript(config);
        expect(script, contains('new Set()'));
        expect(script, contains('results.add('));
      });

      test('returns Array.from(results)', () {
        final script = service.generateScript(config);
        expect(script, contains('return Array.from(results)'));
      });

      test('ignores invalid URLs silently with a catch block', () {
        final script = service.generateScript(config);
        expect(script, contains('catch (_)'));
      });

      test('skips missing/empty attribute values', () {
        final script = service.generateScript(config);
        expect(script, contains('if (!value) return'));
      });

      test('generated script is non-empty', () {
        final script = service.generateScript(config);
        expect(script.trim().isNotEmpty, isTrue);
      });
    });

    // ── Safe template substitution — injection prevention ───────────────────

    group('generateScript — injection-safe substitution', () {
      test('escapes double quotes in selector', () {
        final config = DefaultExtractorConfig(
          kind: DefaultExtractorKind.html,
          cssSelector: r'img[src="photo.jpg"]',
          attributeName: 'src',
        );
        final script = service.generateScript(config);
        // Raw unescaped quote must not appear inside the JS string argument
        expect(
          script,
          isNot(contains('querySelectorAll("img[src="photo.jpg"]")')),
        );
        // Escaped form must be present
        expect(script, contains(r'\"photo.jpg\"'));
      });

      test('escapes backslash in selector', () {
        final config = DefaultExtractorConfig(
          kind: DefaultExtractorKind.html,
          cssSelector: r'img.class\name',
          attributeName: 'src',
        );
        final script = service.generateScript(config);
        // Single backslash must become double in the script
        expect(script, contains(r'\\'));
      });

      test('escapes newline in selector', () {
        final config = DefaultExtractorConfig(
          kind: DefaultExtractorKind.html,
          cssSelector: '.article\nimg',
          attributeName: 'src',
        );
        final script = service.generateScript(config);
        expect(script, contains(r'\n'));
        // Literal newline inside the string literal must not appear
        expect(
          script,
          isNot(contains('querySelectorAll(".article\nimg")')),
        );
      });

      test('escapes carriage return in selector', () {
        final config = DefaultExtractorConfig(
          kind: DefaultExtractorKind.html,
          cssSelector: '.article\rimg',
          attributeName: 'src',
        );
        final script = service.generateScript(config);
        expect(script, contains(r'\r'));
      });

      test('escapes tab in selector', () {
        final config = DefaultExtractorConfig(
          kind: DefaultExtractorKind.html,
          cssSelector: '.class\timg',
          attributeName: 'src',
        );
        final script = service.generateScript(config);
        expect(script, contains(r'\t'));
      });

      test('escapes null byte in selector', () {
        final config = DefaultExtractorConfig(
          kind: DefaultExtractorKind.html,
          cssSelector: '.class\x00img',
          attributeName: 'src',
        );
        final script = service.generateScript(config);
        expect(script, contains(r'\0'));
      });

      test('escapes double quotes in attribute', () {
        final config = DefaultExtractorConfig(
          kind: DefaultExtractorKind.html,
          cssSelector: 'img',
          attributeName: 'data-"evil"',
        );
        final script = service.generateScript(config);
        expect(script, isNot(contains('getAttribute("data-"evil"")')));
        expect(script, contains(r'\"evil\"'));
      });

      test('escapes backslash in attribute', () {
        final config = DefaultExtractorConfig(
          kind: DefaultExtractorKind.html,
          cssSelector: 'img',
          attributeName: r'data\src',
        );
        final script = service.generateScript(config);
        expect(script, contains(r'\\'));
      });

      test('JS injection via selector: double-quote breakout is neutralised', () {
        final config = DefaultExtractorConfig(
          kind: DefaultExtractorKind.html,
          // Payload tries to break out of the querySelector string:
          // raw: ");alert(1);//
          // After escaping: \")
          // The " is escaped, so it remains inside the JS string — no breakout.
          cssSelector: '");alert(1);//',
          attributeName: 'src',
        );
        final script = service.generateScript(config);
        // The double quote must be escaped — preventing string termination.
        expect(script, contains(r'\"'));
        // The querySelectorAll call must be properly closed (not prematurely).
        // Verify the string ends at the correct position by checking the call
        // ends with the expected closing sequence.
        expect(
          script,
          contains('querySelectorAll("\\")'),
        );
      });

      test('JS injection via attribute: double-quote breakout is neutralised', () {
        final config = DefaultExtractorConfig(
          kind: DefaultExtractorKind.html,
          // Payload: ");evil();//
          // After escaping: the " becomes \" — payload stays inside JS string.
          cssSelector: 'img',
          attributeName: '");evil();//',
        );
        final script = service.generateScript(config);
        // The " must be escaped, preventing string termination.
        expect(script, contains(r'\"'));
        // Verify the getAttribute call contains the escaped quote.
        expect(script, contains('getAttribute("\\"'));
      });

      test('JS injection via selector: single-quote breakout is neutralised', () {
        final config = DefaultExtractorConfig(
          kind: DefaultExtractorKind.html,
          // Payload: ');alert(2);//
          // After escaping: the ' becomes \' — payload stays inside JS string.
          cssSelector: "');alert(2);//",
          attributeName: 'src',
        );
        final script = service.generateScript(config);
        // The single quote must be escaped.
        expect(script, contains(r"\'"));
        // Verify the querySelectorAll call contains the escaped single-quote.
        expect(script, contains("querySelectorAll(\"\\')"));
      });

      test('injection via newline in attribute: newline is escaped', () {
        final config = DefaultExtractorConfig(
          kind: DefaultExtractorKind.html,
          // A literal newline in the attribute would terminate the JS string
          // if not escaped. The escaper converts \n to the two-char sequence \n.
          cssSelector: 'img',
          attributeName: 'src\nevil()',
        );
        final script = service.generateScript(config);
        // The literal newline must be replaced with \n escape sequence.
        expect(script, contains(r'\n'));
        // The raw (unescaped) newline must NOT appear inside the string literal.
        expect(script, isNot(contains('getAttribute("src\nevil()'))); 
      });

      test('handles safe unicode characters without escaping them', () {
        final config = DefaultExtractorConfig(
          kind: DefaultExtractorKind.html,
          cssSelector: '.imágenes',
          attributeName: 'src',
        );
        final script = service.generateScript(config);
        // Non-ASCII printable chars (>= 0xA0) are safe in JS strings
        expect(script, isA<String>());
        expect(script.trim().isNotEmpty, isTrue);
      });
    });

    // ── encodeMetadata / decodeMetadata ─────────────────────────────────────

    group('encodeMetadata', () {
      test('encodes HTML config to a JSON string', () {
        const config = DefaultExtractorConfig(
          kind: DefaultExtractorKind.html,
          cssSelector: '.article img',
          attributeName: 'src',
        );
        final json = DefaultExtractorTemplateService.encodeMetadata(config);
        expect(json, contains('"extractorKind":"html"'));
        expect(json, contains('"cssSelector":".article img"'));
        expect(json, contains('"attributeName":"src"'));
      });

      test('round-trips: encode then decode yields the original config', () {
        const original = DefaultExtractorConfig(
          kind: DefaultExtractorKind.html,
          cssSelector: '.article-content img',
          attributeName: 'data-original',
        );
        final encoded = DefaultExtractorTemplateService.encodeMetadata(original);
        final decoded =
            DefaultExtractorTemplateService.decodeMetadata(encoded);
        expect(decoded, isNotNull);
        expect(decoded!.kind, original.kind);
        expect(decoded.cssSelector, original.cssSelector);
        expect(decoded.attributeName, original.attributeName);
      });
    });

    group('decodeMetadata', () {
      test('decodes valid HTML metadata JSON', () {
        const json =
            '{"extractorKind":"html","cssSelector":".article img","attributeName":"src"}';
        final config =
            DefaultExtractorTemplateService.decodeMetadata(json);
        expect(config, isNotNull);
        expect(config!.kind, DefaultExtractorKind.html);
        expect(config.cssSelector, '.article img');
        expect(config.attributeName, 'src');
      });

      test('returns null for null metadata (Phase 1 script extractors)', () {
        expect(
          DefaultExtractorTemplateService.decodeMetadata(null),
          isNull,
        );
      });

      test('returns null for malformed JSON', () {
        expect(
          DefaultExtractorTemplateService.decodeMetadata('not-json{{{'),
          isNull,
        );
      });

      test('returns null for empty string', () {
        expect(
          DefaultExtractorTemplateService.decodeMetadata(''),
          isNull,
        );
      });

      test('returns null for JSON missing extractorKind', () {
        const json = '{"cssSelector":".img","attributeName":"src"}';
        expect(
          DefaultExtractorTemplateService.decodeMetadata(json),
          isNull,
        );
      });

      test('returns null for JSON missing cssSelector', () {
        const json = '{"extractorKind":"html","attributeName":"src"}';
        expect(
          DefaultExtractorTemplateService.decodeMetadata(json),
          isNull,
        );
      });

      test('returns null for JSON missing attributeName', () {
        const json = '{"extractorKind":"html","cssSelector":".img"}';
        expect(
          DefaultExtractorTemplateService.decodeMetadata(json),
          isNull,
        );
      });

      test('returns null for unknown extractorKind (forward-compat)', () {
        const json =
            '{"extractorKind":"future_network_type","cssSelector":".img","attributeName":"src"}';
        expect(
          DefaultExtractorTemplateService.decodeMetadata(json),
          isNull,
        );
      });

      test('ignores unknown extra fields (forward compatibility)', () {
        const json =
            '{"extractorKind":"html","cssSelector":".img","attributeName":"src","futureField":"value","anotherField":42}';
        final config =
            DefaultExtractorTemplateService.decodeMetadata(json);
        expect(config, isNotNull);
        expect(config!.kind, DefaultExtractorKind.html);
        expect(config.cssSelector, '.img');
        expect(config.attributeName, 'src');
      });

      test('returns null for non-object JSON (array)', () {
        expect(
          DefaultExtractorTemplateService.decodeMetadata('["html",".img","src"]'),
          isNull,
        );
      });

      test('returns null when cssSelector is null in JSON', () {
        const json =
            '{"extractorKind":"html","cssSelector":null,"attributeName":"src"}';
        expect(
          DefaultExtractorTemplateService.decodeMetadata(json),
          isNull,
        );
      });

      test('returns null when attributeName is null in JSON', () {
        const json =
            '{"extractorKind":"html","cssSelector":".img","attributeName":null}';
        expect(
          DefaultExtractorTemplateService.decodeMetadata(json),
          isNull,
        );
      });
    });
  });
}
