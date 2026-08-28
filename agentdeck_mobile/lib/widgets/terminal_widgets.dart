import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/terminal_theme.dart';

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
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: TerminalColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor ?? TerminalColors.cardBorder,
            width: borderColor != null ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: TerminalColors.cardBorder, width: 1),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: TerminalColors.neonGreen,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          title!.toUpperCase(),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: TerminalColors.neonGreen,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                    if (trailing != null) trailing!,
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
    this.speed = const Duration(milliseconds: 20),
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
      style: widget.style ?? GoogleFonts.jetBrainsMono(color: TerminalColors.textPrimary),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'running':
      case 'executing':
      case 'online':
      case 'healthy':
        color = TerminalColors.neonGreen;
        break;
      case 'awaiting_approval':
      case 'waiting':
      case 'paused':
        color = TerminalColors.neonAmber;
        break;
      case 'failed':
      case 'crashed':
      case 'stopped':
      case 'error':
        color = TerminalColors.neonRed;
        break;
      default:
        color = TerminalColors.electricCyan;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withOpacity(0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.8),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            status.toUpperCase(),
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
        ],
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
              color: TerminalColors.neonGreen,
              fontSize: 12,
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
            color: TerminalColors.neonGreen,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
