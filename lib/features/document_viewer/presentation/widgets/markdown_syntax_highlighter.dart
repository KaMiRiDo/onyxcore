import 'package:flutter/material.dart';

class MarkdownSyntaxHighlighter extends TextEditingController {

  MarkdownSyntaxHighlighter({
    super.text,
    this.searchQuery = '',
    this.caseSensitive = false,
    this.useRegex = false,
    this.currentMatchIndex = -1,
  });
  String searchQuery;
  bool caseSensitive;
  bool useRegex;
  int currentMatchIndex;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    required bool withComposing, TextStyle? style,
  }) {
    final children = <TextSpan>[];
    final source = text;

    // Updated Regex for cleaner Markdown styling and HTML tags
    final exp = RegExp(
      r'(```[\s\S]*?```)|' // 1: Fenced Code Blocks
      r'(^---+$)|' // 2: Dividers / Frontmatter
      r'(^(#{1,6})\s.*$)|' // 3 & 4: Headings
      r'(\*\*.*?\*\*)|' // 5: Bold
      r'(\*.*?\*|_.*?_)|' // 6: Italic
      '(`.*?`)|' // 7: Inline Code
      r'(\[.*?\])(\(.*?\))|' // 8 & 9: Link Text, Link URL
      r'(^\s*>.*$)|' // 10: Blockquotes
      r'(<)(\/?[a-zA-Z0-9\-]+)([^>]*?)(\/?>)', // 11, 12, 13, 14: HTML Tags
      multiLine: true,
    );

    var lastMatchEnd = 0;

    for (final Match match in exp.allMatches(source)) {
      if (match.start > lastMatchEnd) {
        children.add(
          TextSpan(
            text: source.substring(lastMatchEnd, match.start),
            style: style,
          ),
        );
      }

      if (match.group(1) != null) {
        // Fenced Code Block
        children.add(
          TextSpan(
            text: match.group(1),
            style: style?.copyWith(color: const Color(0xFFCE93D8)),
          ),
        );
      } else if (match.group(2) != null) {
        // Dividers / Frontmatter
        children.add(
          TextSpan(
            text: match.group(2),
            style: style?.copyWith(color: const Color(0xFFA6E22E)),
          ),
        );
      } else if (match.group(3) != null) {
        // Headings (Bright Lime Green, uniform size is handled by not changing fontSize)
        children.add(
          TextSpan(
            text: match.group(3),
            style: style?.copyWith(
              color: const Color(0xFFA6E22E),
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      } else if (match.group(5) != null) {
        // Bold (Standard color, bold weight)
        children.add(
          TextSpan(
            text: match.group(5),
            style: style?.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else if (match.group(6) != null) {
        // Italic (Standard color, italic style)
        children.add(
          TextSpan(
            text: match.group(6),
            style: style?.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (match.group(7) != null) {
        // Inline Code
        children.add(
          TextSpan(
            text: match.group(7),
            style: style?.copyWith(color: const Color(0xFFCE93D8)),
          ),
        );
      } else if (match.group(8) != null && match.group(9) != null) {
        // Link: Text is standard color, URL is muted, italicized, underlined
        children.add(TextSpan(text: match.group(8), style: style));
        children.add(
          TextSpan(
            text: match.group(9),
            style: style?.copyWith(
              color:
                  style.color?.withValues(alpha: 0.6) ??
                  const Color(0xFFABB2BF).withValues(alpha: 0.6),
              fontStyle: FontStyle.italic,
              decoration: TextDecoration.underline,
            ),
          ),
        );
      } else if (match.group(10) != null) {
        // Blockquotes (Bright Lime Green)
        children.add(
          TextSpan(
            text: match.group(10),
            style: style?.copyWith(color: const Color(0xFFA6E22E)),
          ),
        );
      } else if (match.group(11) != null) {
        // HTML Tags
        final blueStyle = style?.copyWith(color: const Color(0xFF64B5F6));
        final yellowStyle = style?.copyWith(color: const Color(0xFFFFCA28));
        final greenStyle = style?.copyWith(color: const Color(0xFFA5D6A7));

        children.add(TextSpan(text: match.group(11), style: blueStyle)); // <
        children.add(
          TextSpan(text: match.group(12), style: blueStyle),
        ); // tag name

        final attributesString = match.group(13);
        if (attributesString != null && attributesString.isNotEmpty) {
          final attrRegex = RegExp(
            r'''(\s+)([a-zA-Z0-9\-]+)(?:(=)(".*?"|'.*?'|[^\s>]+))?''',
          );
          var lastAttrEnd = 0;
          for (final attrMatch in attrRegex.allMatches(attributesString)) {
            if (attrMatch.start > lastAttrEnd) {
              children.add(
                TextSpan(
                  text: attributesString.substring(
                    lastAttrEnd,
                    attrMatch.start,
                  ),
                  style: style,
                ),
              );
            }
            children.add(
              TextSpan(text: attrMatch.group(1), style: style),
            ); // whitespace
            children.add(
              TextSpan(text: attrMatch.group(2), style: yellowStyle),
            ); // attribute name
            if (attrMatch.group(3) != null) {
              children.add(
                TextSpan(text: attrMatch.group(3), style: style),
              ); // =
              children.add(
                TextSpan(text: attrMatch.group(4), style: greenStyle),
              ); // attribute value
            }
            lastAttrEnd = attrMatch.end;
          }
          if (lastAttrEnd < attributesString.length) {
            children.add(
              TextSpan(
                text: attributesString.substring(lastAttrEnd),
                style: style,
              ),
            );
          }
        }

        children.add(
          TextSpan(text: match.group(14), style: blueStyle),
        ); // > or />
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < source.length) {
      children.add(
        TextSpan(text: source.substring(lastMatchEnd), style: style),
      );
    }

    if (searchQuery.isEmpty) {
      return TextSpan(style: style, children: children);
    }

    return TextSpan(
      style: style,
      children: _applySearchHighlighting(children, style),
    );
  }

  List<TextSpan> _applySearchHighlighting(
    List<TextSpan> originalChildren,
    TextStyle? baseStyle,
  ) {
    RegExp searchExp;
    try {
      if (useRegex) {
        searchExp = RegExp(searchQuery, caseSensitive: caseSensitive);
      } else {
        searchExp = RegExp(
          RegExp.escape(searchQuery),
          caseSensitive: caseSensitive,
        );
      }
    } catch (e) {
      // Invalid regex, return original
      return originalChildren;
    }

    final highlightedChildren = <TextSpan>[];
    var globalMatchCounter = 0;

    for (final span in originalChildren) {
      final text = span.text;
      if (text == null || text.isEmpty) {
        highlightedChildren.add(span);
        continue;
      }

      var lastMatchEnd = 0;
      for (final match in searchExp.allMatches(text)) {
        if (match.start > lastMatchEnd) {
          highlightedChildren.add(
            TextSpan(
              text: text.substring(lastMatchEnd, match.start),
              style: span.style,
            ),
          );
        }

        final isCurrentMatch = globalMatchCounter == currentMatchIndex;

        highlightedChildren.add(
          TextSpan(
            text: match.group(0),
            style: (span.style ?? baseStyle ?? const TextStyle()).copyWith(
              backgroundColor: isCurrentMatch
                  ? const Color(0x808A3FFC)
                  : const Color(0x80E845C9),
              color: const Color(0xFFFFFFFF),
              fontWeight: FontWeight.bold,
            ),
          ),
        );

        lastMatchEnd = match.end;
        globalMatchCounter++;
      }

      if (lastMatchEnd < text.length) {
        highlightedChildren.add(
          TextSpan(text: text.substring(lastMatchEnd), style: span.style),
        );
      }
    }

    return highlightedChildren;
  }
}
