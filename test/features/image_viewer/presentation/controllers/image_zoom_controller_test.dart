import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/image_zoom_controller.dart';
import 'package:onyxcore/features/image_viewer/presentation/engines/zoom_animation_engine.dart';

void main() {
  group('ImageZoomController', () {
    late AnimationController animationController;
    late ZoomAnimationEngine animationEngine;
    late ImageZoomController zoomController;


    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      animationController = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 200),
      );
      

      
      animationEngine = ZoomAnimationEngine(
        animationController: animationController,
        onTick: (matrix) {
          zoomController.animationTick = matrix;
        },
      );
      
      zoomController = ImageZoomController(
        animationEngine: animationEngine,
      )..updateConstraints(const Size(1000, 1000), const Size(500, 500));
    });

    tearDown(() {
      zoomController.dispose();
      animationEngine.dispose();
      animationController.dispose();
    });

    test('initial state is correct', () {
      expect(zoomController.currentScale, equals(1.0));
      expect(zoomController.isPanZoomGesture, isFalse);
      expect(zoomController.isInteracting, isFalse);
    });

    test('setIsInteracting updates state and stops animation if true', () {
      zoomController.setZoom(2, focalPoint: const Offset(500, 500));
      expect(animationEngine.isAnimating, isTrue);
      
      zoomController.isInteracting = true;
      expect(zoomController.isInteracting, isTrue);
      expect(animationEngine.isAnimating, isFalse);
    });

    test('setZoom without animation immediately updates transformation', () {
      zoomController.setZoom(2, focalPoint: const Offset(500, 500), animate: false);
      expect(zoomController.currentScale, equals(2.0));
    });

    test('startPanZoomGesture and endPanZoomGesture updates state', () {
      zoomController.startPanZoomGesture(Offset.zero);
      expect(zoomController.isPanZoomGesture, isTrue);
      
      zoomController.endPanZoomGesture();
      expect(zoomController.isPanZoomGesture, isFalse);
    });

    test('updatePinchGesture updates zoom from initial gesture scale', () {
      zoomController
        ..startPanZoomGesture(Offset.zero)
        ..updatePinchGesture(2, const Offset(500, 500));
      expect(zoomController.currentScale, equals(2.0));
    });

    test('applyTranslation applies delta translation', () {
      zoomController
        ..setZoom(2, focalPoint: const Offset(500, 500), animate: false)
        ..applyTranslation(const Offset(50, 50));
      // X and Y should change
      final matrix = zoomController.transformationController.value;
      expect(matrix.getTranslation().x, isNot(equals(0.0)));
    });

    test('reset clears all state', () {
      zoomController
        ..setZoom(2, focalPoint: const Offset(500, 500), animate: false)
        ..isInteracting = true
        ..startPanZoomGesture(Offset.zero)
        ..reset();
      
      expect(zoomController.currentScale, equals(1.0));
      expect(zoomController.isInteracting, isFalse);
      expect(zoomController.isPanZoomGesture, isFalse);
      expect(zoomController.transformationController.value, equals(Matrix4.identity()));
    });
  });
}
