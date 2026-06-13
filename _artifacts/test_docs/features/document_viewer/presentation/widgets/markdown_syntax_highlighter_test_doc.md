# MarkdownSyntaxHighlighter Test Design Document

**Target File:** `lib/features/document_viewer/presentation/widgets/markdown_syntax_highlighter.dart`
**Layer:** Presentation / Widgets (Logic)

This document covers the formatting logic of the custom `MarkdownSyntaxHighlighter` responsible for parsing plaintext markdown and returning a styled `TextSpan` tree for the editor.

## 1. Unit Test Plan Format

| Test ID | File(s) Under Test | Target Method / Block | Scenario (It should...) | Setup & Mocks (Given) | Action (When) | Assertions (Then) |
|---|---|---|---|---|---|---|
| U-DOC-SYNTAX-01 | `markdown_syntax_highlighter.dart` | `.format()` | Highlight Markdown Headers (`#`) | Given `# Heading 1` and `## Heading 2` | Call `format()` | Returns TextSpans with correct header colors and bold font weights. |
| U-DOC-SYNTAX-02 | `markdown_syntax_highlighter.dart` | `.format()` | Highlight Bold (`**`, `__`) and Italic (`*`, `_`) | Given strings with bold and italic wrappers | Call `format()` | Returns TextSpans with `FontStyle.italic` and `FontWeight.bold` respectively. |
| U-DOC-SYNTAX-03 | `markdown_syntax_highlighter.dart` | `.format()` | Highlight Markdown Links | Given `[Link Text](https://url)` | Call `format()` | Returns TextSpans identifying the bracketed text and URL with distinct colors. |
| U-DOC-SYNTAX-04 | `markdown_syntax_highlighter.dart` | `.format()` | Highlight Fenced Code Blocks | Given ` ```dart\ncode\n``` ` | Call `format()` | Returns TextSpans matching the block regex, applying `JetBrains Mono` and code color. |
| U-DOC-SYNTAX-05 | `markdown_syntax_highlighter.dart` | `.format()` | Highlight Blockquotes, Lists, and Math | Given `> quote`, `- list`, and `$$ math $$` | Call `format()` | Returns correctly colorized TextSpans for each respective pattern type. |
| U-DOC-SYNTAX-06 | `markdown_syntax_highlighter.dart` | `.format()` | Handle plain text gracefully | Given plain text without markdown symbols | Call `format()` | Returns a single TextSpan with the default style. |
