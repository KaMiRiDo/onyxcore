import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Reusable widget for image editing controls (brightness, rotation).
class ImageEditingPanel extends StatelessWidget {
  final double rotationAngle;
  final double brightness;
  final ValueChanged<double> onRotationChanged;
  final ValueChanged<double> onBrightnessChanged;

  const ImageEditingPanel({
    required this.rotationAngle,
    required this.brightness,
    required this.onRotationChanged,
    required this.onBrightnessChanged,
    super.key,
  });

  Widget _buildControlLabel(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 14),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.outfit(
            color: Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 200,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildControlLabel(
              Icons.rotate_right,
              'Rotation: ${rotationAngle.toInt()}°',
            ),
            Slider(
              value: rotationAngle,
              min: -180,
              max: 180,
              activeColor: const Color(0xFF00E5FF),
              inactiveColor: Colors.white10,
              onChanged: onRotationChanged,
            ),
            const SizedBox(height: 8),
            _buildControlLabel(Icons.brightness_6, 'Brightness'),
            Slider(
              value: brightness,
              min: -1,
              max: 1, // Max needs to be defined if default is 0.0 to 1.0, wait, the original code had min: -1, and what was max?
              // The original slider didn't specify max, which defaults to 1.0. Let's make it 1.0 explicitly.
              activeColor: const Color(0xFF00E5FF),
              inactiveColor: Colors.white10,
              onChanged: onBrightnessChanged,
            ),
          ],
        ),
      ),
    );
  }
}
