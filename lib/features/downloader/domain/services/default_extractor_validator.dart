/// Validation logic for default extractor fields.
///
/// Pure Dart — no Flutter, no Riverpod. Fully testable standalone.
class DefaultExtractorValidator {
  const DefaultExtractorValidator._();

  static const int _maxNameLength = 255;

  // ── Extractor Name ────────────────────────────────────────────────────────

  /// Validates an extractor name.
  ///
  /// Returns an error message string, or null if the name is valid.
  static String? validateExtractorName(String name) {
    if (name.isEmpty) return 'Extractor name cannot be empty.';
    if (name.trim().isEmpty) return 'Extractor name cannot be only whitespace.';
    if (name.length > _maxNameLength) {
      return 'Extractor name cannot exceed $_maxNameLength characters.';
    }
    return null;
  }

  // ── CSS Selector ──────────────────────────────────────────────────────────

  /// Validates a CSS selector using a heuristic approach.
  ///
  /// Rejects empty/whitespace input, null bytes, block-rule characters, and
  /// unbalanced brackets/parentheses.
  ///
  /// Safety note: even if a malicious selector passes this validator, the
  /// [DefaultExtractorTemplateService] applies full JS-string escaping before
  /// the selector is injected into any generated script, so injection cannot
  /// succeed.
  static String? validateCssSelector(String selector) {
    final trimmed = selector.trim();
    if (trimmed.isEmpty) return 'CSS selector cannot be empty.';

    if (selector.contains('\x00')) {
      return 'CSS selector contains invalid characters.';
    }

    if (selector.contains('{') || selector.contains('}')) {
      return 'CSS selector cannot contain block characters { }.';
    }

    // Balanced square brackets [ ]
    var depth = 0;
    for (final rune in trimmed.runes) {
      if (rune == 0x5B) {
        // [
        depth++;
      } else if (rune == 0x5D) {
        // ]
        depth--;
        if (depth < 0) return 'CSS selector has unbalanced brackets.';
      }
    }
    if (depth != 0) return 'CSS selector has unbalanced brackets.';

    // Balanced parentheses ( )
    depth = 0;
    for (final rune in trimmed.runes) {
      if (rune == 0x28) {
        // (
        depth++;
      } else if (rune == 0x29) {
        // )
        depth--;
        if (depth < 0) return 'CSS selector has unbalanced parentheses.';
      }
    }
    if (depth != 0) return 'CSS selector has unbalanced parentheses.';

    return null;
  }

  // ── Attribute Name ────────────────────────────────────────────────────────

  /// Validates an HTML attribute name.
  ///
  /// Per the HTML spec, attribute names must not contain:
  /// - whitespace characters (space, tab, newline, carriage-return, form-feed)
  /// - null bytes
  /// - `"`, `'`, `>`, `/`, `=`
  /// - control characters (U+0001–U+001F)
  static String? validateAttributeName(String attr) {
    if (attr.isEmpty) return 'Attribute name cannot be empty.';
    if (attr.trim().isEmpty || attr != attr.trim()) {
      return 'Attribute name cannot have leading or trailing whitespace.';
    }

    // Check for internal whitespace
    for (final rune in attr.runes) {
      if (rune == 0x20 ||
          rune == 0x09 ||
          rune == 0x0A ||
          rune == 0x0D ||
          rune == 0x0C) {
        return 'Attribute name cannot contain whitespace.';
      }
    }

    // Check for characters forbidden by the HTML spec
    const invalidChars = ['"', "'", '>', '/', '=', '\x00'];
    for (final c in invalidChars) {
      if (attr.contains(c)) {
        return 'Attribute name contains invalid characters.';
      }
    }

    // Check for control characters U+0001–U+001F
    for (final rune in attr.runes) {
      if (rune >= 0x01 && rune <= 0x1F) {
        return 'Attribute name contains invalid control characters.';
      }
    }

    return null;
  }
}
