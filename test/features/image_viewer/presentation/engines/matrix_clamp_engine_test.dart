import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onyxcore/features/image_viewer/presentation/engines/matrix_clamp_engine.dart';

void main() {
  group('MatrixClampEngine', () {
    test('returns original matrix when imageSize is null', () {
      final matrix = Matrix4.translationValues(10, 20, 0);
      final clamped = MatrixClampEngine.clamp(matrix, const Size(100, 100), null);
      expect(clamped, matrix);
    });

    test('allows translation when viewport is smaller than image', () {
      final matrix = Matrix4.identity()..translateByDouble(-150, -150, 0, 1)..scaleByDouble(2, 2, 2, 1);
      
      final clamped = MatrixClampEngine.clamp(
        matrix,
        const Size(100, 100),
        const Size(200, 200), // Original logic computes fitScale based on this vs viewport. fitScale = 0.5. fittedWidth = 100.
      );
      
      expect(clamped.getTranslation().x, equals(-100.0));
      expect(clamped.getTranslation().y, equals(-100.0));
    });

    test('forces translation to center when viewport is larger than image', () {
      final matrix = Matrix4.identity()..translateByDouble(10, 10, 0, 1);
      
      final clamped = MatrixClampEngine.clamp(
        matrix,
        const Size(100, 100),
        const Size(50, 50),
      );
      
      expect(clamped.getTranslation().x, equals(0.0));
      expect(clamped.getTranslation().y, equals(0.0));
    });

    test('handles extreme zoom and pan clamping', () {
      final matrix = Matrix4.identity()..translateByDouble(100, -2000, 0, 1)..scaleByDouble(10, 10, 10, 1);
      
      final clamped = MatrixClampEngine.clamp(
        matrix,
        const Size(100, 100),
        const Size(100, 100),
      );
      
      expect(clamped.getTranslation().x, equals(0.0)); 
      expect(clamped.getTranslation().y, equals(-900.0)); 
    });
  });
}
