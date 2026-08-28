import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnsiParser {
  static final RegExp _ansiRegex = RegExp(r'\x1b\[([0-9;]*)([a-zA-Z])');

  static List<TextSpan> parse(String text, {double fontSize = 11.5}) {
    if (text.isEmpty) return [];

    final List<TextSpan> spans = [];
    int lastIndex = 0;

    Color currentColor = const Color(0xFFE5E5E5);
    Color? currentBg;
    FontWeight currentWeight = FontWeight.normal;
    FontStyle currentStyle = FontStyle.normal;
    TextDecoration currentDeco = TextDecoration.none;

    for (final match in _ansiRegex.allMatches(text)) {
      if (match.start > lastIndex) {
        final rawText = text.substring(lastIndex, match.start);
        spans.add(TextSpan(
          text: rawText,
          style: GoogleFonts.jetBrainsMono(
            color: currentColor,
            backgroundColor: currentBg,
            fontWeight: currentWeight,
            fontStyle: currentStyle,
            decoration: currentDeco,
            fontSize: fontSize,
            height: 1.25,
          ),
        ));
      }

      final codesStr = match.group(1) ?? '';
      final command = match.group(2) ?? '';

      if (command == 'm') {
        if (codesStr.isEmpty || codesStr == '0') {
          currentColor = const Color(0xFFE5E5E5);
          currentBg = null;
          currentWeight = FontWeight.normal;
          currentStyle = FontStyle.normal;
          currentDeco = TextDecoration.none;
        } else {
          final codes = codesStr.split(';').map((s) => int.tryParse(s) ?? 0).toList();
          for (int i = 0; i < codes.length; i++) {
            final code = codes[i];
            switch (code) {
              case 0:
                currentColor = const Color(0xFFE5E5E5);
                currentBg = null;
                currentWeight = FontWeight.normal;
                currentStyle = FontStyle.normal;
                currentDeco = TextDecoration.none;
                break;
              case 1:
                currentWeight = FontWeight.bold;
                break;
              case 2:
                currentWeight = FontWeight.w300;
                break;
              case 3:
                currentStyle = FontStyle.italic;
                break;
              case 4:
                currentDeco = TextDecoration.underline;
                break;
              // Normal foreground colors
              case 30:
                currentColor = const Color(0xFF3E3E3E);
                break;
              case 31:
                currentColor = const Color(0xFFFF6B6B);
                break;
              case 32:
                currentColor = const Color(0xFF51CF66);
                break;
              case 33:
                currentColor = const Color(0xFFFCC419);
                break;
              case 34:
                currentColor = const Color(0xFF339AF0);
                break;
              case 35:
                currentColor = const Color(0xFFCC5DE8);
                break;
              case 36:
                currentColor = const Color(0xFF20C997);
                break;
              case 37:
                currentColor = const Color(0xFFF1F3F5);
                break;
              case 39:
                currentColor = const Color(0xFFE5E5E5);
                break;
              // Bright foreground colors
              case 90:
                currentColor = const Color(0xFF868E96);
                break;
              case 91:
                currentColor = const Color(0xFFFF8787);
                break;
              case 92:
                currentColor = const Color(0xFF69DB7C);
                break;
              case 93:
                currentColor = const Color(0xFFFFD43B);
                break;
              case 94:
                currentColor = const Color(0xFF4DABF7);
                break;
              case 95:
                currentColor = const Color(0xFFDA77F2);
                break;
              case 96:
                currentColor = const Color(0xFF38D9A9);
                break;
              case 97:
                currentColor = const Color(0xFFFFFFFF);
                break;
              // Backgrounds
              case 40:
                currentBg = const Color(0xFF1E1E1E);
                break;
              case 41:
                currentBg = const Color(0xFF491212);
                break;
              case 42:
                currentBg = const Color(0xFF123B15);
                break;
              case 43:
                currentBg = const Color(0xFF42380E);
                break;
              case 44:
                currentBg = const Color(0xFF122849);
                break;
              case 45:
                currentBg = const Color(0xFF3B1242);
                break;
              case 46:
                currentBg = const Color(0xFF124238);
                break;
              case 47:
                currentBg = const Color(0xFF3A3A3A);
                break;
              case 49:
                currentBg = null;
                break;
            }
          }
        }
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      final rawText = text.substring(lastIndex);
      spans.add(TextSpan(
        text: rawText,
        style: GoogleFonts.jetBrainsMono(
          color: currentColor,
          backgroundColor: currentBg,
          fontWeight: currentWeight,
          fontStyle: currentStyle,
          decoration: currentDeco,
          fontSize: fontSize,
          height: 1.25,
        ),
      ));
    }

    return spans;
  }
}
