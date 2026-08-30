import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AnsiParser {
  // Matches standard ANSI SGR (Select Graphic Rendition) styling sequences: e.g. \x1b[1;32m or [0m
  static final RegExp _sgrRegex = RegExp(
    r'(?:\x1b\[|\b\[)([0-9;]*)m',
  );

  static String sanitizeRawText(String text) {
    if (text.isEmpty) return '';

    var sanitized = text;

    // 1. Remove Operating System Command (OSC) sequences: \x1b]0;...\x07 or \x1b]2;...\x1b\\
    sanitized = sanitized.replaceAll(RegExp(r'\x1b\][^\x07\x1b\n\r]*(?:\x07|\x1b\\|[\r\n]|$)'), '');
    // Also remove loose ]0; OSC sequences (Windows ConPTY without leading \x1b)
    sanitized = sanitized.replaceAll(RegExp(r'\][0-9]*;[^\x07\x1b\n\r]*(?:\x07|\x1b\\|[\r\n]|$)'), '');

    // 2. Remove ISO-2022 Character Set Selection: \x1b)0, \x1b(B, \x1b*B, \x1b+0
    sanitized = sanitized.replaceAll(RegExp(r'\x1b[\(\)\*\+\#\%][0-9A-Za-z]'), '');

    // 3. Remove Device Control Strings (DCS), APC, and Privacy Messages
    sanitized = sanitized.replaceAll(RegExp(r'\x1b[P_^\x58\x5d\x5e\x5f][^\x1b\x07]*(?:\x1b\\|\x07|$)'), '');

    // 4. Remove ALL CSI sequences — covers:
    //   Standard:  \x1b[...H, \x1b[...m, \x1b[?25h
    //   DEC/xterm: \x1b[>4m, \x1b[>4;2m  (modifyOtherKeys)
    //   Kitty kbd: \x1b[=0;1u, \x1b[=1;1u  (progressive enhancement)
    //   Plus any   \x1b[...X final byte in 0x40-0x7E
    sanitized = sanitized.replaceAll(
      RegExp(r'\x1b\[[\x30-\x3f]*[\x20-\x2f]*[\x40-\x7e]'),
      '',
    );

    // 5. Remove single character escape sequences: \x1b=, \x1b>, \x1bM, etc.
    sanitized = sanitized.replaceAll(RegExp(r'\x1b[=><NOM78EFc\x0f\x0e]'), '');

    // 6. Handle carriage return overwrites per line (spinners, progress bars)
    final lines = sanitized.replaceAll('\r\n', '\n').split('\n');
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

    sanitized = cleanLines.join('\n');

    // 7. Remove non-printable ASCII control chars except tab (\x09), newline (\x0A), ESC (\x1B)
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1A\x1C-\x1F]'), '');

    // 8. Collapse 3+ consecutive blank lines into 2 max (suppress PTY spam)
    sanitized = sanitized.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return sanitized;
  }

  static List<TextSpan> parse(String text, {double fontSize = 11.5}) {
    if (text.isEmpty) return [];

    final cleanText = sanitizeRawText(text);
    final List<TextSpan> spans = [];
    int lastIndex = 0;

    Color currentColor = const Color(0xFFFFFFFF); // Pure Titanium White Default
    Color? currentBg;
    FontWeight currentWeight = FontWeight.normal;
    FontStyle currentStyle = FontStyle.normal;
    TextDecoration currentDeco = TextDecoration.none;

    for (final match in _sgrRegex.allMatches(cleanText)) {
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

      if (codesStr == null || codesStr.isEmpty || codesStr == '0') {
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
              // 256 colors: 38;5;n or 24-bit RGB: 38;2;r;g;b
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

class AnsiTextView extends StatelessWidget {
  final String text;
  final double fontSize;
  final bool selectable;

  const AnsiTextView({
    super.key,
    required this.text,
    this.fontSize = 11.5,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    final spans = AnsiParser.parse(text, fontSize: fontSize);

    if (spans.isEmpty) {
      return Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          color: const Color(0xFFFFFFFF),
          fontSize: fontSize,
          height: 1.25,
        ),
      );
    }

    if (selectable) {
      return SelectableText.rich(
        TextSpan(children: spans),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
    );
  }
}
