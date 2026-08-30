import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnsiParser {
  // Matches valid ANSI escape sequences strictly (requiring \x1b or bracketed numbers + m)
  static final RegExp _ansiRegex = RegExp(
    r'\x1b(?:'
    r'\[\??([0-9;]*)([a-zA-Z])' // \x1b[0;32m, \x1b[?25h
    r'|\][^\x07\x1b]*(?:\x07|\x1b\\|\n|$)' // \x1b]... OSC
    r'|\([AB012]' // \x1b(B
    r'|[=>NOM78]' // Keypad/cursor modes with \x1b prefix
    r')'
    r'|(?<!\w)\[([0-9]+(?:;[0-9]+)*)m', // bracketed SGR without \x1b, e.g. [0m or [1;37m
  );

  static String sanitizeRawText(String text) {
    if (text.isEmpty) return '';

    // Handle carriage return overwrites per line
    final lines = text.replaceAll('\r\n', '\n').split('\n');
    final cleanLines = <String>[];

    for (var line in lines) {
      if (line.contains('\r')) {
        final segments = line.split('\r');
        String effective = '';
        for (int i = segments.length - 1; i >= 0; i--) {
          final seg = segments[i].trim();
          if (seg.isNotEmpty) {
            effective = segments[i];
            break;
          }
        }
        if (effective.isEmpty && segments.isNotEmpty) {
          effective = segments.last;
        }
        cleanLines.add(effective);
      } else {
        cleanLines.add(line);
      }
    }

    var result = cleanLines.join('\n');

    // Remove any non-printable control characters (preserving tab \x09, newline \x0A, and escape \x1B)
    result = result.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1A\x1C-\x1F]'), '');
    return result;
  }

  static List<TextSpan> parse(String text, {double fontSize = 11.5}) {
    if (text.isEmpty) return [];

    final cleanText = sanitizeRawText(text);
    final List<TextSpan> spans = [];
    int lastIndex = 0;

    Color currentColor = const Color(0xFFFFFFFF); // Pure White Default
    Color? currentBg;
    FontWeight currentWeight = FontWeight.normal;
    FontStyle currentStyle = FontStyle.normal;
    TextDecoration currentDeco = TextDecoration.none;

    for (final match in _ansiRegex.allMatches(cleanText)) {
      if (match.start > lastIndex) {
        final rawText = cleanText.substring(lastIndex, match.start);
        if (rawText.isNotEmpty) {
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
      }

      final codesStr = match.group(1) ?? match.group(3);
      final command = match.group(2) ?? 'm';

      // Only 'm' is Select Graphic Rendition (SGR)
      if (command == 'm' && codesStr != null) {
        if (codesStr.isEmpty || codesStr == '0') {
          currentColor = const Color(0xFFFFFFFF);
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
                currentColor = const Color(0xFFFFFFFF);
                currentBg = null;
                currentWeight = FontWeight.normal;
                currentStyle = FontStyle.normal;
                currentDeco = TextDecoration.none;
                break;
              case 1:
                currentWeight = FontWeight.w900;
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
              case 21:
              case 22:
                currentWeight = FontWeight.normal;
                break;
              case 23:
                currentStyle = FontStyle.normal;
                break;
              case 24:
                currentDeco = TextDecoration.none;
                break;
              case 27:
                // Inverse off
                break;

              // Standard SGR Color Palette (Obsidian Titanium with Vibrant Accents)
              case 30:
                currentColor = const Color(0xFF495057); // Muted Dark Gray
                break;
              case 31:
                currentColor = const Color(0xFFFF6B6B); // Coral Red
                break;
              case 32:
                currentColor = const Color(0xFF51CF66); // Emerald Green Accent
                break;
              case 33:
                currentColor = const Color(0xFFFCC419); // Amber Gold
                break;
              case 34:
                currentColor = const Color(0xFF339AF0); // Neon Sky Blue
                break;
              case 35:
                currentColor = const Color(0xFFCC5DE8); // Vibrant Purple / Magenta
                break;
              case 36:
                currentColor = const Color(0xFF22D3EE); // Electric Cyan Focus
                break;
              case 37:
                currentColor = const Color(0xFFF8F9FA); // Pure Titanium White
                break;
              case 38:
                if (i + 2 < codes.length && codes[i + 1] == 5) {
                  currentColor = _get256Color(codes[i + 2]);
                  i += 2;
                } else if (i + 4 < codes.length && codes[i + 1] == 2) {
                  final r = codes[i + 2];
                  final g = codes[i + 3];
                  final b = codes[i + 4];
                  currentColor = Color.fromARGB(255, r, g, b);
                  i += 4;
                }
                break;
              case 39:
                currentColor = const Color(0xFFF8F9FA);
                break;

              // High-Intensity / Bright Colors
              case 90:
                currentColor = const Color(0xFF868E96); // Slate Gray
                break;
              case 91:
                currentColor = const Color(0xFFFF8787); // Bright Coral
                break;
              case 92:
                currentColor = const Color(0xFF69DB7C); // Bright Mint Green
                break;
              case 93:
                currentColor = const Color(0xFFFFD43B); // Bright Gold
                break;
              case 94:
                currentColor = const Color(0xFF4DABF7); // Bright Sky Blue
                break;
              case 95:
                currentColor = const Color(0xFFDA77F2); // Bright Violet
                break;
              case 96:
                currentColor = const Color(0xFF38D9A9); // Bright Teal / Aqua
                break;
              case 97:
                currentColor = const Color(0xFFFFFFFF); // Pure White
                break;

              // Monochrome Backgrounds
              case 40:
                currentBg = const Color(0xFF171717);
                break;
              case 41:
              case 42:
              case 43:
              case 44:
              case 45:
              case 46:
              case 47:
                currentBg = const Color(0xFF262626);
                break;
              case 48:
                if (i + 2 < codes.length && codes[i + 1] == 5) {
                  currentBg = _get256Color(codes[i + 2]);
                  i += 2;
                } else if (i + 4 < codes.length && codes[i + 1] == 2) {
                  final r = codes[i + 2];
                  final g = codes[i + 3];
                  final b = codes[i + 4];
                  final grey = ((r * 299 + g * 587 + b * 114) ~/ 1000).clamp(0, 80);
                  currentBg = Color.fromARGB(255, grey, grey, grey);
                  i += 4;
                }
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

    if (lastIndex < cleanText.length) {
      final rawText = cleanText.substring(lastIndex);
      if (rawText.isNotEmpty) {
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
    }

    return spans;
  }

  static Color _get256Color(int code) {
    if (code < 16) {
      const basic = [
        Color(0xFF000000), Color(0xFFFF6B6B), Color(0xFF51CF66), Color(0xFFFCC419),
        Color(0xFF339AF0), Color(0xFFCC5DE8), Color(0xFF22D3EE), Color(0xFFF8F9FA),
        Color(0xFF868E96), Color(0xFFFF8787), Color(0xFF69DB7C), Color(0xFFFFD43B),
        Color(0xFF4DABF7), Color(0xFFDA77F2), Color(0xFF38D9A9), Color(0xFFFFFFFF),
      ];
      return basic[code.clamp(0, 15)];
    } else if (code >= 232) {
      final grey = 8 + (code - 232) * 10;
      return Color.fromARGB(255, grey, grey, grey);
    } else {
      final idx = code - 16;
      final r = ((idx ~/ 36) % 6) * 51;
      final g = ((idx ~/ 6) % 6) * 51;
      final b = (idx % 6) * 51;
      return Color.fromARGB(255, r, g, b);
    }
  }
}
