import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_gesture_handler.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_hud_controller.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_zoom_controller.dart';
import 'package:onyxcore/features/image_viewer/presentation/engines/zoom_animation_engine.dart';
import 'package:onyxcore/features/image_viewer/presentation/widgets/interactive_image_viewport.dart';

void main() {
  testWidgets('InteractiveImageViewport builds correctly and forwards interactions', (WidgetTester tester) async {
    final animationController = AnimationController(vsync: const TestVSync());
    final animationEngine = ZoomAnimationEngine(
      animationController: animationController,
      onTick: (_) {},
    );
    final zoomController = ImageZoomController(
      animationEngine: animationEngine,
    );
    final gestureHandler = ImageGestureHandler(zoomController: zoomController);
    final focusNode = FocusNode();
    final hudController = ImageHudController();

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: InteractiveImageViewport(
              zoomController: zoomController,
              gestureHandler: gestureHandler,
              hudController: hudController,
              isStandalone: true,
              onDoubleTapPopOut: () {},
              focusNode: focusNode,
              isReadyForInteraction: true,
              child: const SizedBox(width: 100, height: 100, child: Text('Image')),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Image'), findsOneWidget);
    expect(find.byType(Listener), findsWidgets);
    expect(find.byType(GestureDetector), findsWidgets);
    
    zoomController.dispose();
    animationEngine.dispose();
    animationController.dispose();
  });
}
