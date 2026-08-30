import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────────────────────
// AnsiParser — full ANSI SGR + Markdown renderer for AgentDeck
// Supports: ANSI colors, ##/###/# headers, ``` code blocks,
//           * / - bullets, > blockquotes, **bold**, *italic*,
//           `inline code`, --- rules, numbered lists (1. 2.)
// ─────────────────────────────────────────────────────────────
class AnsiParser {
  static final RegExp _sgrRegex = RegExp(r'(?:\x1b\[|\b\[)([0-9;]*)m');

  // ── Sanitize: strip all non-SGR terminal control sequences ───────────────
  static String sanitizeRawText(String text) {
    if (text.isEmpty) return '';
    var s = text;

    // OSC sequences: \x1b]0;...\x07 / \x1b]2;...\x1b\  / loose ]0;...
    s = s.replaceAll(RegExp(r'\x1b\][^\x07\x1b\n\r]*(?:\x07|\x1b\\|[\r\n]|$)'), '');
    s = s.replaceAll(RegExp(r'\][0-9]*;[^\x07\x1b\n\r]*(?:\x07|\x1b\\|[\r\n]|$)'), '');

    // ISO-2022 charset: \x1b)0 \x1b(B etc.
    s = s.replaceAll(RegExp(r'\x1b[\(\)\*\+\#\%][0-9A-Za-z]'), '');

    // DCS / APC / PM strings
    s = s.replaceAll(RegExp(r'\x1b[P_^\x58\x5d\x5e\x5f][^\x1b\x07]*(?:\x1b\\|\x07|$)'), '');

    // ALL CSI sequences (full ECMA-48: param bytes 0x30-0x3F, intermediate 0x20-0x2F, final 0x40-0x7E)
    // This strips cursor movement, DEC private modes, kitty keyboard, xterm modifyOtherKeys, etc.
    // but PRESERVES SGR (m) sequences which will be matched separately by _sgrRegex.
    s = s.replaceAll(RegExp(r'\x1b\[[\x30-\x3f]*[\x20-\x2f]*[\x41-\x7e]'), ''); // non-m finals
    // Also strip CSI sequences with > = < ! prefix before m (e.g. \x1b[>4m, \x1b[=1;1u)
    s = s.replaceAll(RegExp(r'\x1b\[[><=!][0-9;]*[a-zA-Z~@]'), '');

    // Single-char escape sequences: \x1b= \x1b> \x1bM etc.
    s = s.replaceAll(RegExp(r'\x1b[=><NOM78EFc\x0f\x0e]'), '');

    // Carriage-return overwrite: keep only last segment per line
    final lines = s.replaceAll('\r\n', '\n').split('\n');
    final cleaned = <String>[];
    for (final line in lines) {
      if (line.contains('\r')) {
        final segs = line.split('\r');
        String effective = '';
        for (int i = segs.length - 1; i >= 0; i--) {
          if (segs[i].trim().isNotEmpty) { effective = segs[i]; break; }
        }
        cleaned.add(effective.isEmpty ? segs.last : effective);
      } else {
        cleaned.add(line);
      }
    }
    s = cleaned.join('\n');

    // Non-printable control chars (keep tab, LF, ESC)
    s = s.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1A\x1C-\x1F]'), '');

    // Collapse 3+ blank lines → max 2
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return s;
  }

  // ── Main parse: ANSI + Markdown ──────────────────────────────────────────
  static List<TextSpan> parse(String text, {double fontSize = 11.5}) {
    if (text.isEmpty) return [];
    final clean = sanitizeRawText(text);
    if (clean.isEmpty) return [];

    final spans = <TextSpan>[];
    final lines = clean.split('\n');
    bool inCodeBlock = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      final isLast = i == lines.length - 1;

      // ── Code fence toggle ───────────────────────────────────────
      if (line.trim().startsWith('```')) {
        inCodeBlock = !inCodeBlock;
        if (!isLast) spans.add(_nl(fontSize));
        continue;
      }

      List<TextSpan> lineSpans;

      if (inCodeBlock) {
        // Code block content
        lineSpans = [TextSpan(
          text: line,
          style: GoogleFonts.jetBrainsMono(
            color: const Color(0xFF51CF66),
            backgroundColor: const Color(0xFF091209),
            fontSize: fontSize - 0.5,
            height: 1.3,
          ),
        )];
      } else if (line == '---' || line == '━━━' || line == '===' || RegExp(r'^-{3,}$').hasMatch(line) || RegExp(r'^={3,}$').hasMatch(line)) {
        // Horizontal rule
        lineSpans = [TextSpan(
          text: '─' * 55,
          style: GoogleFonts.jetBrainsMono(color: const Color(0xFF2D2D2D), fontSize: fontSize - 1, height: 1.3),
        )];
      } else if (line.startsWith('# ')) {
        lineSpans = _header(line.substring(2), fontSize + 2.5, const Color(0xFFFFD43B), underline: true);
      } else if (line.startsWith('## ')) {
        lineSpans = _header(line.substring(3), fontSize + 1.5, const Color(0xFF22D3EE));
      } else if (line.startsWith('### ')) {
        lineSpans = _header(line.substring(4), fontSize + 0.5, const Color(0xFF4DABF7));
      } else if (line.startsWith('#### ')) {
        lineSpans = _header(line.substring(5), fontSize, const Color(0xFFCC5DE8));
      } else if (RegExp(r'^\s*[\*\-•]\s').hasMatch(line)) {
        // Bullet list: * item / - item / • item
        final content = line.replaceFirst(RegExp(r'^\s*[\*\-•]\s+'), '');
        final indent = line.startsWith('  ') ? '    ' : '  ';
        lineSpans = [
          TextSpan(
            text: '$indent• ',
            style: GoogleFonts.jetBrainsMono(color: const Color(0xFF51CF66), fontSize: fontSize, height: 1.35, fontWeight: FontWeight.bold),
          ),
          ..._parseInline(content, fontSize, const Color(0xFFFFFFFF)),
        ];
      } else if (RegExp(r'^\d+\.\s').hasMatch(line)) {
        // Numbered list: 1. item
        final match = RegExp(r'^(\d+)\.\s(.*)').firstMatch(line);
        if (match != null) {
          lineSpans = [
            TextSpan(
              text: '  ${match.group(1)}. ',
              style: GoogleFonts.jetBrainsMono(color: const Color(0xFFFCC419), fontSize: fontSize, height: 1.35, fontWeight: FontWeight.bold),
            ),
            ..._parseInline(match.group(2) ?? '', fontSize, const Color(0xFFFFFFFF)),
          ];
        } else {
          lineSpans = _parseAnsiLine(line, fontSize);
        }
      } else if (line.startsWith('> ')) {
        // Blockquote
        lineSpans = [
          TextSpan(
            text: '  ▌ ',
            style: GoogleFonts.jetBrainsMono(color: const Color(0xFF495057), fontSize: fontSize, height: 1.35),
          ),
          ..._parseInline(line.substring(2), fontSize, const Color(0xFFADB5BD)),
        ];
      } else if (line.startsWith('|') && line.endsWith('|')) {
        // Simple table row
        lineSpans = _tableRow(line, fontSize);
      } else {
        // Regular line: ANSI SGR + inline markdown
        lineSpans = _parseAnsiLine(line, fontSize);
      }

      spans.addAll(lineSpans);
      if (!isLast) spans.add(_nl(fontSize));
    }

    return spans;
  }

  // ── Header builder ───────────────────────────────────────────────────────
  static List<TextSpan> _header(String text, double fontSize, Color color, {bool underline = false}) {
    return [TextSpan(
      text: text,
      style: GoogleFonts.jetBrainsMono(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        height: 1.5,
        decoration: underline ? TextDecoration.underline : TextDecoration.none,
        decorationColor: color.withValues(alpha: 0.4),
      ),
    )];
  }

  // ── Inline markdown: **bold**, *italic*, `code` ──────────────────────────
  static List<TextSpan> _parseInline(String text, double fontSize, Color baseColor) {
    final spans = <TextSpan>[];
    // Pattern: **bold** | *italic* | `code`
    final pattern = RegExp(r'\*\*(.+?)\*\*|\*([^*\n]+?)\*|`([^`]+)`');
    int last = 0;
    for (final m in pattern.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(
          text: text.substring(last, m.start),
          style: _base(fontSize, baseColor),
        ));
      }
      if (m.group(1) != null) {
        // **bold**
        spans.add(TextSpan(
          text: m.group(1),
          style: _base(fontSize, baseColor).copyWith(fontWeight: FontWeight.w900),
        ));
      } else if (m.group(2) != null) {
        // *italic*
        spans.add(TextSpan(
          text: m.group(2),
          style: _base(fontSize, baseColor).copyWith(fontStyle: FontStyle.italic),
        ));
      } else if (m.group(3) != null) {
        // `inline code`
        spans.add(TextSpan(
          text: m.group(3),
          style: GoogleFonts.jetBrainsMono(
            color: const Color(0xFF51CF66),
            backgroundColor: const Color(0xFF0D1A0D),
            fontSize: fontSize - 0.5,
            height: 1.25,
          ),
        ));
      }
      last = m.end;
    }
    if (last < text.length) {
      spans.add(TextSpan(
        text: text.substring(last),
        style: _base(fontSize, baseColor),
      ));
    }
    return spans.isEmpty
        ? [TextSpan(text: text, style: _base(fontSize, baseColor))]
        : spans;
  }

  // ── ANSI SGR line parser (with inline markdown applied) ──────────────────
  static List<TextSpan> _parseAnsiLine(String line, double fontSize) {
    if (line.isEmpty) return [];

    // Check for inline markdown in an otherwise plain line
    final hasMarkdown = line.contains('**') || line.contains('`') ||
        (line.contains('*') && !line.startsWith('* ') && !line.startsWith('- '));

    // If no ANSI codes and has markdown → pure inline markdown parse
    if (!line.contains('\x1b[') && !line.contains('\x1b') && hasMarkdown) {
      return _parseInline(line, fontSize, const Color(0xFFFFFFFF));
    }

    final spans = <TextSpan>[];
    int lastIndex = 0;

    Color currentColor = const Color(0xFFFFFFFF);
    Color? currentBg;
    FontWeight currentWeight = FontWeight.normal;
    FontStyle currentStyle = FontStyle.normal;
    TextDecoration currentDeco = TextDecoration.none;

    for (final match in _sgrRegex.allMatches(line)) {
      if (match.start > lastIndex) {
        final raw = line.substring(lastIndex, match.start);
        if (raw.isNotEmpty) {
          final inlineSpans = hasMarkdown
              ? _parseInline(raw, fontSize, currentColor)
              : [TextSpan(
                  text: raw,
                  style: GoogleFonts.jetBrainsMono(
                    color: currentColor, backgroundColor: currentBg,
                    fontWeight: currentWeight, fontStyle: currentStyle,
                    decoration: currentDeco, fontSize: fontSize, height: 1.25,
                  ),
                )];
          spans.addAll(inlineSpans);
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
              currentColor = const Color(0xFFFFFFFF); currentBg = null;
              currentWeight = FontWeight.normal; currentStyle = FontStyle.normal;
              currentDeco = TextDecoration.none;
              break;
            case 1: currentWeight = FontWeight.w900; break;
            case 2: currentWeight = FontWeight.w300; break;
            case 3: currentStyle = FontStyle.italic; break;
            case 4: currentDeco = TextDecoration.underline; break;
            case 21: case 22: currentWeight = FontWeight.normal; break;
            case 23: currentStyle = FontStyle.normal; break;
            case 24: currentDeco = TextDecoration.none; break;
            // Standard fg colors
            case 30: currentColor = const Color(0xFF495057); break;
            case 31: currentColor = const Color(0xFFFF6B6B); break;
            case 32: currentColor = const Color(0xFF51CF66); break;
            case 33: currentColor = const Color(0xFFFCC419); break;
            case 34: currentColor = const Color(0xFF339AF0); break;
            case 35: currentColor = const Color(0xFFCC5DE8); break;
            case 36: currentColor = const Color(0xFF22D3EE); break;
            case 37: currentColor = const Color(0xFFF8F9FA); break;
            case 38:
              if (i + 2 < codes.length && codes[i + 1] == 5) { currentColor = _get256Color(codes[i + 2]); i += 2; }
              else if (i + 4 < codes.length && codes[i + 1] == 2) { currentColor = Color.fromARGB(255, codes[i + 2], codes[i + 3], codes[i + 4]); i += 4; }
              break;
            case 39: currentColor = const Color(0xFFF8F9FA); break;
            // Bright fg
            case 90: currentColor = const Color(0xFF868E96); break;
            case 91: currentColor = const Color(0xFFFF8787); break;
            case 92: currentColor = const Color(0xFF69DB7C); break;
            case 93: currentColor = const Color(0xFFFFD43B); break;
            case 94: currentColor = const Color(0xFF4DABF7); break;
            case 95: currentColor = const Color(0xFFDA77F2); break;
            case 96: currentColor = const Color(0xFF38D9A9); break;
            case 97: currentColor = const Color(0xFFFFFFFF); break;
            // Background colors
            case 40: currentBg = const Color(0xFF171717); break;
            case 41: case 42: case 43: case 44: case 45: case 46: case 47: currentBg = const Color(0xFF262626); break;
            case 48:
              if (i + 2 < codes.length && codes[i + 1] == 5) { currentBg = _get256Color(codes[i + 2]); i += 2; }
              else if (i + 4 < codes.length && codes[i + 1] == 2) {
                final grey = ((codes[i + 2] * 299 + codes[i + 3] * 587 + codes[i + 4] * 114) ~/ 1000).clamp(0, 80);
                currentBg = Color.fromARGB(255, grey, grey, grey);
                i += 4;
              }
              break;
            case 49: currentBg = null; break;
          }
        }
      }
      lastIndex = match.end;
    }

    if (lastIndex < line.length) {
      final raw = line.substring(lastIndex);
      if (raw.isNotEmpty) {
        final inlineSpans = hasMarkdown
            ? _parseInline(raw, fontSize, currentColor)
            : [TextSpan(
                text: raw,
                style: GoogleFonts.jetBrainsMono(
                  color: currentColor, backgroundColor: currentBg,
                  fontWeight: currentWeight, fontStyle: currentStyle,
                  decoration: currentDeco, fontSize: fontSize, height: 1.25,
                ),
              )];
        spans.addAll(inlineSpans);
      }
    }

    return spans;
  }

  // ── Table row ────────────────────────────────────────────────────────────
  static List<TextSpan> _tableRow(String line, double fontSize) {
    final isHeader = line.contains('---') || line.contains('===');
    if (isHeader) {
      return [TextSpan(
        text: '─' * 55,
        style: GoogleFonts.jetBrainsMono(color: const Color(0xFF2D2D2D), fontSize: fontSize - 1, height: 1.3),
      )];
    }
    final cells = line.split('|').where((c) => c.trim().isNotEmpty).toList();
    final spans = <TextSpan>[];
    for (int i = 0; i < cells.length; i++) {
      spans.add(TextSpan(
        text: ' ${cells[i].trim().padRight(18)} ',
        style: GoogleFonts.jetBrainsMono(
          color: i == 0 ? const Color(0xFF22D3EE) : const Color(0xFFFFFFFF),
          fontSize: fontSize - 0.5,
          height: 1.3,
          fontWeight: i == 0 ? FontWeight.bold : FontWeight.normal,
        ),
      ));
      if (i < cells.length - 1) {
        spans.add(TextSpan(
          text: '│',
          style: GoogleFonts.jetBrainsMono(color: const Color(0xFF2D2D2D), fontSize: fontSize - 0.5, height: 1.3),
        ));
      }
    }
    return spans;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────
  static TextSpan _nl(double fontSize) =>
      TextSpan(text: '\n', style: GoogleFonts.jetBrainsMono(fontSize: fontSize, height: 1.25));

  static TextStyle _base(double fontSize, Color color) => GoogleFonts.jetBrainsMono(
    color: color,
    fontSize: fontSize,
    height: 1.25,
  );

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

// ─────────────────────────────────────────────────────────────
// AnsiTextView widget
// ─────────────────────────────────────────────────────────────
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
      return SelectableText.rich(TextSpan(children: spans));
    }

    return RichText(text: TextSpan(children: spans));
  }
}
