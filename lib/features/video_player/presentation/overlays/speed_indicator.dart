import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';

/// Persistent speed badge shown at the bottom-left when playback rate ≠ 1.0×.
///
/// Mirrors the `StreamBuilder<double>` speed badge block originally at
/// lines 2766–2816 of `video_preview_widget.dart`.
///
/// Subscribes to [rateStream] directly so only this widget rebuilds on
/// rate changes, not the entire player stack.
class SpeedIndicator extends StatelessWidget {
  const SpeedIndicator({
    required this.rateStream,
    required this.currentRate,
    super.key,
  });

  final Stream<double> rateStream;

  /// Current rate read from `player.state.rate` for the initial value.
  final double currentRate;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<double>(
      stream: rateStream,
      builder: (context, snapshot) {
        final rate = snapshot.data ?? currentRate;
        if ((rate - 1.0).abs() < 0.01) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.speed, color: AppColors.violet, size: 14),
              const SizedBox(width: 6),
              Text(
                '${rate.toStringAsFixed(2)}x',
                style: GoogleFonts.manrope(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
