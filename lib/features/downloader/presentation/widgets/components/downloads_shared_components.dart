import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FallbackThumb extends StatelessWidget {
  const FallbackThumb({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      height: 104,
      color: Colors.black26,
      child: const Icon(Icons.broken_image, color: Colors.white24, size: 24),
    );
  }
}

class CountIndicator extends StatelessWidget {
  final IconData icon;
  final int count;
  final bool disabled;

  const CountIndicator({
    super.key,
    required this.icon,
    required this.count,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: disabled ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: disabled ? Colors.white38 : Colors.white, size: 10),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: GoogleFonts.manrope(
              color: disabled ? Colors.white38 : Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
