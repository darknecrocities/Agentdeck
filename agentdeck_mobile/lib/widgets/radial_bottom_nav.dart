import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/terminal_theme.dart';
import '../screens/file_uploader_screen.dart';
import '../screens/account_switcher_screen.dart';
import 'voice_prompt_modal.dart';
import 'remote_machine_modal.dart';

class RadialBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTabSelected;
  final VoidCallback? onScaffoldNewApp;

  const RadialBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.onScaffoldNewApp,
  });

  @override
  State<RadialBottomNav> createState() => _RadialBottomNavState();
}

class _RadialBottomNavState extends State<RadialBottomNav> with SingleTickerProviderStateMixin {
  late AnimationController _radialCtrl;
  late Animation<double> _expandAnim;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _radialCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _expandAnim = CurvedAnimation(
      parent: _radialCtrl,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInBack,
    );
  }

  @override
  void dispose() {
    _radialCtrl.dispose();
    super.dispose();
  }

  void _toggleRadial() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _radialCtrl.forward();
      } else {
        _radialCtrl.reverse();
      }
    });
  }

  void _closeRadial() {
    if (_isOpen) {
      setState(() {
        _isOpen = false;
        _radialCtrl.reverse();
      });
    }
  }

  Widget _buildRadialItem({
    required double angleDeg,
    required double distance,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final rad = angleDeg * (pi / 180.0);

    return AnimatedBuilder(
      animation: _expandAnim,
      builder: (context, child) {
        final progress = _expandAnim.value;
        final currentDistance = distance * progress;
        // Radial offset from bottom right corner
        final dx = -cos(rad) * currentDistance;
        final dy = -sin(rad) * currentDistance;

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: progress.clamp(0.0, 1.0),
            child: Opacity(
              opacity: progress.clamp(0.0, 1.0),
              child: GestureDetector(
                onTap: () {
                  _closeRadial();
                  onTap();
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF141414),
                        border: Border.all(color: color, width: 1.8),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 14,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(icon, color: color, size: 22),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                          color: TerminalColors.pureWhite,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Backdrop overlay to close on outside tap
        if (_isOpen)
          GestureDetector(
            onTap: _closeRadial,
            child: Container(
              color: Colors.black.withValues(alpha: 0.65),
            ),
          ),

        // Pop-Up Half-Circular Radial Arc Items (Bottom-Right Fan)
        if (_isOpen)
          Positioned(
            right: 24,
            bottom: 84,
            child: SizedBox(
              width: 230,
              height: 230,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  // 1. Voice Prompter (Top) - 90 deg
                  _buildRadialItem(
                    angleDeg: 90,
                    distance: 145,
                    icon: Icons.mic,
                    label: 'VOICE STT',
                    color: TerminalColors.cyberCyan,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const VoicePromptModal(),
                      );
                    },
                  ),

                  // 2. Machine Hub (Screen, Webcam, Apps) - 68 deg
                  _buildRadialItem(
                    angleDeg: 68,
                    distance: 140,
                    icon: Icons.settings_remote,
                    label: 'MACHINE',
                    color: const Color(0xFF00E5FF),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const RemoteMachineModal(),
                      );
                    },
                  ),

                  // 3. Terminal PTY - 46 deg
                  _buildRadialItem(
                    angleDeg: 46,
                    distance: 135,
                    icon: Icons.terminal,
                    label: 'TERMINAL',
                    color: const Color(0xFF60A5FA),
                    onTap: () => widget.onTabSelected(4),
                  ),

                  // 4. File Uploader - 24 deg
                  _buildRadialItem(
                    angleDeg: 24,
                    distance: 140,
                    icon: Icons.cloud_upload_outlined,
                    label: 'UPLOAD',
                    color: const Color(0xFFFF922B),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FileUploaderScreen()),
                      );
                    },
                  ),

                  // 5. Accounts & Google Auth - 0 deg (Far right)
                  _buildRadialItem(
                    angleDeg: 0,
                    distance: 145,
                    icon: Icons.manage_accounts,
                    label: 'ACCOUNTS',
                    color: const Color(0xFFCC5DE8),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AccountSwitcherScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

        // Redesigned Futuristic Navigation Bar
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF080808),
            border: const Border(
              top: BorderSide(color: TerminalColors.cardBorder, width: 1.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.9),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            children: [
              // 4 Core Tabs on Left & Center
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavTab(0, Icons.grid_view_rounded, 'DASH'),
                    _buildNavTab(1, Icons.folder_copy_rounded, 'WORKSPACES'),
                    _buildNavTab(2, Icons.smart_toy_rounded, 'AGENTS'),
                    _buildNavTab(3, Icons.access_time_filled_rounded, 'TIMELINE'),
                  ],
                ),
              ),

              const SizedBox(width: 6),

              // Bottom-Right Radial FAB Orb
              GestureDetector(
                onTap: _toggleRadial,
                child: AnimatedBuilder(
                  animation: _expandAnim,
                  builder: (context, child) {
                    final isRotated = _isOpen;

                    return Container(
                      width: 48,
                      height: 48,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isRotated ? TerminalColors.cyberCyan : const Color(0xFF141414),
                        border: Border.all(
                          color: isRotated ? TerminalColors.cyberCyan : TerminalColors.cardBorderLight,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isRotated ? TerminalColors.cyberCyan : Colors.white).withValues(alpha: 0.25),
                            blurRadius: 14,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: Transform.rotate(
                        angle: _expandAnim.value * (pi / 4), // 45 deg rotation into X
                        child: Icon(
                          isRotated ? Icons.close : Icons.apps_rounded,
                          color: isRotated ? Colors.black : TerminalColors.pureWhite,
                          size: 22,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavTab(int index, IconData icon, String label) {
    final isSelected = widget.currentIndex == index;

    return InkWell(
      onTap: () {
        _closeRadial();
        widget.onTabSelected(index);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? TerminalColors.pureWhite : TerminalColors.textMuted,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
                color: isSelected ? TerminalColors.pureWhite : TerminalColors.textMuted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 2),
            if (isSelected)
              Container(
                width: 16,
                height: 2,
                decoration: BoxDecoration(
                  color: TerminalColors.pureWhite,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
