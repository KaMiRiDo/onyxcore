import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full-screen error state shown when media fails to load.
///
/// Mirrors the `_buildErrorState()` helper originally in
/// `_VideoPreviewWidgetState`. Accepts callbacks to avoid a direct reference
/// to the parent state class.
class VideoErrorState extends StatelessWidget {
  const VideoErrorState({
    required this.errorMessage,
    required this.isStandalone,
    required this.onClose,
    super.key,
  });

  final String errorMessage;
  final bool isStandalone;

  /// Called when the user presses the back/close button.
  final VoidCallback onClose;

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
                    Icons.error_outline_rounded,
                    size: 64,
                    color: Colors.red.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to play media',
                    style: GoogleFonts.manrope(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      errorMessage,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.manrope(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
