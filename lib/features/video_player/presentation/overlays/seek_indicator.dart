import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/features/video_player/presentation/utils/video_player_utils.dart';

/// Large OSD seek-position indicator shown during fast-seek and trackpad scrub.
///
/// Mirrors the `AnimatedOpacity + StreamBuilder<Duration>` seek text block
/// originally at lines 2818–2861 of `video_preview_widget.dart`.
///
/// The caller is responsible for updating [displayPosition] and [totalDuration]
/// from the appropriate stream / virtual state.
class SeekIndicator extends StatelessWidget {
  const SeekIndicator({
    required this.isVisible,
    required this.displayPosition,
    required this.totalDuration,
    super.key,
  });

  final bool isVisible;
  final Duration displayPosition;
  final Duration totalDuration;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isVisible ? 1.0 : 0.0,
      child: Text(
        '${VideoPlayerUtils.formatDuration(displayPosition)} / ${VideoPlayerUtils.formatDuration(totalDuration)}',
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 54,
          fontWeight: FontWeight.w400,
          letterSpacing: 1.5,
          shadows: [
            Shadow(
              offset: const Offset(2, 2),
              blurRadius: 4,
              color: Colors.black.withValues(alpha: 0.8),
            ),
            Shadow(
              offset: const Offset(-1, -1),
              blurRadius: 2,
              color: Colors.black.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
