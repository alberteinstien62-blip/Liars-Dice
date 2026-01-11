import 'package:flutter/material.dart';

/// Liar's Dice Premium Color System
/// Neon gaming aesthetic with cyan accents and deep purple backgrounds
class AppColors {
  AppColors._();

  // === PRIMARY BRAND COLORS ===
  static const Color primary = Color(0xFF00F0FF);      // Neon Cyan
  static const Color primaryDark = Color(0xFF00B8C4);  // Darker Cyan
  static const Color primaryLight = Color(0xFF7FFFFF); // Light Cyan

  static const Color secondary = Color(0xFFFF6B00);    // Neon Orange
  static const Color secondaryLight = Color(0xFFFFAB40);

  static const Color accent = Color(0xFFFFD700);       // Gold
  static const Color accentGlow = Color(0xFFFFF176);   // Light Gold

  // === BACKGROUND COLORS ===
  static const Color backgroundDark = Color(0xFF0A0E1A);    // Near Black
  static const Color backgroundMid = Color(0xFF121829);     // Dark Blue
  static const Color backgroundLight = Color(0xFF1A2140);   // Lighter Blue
  static const Color surface = Color(0xFF1E2745);           // Card Surface
  static const Color surfaceLight = Color(0xFF2A3555);      // Elevated Surface

  // === GAME STATE COLORS ===
  static const Color waiting = Color(0xFF6B7280);      // Grey
  static const Color committing = Color(0xFFFF9500);   // Orange
  static const Color bidding = Color(0xFF00E676);      // Green
  static const Color revealing = Color(0xFFAA00FF);    // Purple
  static const Color roundEnd = Color(0xFF2196F3);     // Blue
  static const Color gameOver = Color(0xFFFF1744);     // Red

  // === STATUS COLORS ===
  static const Color success = Color(0xFF00E676);
  static const Color successGlow = Color(0xFF69F0AE);
  static const Color error = Color(0xFFFF1744);
  static const Color errorGlow = Color(0xFFFF5252);
  static const Color warning = Color(0xFFFFAB00);
  static const Color info = Color(0xFF00B0FF);

  // === TEXT COLORS ===
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0BEC5);
  static const Color textMuted = Color(0xFF78909C);
  static const Color textDisabled = Color(0xFF546E7A);

  // === DICE COLORS ===
  static const Color diceWhite = Color(0xFFFAFAFA);
  static const Color diceDot = Color(0xFF1A1A1A);
  static const Color diceGlow = Color(0xFF00F0FF);
  static const Color diceHidden = Color(0xFF37474F);

  // === ELO RANK COLORS ===
  static const Color eloBronze = Color(0xFFCD7F32);
  static const Color eloSilver = Color(0xFFC0C0C0);
  static const Color eloGold = Color(0xFFFFD700);
  static const Color eloPlatinum = Color(0xFF00E5FF);
  static const Color eloDiamond = Color(0xFFE040FB);

  // === RANK COLOR ALIASES ===
  static const Color bronze = eloBronze;
  static const Color silver = eloSilver;
  static const Color gold = eloGold;
  static const Color platinum = eloPlatinum;
  static const Color diamond = eloDiamond;

  // === GRADIENTS ===
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0A0E1A),
      Color(0xFF121829),
      Color(0xFF1A0A2E),
      Color(0xFF0A0E1A),
    ],
    stops: [0.0, 0.3, 0.7, 1.0],
  );

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, Color(0xFF00B8FF)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, secondary],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00E676), Color(0xFF00C853)],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF1744), Color(0xFFD50000)],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E2745),
      Color(0xFF151B30),
    ],
  );

  // === GLOW EFFECTS ===
  static List<BoxShadow> glowEffect(Color color, {double intensity = 1.0}) {
    return [
      BoxShadow(
        color: color.withOpacity(0.6 * intensity),
        blurRadius: 20 * intensity,
        spreadRadius: 2 * intensity,
      ),
      BoxShadow(
        color: color.withOpacity(0.3 * intensity),
        blurRadius: 40 * intensity,
        spreadRadius: 4 * intensity,
      ),
    ];
  }

  static List<BoxShadow> get primaryGlow => glowEffect(primary);
  static List<BoxShadow> get accentGlowShadow => glowEffect(accent);
  static List<BoxShadow> get successGlowShadow => glowEffect(success);
  static List<BoxShadow> get errorGlowShadow => glowEffect(error);

  // === NEON BORDER ===
  static BoxDecoration neonBorder(Color color, {double width = 2}) {
    return BoxDecoration(
      border: Border.all(color: color, width: width),
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.5),
          blurRadius: 10,
          spreadRadius: 1,
        ),
      ],
    );
  }

  // === ELO COLOR HELPER ===
  static Color getEloColor(int elo) {
    if (elo >= 2000) return eloDiamond;
    if (elo >= 1800) return eloPlatinum;
    if (elo >= 1600) return eloGold;
    if (elo >= 1400) return eloSilver;
    return eloBronze;
  }

  static String getEloRank(int elo) {
    if (elo >= 2000) return 'Diamond';
    if (elo >= 1800) return 'Platinum';
    if (elo >= 1600) return 'Gold';
    if (elo >= 1400) return 'Silver';
    return 'Bronze';
  }
}
