import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Liar's Dice Typography System
/// Gaming-inspired typography with sharp, bold headings
class AppTypography {
  AppTypography._();

  // === FONT FAMILIES ===
  // Using system fonts that work well for gaming UIs
  static const String fontFamily = 'Roboto';
  static const String displayFont = 'Roboto';

  // === DISPLAY STYLES (for big headlines) ===
  static const TextStyle displayLarge = TextStyle(
    fontFamily: displayFont,
    fontSize: 48,
    fontWeight: FontWeight.w900,
    letterSpacing: 4,
    color: AppColors.textPrimary,
    height: 1.1,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: displayFont,
    fontSize: 36,
    fontWeight: FontWeight.w800,
    letterSpacing: 3,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: displayFont,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
    color: AppColors.textPrimary,
    height: 1.2,
  );

  // === HEADLINE STYLES ===
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 1,
    color: AppColors.textPrimary,
  );

  static const TextStyle headlineSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
  );

  // === TITLE STYLES ===
  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.25,
    color: AppColors.textPrimary,
  );

  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.25,
    color: AppColors.textSecondary,
  );

  // === BODY STYLES ===
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.15,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    color: AppColors.textMuted,
    height: 1.4,
  );

  // === LABEL STYLES ===
  static const TextStyle labelLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.5,
    color: AppColors.textPrimary,
  );

  static const TextStyle labelMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.25,
    color: AppColors.textSecondary,
  );

  static const TextStyle labelSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1,
    color: AppColors.textMuted,
  );

  // === GAMING-SPECIFIC STYLES ===
  static const TextStyle gameTitle = TextStyle(
    fontFamily: displayFont,
    fontSize: 32,
    fontWeight: FontWeight.w900,
    letterSpacing: 6,
    color: AppColors.textPrimary,
    shadows: [
      Shadow(
        color: AppColors.primary,
        blurRadius: 20,
      ),
    ],
  );

  static const TextStyle bidNumber = TextStyle(
    fontFamily: displayFont,
    fontSize: 56,
    fontWeight: FontWeight.w900,
    color: AppColors.textPrimary,
    height: 1,
  );

  static const TextStyle eloRating = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 1,
  );

  static const TextStyle playerName = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle phaseLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
  );

  static const TextStyle buttonText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: 2,
  );

  static const TextStyle buttonTextLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: 3,
  );

  // === ANIMATED NUMBER STYLE ===
  static const TextStyle animatedCounter = TextStyle(
    fontFamily: displayFont,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: AppColors.primary,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // === HELPER: Add glow to any text style ===
  static TextStyle withGlow(TextStyle style, Color glowColor) {
    return style.copyWith(
      shadows: [
        Shadow(
          color: glowColor.withOpacity(0.8),
          blurRadius: 10,
        ),
        Shadow(
          color: glowColor.withOpacity(0.5),
          blurRadius: 20,
        ),
      ],
    );
  }

  // === HELPER: Add gradient effect ===
  static ShaderMask gradientText({
    required Widget child,
    required Gradient gradient,
  }) {
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(bounds),
      child: child,
    );
  }
}
