import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/api_service.dart';
import '../services/workstation_manager.dart';
import '../theme/terminal_theme.dart';
import '../widgets/remote_machine_modal.dart';

enum MapMode { darkMatter, cyberRadar }

class FindDeckScreen extends StatefulWidget {
  const FindDeckScreen({super.key});

  @override
  State<FindDeckScreen> createState() => _FindDeckScreenState();
}

class _FindDeckScreenState extends State<FindDeckScreen> with TickerProviderStateMixin {
  final WorkstationManager _wsMgr = WorkstationManager();
  final ApiService _api = ApiService();

  late AnimationController _pulseCtrl;
  late AnimationController _radarCtrl;

  MapMode _currentMapMode = MapMode.darkMatter;
  String? _selectedDeviceId;
  bool _isPlayingSound = false;
  String? _soundStatus;

  // Real OSRM Routing Data
  bool _fetchingRoute = false;
  List<Point<double>> _routePoints = [];
  double _routeDistanceMeters = 0.0;
  double _routeDurationSec = 0.0;
  String _routeSummary = '';
  String _nextTurnInstruction = '';

  // Reference GPS coordinate for Phone (Host User)
  final double _phoneLat = 14.59951;
  final double _phoneLon = 120.98422;

  // Synced fleet coordinates & telemetry
  final Map<String, Map<String, dynamic>> _deviceLocations = {
    'mac-main': {
      'lat': 14.59951,
      'lon': 120.98422,
      'distanceMeters': 1.2,
      'locationDesc': 'Same Room • Desk Workstation',
      'signal': 99,
      'latencyMs': 12,
      'battery': 88,
    },
    'win-darknecrocities': {
      'lat': 14.59972,
      'lon': 120.98448,
      'distanceMeters': 3.8,
      'locationDesc': 'Adjacent Workstation • Rig Station',
      'signal': 94,
      'latencyMs': 16,
      'battery': 100,
    },
  };

  // Map Viewport state (Zoom level 16 for high-detail street layout)
  final double _mapZoom = 16.5;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _radarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat();

    _wsMgr.addListener(_onWorkstationsChanged);
    _selectedDeviceId = _wsMgr.currentWorkstation?.id ?? 'mac-main';

    _fetchOsrmRouteForSelected();
  }

  void _onWorkstationsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _wsMgr.removeListener(_onWorkstationsChanged);
    _pulseCtrl.dispose();
    _radarCtrl.dispose();
    super.dispose();
  }

  // --- OSRM Routing Engine ---
  Future<void> _fetchOsrmRouteForSelected() async {
    final workstations = _wsMgr.workstations;
    final selectedWs = workstations.firstWhere(
      (w) => w.id == _selectedDeviceId,
      orElse: () => workstations.isNotEmpty
          ? workstations.first
          : Workstation(id: 'mac-main', name: 'MacBook Air', os: 'macOS', endpoint: 'http://127.0.0.1:8765'),
    );

    final telemetry = _deviceLocations[selectedWs.id] ??
        {
          'lat': 14.59972,
          'lon': 120.98448,
        };

    final targetLat = telemetry['lat'] as double? ?? 14.59972;
    final targetLon = telemetry['lon'] as double? ?? 120.98448;

    setState(() => _fetchingRoute = true);

    try {
      final url = Uri.parse(
        'http://router.project-osrm.org/route/v1/driving/$_phoneLon,$_phoneLat;$targetLon,$targetLat?overview=full&geometries=geojson&steps=true',
      );

      final res = await http.get(url).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final primaryRoute = routes.first as Map<String, dynamic>;
          final geom = primaryRoute['geometry'] as Map<String, dynamic>?;
          final coords = geom?['coordinates'] as List<dynamic>? ?? [];

          final points = coords.map((c) {
            final lon = (c[0] as num).toDouble();
            final lat = (c[1] as num).toDouble();
            return Point<double>(lon, lat);
          }).toList();

          final distance = (primaryRoute['distance'] as num?)?.toDouble() ?? 0.0;
          final duration = (primaryRoute['duration'] as num?)?.toDouble() ?? 0.0;

          // Extract first maneuver step
          String nextStep = 'Proceed to target deck';
          final legs = primaryRoute['legs'] as List<dynamic>?;
          if (legs != null && legs.isNotEmpty) {
            final steps = legs.first['steps'] as List<dynamic>?;
            if (steps != null && steps.length > 1) {
              final maneuver = steps[1]['maneuver'] as Map<String, dynamic>?;
              final streetName = steps[1]['name'] as String? ?? '';
              final mod = maneuver?['modifier'] as String? ?? 'straight';
              nextStep = 'Turn $mod ${streetName.isNotEmpty ? "on $streetName" : "towards destination"}';
            }
          }

          if (mounted) {
            setState(() {
              _routePoints = points;
              _routeDistanceMeters = distance;
              _routeDurationSec = duration;
              _routeSummary = primaryRoute['summary'] as String? ?? 'Direct Route';
              _nextTurnInstruction = nextStep;
              _fetchingRoute = false;
            });
            return;
          }
        }
      }
    } catch (_) {}

    // Fallback direct straight route if offline or OSRM timeout
    if (mounted) {
      setState(() {
        _routePoints = [
          Point<double>(_phoneLon, _phoneLat),
          Point<double>(targetLon, targetLat),
        ];
        _routeDistanceMeters = _calculateHaversineDistance(_phoneLat, _phoneLon, targetLat, targetLon);
        _routeDurationSec = _routeDistanceMeters / 1.4; // walking speed
        _nextTurnInstruction = 'Direct Proximity Line';
        _fetchingRoute = false;
      });
    }
  }

  double _calculateHaversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000; // meters
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
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

  // --- Web Mercator Map Math ---
  static Point<double> latLonToPixel(double lat, double lon, double zoom) {
    final n = pow(2.0, zoom);
    final x = (lon + 180.0) / 360.0 * n * 256.0;
    final latRad = lat * pi / 180.0;
    final y = (1.0 - (log(tan(latRad) + 1.0 / cos(latRad)) / pi)) / 2.0 * n * 256.0;
    return Point<double>(x, y);
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
          'lat': 14.59972,
          'lon': 120.98448,
          'distanceMeters': 3.8,
          'locationDesc': 'Local Tailscale Network',
          'signal': 95,
          'latencyMs': 14,
          'battery': 90,
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
                  const Icon(Icons.explore_rounded, color: TerminalColors.pureWhite, size: 13),
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
                'DARK MAPS & OSRM',
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Map Style Mode Switcher Button
          IconButton(
            icon: Icon(
              _currentMapMode == MapMode.darkMatter ? Icons.layers_rounded : Icons.radar_rounded,
              color: TerminalColors.pureWhite,
            ),
            tooltip: _currentMapMode == MapMode.darkMatter ? 'Switch to Cyber Radar' : 'Switch to Dark Maps',
            onPressed: () {
              setState(() {
                _currentMapMode = _currentMapMode == MapMode.darkMatter ? MapMode.cyberRadar : MapMode.darkMatter;
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Sync Fleet GPS & Route',
            onPressed: _fetchOsrmRouteForSelected,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Dark Mode Real Map Canvas / Cyber Radar
          Positioned.fill(
            child: _buildMapLayer(workstations, selectedWs),
          ),

          // 2. Top OSRM Navigation HUD Bar
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: _buildNavigationHud(),
          ),

          // 3. Bottom Device Detail Sheet & Telemetry (Fixed Overflow)
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

  // --- Top Navigation & OSRM Route HUD ---
  Widget _buildNavigationHud() {
    final distFormatted = _routeDistanceMeters < 1000
        ? '${_routeDistanceMeters.toStringAsFixed(0)}m'
        : '${(_routeDistanceMeters / 1000).toStringAsFixed(1)}km';

    final durationFormatted = _routeDurationSec < 60
        ? '< 1 min'
        : '${(_routeDurationSec / 60).toStringAsFixed(0)} mins';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF383838), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 14,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: TerminalColors.pureWhite),
            ),
            child: const Icon(Icons.directions_car_rounded, color: TerminalColors.pureWhite, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'OSRM ROUTE: $distFormatted ($durationFormatted)',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: TerminalColors.pureWhite,
                        letterSpacing: 0.4,
                      ),
                    ),
                    if (_fetchingRoute)
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.8, color: TerminalColors.pureWhite),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _nextTurnInstruction.isNotEmpty
                      ? (_routeSummary.isNotEmpty ? '$_nextTurnInstruction • via $_routeSummary' : _nextTurnInstruction)
                      : 'Head towards destination workstation',
                  style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: TerminalColors.zinc),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Map Canvas: Dark Matter Tiles & OSRM Polyline Renderer ---
  Widget _buildMapLayer(List<Workstation> workstations, Workstation selectedWs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenCenter = Offset(constraints.maxWidth / 2, constraints.maxHeight / 2 - 50);

        // Center the Web Mercator projection on mid-point between phone and selected workstation
        final selectedTelemetry = _deviceLocations[selectedWs.id] ?? {'lat': 14.59972, 'lon': 120.98448};
        final targetLat = selectedTelemetry['lat'] as double? ?? 14.59972;
        final targetLon = selectedTelemetry['lon'] as double? ?? 120.98448;

        final centerLat = (_phoneLat + targetLat) / 2.0;
        final centerLon = (_phoneLon + targetLon) / 2.0;

        final centerPixel = latLonToPixel(centerLat, centerLon, _mapZoom);

        return Stack(
          children: [
            // 1. Dark Mode Raster Map Tiles (CartoDB Dark Matter / Inverted OSM)
            if (_currentMapMode == MapMode.darkMatter)
              Positioned.fill(
                child: _buildDarkRasterMap(screenCenter, centerLat, centerLon),
              ),

            // 2. Custom Polyline & Radar Vectors Painter
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_pulseCtrl, _radarCtrl]),
                builder: (context, child) {
                  return CustomPaint(
                    painter: _DarkMapVectorPainter(
                      screenCenter: screenCenter,
                      centerPixel: centerPixel,
                      zoom: _mapZoom,
                      pulseValue: _pulseCtrl.value,
                      radarValue: _radarCtrl.value,
                      routeCoords: _routePoints,
                      isRadarMode: _currentMapMode == MapMode.cyberRadar,
                    ),
                  );
                },
              ),
            ),

            // 3. User Phone Pin (Start Position)
            _buildMapPin(
              lat: _phoneLat,
              lon: _phoneLon,
              centerPixel: centerPixel,
              screenCenter: screenCenter,
              isPhone: true,
              label: 'YOU (THIS PHONE)',
              icon: Icons.phone_android_rounded,
              isSelected: false,
              onTap: null,
            ),

            // 4. Synced Fleet Workstation Pins
            for (final ws in workstations) ...[
              _buildWorkstationMapPin(ws, centerPixel, screenCenter, ws.id == selectedWs.id),
            ],
          ],
        );
      },
    );
  }

  // --- Dark Slippy Map Tile Renderer ---
  Widget _buildDarkRasterMap(Offset screenCenter, double centerLat, double centerLon) {
    final centerTileX = ((centerLon + 180.0) / 360.0 * pow(2.0, _mapZoom)).floor();
    final latRad = centerLat * pi / 180.0;
    final centerTileY = ((1.0 - (log(tan(latRad) + 1.0 / cos(latRad)) / pi)) / 2.0 * pow(2.0, _mapZoom)).floor();

    final zoomInt = _mapZoom.floor();

    return Stack(
      children: [
        for (int dx = -2; dx <= 2; dx++)
          for (int dy = -2; dy <= 2; dy++) ...[
            Builder(
              builder: (context) {
                final tileX = centerTileX + dx;
                final tileY = centerTileY + dy;
                final subdomains = ['a', 'b', 'c', 'd'];
                final sub = subdomains[(tileX + tileY).abs() % subdomains.length];
                final tileUrl = 'https://$sub.basemaps.cartocdn.com/rastertiles/dark_all/$zoomInt/$tileX/$tileY.png';

                // Calculate visual position relative to screen center
                final tilePixelOrigin = Point<double>(tileX * 256.0, tileY * 256.0);
                final centerPixel = latLonToPixel(centerLat, centerLon, _mapZoom);

                final left = screenCenter.dx + (tilePixelOrigin.x - centerPixel.x);
                final top = screenCenter.dy + (tilePixelOrigin.y - centerPixel.y);

                return Positioned(
                  left: left,
                  top: top,
                  width: 256,
                  height: 256,
                  child: Image.network(
                    tileUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(
                      color: const Color(0xFF101010),
                      child: const Center(
                        child: Icon(Icons.map_outlined, size: 24, color: Color(0xFF242424)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
      ],
    );
  }

  Widget _buildWorkstationMapPin(Workstation ws, Point<double> centerPixel, Offset screenCenter, bool isSelected) {
    final telemetry = _deviceLocations[ws.id] ?? {'lat': 14.59972, 'lon': 120.98448, 'distanceMeters': 3.8};
    final lat = telemetry['lat'] as double? ?? 14.59972;
    final lon = telemetry['lon'] as double? ?? 120.98448;
    final dist = telemetry['distanceMeters'] as double? ?? 3.8;

    final isMac = ws.os == 'macOS';
    final icon = isMac ? Icons.laptop_mac_rounded : Icons.desktop_windows_rounded;

    return _buildMapPin(
      lat: lat,
      lon: lon,
      centerPixel: centerPixel,
      screenCenter: screenCenter,
      isPhone: false,
      label: '${dist < 1000 ? "${dist.toStringAsFixed(1)}m" : "${(dist / 1000).toStringAsFixed(1)}km"} • ${ws.name}',
      icon: icon,
      isSelected: isSelected,
      onTap: () {
        setState(() => _selectedDeviceId = ws.id);
        _fetchOsrmRouteForSelected();
      },
    );
  }

  Widget _buildMapPin({
    required double lat,
    required double lon,
    required Point<double> centerPixel,
    required Offset screenCenter,
    required bool isPhone,
    required String label,
    required IconData icon,
    required bool isSelected,
    VoidCallback? onTap,
  }) {
    final targetPixel = latLonToPixel(lat, lon, _mapZoom);
    final pinX = screenCenter.dx + (targetPixel.x - centerPixel.x);
    final pinY = screenCenter.dy + (targetPixel.y - centerPixel.y);

    return Positioned(
      left: pinX - 36,
      top: pinY - 36,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing Pin Icon Marker
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (context, child) {
                final scale = isSelected ? 1.0 + (_pulseCtrl.value * 0.22) : 1.0;

                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: isSelected || isPhone ? 48 : 40,
                    height: isSelected || isPhone ? 48 : 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? const Color(0xFF1F1F1F) : Colors.black,
                      border: Border.all(
                        color: isSelected || isPhone ? TerminalColors.pureWhite : const Color(0xFF707070),
                        width: isSelected || isPhone ? 2.2 : 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: isSelected ? 0.40 : 0.15),
                          blurRadius: isSelected ? 18 : 8,
                          spreadRadius: isSelected ? 2 : 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      color: isSelected || isPhone ? TerminalColors.pureWhite : TerminalColors.silver,
                      size: isSelected || isPhone ? 22 : 18,
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
                    color: Colors.black.withValues(alpha: 0.95),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Text(
                label,
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

  // --- Bottom Detail & Telemetry Card (Overflow Fixed With Expanded) ---
  Widget _buildBottomDeviceCard(Workstation ws, Map<String, dynamic> telemetry) {
    final isMac = ws.os == 'macOS';
    final dist = telemetry['distanceMeters'] as double? ?? 3.8;
    final lat = telemetry['lat'] as double? ?? 14.59972;
    final lon = telemetry['lon'] as double? ?? 120.98448;
    final signal = telemetry['signal'] as int? ?? 94;
    final latency = telemetry['latencyMs'] as int? ?? 16;
    final desc = telemetry['locationDesc'] as String? ?? 'Rig Station';

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

          // Header Row: Device Name, OS & Distance Pill (Protected against RenderFlex overflow)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Device Icon Badge
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

              // Title & Subtitle in Expanded to prevent any horizontal overflow
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      ws.name,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: TerminalColors.pureWhite,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${ws.os} • $desc',
                      style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: TerminalColors.zinc),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Distance Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TerminalColors.pureWhite,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.near_me_rounded, size: 11, color: Colors.black),
                    const SizedBox(width: 4),
                    Text(
                      dist < 1000 ? '${dist.toStringAsFixed(1)}m' : '${(dist / 1000).toStringAsFixed(1)}km',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
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
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w900),
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
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w900),
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
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w900),
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
          style: GoogleFonts.jetBrainsMono(fontSize: 9.0, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite),
        ),
      ],
    );
  }
}

// --- Vector Route & Radar Painter ---
class _DarkMapVectorPainter extends CustomPainter {
  final Offset screenCenter;
  final Point<double> centerPixel;
  final double zoom;
  final double pulseValue;
  final double radarValue;
  final List<Point<double>> routeCoords;
  final bool isRadarMode;

  _DarkMapVectorPainter({
    required this.screenCenter,
    required this.centerPixel,
    required this.zoom,
    required this.pulseValue,
    required this.radarValue,
    required this.routeCoords,
    required this.isRadarMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isRadarMode) {
      // Draw Grid Lines in Cyber Radar Mode
      final gridPaint = Paint()
        ..color = const Color(0xFF1A1A1A)
        ..strokeWidth = 0.8;
      const step = 40.0;
      for (double x = 0; x < size.width; x += step) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0; y < size.height; y += step) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }

      // Concentric Sonar Rings
      final radarPaint = Paint()
        ..color = const Color(0xFF2C2C2C)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;
      for (double r = 60; r <= 300; r += 60) {
        canvas.drawCircle(screenCenter, r, radarPaint);
      }
    }

    // Draw OSRM Road Route Polyline (Glowing Pure White / Silver)
    if (routeCoords.length >= 2) {
      final path = Path();
      for (int i = 0; i < routeCoords.length; i++) {
        final pt = routeCoords[i];
        final px = _FindDeckScreenState.latLonToPixel(pt.y, pt.x, zoom);
        final sx = screenCenter.dx + (px.x - centerPixel.x);
        final sy = screenCenter.dy + (px.y - centerPixel.y);

        if (i == 0) {
          path.moveTo(sx, sy);
        } else {
          path.lineTo(sx, sy);
        }
      }

      // Outer glow for route
      final glowPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, glowPaint);

      // Core route line
      final routePaint = Paint()
        ..color = TerminalColors.pureWhite
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, routePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _DarkMapVectorPainter oldDelegate) => true;
}
