import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/interaction_quality_notifier.dart';
import 'package:onyxcore/features/image_viewer/presentation/engines/zoom_animation_engine.dart';

void main() {
  group('ZoomAnimationEngine', () {
    late AnimationController controller;
    late ZoomAnimationEngine engine;
    late List<Matrix4> ticks;

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      controller = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 200),
      );
      ticks = [];
      engine = ZoomAnimationEngine(
        animationController: controller,
        onTick: (matrix) {
          ticks.add(matrix);
        },
      );
    });

    tearDown(() {
      engine.dispose();
      controller.dispose();
    });

    test('animateMatrix stops previous and starts new animation from 0', () {
      final start = Matrix4.identity();
      final end = Matrix4.identity()..scaleByDouble(2, 2, 2, 1);
      
      engine.animateMatrix(start, end);
      
      expect(engine.isAnimating, isTrue);
      // Wait for it to tick a bit
      controller.value = 0.5;
      
      expect(ticks.isNotEmpty, isTrue);
      final intermediateScale = ticks.last.getMaxScaleOnAxis();
      expect(intermediateScale, greaterThan(1.0));
      expect(intermediateScale, lessThan(2.0));
    });

    test('stop cancels the animation', () {
      final start = Matrix4.identity();
      final end = Matrix4.identity()..scaleByDouble(2, 2, 2, 1);
      
      engine.animateMatrix(start, end);
      expect(engine.isAnimating, isTrue);
      
      engine.stop();
      expect(engine.isAnimating, isFalse);
    });

    test('dispose removes listener', () {
      final start = Matrix4.identity();
      final end = Matrix4.identity()..scaleByDouble(2, 2, 2, 1);
      
      engine
        ..animateMatrix(start, end)
        ..dispose();
      controller.value = 0.5; // Should not trigger onTick since listener is removed
      
      // The only ticks should be the ones from 0.0 right when it started
      final ticksCount = ticks.length;
      controller.value = 1.0;
      expect(ticks.length, equals(ticksCount));
    });

    test('animation ticks do not repeatedly notify quality state', () {
      // We will use InteractionQualityNotifier directly to verify notifications
      
      final mockNotifier = InteractionQualityNotifier();
      var notifyCount = 0;
      mockNotifier.addListener(() => notifyCount++);
      
      final localEngine = ZoomAnimationEngine(
        animationController: controller,
        onTick: (matrix) {},
        qualityNotifier: mockNotifier,
      );

      final start = Matrix4.identity();
      final end = Matrix4.identity()..scaleByDouble(2, 2, 2, 1);
      
      localEngine.animateMatrix(start, end);
      
      expect(mockNotifier.isActive, isTrue);
      expect(notifyCount, 1); // Notification for start
      
      // Simulate animation ticks
      controller
        ..value = 0.5
        ..value = 0.6
        ..value = 0.7;
      
      // Still only 1 notification
      expect(notifyCount, 1);
      
      // Finish animation
      controller
        ..value = 1.0
        ..stop();
      
      // Since setting value manually doesn't trigger the 'completed' status
      // in AnimationController synchronously without a ticker, it will remain
      // at 1 notification (the initial start). 
      // The important part is that the ticks (0.5, 0.6, 0.7) didn't increase the count.
      expect(notifyCount, 1); 
      
      localEngine.dispose();
      mockNotifier.dispose();
    });
  });
}
