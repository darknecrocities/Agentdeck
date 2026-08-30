import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/workstation_manager.dart';
import '../theme/terminal_theme.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  final List<String> _bootLogs = [];
  double _bootProgress = 0.0;
  bool _readyToNavigate = false;

  final List<String> _diagnosticSteps = [
    'BOOT: Initializing AgentDeck mobile control plane...',
    'NET: Checking encrypted Tailscale WireGuard mesh...',
    'NODES: Loading saved workstation fleet endpoints...',
    'ENGINE: Connecting Antigravity CLI daemon stream...',
    'AUTH: Verifying local session credentials...',
    'READY: Control plane online. Launching dashboard...',
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.05).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );

    _animController.repeat(reverse: true);
    _startBootSequence();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _startBootSequence() async {
    // 1. Parallel initialize background services
    final initFuture = Future.wait([
      WorkstationManager().init(),
      ApiService().initFromPrefs(),
    ]);

    // 2. Play boot animation sequence
    for (int i = 0; i < _diagnosticSteps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 260));
      if (!mounted) return;
      setState(() {
        _bootLogs.add(_diagnosticSteps[i]);
        _bootProgress = (i + 1) / _diagnosticSteps.length;
      });
    }

    await initFuture;
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() => _readyToNavigate = true);
    _proceedToMain();
  }

  void _proceedToMain() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (context, animation, secondaryAnimation) => const MainNavigationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TerminalColors.background,
      body: GestureDetector(
        onTap: () {
          if (_readyToNavigate) {
            _proceedToMain();
          }
        },
        child: SafeArea(
          child: Stack(
            children: [
              // Subtle background scanline / ambient glow
              Positioned.fill(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _glowAnimation,
                    builder: (context, child) {
                      return Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.05 * _glowAnimation.value),
                              blurRadius: 100,
                              spreadRadius: 40,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Main Splash Content
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),

                      // Animated Eagle Branding Logo
                      AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D0D0D),
                                borderRadius: BorderRadius.circular(26),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2 + (0.3 * _glowAnimation.value)),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.12 * _glowAnimation.value),
                                    blurRadius: 24,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Image.asset(
                                  'assets/images/agentdeck.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Brand Title & Tagline
                      Text(
                        'AGENTDECK',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.0,
                          color: TerminalColors.pureWhite,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'AI CODING AGENT CONTROL PLANE',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                          color: TerminalColors.zinc,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Progress Bar
                      Container(
                        width: double.infinity,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1C),
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: _bootProgress.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: TerminalColors.pureWhite,
                              borderRadius: BorderRadius.circular(2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Cyber Terminal Diagnostic Log Box
                      Container(
                        width: double.infinity,
                        height: 120,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF080808),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF1E1E1E)),
                        ),
                        child: ListView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _bootLogs.length,
                          itemBuilder: (context, index) {
                            final log = _bootLogs[index];
                            final isLast = index == _bootLogs.length - 1;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '> ',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: isLast ? TerminalColors.pureWhite : TerminalColors.textMuted,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      log,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9.5,
                                        color: isLast ? TerminalColors.pureWhite : TerminalColors.zinc,
                                        fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      const Spacer(),

                      // Footer status info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF51CF66),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'SECURE TAILSCALE TUNNEL READY',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: TerminalColors.textMuted,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
