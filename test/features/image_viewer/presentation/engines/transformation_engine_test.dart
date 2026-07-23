import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/image_viewer/presentation/engines/transformation_engine.dart';

void main() {
  group('TransformationEngine', () {
    test('computeZoom returns identity when scale is 1.0', () {
      final matrix = Matrix4.identity()..scaleByDouble(2, 2, 2, 1);
      final result = TransformationEngine.computeZoom(matrix, 1, Offset.zero);
      expect(result, equals(Matrix4.identity()));
    });

    test('computeZoom returns null when scale change is negligible', () {
      final matrix = Matrix4.identity()..scaleByDouble(2, 2, 2, 1);
      final result = TransformationEngine.computeZoom(matrix, 2.0001, Offset.zero);
      expect(result, isNull);
    });

    test('computeZoom correctly applies cursor-centered zoom', () {
      final matrix = Matrix4.identity();
      const focalPoint = Offset(50, 50);
      
      // Zooming in by 2x at (50, 50) means scene point (50, 50) stays at viewport (50, 50)
      final result = TransformationEngine.computeZoom(matrix, 2, focalPoint);
      expect(result, isNotNull);
      
      // Check if focal point in new matrix maps back to the same scene point
      // scene point was (50,50). 
      // viewport point = matrix * scene_point
      // new viewport point for (50, 50) should still be (50, 50).
      const scenePoint = Offset(50, 50);
      final newViewportPoint = MatrixUtils.transformPoint(result!, scenePoint);
      
      expect(newViewportPoint.dx, closeTo(50.0, 0.001));
      expect(newViewportPoint.dy, closeTo(50.0, 0.001));
      expect(result.getMaxScaleOnAxis(), closeTo(2.0, 0.001));
    });

    test('computeGestureZoom returns identity when target scale is 1.0', () {
      final matrix = Matrix4.identity()..scaleByDouble(3, 3, 3, 1);
      final result = TransformationEngine.computeGestureZoom(matrix, 1, Offset.zero);
      expect(result, equals(Matrix4.identity()));
    });

    test('computeGestureZoom properly anchors focal point relative to start matrix', () {
      final startMatrix = Matrix4.identity()..translateByDouble(10, 10, 0, 1)..scaleByDouble(2, 2, 2, 1);
      const focalPoint = Offset(30, 30); // Viewport focal point
      
      // Target scale is 4.0
      final result = TransformationEngine.computeGestureZoom(startMatrix, 4, focalPoint);
      expect(result, isNotNull);
      
      // At start, viewport (30,30) mapped to scene point:
      // inverseStart = scale(0.5) * translate(-10, -10)
      // Actually (30,30) -> startMatrix -> scene point is:
      // 30 = 2*x + 10 => x = 10
      // 30 = 2*y + 10 => y = 10
      // So scene point is (10, 10).
      
      // In the result matrix, scene point (10, 10) must still map to viewport (30, 30)
      const scenePoint = Offset(10, 10);
      final newViewportPoint = MatrixUtils.transformPoint(result!, scenePoint);
      
      expect(newViewportPoint.dx, closeTo(30.0, 0.001));
      expect(newViewportPoint.dy, closeTo(30.0, 0.001));
      expect(result.getMaxScaleOnAxis(), closeTo(4.0, 0.001));
    });
  });
}
