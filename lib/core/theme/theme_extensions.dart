import 'package:flutter/material.dart';

class DesignSystemExtension extends ThemeExtension<DesignSystemExtension> {
  final BoxShadow premiumShadow;
  final BorderSide bentoBorder;
  final Gradient aiGradient;
  final Color aiGlowColor;
  final double cardRadius;
  final double buttonRadius;

  const DesignSystemExtension({
    required this.premiumShadow,
    required this.bentoBorder,
    required this.aiGradient,
    required this.aiGlowColor,
    required this.cardRadius,
    required this.buttonRadius,
  });

  @override
  ThemeExtension<DesignSystemExtension> copyWith({
    BoxShadow? premiumShadow,
    BorderSide? bentoBorder,
    Gradient? aiGradient,
    Color? aiGlowColor,
    double? cardRadius,
    double? buttonRadius,
  }) {
    return DesignSystemExtension(
      premiumShadow: premiumShadow ?? this.premiumShadow,
      bentoBorder: bentoBorder ?? this.bentoBorder,
      aiGradient: aiGradient ?? this.aiGradient,
      aiGlowColor: aiGlowColor ?? this.aiGlowColor,
      cardRadius: cardRadius ?? this.cardRadius,
      buttonRadius: buttonRadius ?? this.buttonRadius,
    );
  }

  @override
  ThemeExtension<DesignSystemExtension> lerp(
    ThemeExtension<DesignSystemExtension>? other,
    double t,
  ) {
    if (other is! DesignSystemExtension) {
      return this;
    }
    return DesignSystemExtension(
      premiumShadow: BoxShadow.lerp(premiumShadow, other.premiumShadow, t)!,
      bentoBorder: BorderSide.lerp(bentoBorder, other.bentoBorder, t),
      aiGradient: Gradient.lerp(aiGradient, other.aiGradient, t)!,
      aiGlowColor: Color.lerp(aiGlowColor, other.aiGlowColor, t)!,
      cardRadius: t < 0.5 ? cardRadius : other.cardRadius,
      buttonRadius: t < 0.5 ? buttonRadius : other.buttonRadius,
    );
  }

  static const DesignSystemExtension light = DesignSystemExtension(
    premiumShadow: BoxShadow(
      color: Color(0x146366F1), // Indigo with 8% opacity (0.08)
      offset: Offset(0, 4),
      blurRadius: 20,
    ),
    bentoBorder: BorderSide(
      color: Color(0xFFF1F5F9),
      width: 1,
    ),
    aiGradient: LinearGradient(
      colors: [Color(0xFF4648D4), Color(0xFF8455EF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    aiGlowColor: Color(0xFF8455EF),
    cardRadius: 16.0,
    buttonRadius: 8.0,
  );
}
