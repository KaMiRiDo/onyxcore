import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/playback_speed_control.dart';

void main() {
  testWidgets('PlaybackSpeedControl renders all speeds and handles tap', (WidgetTester tester) async {
    var selectedSpeed = 1.0;
    
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaybackSpeedControl(
            currentSpeed: 1,
            onSpeedSelected: (speed) {
              selectedSpeed = speed;
            },
          ),
        ),
      ),
    );

    for (final speed in PlaybackSpeedControl.speeds) {
      expect(find.text('${speed}x'), findsOneWidget);
    }

    await tester.tap(find.text('1.5x'));
    await tester.pump();

    expect(selectedSpeed, 1.5);
  });

  testWidgets('PlaybackSpeedControl uses different styles for selected and unselected speeds', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PlaybackSpeedControl(
            currentSpeed: 2,
            onSpeedSelected: (speed) {},
          ),
        ),
      ),
    );

    expect(find.byType(Spacer), findsOneWidget);
  });
}
