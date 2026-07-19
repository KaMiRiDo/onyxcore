import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/video_speed_overlay.dart';

void main() {
  testWidgets('VideoSpeedOverlay renders correctly within bounds', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoSpeedOverlay(
            speed: 1.5,
            onSpeedChanged: (s) {},
          ),
        ),
      ),
    );

    expect(find.text('1.50x'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 1.5);
  });

  testWidgets('VideoSpeedOverlay clamps speed below minimum', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoSpeedOverlay(
            speed: 0.1,
            onSpeedChanged: (_) {},
          ),
        ),
      ),
    );

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 0.25);
  });

  testWidgets('VideoSpeedOverlay clamps speed above maximum', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoSpeedOverlay(
            speed: 5,
            onSpeedChanged: (_) {},
          ),
        ),
      ),
    );

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 4.0);
  });
}
