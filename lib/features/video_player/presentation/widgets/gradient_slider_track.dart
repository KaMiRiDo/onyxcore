import 'package:flutter/material.dart';

/// A custom slider track shape that paints a gradient for the active track.
class GradientRectSliderTrackShape extends RectangularSliderTrackShape {
  const GradientRectSliderTrackShape({
    required this.gradient,
    this.bufferProgress,
  });

  final Gradient gradient;
  final double? bufferProgress;

  @override
  void paint(
    PaintingContext context,
    Offset offset, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    Offset? secondaryOffset,
    bool isDiscrete = false,
    bool isEnabled = false,
  }) {
    // If the slider track height is less than or equal to 0, it shouldn't be painted.
    if (sliderTheme.trackHeight == null || sliderTheme.trackHeight! <= 0) {
      return;
    }

    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    // BUG-FIX: Force the track to use the FULL width of the parentBox
    // by overriding the default 24px margin in RectangularSliderTrackShape.
    final Rect fullWidthRect = Rect.fromLTWH(
      offset.dx,
      trackRect.top,
      parentBox.size.width,
      trackRect.height,
    );

    final Radius radius = Radius.circular(fullWidthRect.height / 2);
    final RRect fullTrackRRect = RRect.fromRectAndRadius(fullWidthRect, radius);

    final Paint activePaint = Paint()..shader = gradient.createShader(fullWidthRect);
    final Paint inactivePaint = Paint()..color = sliderTheme.inactiveTrackColor!;
    final Paint bufferPaint = Paint()..color = Colors.white30;

    // 1. Draw inactive track (full width)
    context.canvas.drawRRect(fullTrackRRect, inactivePaint);

    // 2. Draw buffer track (clipped)
    if (bufferProgress != null && bufferProgress! > 0) {
      final double bufferDx = fullWidthRect.left + (fullWidthRect.width * bufferProgress!);
      context.canvas.save();
      context.canvas.clipRect(
        Rect.fromLTRB(fullWidthRect.left, fullWidthRect.top, bufferDx, fullWidthRect.bottom),
      );
      context.canvas.drawRRect(fullTrackRRect, bufferPaint);
      context.canvas.restore();
    }

    // 3. Draw active track (clipped)
    if (thumbCenter.dx > fullWidthRect.left) {
      context.canvas.save();
      context.canvas.clipRect(
        Rect.fromLTRB(fullWidthRect.left, fullWidthRect.top, thumbCenter.dx, fullWidthRect.bottom),
      );
      context.canvas.drawRRect(fullTrackRRect, activePaint);
      context.canvas.restore();
    }
  }
}
