import 'package:flutter/material.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/interaction_quality_notifier.dart';
import 'package:onyxcore/features/image_viewer/presentation/engines/matrix_clamp_engine.dart';
import 'package:onyxcore/features/image_viewer/presentation/engines/transformation_engine.dart';
import 'package:onyxcore/features/image_viewer/presentation/engines/zoom_animation_engine.dart';

class ImageZoomController extends ChangeNotifier {
  
  ImageZoomController({
    required this.animationEngine,
    this.qualityNotifier,
  }) {
    transformationController.addListener(_onTransformationChanged);
  }
  final TransformationController transformationController = TransformationController();
  final ZoomAnimationEngine animationEngine;
  final InteractionQualityNotifier? qualityNotifier;
  
  double _initialScale = 1;
  final ValueNotifier<double> scaleNotifier = ValueNotifier(1);
  Matrix4 _gestureStartMatrix = Matrix4.identity();
  double _scrubAccumulatedScale = 1;
  
  bool _isPanZoomGesture = false;
  bool _isInteracting = false;
  
  Size _viewportSize = Size.zero;
  Size get viewportSize => _viewportSize;
  Size? _imageSize;

  double get currentScale => scaleNotifier.value;
  bool get isPanZoomGesture => _isPanZoomGesture;
  bool get isInteracting => _isInteracting;
  bool get isAnimating => animationEngine.isAnimating;

  void updateConstraints(Size viewportSize, Size? imageSize) {
    _viewportSize = viewportSize;
    _imageSize = imageSize;
    if (_viewportSize != Size.zero && _imageSize != null) {
      _onTransformationChanged();
    }
  }

  set isInteracting(bool interacting) {
    if (_isInteracting == interacting) return;
    _isInteracting = interacting;
    if (interacting) {
      if (animationEngine.isAnimating) {
        animationEngine.stop();
      }
      qualityNotifier?.onInteractionStart();
    } else {
      qualityNotifier?.onInteractionEnd();
    }
    notifyListeners();
  }

  void startPanZoomGesture(Offset initialPosition) {
    _initialScale = scaleNotifier.value;
    _gestureStartMatrix = transformationController.value.clone();
    _scrubAccumulatedScale = 1.0;
    _isPanZoomGesture = true;
    qualityNotifier?.onInteractionStart();
    notifyListeners();
  }

  void endPanZoomGesture() {
    _isPanZoomGesture = false;
    qualityNotifier?.onInteractionEnd();
    notifyListeners();
  }

  void updateScrubGesture(double dy, Offset focalPoint) {
    _scrubAccumulatedScale *= 1.0 + (dy * 0.005);
    _setZoomFromGesture(_initialScale * _scrubAccumulatedScale, focalPoint);
  }

  void updatePinchGesture(double scale, Offset focalPoint) {
    _setZoomFromGesture(_initialScale * scale, focalPoint);
  }
  
  void applyTranslation(Offset delta) {
    final translation = Matrix4.translationValues(delta.dx, delta.dy, 0);
    final nextMatrix = (translation * transformationController.value) as Matrix4;
    
    if (nextMatrix.storage.any((v) => !v.isFinite)) {
      return;
    }
    transformationController.value = nextMatrix;
  }
  
  void setZoom(double newScale, {required Offset focalPoint, bool animate = true}) {
    final nextMatrix = TransformationEngine.computeZoom(
      transformationController.value,
      newScale,
      focalPoint,
    );
    
    if (nextMatrix == null) return;

    if (animate) {
      animationEngine.animateMatrix(transformationController.value, nextMatrix);
    } else {
      transformationController.value = nextMatrix;
    }
  }

  void _setZoomFromGesture(double targetScale, Offset viewportFocalPoint) {
    final nextMatrix = TransformationEngine.computeGestureZoom(
      _gestureStartMatrix,
      targetScale,
      viewportFocalPoint,
    );
    
    if (nextMatrix == null) return;
    transformationController.value = nextMatrix;
  }

  // ignore: avoid_setters_without_getters
  set animationTick(Matrix4 value) {
    transformationController.value = value;
  }

  void _onTransformationChanged() {
    if (_viewportSize == Size.zero) return;
    
    final clamped = MatrixClampEngine.clamp(
      transformationController.value,
      _viewportSize,
      _imageSize,
    );

    final currentTx = transformationController.value.getTranslation().x;
    final currentTy = transformationController.value.getTranslation().y;
    final clampedTx = clamped.getTranslation().x;
    final clampedTy = clamped.getTranslation().y;

    if ((currentTx - clampedTx).abs() > 0.1 ||
        (currentTy - clampedTy).abs() > 0.1) {
      transformationController.value = clamped;
      return;
    }

    final scale = transformationController.value.getMaxScaleOnAxis();
    if (scale != scaleNotifier.value) {
      scaleNotifier.value = scale;
      // No longer notifyListeners() on every scale tick for the controller itself, the ValueNotifier does it!
    }
  }
  
  void reset() {
    transformationController.value = Matrix4.identity();
    scaleNotifier.value = 1.0;
    _isPanZoomGesture = false;
    _isInteracting = false;
    notifyListeners();
  }

  @override
  void dispose() {
    transformationController
      ..removeListener(_onTransformationChanged)
      ..dispose();
    scaleNotifier.dispose();
    super.dispose();
  }
}
