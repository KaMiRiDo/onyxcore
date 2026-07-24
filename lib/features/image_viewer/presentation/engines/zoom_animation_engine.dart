import 'package:flutter/material.dart';
import 'package:onyxcore/features/image_viewer/presentation/controllers/interaction_quality_notifier.dart';

class ZoomAnimationEngine {

  ZoomAnimationEngine({
    required AnimationController animationController,
    required this.onTick,
    this.qualityNotifier,
  }) : _animationController = animationController {
    _animationController
      ..addListener(_onAnimationTick)
      ..addStatusListener(_onAnimationStatusChanged);
  }
  final AnimationController _animationController;
  final void Function(Matrix4) onTick;
  final InteractionQualityNotifier? qualityNotifier;
  Animation<Matrix4>? _zoomAnimation;

  void _onAnimationTick() {
    if (_zoomAnimation != null) {
      onTick(_zoomAnimation!.value);
    }
  }

  void _onAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.forward || status == AnimationStatus.reverse) {
      qualityNotifier?.onInteractionStart();
    } else if (status == AnimationStatus.completed || status == AnimationStatus.dismissed) {
      qualityNotifier?.onInteractionEnd();
    }
  }

  bool get isAnimating => _animationController.isAnimating;
  
  Animation<Matrix4>? get currentAnimation => _zoomAnimation;

  void animateMatrix(Matrix4 start, Matrix4 end) {
    _animationController.stop();
    _zoomAnimation = Matrix4Tween(begin: start, end: end).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );
    _animationController.forward(from: 0);
  }

  void stop() {
    _animationController.stop();
  }

  void dispose() {
    _animationController
      ..removeListener(_onAnimationTick)
      ..removeStatusListener(_onAnimationStatusChanged);
  }
}
