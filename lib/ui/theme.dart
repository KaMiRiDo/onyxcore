import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Onyx Monolith Core Palette
  static const Color background = Color(0xFF050505);
  static const Color surfaceBase = Color(0xFF0A0A0A);
  static const Color borderColor = Color(0x26484848); // rgba(72, 72, 72, 0.15)
  
  // Signature Gradient Colors
  static const Color magenta = Color(0xFFE845C9);
  static const Color violet = Color(0xFF8A3FFC);
  static const Color indigo = Color(0xFF4A25E1);
  
  // Text Colors
  static const Color textBody = Colors.white;
  static const Color textMuted = Color(0xFF6B7280);
  
  // Signature Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [magenta, violet, indigo],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Typography Constants
  static TextStyle get headlineStyle => GoogleFonts.manrope(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.48, // -0.02em
    color: textBody,
  );

  static TextStyle get labelStyle => GoogleFonts.manrope(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.0,
    color: textBody,
  );

  static TextStyle get technicalStyle => GoogleFonts.manrope(
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textMuted,
  );

  static ThemeData get theme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.manropeTextTheme().apply(
        bodyColor: textBody,
        displayColor: textBody,
      ),
      colorScheme: const ColorScheme.dark(
        primary: violet,
        secondary: magenta,
        surface: surfaceBase,
        background: background,
      ),
      iconTheme: const IconThemeData(color: Colors.white70),
    );
  }
}
