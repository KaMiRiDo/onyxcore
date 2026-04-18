import 'package:flutter/material.dart';

/// A custom slider track shape that paints a gradient for the active track.
class GradientRectSliderTrackShape extends RectangularSliderTrackShape {
  const GradientRectSliderTrackShape({required this.gradient});

  final Gradient gradient;

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

    // The active and inactive track rectangles.
    final Rect activeTrackRect = Rect.fromLTRB(
      trackRect.left,
      trackRect.top,
      thumbCenter.dx,
      trackRect.bottom,
    );
    final Rect inactiveTrackRect = Rect.fromLTRB(
      thumbCenter.dx,
      trackRect.top,
      trackRect.right,
      trackRect.bottom,
    );

    final Paint activePaint = Paint()..shader = gradient.createShader(activeTrackRect);
    final Paint inactivePaint = Paint()..color = sliderTheme.inactiveTrackColor!;

    final Radius radius = Radius.circular(trackRect.height / 2);

    context.canvas.drawRRect(
      RRect.fromRectAndRadius(activeTrackRect, radius),
      activePaint,
    );
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(inactiveTrackRect, radius),
      inactivePaint,
    );
  }
}
