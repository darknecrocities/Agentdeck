import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TerminalColors {
  static const Color background = Color(0xFF0A0E14);
  static const Color surface = Color(0xFF12161F);
  static const Color surfaceHover = Color(0xFF1A202C);
  static const Color cardBorder = Color(0xFF1E2638);
  static const Color cardBorderGlow = Color(0xFF00FF9D);

  // Accents
  static const Color neonGreen = Color(0xFF00FF9D);
  static const Color electricCyan = Color(0xFF00E5FF);
  static const Color neonAmber = Color(0xFFFFB86C);
  static const Color neonRed = Color(0xFFFF5555);
  static const Color neonPurple = Color(0xFFBD93F9);

  // Typography
  static const Color textPrimary = Color(0xFFE6EDF3);
  static const Color textSecondary = Color(0xFF8B949E);
  static const Color textMuted = Color(0xFF484F58);
}

class TerminalTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: TerminalColors.background,
      primaryColor: TerminalColors.neonGreen,
      cardColor: TerminalColors.surface,
      dividerColor: TerminalColors.cardBorder,
      colorScheme: const ColorScheme.dark(
        primary: TerminalColors.neonGreen,
        secondary: TerminalColors.electricCyan,
        surface: TerminalColors.surface,
        error: TerminalColors.neonRed,
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.jetBrainsMono(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: TerminalColors.textPrimary,
        ),
        titleLarge: GoogleFonts.jetBrainsMono(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: TerminalColors.textPrimary,
        ),
        titleMedium: GoogleFonts.jetBrainsMono(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: TerminalColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.jetBrainsMono(
          fontSize: 14,
          color: TerminalColors.textPrimary,
        ),
        bodyMedium: GoogleFonts.jetBrainsMono(
          fontSize: 13,
          color: TerminalColors.textSecondary,
        ),
        labelSmall: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          color: TerminalColors.textMuted,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: TerminalColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.jetBrainsMono(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: TerminalColors.neonGreen,
        ),
        iconTheme: const IconThemeData(color: TerminalColors.neonGreen),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: TerminalColors.surface,
        selectedItemColor: TerminalColors.neonGreen,
        unselectedItemColor: TerminalColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
