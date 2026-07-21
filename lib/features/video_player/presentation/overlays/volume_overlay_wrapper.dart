import 'package:flutter/material.dart';
import 'package:onyxcore/features/video_player/presentation/widgets/video_volume_overlay.dart';

/// Animated wrapper for [VideoVolumeOverlay].
///
/// Mirrors the `AnimatedOpacity + StreamBuilder<double> + VideoVolumeOverlay`
/// block originally at lines 2705–2733 of `video_preview_widget.dart`.
///
/// Subscribes to [volumeStream] internally so only this widget rebuilds on
/// volume changes.
class VolumeOverlayWrapper extends StatelessWidget {
  const VolumeOverlayWrapper({
    required this.isVisible,
    required this.volumeStream,
    required this.currentVolume,
    required this.onVolumeChanged,
    super.key,
  });

  final bool isVisible;
  final Stream<double> volumeStream;

  /// Fallback value read from `player.state.volume`.
  final double currentVolume;
  final ValueChanged<double> onVolumeChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isVisible ? 1.0 : 0.0,
        child: StreamBuilder<double>(
          stream: volumeStream,
          builder: (context, snapshot) {
            final vol = snapshot.data ?? currentVolume;
            return VideoVolumeOverlay(
              volume: vol,
              onVolumeChanged: onVolumeChanged,
            );
          },
        ),
      ),
    );
  }
}
