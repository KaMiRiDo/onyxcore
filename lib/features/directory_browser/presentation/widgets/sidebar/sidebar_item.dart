import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:onyxcore/core/theme/app_colors.dart';
import 'package:onyxcore/core/theme/app_theme.dart';

/// Individual sidebar navigation item — pixel-perfect replica of original _buildSidebarItem().
class SidebarItem extends StatelessWidget {
  const SidebarItem({
    required this.icon,
    required this.label,
    required this.path,
    required this.isActive,
    required this.onTap,
    this.progress,
    this.onEject,
    super.key,
  });

  final IconData icon;
  final String label;
  final String path;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onEject;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    Widget labelWidget = isActive
        ? ShaderMask(
            shaderCallback: (bounds) =>
                AppTheme.primaryGradient.createShader(bounds),
            child: Text(
              label,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: Colors.white,
              ),
            ),
          )
        : Text(
            label,
            style: GoogleFonts.manrope(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          );

    Widget content = Row(
      children: [
        isActive
            ? ShaderMask(
                shaderCallback: (bounds) =>
                    AppTheme.primaryGradient.createShader(bounds),
                child: Icon(icon, size: 20, color: Colors.white),
              )
            : Icon(icon, color: AppColors.textMuted, size: 20),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              labelWidget,
              if (progress != null) ...[
                const SizedBox(height: 4),
                Container(
                  height: 3,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress!.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onEject != null)
          IconButton(
            icon: const Icon(Icons.eject_outlined, size: 16, color: AppColors.textMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onEject,
            hoverColor: Colors.white10,
          ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: const BoxDecoration(
            color: Colors.transparent,
          ),
          child: content,
        ),
      ),
    );
  }
}
