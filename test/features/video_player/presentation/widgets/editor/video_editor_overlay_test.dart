import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:media_kit/media_kit.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/editor/video_editor_overlay.dart';

void main() {
  group('VideoEditorOverlay', () {
    testWidgets('renders close button and it triggers onClose callback', (tester) async {
      MediaKit.ensureInitialized();
      final player = Player();
      final controller = VideoController(player);
      bool isClosed = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VideoEditorOverlay(
                controller: controller,
                sourceFile: '/test/video.mp4',
                onClose: () {
                  isClosed = true;
                },
              ),
            ),
          ),
        ),
      );

      // Should have a close button
      final closeButton = find.byIcon(Icons.close);
      expect(closeButton, findsOneWidget);

      await tester.tap(closeButton);
      expect(isClosed, true);
    });

    testWidgets('renders Trim and Extract buttons', (tester) async {
      MediaKit.ensureInitialized();
      final player = Player();
      final controller = VideoController(player);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: VideoEditorOverlay(
                controller: controller,
                sourceFile: '/test/video.mp4',
                onClose: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.byTooltip('Trim & Merge'), findsOneWidget);
      expect(find.byTooltip('Extract Frames'), findsOneWidget);
    });
  });
}
