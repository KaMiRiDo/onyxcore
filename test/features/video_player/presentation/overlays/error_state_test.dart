import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/video_player/presentation/overlays/error_state.dart';

void main() {
  group('VideoErrorState', () {
    testWidgets('renders error message and does not render duplicate close button', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoErrorState(
              errorMessage: 'Format not supported',
              isStandalone: false,
              onClose: () {},
            ),
          ),
        ),
      );

      // Verify the error text is shown
      expect(find.text('Failed to play media'), findsOneWidget);
      expect(find.text('Format not supported'), findsOneWidget);

      // Verify the duplicate close/back button is removed
      expect(find.byType(IconButton), findsNothing);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });

    testWidgets('does not render close button in standalone mode either', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoErrorState(
              errorMessage: 'Standalone error',
              isStandalone: true,
              onClose: () {},
            ),
          ),
        ),
      );

      expect(find.text('Standalone error'), findsOneWidget);
      expect(find.byType(IconButton), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsNothing);
    });
  });
}
