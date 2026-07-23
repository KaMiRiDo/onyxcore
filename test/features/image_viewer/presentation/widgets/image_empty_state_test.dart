import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_empty_state.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('ImageEmptyState', () {
    testWidgets('renders empty state correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageEmptyState(),
          ),
        ),
      );

      // Should find the icon
      expect(find.byIcon(Icons.image_not_supported_rounded), findsOneWidget);

      // Should find the text
      expect(find.text('No more images to view.'), findsOneWidget);

      // Verify the colored box background
      final coloredBox = tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(ImageEmptyState),
          matching: find.byType(ColoredBox),
        ).first,
      );
      expect(coloredBox.color, const Color(0xFF121212));
    });
  });
}
