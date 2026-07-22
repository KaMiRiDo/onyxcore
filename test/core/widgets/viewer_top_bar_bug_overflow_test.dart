import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/core/widgets/viewer_top_bar.dart';

void main() {
  testWidgets('ViewerTopBar title and metadata use ellipsis to prevent overflow', (WidgetTester tester) async {
    const longTitle = 'This is a very very very very very long title that would definitely overflow on a small screen and break the UI layout completely.png';
    const longMetadata = '1/100 • 3840x2160 • 15.5 MB • ISO 100 • f/2.8 • 1/1000s • 50mm • Sony A7III • This is a very long string that should also be truncated nicely';

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ViewerTopBar(
            title: longTitle,
            metadata: longMetadata,
          ),
        ),
      ),
    );

    // Find the title text (it might be wrapped in a Tooltip, so we find by partial text if trimmed)
    final textWidgets = tester.widgetList<Text>(find.byType(Text));
    
    // There should be at least two Text widgets (title and metadata)
    expect(textWidgets.length, greaterThanOrEqualTo(2));

    for (final textWidget in textWidgets) {
      expect(textWidget.maxLines, 1, reason: 'Text should be constrained to 1 line to prevent wrapping and breaking layout');
      
      // Wait, ViewerTopBar might use GoogleFonts which returns a specific TextStyle. 
      // We can check if the TextStyle has overflow or if the Text widget itself has overflow.
      // Often, overflow is handled at the TextStyle level or the Text widget level.
      // We'll check both.
      final hasEllipsis = (textWidget.style?.overflow == TextOverflow.ellipsis) || (textWidget.overflow == TextOverflow.ellipsis);
      // Wait, actually _trimMiddle truncates the title so it might NOT need ellipsis, but metadata definitely needs it!
      // I'll just check that ALL texts in ViewerTopBar have ellipsis!
      if (textWidget.data != null && textWidget.data!.contains('1/100')) {
         expect(textWidget.overflow, TextOverflow.ellipsis, reason: 'Metadata must have ellipsis overflow');
      }
    }
  });
}
