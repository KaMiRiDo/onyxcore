import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Central design system for the OnyxCore application.
///
/// Provides the ThemeData configuration, signature gradient,
/// and typography constants for the Onyx Monolith aesthetic.
class AppTheme {
  const AppTheme._();

  // Signature Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [AppColors.magenta, AppColors.violet, AppColors.indigo],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Typography Constants
  static TextStyle get headlineStyle => GoogleFonts.manrope(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.48,
    color: AppColors.textBody,
  );

  static TextStyle get labelStyle => GoogleFonts.manrope(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
    color: AppColors.textBody,
  );

  static TextStyle get technicalStyle => GoogleFonts.manrope(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: GoogleFonts.manropeTextTheme().apply(
        bodyColor: AppColors.textBody,
        displayColor: AppColors.textBody,
      ),
      colorScheme: const ColorScheme.dark(
        primary: AppColors.violet,
        secondary: AppColors.magenta,
        surface: AppColors.surfaceBase,
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF181818).withOpacity(0.95),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        textStyle: GoogleFonts.manrope(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
