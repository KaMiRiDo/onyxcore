import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/document_viewer/presentation/widgets/markdown_syntax_highlighter.dart';

void main() {
  group('MarkdownSyntaxHighlighter', () {
    late BuildContext mockContext;
    late TextStyle baseStyle;

    setUp(() {
      baseStyle = const TextStyle(color: Colors.white, fontSize: 14);
    });

    Widget buildTestContext(Widget child) {
      return MaterialApp(
        home: Scaffold(body: child),
      );
    }

    testWidgets('U-DOC-SYNTAX-01: Highlights Markdown Headers (#)', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestContext(Container()));
      final context = tester.element(find.byType(Container));

      final controller = MarkdownSyntaxHighlighter(text: '# Heading 1');
      final span = controller.buildTextSpan(
        context: context,
        style: baseStyle,
        withComposing: false,
      );

      expect(span.children, isNotNull);
      expect(span.children!.length, 1);
      final firstSpan = span.children![0] as TextSpan;
      expect(firstSpan.text, '# Heading 1');
      expect(firstSpan.style?.color, const Color(0xFFFF7043));
      expect(firstSpan.style?.fontWeight, FontWeight.bold);
    });

    testWidgets('U-DOC-SYNTAX-02: Highlights Bold (**) and Italic (_)', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestContext(Container()));
      final context = tester.element(find.byType(Container));

      final controller = MarkdownSyntaxHighlighter(text: 'text **bold** and _italic_');
      final span = controller.buildTextSpan(
        context: context,
        style: baseStyle,
        withComposing: false,
      );

      expect(span.children?.length, 4);
      final boldSpan = span.children![1] as TextSpan;
      expect(boldSpan.text, '**bold**');
      expect(boldSpan.style?.fontWeight, FontWeight.bold);

      final italicSpan = span.children![3] as TextSpan;
      expect(italicSpan.text, '_italic_');
      expect(italicSpan.style?.fontStyle, FontStyle.italic);
    });

    testWidgets('U-DOC-SYNTAX-03: Highlights Markdown Links', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestContext(Container()));
      final context = tester.element(find.byType(Container));

      final controller = MarkdownSyntaxHighlighter(text: '[Google](https://google.com)');
      final span = controller.buildTextSpan(
        context: context,
        style: baseStyle,
        withComposing: false,
      );

      final linkSpan = span.children![0] as TextSpan;
      expect(linkSpan.text, '[Google](https://google.com)');
      expect(linkSpan.style?.color, const Color(0xFF4FC3F7));
      expect(linkSpan.style?.decoration, TextDecoration.underline);
    });

    testWidgets('U-DOC-SYNTAX-04: Highlights Fenced Code Blocks and Inline Code', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestContext(Container()));
      final context = tester.element(find.byType(Container));

      final controller = MarkdownSyntaxHighlighter(text: 'use `print()` \n```dart\nmain()\n```');
      final span = controller.buildTextSpan(
        context: context,
        style: baseStyle,
        withComposing: false,
      );

      final inlineSpan = span.children!.firstWhere((s) => (s as TextSpan).text == '`print()`') as TextSpan;
      expect(inlineSpan.style?.color, const Color(0xFFCE93D8));

      final blockSpan = span.children!.firstWhere((s) => (s as TextSpan).text!.contains('```dart')) as TextSpan;
      expect(blockSpan.style?.color, const Color(0xFFCE93D8));
    });

    testWidgets('U-DOC-SYNTAX-05: Highlights Blockquotes, Lists, and Math blocks', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestContext(Container()));
      final context = tester.element(find.byType(Container));

      final controller = MarkdownSyntaxHighlighter(text: '> quote\n- list\n\$\$ math \$\$');
      final span = controller.buildTextSpan(
        context: context,
        style: baseStyle,
        withComposing: false,
      );

      final quoteSpan = span.children!.firstWhere((s) => (s as TextSpan).text!.contains('> quote')) as TextSpan;
      expect(quoteSpan.style?.color, const Color(0xFFA5D6A7)); // Blockquote color

      final listSpan = span.children!.firstWhere((s) => (s as TextSpan).text!.contains('- ')) as TextSpan;
      expect(listSpan.style?.color, const Color(0xFFFFCA28)); // List color

      final mathSpan = span.children!.firstWhere((s) => (s as TextSpan).text!.contains('\$\$ math \$\$')) as TextSpan;
      expect(mathSpan.style?.color, const Color(0xFF80CBC4)); // Math color
    });

    testWidgets('U-DOC-SYNTAX-06: Handles plain text gracefully', (WidgetTester tester) async {
      await tester.pumpWidget(buildTestContext(Container()));
      final context = tester.element(find.byType(Container));

      final controller = MarkdownSyntaxHighlighter(text: 'Just some plain text.');
      final span = controller.buildTextSpan(
        context: context,
        style: baseStyle,
        withComposing: false,
      );

      expect(span.children?.length, 1);
      final firstSpan = span.children![0] as TextSpan;
      expect(firstSpan.text, 'Just some plain text.');
      expect(firstSpan.style, baseStyle);
    });
  });
}
