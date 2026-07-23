import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/image_editing_panel.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('ImageEditingPanel', () {
    testWidgets('renders sliders and fires callbacks', (tester) async {
      var rotation = -180.0;
      var bright = -1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ImageEditingPanel(
                  rotationAngle: rotation,
                  brightness: bright,
                  onRotationChanged: (val) {
                    setState(() => rotation = val);
                  },
                  onBrightnessChanged: (val) {
                    setState(() => bright = val);
                  },
                );
              },
            ),
          ),
        ),
      );

      final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      expect(sliders.length, 2);

      // Slide rotation
      await tester.tap(find.byWidget(sliders[0]));
      expect(rotation, isNot(equals(-180.0)));

      // Slide brightness
      await tester.tap(find.byWidget(sliders[1]));
      expect(bright, isNot(equals(-1.0)));
    });
  });
}
