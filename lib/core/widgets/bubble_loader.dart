import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:onyxcore/core/theme/app_colors.dart';

class BubbleLoader extends StatefulWidget {
  final double size;
  const BubbleLoader({super.key, this.size = 80});

  @override
  State<BubbleLoader> createState() => _BubbleLoaderState();
}

class _BubbleLoaderState extends State<BubbleLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: BubblePainter(
                progress: _controller.value,
                color: AppColors.magenta,
              ),
            );
          },
        ),
      ),
    );
  }
}

class BubblePainter extends CustomPainter {
  final double progress;
  final Color color;

  BubblePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) + (progress * math.pi * 2);
      final bubbleProgress = (progress + (i * 0.125)) % 1.0;
      final offsetDist = radius * 0.6 * math.sin(bubbleProgress * math.pi);
      
      final bubbleCenter = Offset(
        center.dx + math.cos(angle) * offsetDist,
        center.dy + math.sin(angle) * offsetDist,
      );

      final bubbleRadius = 8.0 * math.sin(bubbleProgress * math.pi);
      
      final paint = Paint()
        ..sharedGradient(
          Rect.fromCircle(center: bubbleCenter, radius: bubbleRadius),
          [
            AppColors.magenta.withOpacity(0.8),
            AppColors.violet.withOpacity(0.4),
          ],
        );

      canvas.drawCircle(bubbleCenter, bubbleRadius, paint);
    }
  }

  @override
  bool shouldRepaint(BubblePainter oldDelegate) => true;
}

extension on Paint {
  void sharedGradient(Rect rect, List<Color> colors) {
    shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: colors,
    ).createShader(rect);
  }
}
