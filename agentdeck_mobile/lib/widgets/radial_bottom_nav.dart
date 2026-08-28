import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/terminal_theme.dart';
import '../screens/file_uploader_screen.dart';
import '../screens/account_switcher_screen.dart';
import 'voice_prompt_modal.dart';

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
                        border: Border.all(color: TerminalColors.cardBorder, width: 0.8),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: TerminalColors.pureWhite,
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
      clipBehavior: Clip.none,
      alignment: Alignment.bottomRight,
      children: [
        // Backdrop Dismiss Overlay
        if (_isOpen)
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeRadial,
              behavior: HitTestBehavior.opaque,
              child: Container(
                color: Colors.black.withValues(alpha: 0.65),
              ),
            ),
          ),

        // Pop-Up Half-Circular Radial Arc Items (Bottom-Right Fan)
        if (_isOpen)
          Positioned(
            right: 24,
            bottom: 84,
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  // 1. Voice Prompter (Top) - 90 deg
                  _buildRadialItem(
                    angleDeg: 90,
                    distance: 145,
                    icon: Icons.mic,
                    label: 'VOICE STT',
                    color: const Color(0xFF51CF66),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const VoicePromptModal(),
                      );
                    },
                  ),

                  // 2. Terminal PTY - 68 deg
                  _buildRadialItem(
                    angleDeg: 68,
                    distance: 140,
                    icon: Icons.terminal,
                    label: 'TERMINAL',
                    color: const Color(0xFF339AF0),
                    onTap: () => widget.onTabSelected(4),
                  ),

                  // 3. File Uploader - 45 deg
                  _buildRadialItem(
                    angleDeg: 45,
                    distance: 135,
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

                  // 4. Accounts & Google Auth - 22 deg
                  _buildRadialItem(
                    angleDeg: 22,
                    distance: 140,
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

                  // 5. Scaffold App - 0 deg (Far right)
                  _buildRadialItem(
                    angleDeg: 0,
                    distance: 145,
                    icon: Icons.add_to_queue,
                    label: 'NEW APP',
                    color: const Color(0xFF20C997),
                    onTap: () => widget.onTabSelected(1),
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
                        color: isRotated ? const Color(0xFF51CF66) : const Color(0xFF141414),
                        border: Border.all(
                          color: isRotated ? const Color(0xFF51CF66) : TerminalColors.cardBorderLight,
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isRotated ? const Color(0xFF51CF66) : Colors.white).withValues(alpha: 0.22),
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
