import 'package:flutter/material.dart';

class TransformationEngine {
  /// Computes a new matrix for a zoom interaction centered around [focalPoint].
  /// Returns null if the matrix is invalid or the scale change is negligible.
  static Matrix4? computeZoom(Matrix4 currentMatrix, double newScale, Offset focalPoint) {
    final clampedScale = newScale.clamp(1.0, 15.0);

    if (clampedScale == 1.0) {
      return Matrix4.identity();
    }

    final oldScale = currentMatrix.getMaxScaleOnAxis();
    if ((clampedScale - oldScale).abs() < 0.001) return null;

    final scaleRatio = clampedScale / oldScale;

    try {
      final inverseMatrix = Matrix4.inverted(currentMatrix);
      final scenePoint = MatrixUtils.transformPoint(inverseMatrix, focalPoint);

      final newMatrix = currentMatrix.clone()
        ..translate(scenePoint.dx, scenePoint.dy)
        ..scale(scaleRatio, scaleRatio)
        ..translate(-scenePoint.dx, -scenePoint.dy);

      if (newMatrix.storage.any((v) => !v.isFinite)) {
        return null;
      }
      return newMatrix;
    } catch (e) {
      return null;
    }
  }

  /// Computes a new matrix for a pinch-to-zoom gesture, anchoring the [viewportFocalPoint]
  /// to the [gestureStartMatrix].
  /// Returns null if the matrix is invalid or the start scale is negligible.
  static Matrix4? computeGestureZoom(Matrix4 gestureStartMatrix, double targetScale, Offset viewportFocalPoint) {
    final clampedScale = targetScale.clamp(1.0, 15.0);

    if (clampedScale == 1.0) {
      return Matrix4.identity();
    }

    final startScale = gestureStartMatrix.getMaxScaleOnAxis();
    if (startScale < 0.001) return null;
    final scaleRatio = clampedScale / startScale;

    try {
      final inverseStart = Matrix4.inverted(gestureStartMatrix);
      final scenePoint = MatrixUtils.transformPoint(
        inverseStart,
        viewportFocalPoint,
      );

      final newMatrix = gestureStartMatrix.clone()
        ..translate(scenePoint.dx, scenePoint.dy)
        ..scale(scaleRatio, scaleRatio)
        ..translate(-scenePoint.dx, -scenePoint.dy);

      if (newMatrix.storage.any((v) => !v.isFinite)) return null;

      return newMatrix;
    } catch (e) {
      return null;
    }
  }
}
