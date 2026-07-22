import 'package:flutter/material.dart';
import 'package:onyxcore/core/theme/app_theme.dart';

class VideoSpeedOverlay extends StatelessWidget {
  const VideoSpeedOverlay({
    required this.speed,
    required this.onSpeedChanged,
    super.key,
  });
  final double speed;
  final ValueChanged<double> onSpeedChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 200,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(
            '${speed.toStringAsFixed(2)}x',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                  thumbShape: SliderComponentShape.noThumb,
                  overlayShape: SliderComponentShape.noOverlay,
                  trackShape: _GradientRectSliderTrackShape(),
                ),
                child: Slider(
                  value: speed.clamp(0.25, 4.0),
                  min: 0.25,
                  max: 4,
                  onChanged: onSpeedChanged,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Icon(Icons.speed, color: Colors.white70, size: 16),
        ],
      ),
    );
  }
}

class _GradientRectSliderTrackShape extends SliderTrackShape
    with BaseSliderTrackShape {
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
    double additionalActiveTrackHeight = 0,
  }) {
    final trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    const activeGradient = AppTheme.primaryGradient;

    final activePaint = Paint()
      ..shader = activeGradient.createShader(trackRect);
    final inactivePaint = Paint()..color = sliderTheme.inactiveTrackColor!;

    final trackRadius = trackRect.height / 2;

    // Paint inactive track
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, Radius.circular(trackRadius)),
      inactivePaint,
    );

    // Paint active track
    final activeRect = Rect.fromLTRB(
      trackRect.left,
      trackRect.top,
      thumbCenter.dx,
      trackRect.bottom,
    );

    context.canvas.drawRRect(
      RRect.fromRectAndRadius(activeRect, Radius.circular(trackRadius)),
      activePaint,
    );
  }
}
