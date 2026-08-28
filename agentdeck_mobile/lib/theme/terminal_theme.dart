import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TerminalColors {
  // Pure Black & White Monochrome Master Palette
  static const Color background = Color(0xFF000000);
  static const Color surface = Color(0xFF0C0C0C);
  static const Color surfaceHover = Color(0xFF171717);
  static const Color surfaceElevated = Color(0xFF222222);
  
  // Monochrome Borders
  static const Color cardBorder = Color(0xFF262626);
  static const Color cardBorderLight = Color(0xFF404040);
  static const Color cardBorderGlow = Color(0xFFFFFFFF);
  static const Color titaniumBorder = Color(0xFF2E2E2E);
  static const Color titaniumBorderGlow = Color(0xFFFFFFFF);

  // Stark Pure White & Monochrome Scales (Zero Blue, Zero Green)
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color silver = Color(0xFFE2E8F0);
  static const Color zinc = Color(0xFFA3A3A3);
  static const Color textMuted = Color(0xFF666666);
  static const Color textDark = Color(0xFF171717);

  // Monochromatic Primary Accents
  static const Color cyberCyan = Color(0xFFFFFFFF); // Pure White
  static const Color electricBlue = Color(0xFFE2E8F0); // Titanium Silver
  static const Color iceCyanGlow = Color(0xFFFFFFFF); // Pure White Glow
  static const Color obsidianCard = Color(0xFF0C0C0C);

  // Status Inverted Pills
  static const Color badgeBg = Color(0xFFFFFFFF);
  static const Color badgeText = Color(0xFF000000);
  static const Color badgeBorder = Color(0xFFE5E5E5);
  
  // Monochrome Alerts
  static const Color warning = Color(0xFFE2E8F0);
  static const Color danger = Color(0xFFFFFFFF);

  // Compatibility Mappings
  static const Color neonGreen = Color(0xFFFFFFFF);
  static const Color electricCyan = Color(0xFFFFFFFF);
  static const Color neonAmber = Color(0xFFE2E8F0);
  static const Color neonRed = Color(0xFFFFFFFF);
  static const Color neonPurple = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFA3A3A3);
}

class TerminalTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: TerminalColors.background,
      primaryColor: TerminalColors.pureWhite,
      cardColor: TerminalColors.surface,
      dividerColor: TerminalColors.cardBorder,
      colorScheme: const ColorScheme.dark(
        primary: TerminalColors.pureWhite,
        secondary: TerminalColors.silver,
        surface: TerminalColors.surface,
        error: TerminalColors.pureWhite,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.jetBrainsMono(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: TerminalColors.pureWhite,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.jetBrainsMono(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: TerminalColors.pureWhite,
          letterSpacing: 0.2,
        ),
        titleMedium: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: TerminalColors.pureWhite,
        ),
        bodyLarge: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          color: TerminalColors.pureWhite,
          height: 1.4,
        ),
        bodyMedium: GoogleFonts.jetBrainsMono(
          fontSize: 12,
          color: TerminalColors.zinc,
          height: 1.3,
        ),
        labelSmall: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          color: TerminalColors.textMuted,
          letterSpacing: 0.6,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: TerminalColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: TerminalColors.pureWhite,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(
          color: TerminalColors.pureWhite,
          size: 20,
        ),
        shape: const Border(
          bottom: BorderSide(
            color: TerminalColors.cardBorder,
            width: 1,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: TerminalColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(
            color: TerminalColors.cardBorder,
            width: 1,
          ),
        ),
      ),
      iconTheme: const IconThemeData(
        color: TerminalColors.pureWhite,
      ),
    );
  }
}
