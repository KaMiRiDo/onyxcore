import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full-screen empty state shown when there are no more videos to play.
///
/// Mirrors the `_buildEmptyState()` helper originally in
/// `_VideoPreviewWidgetState`. Uses [Consumer] internally for the sidebar
/// toggle so it rebuilds independently of the player state.
class VideoEmptyState extends StatelessWidget {
  const VideoEmptyState({
    super.key,
    this.isStandalone = false,
    this.onClose,
  });

  final bool isStandalone;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: const Color(0xFF121212),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.videocam_off_rounded,
                    size: 64,
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No video files to play next.',
                    style: GoogleFonts.manrope(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (isStandalone)
          Positioned(
            top: 24,
            left: 24,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: onClose,
                tooltip: 'Close window',
              ),
            ),
          ),
      ],
    );
  }
}
