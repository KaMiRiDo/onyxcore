import 'dart:math' as math;

import 'package:flutter/material.dart';

class MatrixClampEngine {
  /// Clamps the translation of [matrix] such that the image stays within the viewport boundaries.
  /// If [imageSize] is null, returns the original matrix unmodified.
  static Matrix4 clamp(Matrix4 matrix, Size viewportSize, Size? imageSize) {
    if (imageSize == null) return matrix;

    final scaleX = viewportSize.width / imageSize.width;
    final scaleY = viewportSize.height / imageSize.height;
    final double fitScale = math.min(scaleX, scaleY);

    final fittedWidth = imageSize.width * fitScale;
    final fittedHeight = imageSize.height * fitScale;

    final currentZoom = matrix.getMaxScaleOnAxis();
    final scaledWidth = fittedWidth * currentZoom;
    final scaledHeight = fittedHeight * currentZoom;

    final padX = (viewportSize.width - fittedWidth) / 2;
    final padY = (viewportSize.height - fittedHeight) / 2;

    double minTx;
    double maxTx;
    if (scaledWidth > viewportSize.width) {
      minTx = viewportSize.width - scaledWidth - padX * currentZoom;
      maxTx = -padX * currentZoom;
    } else {
      minTx = maxTx = viewportSize.width * (1 - currentZoom) / 2;
    }

    double minTy;
    double maxTy;
    if (scaledHeight > viewportSize.height) {
      minTy = viewportSize.height - scaledHeight - padY * currentZoom;
      maxTy = -padY * currentZoom;
    } else {
      minTy = maxTy = viewportSize.height * (1 - currentZoom) / 2;
    }

    final clampedTx = matrix.getTranslation().x.clamp(minTx, maxTx);
    final clampedTy = matrix.getTranslation().y.clamp(minTy, maxTy);

    final clampedMatrix = matrix.clone();
    clampedMatrix.setTranslationRaw(clampedTx, clampedTy, 0);
    return clampedMatrix;
  }
}
