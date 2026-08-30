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
    // Censor IP address e.g. 100.64.0.1 -> 100.•••.•••.1 or http://100.64.0.1:8765 -> http://100.•••.•••.1:8765
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

class AgentDeckMascotThinking extends StatefulWidget {
  final String speechText;
  final double size;
  final VoidCallback? onTap;

  const AgentDeckMascotThinking({
    super.key,
    this.speechText = 'Analyzing repository state & planning tasks...',
    this.size = 110,
    this.onTap,
  });

  @override
  State<AgentDeckMascotThinking> createState() => _AgentDeckMascotThinkingState();
}

class _AgentDeckMascotThinkingState extends State<AgentDeckMascotThinking> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _floatAnim;
  late Animation<double> _bulbPulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );

    _bulbPulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _floatAnim.value),
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.08 * _bulbPulse.value),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/agentdeck_thinking.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'AI AGENT THINKING',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedBuilder(
                        animation: _bulbPulse,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _bulbPulse.value,
                            child: const Icon(Icons.lightbulb, size: 13, color: Color(0xFFFFD43B)),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.speechText,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: TerminalColors.pureWhite,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AgentDeckMascotPointing extends StatefulWidget {
  final String speechText;
  final String buttonText;
  final double size;
  final VoidCallback? onButtonTap;

  const AgentDeckMascotPointing({
    super.key,
    this.speechText = 'Autonomous mission control ready. Dispatch a prompt to begin!',
    this.buttonText = 'PROMPT AGY',
    this.size = 90,
    this.onButtonTap,
  });

  @override
  State<AgentDeckMascotPointing> createState() => _AgentDeckMascotPointingState();
}

class _AgentDeckMascotPointingState extends State<AgentDeckMascotPointing> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _bounceAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _bounceAnim = Tween<double>(begin: 0, end: -4).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _bounceAnim.value),
                child: SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: Image.asset(
                    'assets/images/agentdeck_pointing.png',
                    fit: BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.speechText,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    color: TerminalColors.pureWhite,
                    height: 1.35,
                  ),
                ),
                if (widget.onButtonTap != null) ...[
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TerminalColors.pureWhite,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(80, 30),
                    ),
                    icon: const Icon(Icons.bolt, size: 14),
                    label: Text(
                      widget.buttonText,
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                    onPressed: widget.onButtonTap,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TailscaleRadarPulse extends StatefulWidget {
  final bool isConnected;
  final int? latencyMs;
  final VoidCallback? onTap;

  const TailscaleRadarPulse({
    super.key,
    required this.isConnected,
    this.latencyMs,
    this.onTap,
  });

  @override
  State<TailscaleRadarPulse> createState() => _TailscaleRadarPulseState();
}

class _TailscaleRadarPulseState extends State<TailscaleRadarPulse> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.isConnected ? const Color(0xFF51CF66).withValues(alpha: 0.6) : const Color(0xFF404040),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (widget.isConnected)
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) {
                      return Container(
                        width: 14 * _pulse.value,
                        height: 14 * _pulse.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF51CF66).withValues(alpha: (1.0 - _pulse.value).clamp(0.0, 1.0) * 0.5),
                        ),
                      );
                    },
                  ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.isConnected ? const Color(0xFF51CF66) : TerminalColors.zinc,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            Text(
              widget.isConnected
                  ? (widget.latencyMs != null ? '${widget.latencyMs}ms' : 'TS MESH')
                  : 'TS OFFLINE',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9.5,
                fontWeight: FontWeight.w900,
                color: widget.isConnected ? const Color(0xFF51CF66) : TerminalColors.zinc,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MetricBar extends StatelessWidget {
  final String label;
  final int percent;
  final String? subtitle;

  const MetricBar({
    super.key,
    required this.label,
    required this.percent,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = percent.clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                color: TerminalColors.zinc,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle ?? '$clamped%',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10.5,
                color: TerminalColors.pureWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (clamped / 100.0).clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: clamped > 85
                    ? const Color(0xFFFF6B6B)
                    : (clamped > 60 ? const Color(0xFFFFD43B) : TerminalColors.pureWhite),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
