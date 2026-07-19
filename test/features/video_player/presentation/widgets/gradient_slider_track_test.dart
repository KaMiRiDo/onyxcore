import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/gradient_slider_track.dart';

void main() {
  group('GradientRectSliderTrackShape', () {
    testWidgets('paints inactive, active, and buffer tracks correctly', (tester) async {
      const gradient = LinearGradient(colors: [Colors.red, Colors.blue]);
      final trackShape = GradientRectSliderTrackShape(
        gradient: gradient,
        bufferProgress: 0.5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackShape: trackShape,
                    inactiveTrackColor: Colors.grey,
                  ),
                  child: Slider(
                    value: 0.25,
                    onChanged: (v) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      // We just need to ensure it renders without exceptions and the shape handles paint correctly.
      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);
    });
    
    testWidgets('paints correctly without bufferProgress', (tester) async {
      const gradient = LinearGradient(colors: [Colors.red, Colors.blue]);
      final trackShape = GradientRectSliderTrackShape(
        gradient: gradient,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 200,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackShape: trackShape,
                    inactiveTrackColor: Colors.grey,
                  ),
                  child: Slider(
                    value: 0.25,
                    onChanged: (v) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);
    });
  });
}
