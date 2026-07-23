import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable widget displaying an empty state when there are no more images to view.
class ImageEmptyState extends StatelessWidget {
  const ImageEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF121212),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_not_supported_rounded,
              size: 64,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            Text(
              'No more images to view.',
              style: GoogleFonts.manrope(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
