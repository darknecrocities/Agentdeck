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
  Uint8List? _screenBytes;
  bool _loadingScreen = false;
  String? _screenError;

  Uint8List? _camBytes;
  bool _loadingCam = false;
  String? _camError;

  String _launchStatus = '';
  bool _launching = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _captureScreen() async {
    setState(() {
      _loadingScreen = true;
      _screenError = null;
    });

    final b64 = await _api.takeScreenshot();
    if (mounted) {
      setState(() {
        _loadingScreen = false;
        if (b64 != null && b64.isNotEmpty) {
          try {
            _screenBytes = base64Decode(b64);
          } catch (_) {
            _screenError = 'Failed to decode image data.';
          }
        } else {
          _screenError = 'Failed to capture screenshot. Ensure daemon is running with display permissions.';
        }
      });
    }
  }

  Future<void> _captureCam() async {
    setState(() {
      _loadingCam = true;
      _camError = null;
    });

    final b64 = await _api.takeCameraSnapshot();
    if (mounted) {
      setState(() {
        _loadingCam = false;
        if (b64 != null && b64.isNotEmpty) {
          try {
            _camBytes = base64Decode(b64);
          } catch (_) {
            _camError = 'Failed to decode camera image.';
          }
        } else {
          _camError = 'Workstation camera capture unavailable or requires camera permissions/ffmpeg.';
        }
      });
    }
  }

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
          content: Text(_launchStatus, style: GoogleFonts.jetBrainsMono(fontSize: 11)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showCustomAppDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: TerminalColors.cyberCyan),
        ),
        title: Text(
          'LAUNCH CUSTOM APP / COMMAND',
          style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite),
        ),
        content: TextField(
          controller: ctrl,
          style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 12),
          decoration: InputDecoration(
            hintText: 'e.g. notepad.exe or spotify',
            hintStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 11),
            filled: true,
            fillColor: Colors.black,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: TerminalColors.cardBorder)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 11)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: TerminalColors.cyberCyan, foregroundColor: Colors.black),
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
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 14, left: 14, right: 14, bottom: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF090D16),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: TerminalColors.cyberCyan, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Color(0x3338BDF8),
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
                      color: const Color(0xFF0F2338),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: TerminalColors.cyberCyan),
                    ),
                    child: const Icon(Icons.settings_remote, color: TerminalColors.cyberCyan, size: 16),
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
                        activeWs?.name ?? 'Active Host Computer',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.cyberCyan),
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

          // Cyber Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                color: const Color(0xFF0F2338),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: TerminalColors.cyberCyan),
              ),
              labelColor: TerminalColors.cyberCyan,
              unselectedLabelColor: TerminalColors.zinc,
              labelStyle: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold),
              indicatorSize: TabBarIndicatorSize.tab,
              tabs: const [
                Tab(icon: Icon(Icons.apps, size: 14), text: 'LAUNCH APPS'),
                Tab(icon: Icon(Icons.desktop_windows, size: 14), text: 'SCREEN LIVE'),
                Tab(icon: Icon(Icons.videocam, size: 14), text: 'WEBCAM'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Tab Content Views
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                // TAB 1: APPS LAUNCHER
                _buildAppLauncherTab(),

                // TAB 2: REMOTE DESKTOP SCREEN CAPTURE
                _buildScreenCaptureTab(),

                // TAB 3: WEBCAM SNAPSHOT
                _buildCameraTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppLauncherTab() {
    return ListView(
      children: [
        Text(
          'CLICK ANY APP TO LAUNCH REMOTELY ON WORKSTATION:',
          style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.zinc),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 2.1,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildAppLauncherCard('VS Code', 'Open IDE editor', Icons.code, () => _launchApp('vscode')),
            _buildAppLauncherCard('Antigravity', 'Launch CLI Agent', Icons.auto_awesome, () => _launchApp('antigravity')),
            _buildAppLauncherCard('Terminal', 'Open Terminal / PTY', Icons.terminal, () => _launchApp('terminal')),
            _buildAppLauncherCard('File Explorer', 'Browse host files', Icons.folder_open, () => _launchApp('explorer')),
            _buildAppLauncherCard('Chrome Browser', 'Open Web Browser', Icons.public, () => _launchApp('browser', customUrl: 'https://github.com/darknecrocities/Agentdeck')),
            _buildAppLauncherCard('Task Manager', 'Activity & Processes', Icons.speed, () => _launchApp('taskmgr')),
          ],
        ),
        const SizedBox(height: 14),

        // Quick File Explorer & Custom Command
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: TerminalColors.cyberCyan,
                  side: const BorderSide(color: Color(0xFF1E293B)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.description, size: 16),
                label: Text('VIEW FILES LIVE', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const FileViewerModal(),
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F2338),
                  foregroundColor: TerminalColors.cyberCyan,
                  side: const BorderSide(color: TerminalColors.cyberCyan),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.play_arrow, size: 16),
                label: Text('CUSTOM APP', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: _showCustomAppDialog,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAppLauncherCard(String title, String desc, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: _launching ? null : onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0C1322),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF090D16),
                shape: BoxShape.circle,
                border: Border.all(color: TerminalColors.cyberCyan.withValues(alpha: 0.5)),
              ),
              child: Icon(icon, color: TerminalColors.cyberCyan, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: TerminalColors.pureWhite,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      color: TerminalColors.zinc,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenCaptureTab() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'REMOTE WORKSTATION DESKTOP STREAM:',
              style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.zinc),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F2338),
                foregroundColor: TerminalColors.cyberCyan,
                side: const BorderSide(color: TerminalColors.cyberCyan),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              icon: _loadingScreen
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: TerminalColors.cyberCyan))
                  : const Icon(Icons.refresh, size: 14),
              label: Text('CAPTURE SCREEN', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold)),
              onPressed: _loadingScreen ? null : _captureScreen,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: _screenBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.memory(
                        _screenBytes!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _screenError != null ? Icons.error_outline : Icons.desktop_windows_outlined,
                          size: 40,
                          color: _screenError != null ? const Color(0xFFF87171) : TerminalColors.zinc,
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            _screenError ?? 'Tap "CAPTURE SCREEN" above to pull high-res live view of your workstation desktop.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: _screenError != null ? const Color(0xFFF87171) : TerminalColors.zinc,
                            ),
                          ),
                        ),
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'REMOTE WORKSTATION WEBCAM FEED:',
              style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.zinc),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F2338),
                foregroundColor: TerminalColors.cyberCyan,
                side: const BorderSide(color: TerminalColors.cyberCyan),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
              icon: _loadingCam
                  ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: TerminalColors.cyberCyan))
                  : const Icon(Icons.camera_alt, size: 14),
              label: Text('CAPTURE WEBCAM', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold)),
              onPressed: _loadingCam ? null : _captureCam,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: _camBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _camBytes!,
                      fit: BoxFit.contain,
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _camError != null ? Icons.videocam_off : Icons.videocam_outlined,
                          size: 40,
                          color: _camError != null ? const Color(0xFFF87171) : TerminalColors.zinc,
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            _camError ?? 'Tap "CAPTURE WEBCAM" to take a snapshot from your workstation camera in real time.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              color: _camError != null ? const Color(0xFFF87171) : TerminalColors.zinc,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
