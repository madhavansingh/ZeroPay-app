import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle get displayLarge => GoogleFonts.inter(
        fontSize: 32.0,
        fontWeight: FontWeight.bold,
        height: 1.25,
        letterSpacing: -0.64,
      );

  static TextStyle get headlineMedium => GoogleFonts.inter(
        fontSize: 24.0,
        fontWeight: FontWeight.bold,
        height: 1.33,
        letterSpacing: -0.24,
      );

  static TextStyle get headlineSmall => GoogleFonts.inter(
        fontSize: 20.0,
        fontWeight: FontWeight.w600,
        height: 1.4,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16.0,
        fontWeight: FontWeight.normal,
        height: 1.5,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14.0,
        fontWeight: FontWeight.normal,
        height: 1.43,
      );

  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 12.0,
        fontWeight: FontWeight.w600,
        height: 1.33,
        letterSpacing: 0.12,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 10.0,
        fontWeight: FontWeight.w500,
        height: 1.4,
      );

  // Tabular lining figures style for transaction amounts / number balances
  static TextStyle get tabularNumbers => GoogleFonts.inter(
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
