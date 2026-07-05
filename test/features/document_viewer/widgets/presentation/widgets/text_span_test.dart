import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/document_viewer/presentation/widgets/markdown_syntax_highlighter.dart';

void main() {
  testWidgets('buildTextSpan preserves all characters exactly', (WidgetTester tester) async {
    final highlighter = MarkdownSyntaxHighlighter();
    
    const text = '''
---
title: Welcome to Markdown Viewer
---

# Welcome to Markdown Viewer

## ✨ Key Features
- **Live Preview** with GitHub styling is good as good as that.
- **Emoji Support** 😄 👍 🎉

## 💻 Code with Syntax Highlightingsaa
```javascript
function renderMarkdown() {
  // Test
}
```
''';
    highlighter.text = text;
    
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (context) {
      final span = highlighter.buildTextSpan(
        context: context, 
        style: const TextStyle(), 
        withComposing: false
      );
      
      final reconstructed = span.toPlainText();
      
      print(r'Original length: ${text.length}');
      print(r'Reconstructed length: ${reconstructed.length}');
      
      if (text != reconstructed) {
        print('MISMATCH!');
        for (var i = 0; i < text.length && i < reconstructed.length; i++) {
          if (text[i] != reconstructed[i]) {
            print(r'First mismatch at index $i: expected "${text[i]}" got "${reconstructed[i]}"');
            break;
          }
        }
      }
      
      expect(reconstructed, text);
      return Container();
    }))));
  });
}
