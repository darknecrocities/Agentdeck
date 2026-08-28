import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/workstation_manager.dart';
import '../theme/terminal_theme.dart';
import '../widgets/remote_machine_modal.dart';

class FindDeckScreen extends StatefulWidget {
  const FindDeckScreen({super.key});

  @override
  State<FindDeckScreen> createState() => _FindDeckScreenState();
}

class _FindDeckScreenState extends State<FindDeckScreen> with TickerProviderStateMixin {
  final WorkstationManager _wsMgr = WorkstationManager();
  final ApiService _api = ApiService();

  late AnimationController _radarPulseCtrl;
  late AnimationController _sonarRingCtrl;

  String? _selectedDeviceId;
  bool _isPlayingSound = false;
  String? _soundStatus;

  // Mocked localized telemetry & coordinates for fleet devices relative to phone
  // (Base reference: Phone at 0, 0 local offset)
  final Map<String, Map<String, dynamic>> _deviceLocations = {
    'mac-main': {
      'lat': 14.59951,
      'lon': 120.98422,
      'distanceMeters': 1.2,
      'locationDesc': 'Same Room • Desk / Workspace',
      'signal': 99,
      'latencyMs': 12,
      'battery': 88,
      'offset': const Offset(55, -75), // Visual position on map canvas
    },
    'win-darknecrocities': {
      'lat': 14.59972,
      'lon': 120.98448,
      'distanceMeters': 3.8,
      'locationDesc': 'Adjacent Workstation • Rig Station',
      'signal': 94,
      'latencyMs': 16,
      'battery': 100,
      'offset': const Offset(-80, -110),
    },
  };

  @override
  void initState() {
    super.initState();
    _radarPulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _sonarRingCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    _wsMgr.addListener(_onWorkstationsChanged);
    _selectedDeviceId = _wsMgr.currentWorkstation?.id ?? 'mac-main';
  }

  void _onWorkstationsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _wsMgr.removeListener(_onWorkstationsChanged);
    _radarPulseCtrl.dispose();
    _sonarRingCtrl.dispose();
    super.dispose();
  }

  Future<void> _playSoundOnWorkstation(Workstation ws) async {
    setState(() {
      _isPlayingSound = true;
      _soundStatus = 'Chiming ${ws.name}...';
    });

    try {
      final res = await _api.playSound();
      if (mounted) {
        setState(() {
          _isPlayingSound = false;
          _soundStatus = res['success'] == true ? '🔊 Alert chimed on ${ws.name}!' : '⚠️ Could not play sound.';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF171717),
            content: Text(
              _soundStatus!,
              style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 11),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isPlayingSound = false;
          _soundStatus = '⚠️ Network error.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workstations = _wsMgr.workstations;
    final selectedWs = workstations.firstWhere(
      (w) => w.id == _selectedDeviceId,
      orElse: () => workstations.isNotEmpty
          ? workstations.first
          : Workstation(id: 'mac-main', name: 'MacBook Air', os: 'macOS', endpoint: 'http://127.0.0.1:8765'),
    );

    final telemetry = _deviceLocations[selectedWs.id] ??
        {
          'lat': 14.59951,
          'lon': 120.98422,
          'distanceMeters': 2.5,
          'locationDesc': 'Local Tailscale Network',
          'signal': 95,
          'latencyMs': 14,
          'battery': 90,
          'offset': const Offset(60, -90),
        };

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF171717),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: TerminalColors.pureWhite),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.radar_rounded, color: TerminalColors.pureWhite, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    'FIND DECK',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: TerminalColors.pureWhite,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'LIVE FLEET RADAR & GPS',
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Sync Fleet GPS',
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Cyber Map Grid & Radar Background
          Positioned.fill(
            child: _buildCyberMapCanvas(workstations, selectedWs),
          ),

          // 2. Top Precision Status Pill
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF333333)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.7),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: TerminalColors.pureWhite,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.8),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${workstations.length} FLEET DECKS SYNCED',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: TerminalColors.pureWhite,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'UWB & TAILSCALE GPS',
                    style: GoogleFonts.jetBrainsMono(fontSize: 9, color: TerminalColors.zinc),
                  ),
                ],
              ),
            ),
          ),

          // 3. Bottom Device Detail Sheet & Device Carousel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomDeviceCard(selectedWs, telemetry),
          ),
        ],
      ),
    );
  }

  // --- Cyber Interactive Map Canvas ---
  Widget _buildCyberMapCanvas(List<Workstation> workstations, Workstation selectedWs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final center = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2 - 60);

        return Stack(
          children: [
            // Custom Grid & Radar Ring Background Paint
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_radarPulseCtrl, _sonarRingCtrl]),
                builder: (context, child) {
                  return CustomPaint(
                    painter: _CyberMapPainter(
                      center: center,
                      pulseValue: _radarPulseCtrl.value,
                      sonarValue: _sonarRingCtrl.value,
                      workstationOffsets: workstations.map((w) {
                        final off = _deviceLocations[w.id]?['offset'] as Offset? ?? const Offset(60, -70);
                        return center + off;
                      }).toList(),
                    ),
                  );
                },
              ),
            ),

            // Phone Pin (Center Origin)
            Positioned(
              left: center.dx - 22,
              top: center.dy - 22,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black,
                      border: Border.all(color: TerminalColors.pureWhite, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.4),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.phone_android_rounded, color: TerminalColors.pureWhite, size: 22),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFF404040)),
                    ),
                    child: Text(
                      'YOU (THIS PHONE)',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 7.5,
                        fontWeight: FontWeight.w900,
                        color: TerminalColors.pureWhite,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Workstation Map Pins
            for (final ws in workstations) ...[
              _buildWorkstationPin(ws, center, ws.id == selectedWs.id),
            ],
          ],
        );
      },
    );
  }

  Widget _buildWorkstationPin(Workstation ws, Offset center, bool isSelected) {
    final telemetry = _deviceLocations[ws.id] ??
        {
          'distanceMeters': 2.5,
          'offset': const Offset(60, -70),
        };

    final visualOffset = telemetry['offset'] as Offset? ?? const Offset(60, -70);
    final pinPos = center + visualOffset;
    final dist = telemetry['distanceMeters'] as double? ?? 1.5;

    final isMac = ws.os == 'macOS';
    final icon = isMac ? Icons.laptop_mac_rounded : Icons.desktop_windows_rounded;

    return Positioned(
      left: pinPos.dx - 36,
      top: pinPos.dy - 36,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            _selectedDeviceId = ws.id;
          });
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Outer Pulsing Glow Marker
            AnimatedBuilder(
              animation: _sonarRingCtrl,
              builder: (context, child) {
                final pulseScale = isSelected ? 1.0 + (_sonarRingCtrl.value * 0.25) : 1.0;

                return Transform.scale(
                  scale: pulseScale,
                  child: Container(
                    width: isSelected ? 52 : 44,
                    height: isSelected ? 52 : 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? const Color(0xFF1C1C1C) : Colors.black,
                      border: Border.all(
                        color: isSelected ? TerminalColors.pureWhite : const Color(0xFF666666),
                        width: isSelected ? 2.2 : 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: isSelected ? 0.35 : 0.10),
                          blurRadius: isSelected ? 20 : 8,
                          spreadRadius: isSelected ? 2 : 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? TerminalColors.pureWhite : TerminalColors.silver,
                      size: isSelected ? 24 : 20,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),

            // Distance Tag Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? TerminalColors.pureWhite : Colors.black,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: isSelected ? TerminalColors.pureWhite : const Color(0xFF404040),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.9),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Text(
                '${dist < 1000 ? "${dist.toStringAsFixed(1)}m" : "${(dist / 1000).toStringAsFixed(1)}km"} • ${ws.name}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 8.0,
                  fontWeight: FontWeight.w900,
                  color: isSelected ? Colors.black : TerminalColors.pureWhite,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Bottom Detail & Telemetry Card ---
  Widget _buildBottomDeviceCard(Workstation ws, Map<String, dynamic> telemetry) {
    final isMac = ws.os == 'macOS';
    final dist = telemetry['distanceMeters'] as double? ?? 1.2;
    final lat = telemetry['lat'] as double? ?? 14.59951;
    final lon = telemetry['lon'] as double? ?? 120.98422;
    final signal = telemetry['signal'] as int? ?? 98;
    final latency = telemetry['latencyMs'] as int? ?? 12;
    final desc = telemetry['locationDesc'] as String? ?? 'Local Desk';

    return Container(
      padding: const EdgeInsets.only(top: 14, left: 16, right: 16, bottom: 24),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        border: Border(top: BorderSide(color: Color(0xFF404040), width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black,
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle bar
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF404040),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header Row: Device Name, OS & Distance Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: TerminalColors.pureWhite),
                    ),
                    child: Icon(
                      isMac ? Icons.laptop_mac_rounded : Icons.desktop_windows_rounded,
                      color: TerminalColors.pureWhite,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ws.name,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: TerminalColors.pureWhite,
                        ),
                      ),
                      Text(
                        '${ws.os} • $desc',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: TerminalColors.pureWhite,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.near_me_rounded, size: 12, color: Colors.black),
                    const SizedBox(width: 4),
                    Text(
                      dist < 1000 ? '${dist.toStringAsFixed(1)} METERS' : '${(dist / 1000).toStringAsFixed(1)} KM',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Telemetry Grid Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0C0C0C),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTelemetryItem(Icons.gps_fixed_rounded, 'COORDINATES', '${lat.toStringAsFixed(4)}°N, ${lon.toStringAsFixed(4)}°E'),
                _buildTelemetryItem(Icons.wifi_tethering_rounded, 'SIGNAL / PING', '$signal% • ${latency}ms'),
                _buildTelemetryItem(Icons.lan_outlined, 'TAILSCALE IP', ws.endpoint.replaceAll('http://', '').split(':').first),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons: Play Sound (Chime), Set Active, Remote Machine Control
          Row(
            children: [
              // 1. Play Sound Alert (Audible Finder)
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: TerminalColors.pureWhite,
                    side: const BorderSide(color: TerminalColors.pureWhite, width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: _isPlayingSound
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.volume_up_rounded, size: 16),
                  label: Text(
                    'PLAY SOUND',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.w900),
                  ),
                  onPressed: _isPlayingSound ? null : () => _playSoundOnWorkstation(ws),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Switch Active Workstation Target
              if (!ws.isCurrent)
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF141414),
                      foregroundColor: TerminalColors.pureWhite,
                      side: const BorderSide(color: Color(0xFF404040)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                    label: Text(
                      'CONNECT',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.w900),
                    ),
                    onPressed: () => _wsMgr.switchTo(ws.id),
                  ),
                ),
              if (!ws.isCurrent) const SizedBox(width: 8),

              // 3. Remote Machine Modal (Screen, Cam, Apps)
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TerminalColors.pureWhite,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: const Icon(Icons.settings_remote_rounded, size: 16),
                  label: Text(
                    'REMOTE',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.w900),
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const RemoteMachineModal(),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: TerminalColors.zinc),
            const SizedBox(width: 3),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(fontSize: 8, color: TerminalColors.zinc, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite),
        ),
      ],
    );
  }
}

// --- Custom Cyber Map Background Painter ---
class _CyberMapPainter extends CustomPainter {
  final Offset center;
  final double pulseValue;
  final double sonarValue;
  final List<Offset> workstationOffsets;

  _CyberMapPainter({
    required this.center,
    required this.pulseValue,
    required this.sonarValue,
    required this.workstationOffsets,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF181818)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    // Draw Grid Lines
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw Concentric Radar Circles from Phone Center
    final radarPaint = Paint()
      ..color = const Color(0xFF2B2B2B)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    for (double r = 60; r <= 300; r += 60) {
      canvas.drawCircle(center, r, radarPaint);
    }

    // Draw Expanding Sonar Wave Ring
    final wavePaint = Paint()
      ..color = Colors.white.withValues(alpha: (1.0 - sonarValue) * 0.35)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 40 + (sonarValue * 220), wavePaint);

    // Draw Sweeping Radar Line
    final sweepAngle = pulseValue * 2 * pi;
    final sweepEnd = center + Offset(cos(sweepAngle) * 260, sin(sweepAngle) * 260);
    final sweepPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 1.2;
    canvas.drawLine(center, sweepEnd, sweepPaint);

    // Draw Proximity Connection Lines from Phone to Workstations
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    for (final target in workstationOffsets) {
      canvas.drawLine(center, target, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberMapPainter oldDelegate) => true;
}
