import 'dart:convert';

import 'package:flutter/foundation.dart';

// ── Kind enum ────────────────────────────────────────────────────────────────

/// Identifies the kind of default extractor.
///
/// Extensible: future extractor types (e.g. network) are added here without
/// rewriting the dialog or runtime.
enum DefaultExtractorKind {
  html,
  // Future: network, etc.
}

// ── Config ───────────────────────────────────────────────────────────────────

/// Immutable configuration for a default extractor.
@immutable
class DefaultExtractorConfig {
  const DefaultExtractorConfig({
    required this.kind,
    required this.cssSelector,
    required this.attributeName,
  });

  final DefaultExtractorKind kind;
  final String cssSelector;
  final String attributeName;
}

// ── Service ──────────────────────────────────────────────────────────────────

/// Generates JavaScript extractor scripts from predefined templates.
///
/// Template logic is isolated from all UI code. The selector and attribute
/// values are fully JS-string-escaped before injection into any template,
/// preventing arbitrary code injection regardless of the input content.
///
/// Only pure Dart — no Flutter, no Riverpod. Fully testable standalone.
class DefaultExtractorTemplateService {
  const DefaultExtractorTemplateService();

  /// Generates a JavaScript extractor script for the given [config].
  String generateScript(DefaultExtractorConfig config) {
    switch (config.kind) {
      case DefaultExtractorKind.html:
        return _generateHtmlExtractorScript(
          config.cssSelector,
          config.attributeName,
        );
    }
  }

  // ── Metadata codec ────────────────────────────────────────────────────────

  /// Encodes a [DefaultExtractorConfig] to a JSON metadata string for
  /// persistence in the [CustomExtractor.metadata] field.
  static String encodeMetadata(DefaultExtractorConfig config) {
    return jsonEncode(<String, dynamic>{
      'extractorKind': config.kind.name,
      'cssSelector': config.cssSelector,
      'attributeName': config.attributeName,
    });
  }

  /// Decodes a [CustomExtractor.metadata] JSON string into a
  /// [DefaultExtractorConfig].
  ///
  /// Returns null when:
  /// - [metadata] is null (Phase 1 script extractors — not an error)
  /// - [metadata] is malformed JSON
  /// - [metadata] is missing required fields
  /// - [metadata] references an unknown extractorKind (forward-compat)
  ///
  /// Callers must treat a null return as "this is a script extractor" and
  /// must not crash or show an error to the user.
  static DefaultExtractorConfig? decodeMetadata(String? metadata) {
    if (metadata == null || metadata.isEmpty) return null;
    try {
      final dynamic raw = jsonDecode(metadata);
      if (raw is! Map<String, dynamic>) return null;

      final kindStr = raw['extractorKind'] as String?;
      if (kindStr == null) return null;

      // Safe lookup — unknown kinds return null (forward compat)
      final kind = DefaultExtractorKind.values
          .where((k) => k.name == kindStr)
          .firstOrNull;
      if (kind == null) return null;

      final cssSelector = raw['cssSelector'] as String?;
      final attributeName = raw['attributeName'] as String?;
      if (cssSelector == null || attributeName == null) return null;

      return DefaultExtractorConfig(
        kind: kind,
        cssSelector: cssSelector,
        attributeName: attributeName,
      );
    } catch (_) {
      // Malformed JSON or unexpected structure — degrade gracefully.
      return null;
    }
  }

  // ── HTML Extractor template ───────────────────────────────────────────────

  String _generateHtmlExtractorScript(
    String cssSelector,
    String attributeName,
  ) {
    final escapedSelector = _escapeJsString(cssSelector);
    final escapedAttribute = _escapeJsString(attributeName);

    return '''async function extract(url) {
  const results = new Set();

  document
    .querySelectorAll("$escapedSelector")
    .forEach((element) => {
      const value = element.getAttribute("$escapedAttribute");

      if (!value) return;

      try {
        const absoluteUrl = new URL(value, document.baseURI).href;

        if (
          absoluteUrl.startsWith("http://") ||
          absoluteUrl.startsWith("https://")
        ) {
          results.add(absoluteUrl);
        }
      } catch (_) {
        // Ignore invalid URLs.
      }
    });

  return Array.from(results);
}
''';
  }

  // ── Safe JS string escaping ───────────────────────────────────────────────

  /// Escapes a string value for safe use inside a JavaScript double-quoted
  /// string literal.
  ///
  /// All characters that could terminate or escape out of the JS string are
  /// replaced with their `\xXX` or `\uXXXX` escape sequences. This prevents
  /// any user-supplied selector or attribute value from injecting arbitrary
  /// JavaScript into the generated extractor script.
  static String _escapeJsString(String value) {
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      switch (rune) {
        case 0x5C: // backslash \
          buffer.write(r'\\');
        case 0x22: // double quote "
          buffer.write(r'\"');
        case 0x27: // single quote ' (defensive)
          buffer.write(r"\'");
        case 0x0A: // newline \n
          buffer.write(r'\n');
        case 0x0D: // carriage return \r
          buffer.write(r'\r');
        case 0x09: // tab \t
          buffer.write(r'\t');
        case 0x0C: // form feed \f
          buffer.write(r'\f');
        case 0x0B: // vertical tab \v
          buffer.write(r'\v');
        case 0x00: // null byte \0
          buffer.write(r'\0');
        default:
          if (rune < 0x20 || (rune >= 0x7F && rune <= 0x9F)) {
            // Control characters → \uXXXX
            buffer
                .write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
          } else if (rune > 0xFFFF) {
            // Supplementary plane → surrogate pair
            final hi = 0xD800 + ((rune - 0x10000) >> 10);
            final lo = 0xDC00 + ((rune - 0x10000) & 0x3FF);
            buffer
              ..write('\\u${hi.toRadixString(16).padLeft(4, '0')}')
              ..write('\\u${lo.toRadixString(16).padLeft(4, '0')}');
          } else {
            buffer.writeCharCode(rune);
          }
      }
    }
    return buffer.toString();
  }
}
