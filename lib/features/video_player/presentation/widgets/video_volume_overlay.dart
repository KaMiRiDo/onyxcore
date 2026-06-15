import 'package:flutter/material.dart';
import 'package:onyxcore/core/theme/app_theme.dart';

class VideoVolumeOverlay extends StatelessWidget {
  final double volume;
  final ValueChanged<double> onVolumeChanged;

  const VideoVolumeOverlay({
    required this.volume,
    required this.onVolumeChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 200,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            '${volume.toInt()}%',
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
                  inactiveTrackColor: Colors.white.withOpacity(0.2),
                  thumbShape: SliderComponentShape.noThumb,
                  overlayShape: SliderComponentShape.noOverlay,
                  trackShape: _GradientRectSliderTrackShape(),
                ),
                child: Slider(
                  value: volume.clamp(0.0, 200.0),
                  min: 0,
                  max: 200,
                  onChanged: onVolumeChanged,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Icon(
            volume == 0 ? Icons.volume_off : Icons.volume_up,
            color: Colors.white70,
            size: 16,
          ),
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
    final Rect trackRect = getPreferredRect(
      parentBox: parentBox,
      offset: offset,
      sliderTheme: sliderTheme,
      isEnabled: isEnabled,
      isDiscrete: isDiscrete,
    );

    final activeGradient = AppTheme.primaryGradient;

    final Paint activePaint = Paint()
      ..shader = activeGradient.createShader(trackRect);
    final Paint inactivePaint = Paint()
      ..color = sliderTheme.inactiveTrackColor!;

    final double trackRadius = trackRect.height / 2;

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
