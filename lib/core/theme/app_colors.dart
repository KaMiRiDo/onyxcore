import 'package:flutter/material.dart';

/// Centralized color palette for the Onyx Monolith design system.
///
/// All colors used across the application should reference this class
/// to ensure visual consistency.
class AppColors {
  const AppColors._();

  // Onyx Monolith Core Palette
  static const Color background = Color(0xFF050505);
  static const Color surfaceBase = Color(0xFF0A0A0A);
  static const Color borderColor = Color(0x26484848);

  // Signature Gradient Colors
  static const Color magenta = Color(0xFFE845C9);
  static const Color violet = Color(0xFF8A3FFC);
  static const Color indigo = Color(0xFF4A25E1);

  // Accent Colors
  static const Color cyan = Color(0xFF00E5FF);
  static const Color teal = Color(0xFF00BCD4);

  // Text Colors
  static const Color textBody = Colors.white;
  static const Color textMuted = Color(0xFF6B7280);

  // Semantic Colors
  static const Color error = Colors.redAccent;
  static const Color success = Colors.greenAccent;

  // Video Player Panel
  static const Color videoPanel = Color(0xFF192229);
}
