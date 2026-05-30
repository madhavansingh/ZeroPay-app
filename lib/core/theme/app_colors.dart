import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Theme Colors (Indigo & Violet)
  static const Color primary = Color(0xFF4648D4);
  static const Color primaryContainer = Color(0xFF6063EE);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFFFFBFF);
  
  static const Color secondary = Color(0xFF6B38D4);
  static const Color secondaryContainer = Color(0xFF8455ef);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFFFFFBFF);

  // Tertiary Colors (Success Green)
  static const Color tertiary = Color(0xFF006C49);
  static const Color tertiaryContainer = Color(0xFF00885D);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFF000703);

  // Status & Errors
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Surface & Neutrals (Lumina OS Premium Soft Mode)
  static const Color background = Color(0xFFF8F9FC);
  static const Color onBackground = Color(0xFF191C1E);
  
  static const Color surface = Color(0xFFF8F9FC);
  static const Color surfaceDim = Color(0xFFD9DADD);
  static const Color surfaceBright = Color(0xFFF8F9FC);
  static const Color onSurface = Color(0xFF191C1E);
  static const Color onSurfaceVariant = Color(0xFF464554);

  // Surface Containers (Soft layering depth card system)
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFF2F3F6);
  static const Color surfaceContainer = Color(0xFFEDEEF1);
  static const Color surfaceContainerHigh = Color(0xFFE7E8EB);
  static const Color surfaceContainerHighest = Color(0xFFE1E2E5);

  // Outlines & Borders
  static const Color outline = Color(0xFF767586);
  static const Color outlineVariant = Color(0xFFC7C4D7);

  // AI Glow Gradients
  static const List<Color> aiGradient = [
    Color(0xFF4648D4),
    Color(0xFF8455EF),
  ];

  static const Color aiGlowColor = Color(0xFF8455EF);
}
