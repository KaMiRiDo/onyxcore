import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';

/// Cloud storage section item — pixel-perfect replica of original _buildCloudItem().
class CloudItem extends StatelessWidget {
  const CloudItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: const DecorationImage(
                image: NetworkImage('https://i.pravatar.cc/150?u=alex'),
                fit: BoxFit.cover,
              ),
              border: Border.all(color: Colors.white10, width: 1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Alex Smith",
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
