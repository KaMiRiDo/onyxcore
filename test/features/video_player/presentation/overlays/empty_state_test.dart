import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/video_player/presentation/overlays/empty_state.dart';

void main() {
  group('VideoEmptyState Widget Tests', () {
    testWidgets('Renders correctly in non-standalone mode', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VideoEmptyState(isStandalone: false),
          ),
        ),
      );

      expect(find.byType(VideoEmptyState), findsOneWidget);
      expect(find.byIcon(Icons.videocam_off_rounded), findsOneWidget);
      expect(find.text('No video files to play next.'), findsOneWidget);
      
      // Close button should not be present
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('Renders close button in standalone mode and handles tap', (tester) async {
      bool closeCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoEmptyState(
              isStandalone: true,
              onClose: () => closeCalled = true,
            ),
          ),
        ),
      );

      // Verify close button is present
      final closeButtonFinder = find.byIcon(Icons.close_rounded);
      expect(closeButtonFinder, findsOneWidget);

      // Tap close button
      await tester.tap(closeButtonFinder);
      await tester.pumpAndSettle();

      expect(closeCalled, isTrue);
    });
  });
}
