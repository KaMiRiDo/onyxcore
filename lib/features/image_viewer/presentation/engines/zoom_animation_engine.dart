import 'package:flutter/material.dart';

class ZoomAnimationEngine {
  final AnimationController _animationController;
  final void Function(Matrix4) onTick;
  Animation<Matrix4>? _zoomAnimation;

  ZoomAnimationEngine({
    required AnimationController animationController,
    required this.onTick,
  }) : _animationController = animationController {
    _animationController.addListener(_onAnimationTick);
  }

  void _onAnimationTick() {
    if (_zoomAnimation != null) {
      onTick(_zoomAnimation!.value);
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
    _animationController.removeListener(_onAnimationTick);
  }
}
