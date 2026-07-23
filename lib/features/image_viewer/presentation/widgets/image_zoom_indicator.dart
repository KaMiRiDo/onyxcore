import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable widget for displaying the current zoom level percentage.
class ImageZoomIndicator extends StatelessWidget {
  final double scale;

  const ImageZoomIndicator({
    required this.scale,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.1,
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: 10,
            sigmaY: 10,
          ),
          child: Text(
            '${(scale * 100).toInt()}%',
            style: GoogleFonts.outfit(
              color: Colors.white.withValues(
                alpha: 0.9,
              ),
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
