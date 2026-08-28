import 'dart:math';
import 'dart:ui';
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
      duration: const Duration(milliseconds: 260),
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

  Widget _buildPositionedButton({
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
        if (progress <= 0.01) return const SizedBox.shrink();

        final currentDistance = distance * progress;
        // Position relative to bottom-right corner
        final bottomPos = 72.0 + (sin(rad) * currentDistance);
        final rightPos = 18.0 + (cos(rad) * currentDistance);

        return Positioned(
          bottom: bottomPos,
          right: rightPos,
          child: Transform.scale(
            scale: progress.clamp(0.0, 1.0),
            child: Opacity(
              opacity: progress.clamp(0.0, 1.0),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: () {
                    _closeRadial();
                    onTap();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black,
                            border: Border.all(color: color, width: 1.6),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.28),
                                blurRadius: 18,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Icon(icon, color: color, size: 24),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF404040), width: 1.0),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.9),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Text(
                            label,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.0,
                              fontWeight: FontWeight.w900,
                              color: TerminalColors.pureWhite,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
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
    final screenSize = MediaQuery.of(context).size;

    if (_isOpen) {
      return SizedBox(
        width: screenSize.width,
        height: screenSize.height,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            // 1. Frosted Glass Blur Backdrop Overlay
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeRadial,
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
            ),

            // 2. Direct Positioned Floating Action Buttons
            // 1. Vibe Agent (Top-most) - 90 deg, 195px
            _buildPositionedButton(
              angleDeg: 90,
              distance: 195,
              icon: Icons.record_voice_over_rounded,
              label: 'VIBE AGENT',
              color: TerminalColors.pureWhite,
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const VoicePromptModal(),
                );
              },
            ),

            // 2. Machine Remote Control (Screen, Cam, Apps) - 68 deg, 215px
            _buildPositionedButton(
              angleDeg: 68,
              distance: 215,
              icon: Icons.settings_remote_rounded,
              label: 'MACHINE',
              color: TerminalColors.pureWhite,
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const RemoteMachineModal(),
                );
              },
            ),

            // 3. Interactive Terminal PTY - 46 deg, 195px
            _buildPositionedButton(
              angleDeg: 46,
              distance: 195,
              icon: Icons.terminal_rounded,
              label: 'TERMINAL',
              color: TerminalColors.silver,
              onTap: () => widget.onTabSelected(4),
            ),

            // 4. File Uploader - 24 deg, 215px
            _buildPositionedButton(
              angleDeg: 24,
              distance: 215,
              icon: Icons.cloud_upload_rounded,
              label: 'UPLOAD',
              color: TerminalColors.silver,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FileUploaderScreen()),
                );
              },
            ),

            // 5. Google OAuth & Switcher - 0 deg, 195px
            _buildPositionedButton(
              angleDeg: 0,
              distance: 195,
              icon: Icons.manage_accounts_rounded,
              label: 'ACCOUNTS',
              color: TerminalColors.zinc,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AccountSwitcherScreen()),
                );
              },
            ),

            // 3. Bottom Bar
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomBar(),
            ),
          ],
        ),
      );
    }

    // Default Closed State (only renders 64px bottom nav bar)
    return _buildBottomBar();
  }

  Widget _buildBottomBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.black,
        border: const Border(
          top: BorderSide(color: Color(0xFF262626), width: 1.2),
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
          // 4 Core Navigation Tabs
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
                    color: isRotated ? TerminalColors.pureWhite : const Color(0xFF141414),
                    border: Border.all(
                      color: isRotated ? TerminalColors.pureWhite : const Color(0xFF404040),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withValues(alpha: isRotated ? 0.40 : 0.10),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Transform.rotate(
                    angle: _expandAnim.value * (pi / 4),
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
