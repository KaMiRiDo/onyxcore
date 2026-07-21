import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/video_player/presentation/overlays/seek_indicator.dart';
import 'package:onyxcore/features/video_player/presentation/utils/video_player_utils.dart';

void main() {
  group('SeekIndicator Widget Tests', () {
    testWidgets('Renders correctly when visible and formats duration properly', (tester) async {
      const displayPosition = Duration(seconds: 120);
      const totalDuration = Duration(seconds: 360);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SeekIndicator(
              isVisible: true,
              displayPosition: displayPosition,
              totalDuration: totalDuration,
            ),
          ),
        ),
      );

      expect(find.byType(SeekIndicator), findsOneWidget);
      
      final expectedText = '${VideoPlayerUtils.formatDuration(displayPosition)} / ${VideoPlayerUtils.formatDuration(totalDuration)}';
      expect(find.text(expectedText), findsOneWidget);

      final AnimatedOpacity opacityWidget = tester.widget(find.byType(AnimatedOpacity));
      expect(opacityWidget.opacity, 1.0);
    });

    testWidgets('Is not visible when isVisible is false', (tester) async {
      const displayPosition = Duration(seconds: 120);
      const totalDuration = Duration(seconds: 360);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SeekIndicator(
              isVisible: false,
              displayPosition: displayPosition,
              totalDuration: totalDuration,
            ),
          ),
        ),
      );

      final AnimatedOpacity opacityWidget = tester.widget(find.byType(AnimatedOpacity));
      expect(opacityWidget.opacity, 0.0);
    });
  });
}
