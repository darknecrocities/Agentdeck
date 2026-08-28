import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/workstation_manager.dart';
import '../theme/terminal_theme.dart';
import 'file_viewer_modal.dart';

class RemoteMachineModal extends StatefulWidget {
  const RemoteMachineModal({super.key});

  @override
  State<RemoteMachineModal> createState() => _RemoteMachineModalState();
}

class _RemoteMachineModalState extends State<RemoteMachineModal> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final WorkstationManager _wsMgr = WorkstationManager();

  late TabController _tabCtrl;

  // Screen Stream State
  bool _isStreamingScreen = false;
  bool _fetchingScreen = false;
  Uint8List? _screenBytes;
  String? _screenError;
  int _screenFrameCount = 0;
  Timer? _screenStreamTimer;
  int _screenIntervalMs = 250; // ~4 FPS live desktop stream
  final TransformationController _screenTransformCtrl = TransformationController();
  double _screenZoomLevel = 1.0;

  // Webcam Stream State
  bool _isStreamingCam = false;
  bool _fetchingCam = false;
  Uint8List? _camBytes;
  String? _camError;
  int _camFrameCount = 0;
  Timer? _camStreamTimer;
  int _camIntervalMs = 150; // ~7 FPS smooth live webcam stream
  final TransformationController _camTransformCtrl = TransformationController();
  double _camZoomLevel = 1.0;

  // Launch App State
  bool _launching = false;
  String _launchStatus = '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(_onTabChanged);

    _screenTransformCtrl.addListener(() {
      final scale = _screenTransformCtrl.value.getMaxScaleOnAxis();
      if ((scale - _screenZoomLevel).abs() > 0.05) {
        setState(() => _screenZoomLevel = scale);
      }
    });

    _camTransformCtrl.addListener(() {
      final scale = _camTransformCtrl.value.getMaxScaleOnAxis();
      if ((scale - _camZoomLevel).abs() > 0.05) {
        setState(() => _camZoomLevel = scale);
      }
    });
  }

  void _zoomInScreen() {
    final currentScale = _screenTransformCtrl.value.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.4).clamp(1.0, 10.0);
    _screenTransformCtrl.value = Matrix4.diagonal3Values(newScale, newScale, 1.0);
    setState(() => _screenZoomLevel = newScale);
  }

  void _zoomOutScreen() {
    final currentScale = _screenTransformCtrl.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.4).clamp(1.0, 10.0);
    _screenTransformCtrl.value = Matrix4.diagonal3Values(newScale, newScale, 1.0);
    setState(() => _screenZoomLevel = newScale);
  }

  void _resetScreenZoom() {
    _screenTransformCtrl.value = Matrix4.identity();
    setState(() => _screenZoomLevel = 1.0);
  }

  void _handleScreenDoubleTap(TapDownDetails details) {
    if (_screenZoomLevel > 1.2) {
      _resetScreenZoom();
    } else {
      final pos = details.localPosition;
      final matrix = Matrix4.translationValues(-pos.dx * 1.5, -pos.dy * 1.5, 0.0)
        ..multiply(Matrix4.diagonal3Values(2.5, 2.5, 1.0));
      _screenTransformCtrl.value = matrix;
      setState(() => _screenZoomLevel = 2.5);
    }
  }

  void _onTabChanged() {
    if (_tabCtrl.indexIsChanging) return;

    if (_tabCtrl.index == 1) {
      _stopCamStream();
      _startScreenStream();
    } else if (_tabCtrl.index == 2) {
      _stopScreenStream();
      _startCamStream();
    } else {
      _stopScreenStream();
      _stopCamStream();
    }
  }

  @override
  void dispose() {
    _stopScreenStream();
    _stopCamStream();
    _api.stopCamera();
    _screenTransformCtrl.dispose();
    _camTransformCtrl.dispose();
    _tabCtrl.removeListener(_onTabChanged);
    _tabCtrl.dispose();
    super.dispose();
  }

  // --- Screen Live Streaming Engine ---
  void _startScreenStream() {
    if (_isStreamingScreen) return;
    setState(() {
      _isStreamingScreen = true;
      _screenError = null;
    });
    _fetchScreenFrameLoop();
  }

  void _stopScreenStream() {
    _screenStreamTimer?.cancel();
    _screenStreamTimer = null;
    if (mounted && _isStreamingScreen) {
      setState(() => _isStreamingScreen = false);
    }
  }

  Future<void> _fetchScreenFrameLoop() async {
    if (!_isStreamingScreen || !mounted) return;
    if (_fetchingScreen) return;

    _fetchingScreen = true;
    final b64 = await _api.takeScreenshot();
    _fetchingScreen = false;

    if (mounted) {
      if (b64 != null && b64.isNotEmpty) {
        try {
          final bytes = base64Decode(b64);
          setState(() {
            _screenBytes = bytes;
            _screenFrameCount++;
            _screenError = null;
          });
        } catch (_) {
          setState(() => _screenError = 'Failed to decode screen stream frame.');
        }
      } else if (_screenBytes == null) {
        setState(() => _screenError = 'Workstation screen stream unavailable. Ensure permissions are granted.');
      }

      if (_isStreamingScreen) {
        _screenStreamTimer = Timer(Duration(milliseconds: _screenIntervalMs), _fetchScreenFrameLoop);
      }
    }
  }

  // --- Webcam Live Streaming Engine ---
  void _startCamStream() {
    if (_isStreamingCam) return;
    setState(() {
      _isStreamingCam = true;
      _camError = null;
    });
    _fetchCamFrameLoop();
  }

  void _stopCamStream() {
    _camStreamTimer?.cancel();
    _camStreamTimer = null;
    _api.stopCamera();
    if (mounted && _isStreamingCam) {
      setState(() => _isStreamingCam = false);
    }
  }

  Future<void> _fetchCamFrameLoop() async {
    if (!_isStreamingCam || !mounted) return;
    if (_fetchingCam) return;

    _fetchingCam = true;
    final b64 = await _api.takeCameraSnapshot();
    _fetchingCam = false;

    if (mounted) {
      if (b64 != null && b64.isNotEmpty) {
        try {
          final bytes = base64Decode(b64);
          setState(() {
            _camBytes = bytes;
            _camFrameCount++;
            _camError = null;
          });
        } catch (_) {
          setState(() => _camError = 'Failed to decode webcam stream frame.');
        }
      } else if (_camBytes == null) {
        setState(() => _camError = 'Workstation webcam capture unavailable or requires camera permissions/ffmpeg.');
      }

      if (_isStreamingCam) {
        _camStreamTimer = Timer(Duration(milliseconds: _camIntervalMs), _fetchCamFrameLoop);
      }
    }
  }

  // --- App Launcher ---
  Future<void> _launchApp(String appName, {String? customPath, String? customUrl}) async {
    setState(() {
      _launching = true;
      _launchStatus = 'Launching $appName...';
    });

    final res = await _api.launchApp(app: appName, path: customPath, url: customUrl);
    if (mounted) {
      setState(() {
        _launching = false;
        if (res['success'] == true) {
          _launchStatus = '✅ Successfully launched $appName on workstation!';
        } else {
          _launchStatus = '⚠️ ${res['error'] ?? "Failed to launch $appName"}';
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF171717),
          content: Text(_launchStatus, style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.pureWhite)),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showCustomAppDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF404040)),
        ),
        title: Text(
          'LAUNCH CUSTOM APP / COMMAND',
          style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite),
        ),
        content: TextField(
          controller: ctrl,
          style: GoogleFonts.jetBrainsMono(fontSize: 12, color: TerminalColors.pureWhite),
          decoration: InputDecoration(
            hintText: 'e.g. cursor, neovim, htop, calc...',
            hintStyle: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.zinc),
            filled: true,
            fillColor: const Color(0xFF141414),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Color(0xFF262626)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: TerminalColors.pureWhite),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 11)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TerminalColors.pureWhite, foregroundColor: Colors.black),
            onPressed: () {
              final cmd = ctrl.text.trim();
              if (cmd.isNotEmpty) {
                Navigator.pop(ctx);
                _launchApp(cmd);
              }
            },
            child: Text('LAUNCH', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeWs = _wsMgr.activeWorkstation;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.only(top: 14, left: 14, right: 14, bottom: 20),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171717),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: const Color(0xFF404040)),
                    ),
                    child: const Icon(Icons.settings_remote_rounded, color: TerminalColors.pureWhite, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REMOTE WORKSTATION CONTROL',
                        style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: TerminalColors.pureWhite,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        activeWs?.name ?? 'Host Machine',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: TerminalColors.zinc, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tab Bar Controls
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0C0C0C),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: TerminalColors.pureWhite, width: 1.2),
              ),
              labelColor: TerminalColors.pureWhite,
              unselectedLabelColor: TerminalColors.zinc,
              labelStyle: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold),
              unselectedLabelStyle: GoogleFonts.jetBrainsMono(fontSize: 10),
              tabs: const [
                Tab(icon: Icon(Icons.apps_rounded, size: 16), text: 'LAUNCH APPS'),
                Tab(icon: Icon(Icons.desktop_windows_rounded, size: 16), text: 'SCREEN LIVE'),
                Tab(icon: Icon(Icons.videocam_rounded, size: 16), text: 'WEBCAM'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tab Content Views
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildAppsTab(),
                _buildScreenTab(),
                _buildCameraTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppsTab() {
    final activeWs = _wsMgr.activeWorkstation;
    final isWin = activeWs?.os == 'Windows';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'QUICK LAUNCH ON REMOTE WORKSTATION:',
            style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.zinc),
          ),
          const SizedBox(height: 10),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildAppTile(
                icon: Icons.code_rounded,
                name: 'VS Code',
                description: 'Open active workspace in VS Code',
                onTap: () => _launchApp('vscode'),
              ),
              _buildAppTile(
                icon: Icons.auto_awesome,
                name: 'Antigravity IDE',
                description: 'Open current codebase in AGY IDE',
                onTap: () => _launchApp('antigravity'),
              ),
              _buildAppTile(
                icon: Icons.terminal_rounded,
                name: isWin ? 'Windows Terminal' : 'Terminal',
                description: 'Open remote interactive shell',
                onTap: () => _launchApp(isWin ? 'powershell' : 'terminal'),
              ),
              _buildAppTile(
                icon: Icons.folder_open_rounded,
                name: isWin ? 'File Explorer' : 'Finder',
                description: 'Open file explorer in project directory',
                onTap: () => _launchApp('explorer'),
              ),
              _buildAppTile(
                icon: Icons.monitor_heart_rounded,
                name: isWin ? 'Task Manager' : 'Activity Monitor',
                description: 'Open workstation system performance monitor',
                onTap: () => _launchApp('taskmgr'),
              ),
              _buildAppTile(
                icon: Icons.language_rounded,
                name: 'Web Browser',
                description: 'Launch Google Chrome / Default Browser',
                onTap: () => _launchApp('browser', customUrl: 'https://github.com/darknecrocities/Agentdeck'),
              ),
              _buildAppTile(
                icon: Icons.insert_drive_file_outlined,
                name: 'View Remote Cargo.toml',
                description: 'Read and stream project file live',
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const FileViewerModal(),
                  );
                },
              ),
              _buildAppTile(
                icon: Icons.add_circle_outline_rounded,
                name: 'Custom App / CLI',
                description: 'Execute arbitrary application or terminal command',
                onTap: _showCustomAppDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppTile({
    required IconData icon,
    required String name,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _launching ? null : onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: (MediaQuery.of(context).size.width - 40) / 2,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0E0E0E),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF171717),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFF404040)),
                  ),
                  child: Icon(icon, size: 14, color: TerminalColors.pureWhite),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: TerminalColors.pureWhite,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              description,
              style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: TerminalColors.zinc),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenTab() {
    return Column(
      children: [
        // Live Streaming Header Control Bar with Explicit ON/OFF Switch
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isStreamingScreen ? TerminalColors.pureWhite : TerminalColors.zinc,
                    boxShadow: _isStreamingScreen
                        ? [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  _isStreamingScreen ? 'SCREENSHARE: ON (LIVE)' : 'SCREENSHARE: OFF',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: _isStreamingScreen ? TerminalColors.pureWhite : TerminalColors.zinc,
                  ),
                ),
                if (_isStreamingScreen) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171717),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFF404040)),
                    ),
                    child: Text(
                      '#$_screenFrameCount',
                      style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: TerminalColors.zinc),
                    ),
                  ),
                ],
              ],
            ),
            Row(
              children: [
                // Explicit Power Toggle Button (ON / OFF)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isStreamingScreen ? const Color(0xFF1F1F1F) : TerminalColors.pureWhite,
                    foregroundColor: _isStreamingScreen ? TerminalColors.pureWhite : Colors.black,
                    side: BorderSide(color: _isStreamingScreen ? const Color(0xFF404040) : TerminalColors.pureWhite),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: Icon(_isStreamingScreen ? Icons.power_settings_new_rounded : Icons.play_arrow_rounded, size: 14),
                  label: Text(
                    _isStreamingScreen ? 'TURN OFF' : 'TURN ON',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                  onPressed: () {
                    if (_isStreamingScreen) {
                      _stopScreenStream();
                    } else {
                      _startScreenStream();
                    }
                  },
                ),
                const SizedBox(width: 6),
                // Instant One-off Refresh Snapshot Button
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: TerminalColors.pureWhite, size: 18),
                  tooltip: 'Single Snapshot',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => _fetchScreenFrameLoop(),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Live Screen Viewport (Interactive Zoom & Pan)
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: _isStreamingScreen && _screenBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        // Interactive Pinch-to-Zoom & Pan Canvas with Double-tap Zoom
                        Positioned.fill(
                          child: GestureDetector(
                            onDoubleTapDown: _handleScreenDoubleTap,
                            child: InteractiveViewer(
                              transformationController: _screenTransformCtrl,
                              minScale: 1.0,
                              maxScale: 10.0,
                              boundaryMargin: const EdgeInsets.all(300),
                              clipBehavior: Clip.none,
                              child: Center(
                                child: Image.memory(
                                  _screenBytes!,
                                  fit: BoxFit.contain,
                                  gaplessPlayback: true,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Top-Left: Live Stream Overlay Badge
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF404040)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: TerminalColors.pureWhite,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'SCREEN LIVE',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: TerminalColors.pureWhite,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Top-Right: Zoom Multiplier Badge
                        if (_screenZoomLevel > 1.05)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${_screenZoomLevel.toStringAsFixed(1)}x ZOOM',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),

                        // Bottom-Right: Floating Zoom HUD Controls (+ / - / Reset)
                        Positioned(
                          bottom: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF444444)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.8),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Zoom Out
                                IconButton(
                                  icon: const Icon(Icons.remove_rounded, color: TerminalColors.pureWhite, size: 16),
                                  tooltip: 'Zoom Out',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: _zoomOutScreen,
                                ),
                                Container(
                                  height: 14,
                                  width: 1,
                                  color: const Color(0xFF333333),
                                ),
                                // Zoom In
                                IconButton(
                                  icon: const Icon(Icons.add_rounded, color: TerminalColors.pureWhite, size: 16),
                                  tooltip: 'Zoom In',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  onPressed: _zoomInScreen,
                                ),
                                if (_screenZoomLevel > 1.05) ...[
                                  Container(
                                    height: 14,
                                    width: 1,
                                    color: const Color(0xFF333333),
                                  ),
                                  // Reset Zoom
                                  IconButton(
                                    icon: const Icon(Icons.restart_alt_rounded, color: TerminalColors.pureWhite, size: 16),
                                    tooltip: 'Reset Zoom (1.0x)',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    onPressed: _resetScreenZoom,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        // Bottom-Left: Double-tap Gesture Hint (Fades out when zoomed)
                        if (_screenZoomLevel <= 1.05)
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF333333)),
                              ),
                              child: Text(
                                'Double-tap or pinch to zoom',
                                style: GoogleFonts.jetBrainsMono(fontSize: 8, color: TerminalColors.zinc),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isStreamingScreen) ...[
                          const Icon(Icons.desktop_access_disabled_rounded, size: 44, color: TerminalColors.zinc),
                          const SizedBox(height: 12),
                          Text(
                            'Screenshare is currently OFF',
                            style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap the button below to turn on the live desktop stream.',
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TerminalColors.pureWhite,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 16),
                            label: Text('START SCREENSHARE', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w900)),
                            onPressed: _startScreenStream,
                          ),
                        ] else ...[
                          if (_screenError != null)
                            const Icon(Icons.error_outline, size: 36, color: TerminalColors.zinc)
                          else
                            const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: TerminalColors.pureWhite),
                            ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              _screenError ?? 'Connecting to live workstation screen stream...',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                color: TerminalColors.zinc,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraTab() {
    return Column(
      children: [
        // Live Webcam Streaming Header Control Bar with Explicit ON/OFF Switch
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isStreamingCam ? TerminalColors.pureWhite : TerminalColors.zinc,
                    boxShadow: _isStreamingCam
                        ? [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                ),
                const SizedBox(width: 7),
                Text(
                  _isStreamingCam ? 'WEBCAM: ON (LIVE)' : 'WEBCAM: OFF',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    color: _isStreamingCam ? TerminalColors.pureWhite : TerminalColors.zinc,
                  ),
                ),
                if (_isStreamingCam) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171717),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFF404040)),
                    ),
                    child: Text(
                      '#$_camFrameCount',
                      style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: TerminalColors.zinc),
                    ),
                  ),
                ],
              ],
            ),
            Row(
              children: [
                // Explicit Power Toggle Button (ON / OFF)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isStreamingCam ? const Color(0xFF1F1F1F) : TerminalColors.pureWhite,
                    foregroundColor: _isStreamingCam ? TerminalColors.pureWhite : Colors.black,
                    side: BorderSide(color: _isStreamingCam ? const Color(0xFF404040) : TerminalColors.pureWhite),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                  icon: Icon(_isStreamingCam ? Icons.power_settings_new_rounded : Icons.videocam_rounded, size: 14),
                  label: Text(
                    _isStreamingCam ? 'TURN OFF' : 'TURN ON',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w900),
                  ),
                  onPressed: () {
                    if (_isStreamingCam) {
                      _stopCamStream();
                    } else {
                      _startCamStream();
                    }
                  },
                ),
                const SizedBox(width: 6),
                // Instant One-off Refresh Snapshot Button
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: TerminalColors.pureWhite, size: 18),
                  tooltip: 'Single Snapshot',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => _fetchCamFrameLoop(),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Live Webcam Viewport
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: _isStreamingCam && _camBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Image.memory(
                            _camBytes!,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        ),
                        // Live Webcam Overlay Badge
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF404040)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: TerminalColors.pureWhite,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'WEBCAM LIVE',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: TerminalColors.pureWhite,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!_isStreamingCam) ...[
                          const Icon(Icons.videocam_off_rounded, size: 44, color: TerminalColors.zinc),
                          const SizedBox(height: 12),
                          Text(
                            'Webcam is currently OFF',
                            style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Hardware sensor is released and camera indicator LED is off.',
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 14),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TerminalColors.pureWhite,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            ),
                            icon: const Icon(Icons.videocam_rounded, size: 16),
                            label: Text('START WEBCAM FEED', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w900)),
                            onPressed: _startCamStream,
                          ),
                        ] else ...[
                          if (_camError != null)
                            const Icon(Icons.videocam_off_rounded, size: 36, color: TerminalColors.zinc)
                          else
                            const SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2.2, color: TerminalColors.pureWhite),
                            ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              _camError ?? 'Connecting to workstation live webcam feed...',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                color: TerminalColors.zinc,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
