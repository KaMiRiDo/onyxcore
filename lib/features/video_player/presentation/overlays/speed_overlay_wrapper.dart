import 'package:flutter/material.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/video_speed_overlay.dart';

/// Animated wrapper for [VideoSpeedOverlay].
///
/// Mirrors the `AnimatedOpacity + StreamBuilder<double> + VideoSpeedOverlay`
/// block originally at lines 2735–2763 of `video_preview_widget.dart`.
///
/// Subscribes to [rateStream] internally so only this widget rebuilds on
/// rate changes.
class SpeedOverlayWrapper extends StatelessWidget {
  const SpeedOverlayWrapper({
    required this.isVisible,
    required this.rateStream,
    required this.currentRate,
    required this.onSpeedChanged,
    super.key,
  });

  final bool isVisible;
  final Stream<double> rateStream;

  /// Fallback value read from `player.state.rate`.
  final double currentRate;
  final ValueChanged<double> onSpeedChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isVisible ? 1.0 : 0.0,
        child: StreamBuilder<double>(
          stream: rateStream,
          builder: (context, snapshot) {
            final rate = snapshot.data ?? currentRate;
            return VideoSpeedOverlay(
              speed: rate,
              onSpeedChanged: onSpeedChanged,
            );
          },
        ),
      ),
    );
  }
}
