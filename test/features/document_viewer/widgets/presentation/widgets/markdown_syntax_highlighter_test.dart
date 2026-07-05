import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/document_viewer/presentation/widgets/markdown_syntax_highlighter.dart';

void main() {
  group('MarkdownSyntaxHighlighter Tests', () {
    Future<BuildContext> getContext(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: Container())));
      return tester.element(find.byType(Container));
    }

    testWidgets('W-DOC-SYNTAX-1: Highlights headings correctly', (WidgetTester tester) async {
      final context = await getContext(tester);
      final highlighter = MarkdownSyntaxHighlighter();
      highlighter.text = '# Heading 1\n## Heading 2';
      
      final textSpan = highlighter.buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: false,
      );
      
      // Expected to find color 0xFFA6E22E for headings
      final children = textSpan.children!;
      expect(children.length, greaterThan(1));
      
      // Find the span for '# Heading 1'
      final h1Span = children.where((span) => span is TextSpan && span.text == '# Heading 1').first as TextSpan;
      expect(h1Span.style?.color, const Color(0xFFA6E22E));
      expect(h1Span.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('W-DOC-SYNTAX-2: Highlights bold and italic correctly', (WidgetTester tester) async {
      final context = await getContext(tester);
      final highlighter = MarkdownSyntaxHighlighter();
      highlighter.text = 'This is **bold** and *italic*.';
      
      final textSpan = highlighter.buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: false,
      );
      
      final children = textSpan.children!;
      
      final boldSpan = children.where((span) => span is TextSpan && span.text == '**bold**').first as TextSpan;
      expect(boldSpan.style?.fontWeight, FontWeight.bold);
      
      final italicSpan = children.where((span) => span is TextSpan && span.text == '*italic*').first as TextSpan;
      expect(italicSpan.style?.fontStyle, FontStyle.italic);
    });

    testWidgets('W-DOC-SYNTAX-3: Highlights fenced code blocks', (WidgetTester tester) async {
      final context = await getContext(tester);
      final highlighter = MarkdownSyntaxHighlighter();
      highlighter.text = '```\ncode block\n```';
      
      final textSpan = highlighter.buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: false,
      );
      
      final children = textSpan.children!;
      final codeSpan = children.where((span) => span is TextSpan && (span.text?.contains('code block') ?? false)).first as TextSpan;
      expect(codeSpan.style?.color, const Color(0xFFCE93D8));
    });

    testWidgets('W-DOC-SYNTAX-4: Highlights inline code', (WidgetTester tester) async {
      final context = await getContext(tester);
      final highlighter = MarkdownSyntaxHighlighter();
      highlighter.text = 'Use the `print` statement.';
      
      final textSpan = highlighter.buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: false,
      );
      
      final children = textSpan.children!;
      final inlineCodeSpan = children.where((span) => span is TextSpan && span.text == '`print`').first as TextSpan;
      expect(inlineCodeSpan.style?.color, const Color(0xFFCE93D8));
    });

    testWidgets('W-DOC-SYNTAX-5: Highlights blockquotes', (WidgetTester tester) async {
      final context = await getContext(tester);
      final highlighter = MarkdownSyntaxHighlighter();
      highlighter.text = '> This is a quote';
      
      final textSpan = highlighter.buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: false,
      );
      
      final children = textSpan.children!;
      final quoteSpan = children.where((span) => span is TextSpan && span.text == '> This is a quote').first as TextSpan;
      expect(quoteSpan.style?.color, const Color(0xFFA6E22E));
    });

    testWidgets('W-DOC-SYNTAX-6: Highlights links', (WidgetTester tester) async {
      final context = await getContext(tester);
      final highlighter = MarkdownSyntaxHighlighter();
      highlighter.text = '[Link Text](https://example.com)';
      
      final textSpan = highlighter.buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: false,
      );
      
      final children = textSpan.children!;
      final linkTextSpan = children.where((span) => span is TextSpan && span.text == '[Link Text]').first as TextSpan;
      final linkUrlSpan = children.where((span) => span is TextSpan && span.text == '(https://example.com)').first as TextSpan;
      
      expect(linkTextSpan.style?.color, isNull); // Falls back to default text style
      expect(linkUrlSpan.style?.decoration, TextDecoration.underline);
      expect(linkUrlSpan.style?.fontStyle, FontStyle.italic);
    });

    testWidgets('W-DOC-SYNTAX-7: Highlights HTML tags', (WidgetTester tester) async {
      final context = await getContext(tester);
      final highlighter = MarkdownSyntaxHighlighter();
      highlighter.text = '<div class="test">content</div>';
      
      final textSpan = highlighter.buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: false,
      );
      
      final children = textSpan.children!;
      
      // Look for the tag name 'div'
      final divSpan = children.where((span) => span is TextSpan && span.text == 'div').first as TextSpan;
      expect(divSpan.style?.color, const Color(0xFF64B5F6));
      
      // Look for the attribute name 'class'
      final classSpan = children.where((span) => span is TextSpan && span.text == 'class').first as TextSpan;
      expect(classSpan.style?.color, const Color(0xFFFFCA28));
      
      // Look for the attribute value '"test"'
      final valSpan = children.where((span) => span is TextSpan && span.text == '"test"').first as TextSpan;
      expect(valSpan.style?.color, const Color(0xFFA5D6A7));
    });

    testWidgets('W-DOC-SYNTAX-8: Highlights search query matches', (WidgetTester tester) async {
      final context = await getContext(tester);
      final highlighter = MarkdownSyntaxHighlighter(
        text: 'This is a test document with test data.',
        searchQuery: 'test',
        currentMatchIndex: 0,
      );
      
      final textSpan = highlighter.buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: false,
      );
      
      final children = textSpan.children!;
      
      // Should split the text around 'test'
      final testSpans = children.where((span) => span is TextSpan && span.text == 'test').cast<TextSpan>().toList();
      expect(testSpans.length, 2);
      
      // First match should be highlighted as current (Light Violet)
      expect(testSpans[0].style?.backgroundColor, const Color(0x808A3FFC));
      expect(testSpans[0].style?.color, const Color(0xFFFFFFFF));
      expect(testSpans[0].style?.fontWeight, FontWeight.bold);

      // Second match should be highlighted as normal (Pink)
      expect(testSpans[1].style?.backgroundColor, const Color(0x80E845C9));
      expect(testSpans[1].style?.color, const Color(0xFFFFFFFF));
      expect(testSpans[1].style?.fontWeight, FontWeight.bold);
    });

    testWidgets('W-DOC-SYNTAX-9: Handles regex search', (WidgetTester tester) async {
      final context = await getContext(tester);
      final highlighter = MarkdownSyntaxHighlighter(
        text: 'Error 404 and Error 500',
        searchQuery: r'\b\d{3}\b', // match 3 digits
        useRegex: true,
      );
      
      final textSpan = highlighter.buildTextSpan(
        context: context,
        style: const TextStyle(),
        withComposing: false,
      );
      
      final children = textSpan.children!;
      final matchSpans = children.where((span) => span is TextSpan && (span.text == '404' || span.text == '500')).cast<TextSpan>().toList();
      expect(matchSpans.length, 2);
      expect(matchSpans[0].style?.backgroundColor, const Color(0x80E845C9));
    });
  });
}
