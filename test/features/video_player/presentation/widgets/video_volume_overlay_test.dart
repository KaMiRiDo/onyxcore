import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/video_volume_overlay.dart';

void main() {
  testWidgets('VideoVolumeOverlay renders correctly within bounds', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoVolumeOverlay(
            volume: 75,
            onVolumeChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('75%'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 75.0);
  });

  testWidgets('VideoVolumeOverlay shows volume_off icon when volume is 0', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoVolumeOverlay(
            volume: 0,
            onVolumeChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('0%'), findsOneWidget);
    expect(find.byIcon(Icons.volume_off), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 0.0);
  });

  testWidgets('VideoVolumeOverlay clamps volume above maximum', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoVolumeOverlay(
            volume: 250,
            onVolumeChanged: (_) {},
          ),
        ),
      ),
    );

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 200.0);
  });

  testWidgets('VideoVolumeOverlay clamps volume below minimum', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VideoVolumeOverlay(
            volume: -10,
            onVolumeChanged: (_) {},
          ),
        ),
      ),
    );

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.value, 0.0);
  });
}
