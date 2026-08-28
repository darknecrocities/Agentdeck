import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnsiParser {
  // Matches both standard \x1b[...] and raw bracketed [...m] escape sequences
  static final RegExp _ansiRegex = RegExp(
    r'(?:\x1b|\u001b)?(?:'
    r'\[\??([0-9;]*)([a-zA-Z])' // CSI sequences: e.g. \x1b[0;32m or [1;37m or \x1b[?25h
    r'|\][^\x07\x1b]*(?:\x07|\x1b\\|\n|$)' // OSC sequences
    r'|\([AB012]' // Character sets
    r'|[=>NOM78]' // Keypad/cursor modes
    r')',
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

    // Remove any remaining control characters (preserving tab \x09, newline \x0A, and escape \x1B)
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

      final codesStr = match.group(1);
      final command = match.group(2);

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

              // Pure Black & White Monochrome Palette (No Blue, No Green)
              case 30:
                currentColor = const Color(0xFF525252); // Muted Dark
                break;
              case 31:
                currentColor = const Color(0xFFE2E8F0); // Platinum
                break;
              case 32:
                currentColor = const Color(0xFFFFFFFF); // Pure White Highlight
                break;
              case 33:
                currentColor = const Color(0xFFD4D4D4); // Light Silver
                break;
              case 34:
                currentColor = const Color(0xFFE5E5E5); // Titanium White
                break;
              case 35:
                currentColor = const Color(0xFFCBD5E1); // Silver
                break;
              case 36:
                currentColor = const Color(0xFFFFFFFF); // Pure White Focus
                break;
              case 37:
                currentColor = const Color(0xFFFFFFFF); // Pure White
                break;
              case 38:
                // 256 colors or RGB -> Grayscale
                if (i + 2 < codes.length && codes[i + 1] == 5) {
                  currentColor = _getMonochrome256Color(codes[i + 2]);
                  i += 2;
                } else if (i + 4 < codes.length && codes[i + 1] == 2) {
                  final r = codes[i + 2];
                  final g = codes[i + 3];
                  final b = codes[i + 4];
                  final grey = ((r * 299 + g * 587 + b * 114) ~/ 1000).clamp(60, 255);
                  currentColor = Color.fromARGB(255, grey, grey, grey);
                  i += 4;
                }
                break;
              case 39:
                currentColor = const Color(0xFFFFFFFF);
                break;

              // Bright foreground colors (Pure Monochrome)
              case 90:
                currentColor = const Color(0xFF737373); // Neutral Slate
                break;
              case 91:
                currentColor = const Color(0xFFE5E5E5); // Bright Silver
                break;
              case 92:
                currentColor = const Color(0xFFFFFFFF); // Pure White
                break;
              case 93:
                currentColor = const Color(0xFFF5F5F5); // Bright White
                break;
              case 94:
                currentColor = const Color(0xFFE2E8F0); // Platinum
                break;
              case 95:
                currentColor = const Color(0xFFD4D4D4); // Light Silver
                break;
              case 96:
                currentColor = const Color(0xFFFFFFFF); // Pure White
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
                  currentBg = _getMonochrome256Color(codes[i + 2]);
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

  static Color _getMonochrome256Color(int code) {
    if (code < 16) {
      const basic = [
        Color(0xFF000000), Color(0xFFCBD5E1), Color(0xFFFFFFFF), Color(0xFFE2E8F0),
        Color(0xFFFFFFFF), Color(0xFFD4D4D4), Color(0xFFFFFFFF), Color(0xFFE5E5E5),
        Color(0xFF737373), Color(0xFFE2E8F0), Color(0xFFFFFFFF), Color(0xFFF5F5F5),
        Color(0xFFE2E8F0), Color(0xFFD4D4D4), Color(0xFFFFFFFF), Color(0xFFFFFFFF),
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
      final grey = ((r * 299 + g * 587 + b * 114) ~/ 1000).clamp(40, 255);
      return Color.fromARGB(255, grey, grey, grey);
    }
  }
}
