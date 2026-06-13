class HtmlSearchHighlighter {
  static String highlightMatches(
    String htmlContent,
    String query, {
    bool caseSensitive = false,
    bool useRegex = false,
    int currentMatchIndex = -1,
  }) {
    if (query.isEmpty) return htmlContent;

    RegExp searchExp;
    try {
      if (useRegex) {
        searchExp = RegExp(query, caseSensitive: caseSensitive);
      } else {
        searchExp = RegExp(RegExp.escape(query), caseSensitive: caseSensitive);
      }
    } catch (e) {
      // Invalid regex
      return htmlContent;
    }

    // We only want to highlight text nodes, not HTML tags or attributes.
    // A simple approach is to split the string by tags, process the text chunks, and reassemble.
    final tagRegex = RegExp(r'(<[^>]+>)');
    final parts = htmlContent.split(tagRegex);
    final tags = tagRegex.allMatches(htmlContent).map((m) => m.group(1)!).toList();

    final buffer = StringBuffer();
    int globalMatchCounter = 0;
    
    for (int i = 0; i < parts.length; i++) {
      String textPart = parts[i];
      if (textPart.isNotEmpty) {
        // Highlight matches inside textPart
        int lastMatchEnd = 0;
        for (final match in searchExp.allMatches(textPart)) {
          if (match.start > lastMatchEnd) {
            buffer.write(textPart.substring(lastMatchEnd, match.start));
          }
          final matchedText = match.group(0)!;
          
          final bool isCurrentMatch = globalMatchCounter == currentMatchIndex;
          final backgroundColor = isCurrentMatch ? '#808A3FFC' : '#80E845C9';
          final textColor = '#FFFFFF';
          
          // Use span tag with custom styling because flutter_html supports inline styles on spans better
          buffer.write('<span style="background-color: $backgroundColor; color: $textColor;">$matchedText</span>');
          
          lastMatchEnd = match.end;
          globalMatchCounter++;
        }
        if (lastMatchEnd < textPart.length) {
          buffer.write(textPart.substring(lastMatchEnd));
        }
      }

      if (i < tags.length) {
        buffer.write(tags[i]);
      }
    }

    return buffer.toString();
  }
}
