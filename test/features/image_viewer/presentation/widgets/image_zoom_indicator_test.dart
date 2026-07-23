import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_zoom_indicator.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('ImageZoomIndicator', () {
    testWidgets('renders correct percentage text at scale 1.0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageZoomIndicator(scale: 1.0),
          ),
        ),
      );

      expect(find.text('100%'), findsOneWidget);
    });

    testWidgets('renders correct percentage text at scale 1.5', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ImageZoomIndicator(scale: 1.5),
          ),
        ),
      );

      expect(find.text('150%'), findsOneWidget);
    });
  });
}
