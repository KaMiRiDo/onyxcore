import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:onyxcore/core/theme/app_colors.dart';

class PlayingEqAnimation extends StatefulWidget {
  const PlayingEqAnimation({super.key});

  @override
  State<PlayingEqAnimation> createState() => _PlayingEqAnimationState();
}

class _PlayingEqAnimationState extends State<PlayingEqAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _EqBar(animation: _controller, offset: 0),
          _EqBar(animation: _controller, offset: 0.3),
          _EqBar(animation: _controller, offset: 0.6),
        ],
      ),
    );
  }
}

class _EqBar extends StatelessWidget {

  const _EqBar({required this.animation, required this.offset});
  final Animation<double> animation;
  final double offset;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // Shift the animation phase
        final value = (animation.value + offset) % 1.0;
        // Use a sine wave for smooth bouncing
        final height = 4.0 + (math.sin(value * math.pi) * 8.0);

        return Container(
          width: 3,
          height: height,
          decoration: BoxDecoration(
            color: AppColors.magenta,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      },
    );
  }
}
