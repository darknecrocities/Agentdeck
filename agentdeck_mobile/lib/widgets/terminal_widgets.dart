import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/terminal_theme.dart';

class AgentDeckLogoHeader extends StatelessWidget {
  final double size;
  final bool showText;

  const AgentDeckLogoHeader({
    super.key,
    this.size = 28,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: TerminalColors.cardBorderLight, width: 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/images/agentdeck.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.white,
              child: const Center(
                child: Icon(Icons.code_rounded, color: Colors.black, size: 16),
              ),
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'AGENTDECK',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: TerminalColors.pureWhite,
                letterSpacing: 0.8,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

class TerminalCard extends StatelessWidget {
  final Widget child;
  final String? title;
  final Widget? trailing;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const TerminalCard({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.borderColor,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        decoration: BoxDecoration(
          color: TerminalColors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: borderColor ?? TerminalColors.cardBorder,
            width: borderColor != null ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: TerminalColors.cardBorder, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: TerminalColors.pureWhite,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              title!.toUpperCase(),
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: TerminalColors.pureWhite,
                                letterSpacing: 0.8,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ],
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

class AnimatedStreamingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final Duration speed;

  const AnimatedStreamingText({
    super.key,
    required this.text,
    this.style,
    this.speed = const Duration(milliseconds: 15),
  });

  @override
  State<AnimatedStreamingText> createState() => _AnimatedStreamingTextState();
}

class _AnimatedStreamingTextState extends State<AnimatedStreamingText> {
  String _displayed = '';
  Timer? _timer;
  int _charIndex = 0;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  @override
  void didUpdateWidget(covariant AnimatedStreamingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    _timer?.cancel();
    _displayed = '';
    _charIndex = 0;
    _timer = Timer.periodic(widget.speed, (timer) {
      if (_charIndex < widget.text.length) {
        setState(() {
          _displayed += widget.text[_charIndex];
          _charIndex++;
        });
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayed,
      style: widget.style ?? GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final isActive = s == 'running' || s == 'executing' || s == 'online' || s == 'healthy';

    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: TerminalColors.pureWhite,
          borderRadius: BorderRadius.circular(3),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              status.toUpperCase(),
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: Colors.black,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: TerminalColors.cardBorderLight, width: 1),
      ),
      child: Text(
        status.toUpperCase(),
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: TerminalColors.zinc,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class AsciiProgressBar extends StatelessWidget {
  final int percent;
  final int totalBlocks;

  const AsciiProgressBar({
    super.key,
    required this.percent,
    this.totalBlocks = 20,
  });

  @override
  Widget build(BuildContext context) {
    final filled = ((percent / 100) * totalBlocks).round().clamp(0, totalBlocks);
    final empty = totalBlocks - filled;
    final bar = '█' * filled + '░' * empty;

    return Row(
      children: [
        Expanded(
          child: Text(
            bar,
            style: GoogleFonts.jetBrainsMono(
              color: TerminalColors.pureWhite,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
            maxLines: 1,
            overflow: TextOverflow.clip,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$percent%',
          style: GoogleFonts.jetBrainsMono(
            color: TerminalColors.pureWhite,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class CensoredEndpointBadge extends StatefulWidget {
  final String text;
  final String prefix;
  final TextStyle? style;
  final bool initiallyHidden;

  const CensoredEndpointBadge({
    super.key,
    required this.text,
    this.prefix = '',
    this.style,
    this.initiallyHidden = true,
  });

  @override
  State<CensoredEndpointBadge> createState() => _CensoredEndpointBadgeState();
}

class _CensoredEndpointBadgeState extends State<CensoredEndpointBadge> {
  late bool _hidden;

  @override
  void initState() {
    super.initState();
    _hidden = widget.initiallyHidden;
  }

  String _censorText(String raw) {
    if (raw.isEmpty) return raw;
    // Censor IP address e.g. 127.0.0.1 -> 100.•••.•••.27 or http://127.0.0.1:8765 -> http://100.•••.•••.27:8765
    return raw.replaceAllMapped(
      RegExp(r'(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})'),
      (match) => '${match[1]}.•••.•••.${match[4]}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayText = _hidden ? _censorText(widget.text) : widget.text;
    final defaultStyle = GoogleFonts.jetBrainsMono(
      fontSize: 10,
      color: TerminalColors.zinc,
      fontWeight: FontWeight.w600,
    );

    return InkWell(
      onTap: () => setState(() => _hidden = !_hidden),
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${widget.prefix}$displayText',
              style: widget.style ?? defaultStyle,
            ),
            const SizedBox(width: 4),
            Icon(
              _hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              size: 13,
              color: _hidden ? TerminalColors.zinc : TerminalColors.pureWhite,
            ),
          ],
        ),
      ),
    );
  }
}
