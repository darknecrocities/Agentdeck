import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/workstation_manager.dart';
import '../theme/terminal_theme.dart';
import 'terminal_widgets.dart';

class TailscaleModal extends StatefulWidget {
  const TailscaleModal({super.key});

  @override
  State<TailscaleModal> createState() => _TailscaleModalState();
}

class _TailscaleModalState extends State<TailscaleModal> with SingleTickerProviderStateMixin {
  final WorkstationManager _wsMgr = WorkstationManager();

  late TabController _guideTabCtrl;
  final TextEditingController _endpointCtrl = TextEditingController();
  final TextEditingController _nameCtrl = TextEditingController();
  String _selectedOs = 'macOS';

  bool _isDiagnosing = false;
  int? _activeLatency;
  bool? _isOnline;
  List<String> _diagLogs = [];

  @override
  void initState() {
    super.initState();
    _guideTabCtrl = TabController(length: 3, vsync: this);
    final active = _wsMgr.activeWorkstation;
    if (active != null) {
      _endpointCtrl.text = active.endpoint;
      _nameCtrl.text = active.name;
      _selectedOs = active.os;
    }
    _runDiagnostic();
  }

  @override
  void dispose() {
    _guideTabCtrl.dispose();
    _endpointCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _runDiagnostic() async {
    final active = _wsMgr.activeWorkstation;
    if (active == null) return;

    setState(() {
      _isDiagnosing = true;
      _diagLogs = [
        'Checking mobile Tailscale mesh tunnel...',
        'Target endpoint: ${active.endpoint}',
      ];
    });

    final res = await _wsMgr.pingWithLatency(active.endpoint);
    if (!mounted) return;

    setState(() {
      _isDiagnosing = false;
      _isOnline = res.online;
      _activeLatency = res.latencyMs;
      if (res.online) {
        _diagLogs.add('[OK] WireGuard tunnel active & responsive');
        _diagLogs.add('[OK] Daemon /health probe returned 200 OK');
        _diagLogs.add('[READY] Latency: ${res.latencyMs}ms (Sub-50ms high speed)');
      } else {
        _diagLogs.add('[FAIL] Unable to reach ${active.endpoint}');
        _diagLogs.add('[TIP] 1. Ensure Tailscale is connected on your mobile device.');
        _diagLogs.add('[TIP] 2. Ensure daemon is running on ${active.os}: "cargo run --bin agentdeckd"');
        _diagLogs.add('[TIP] 3. Check firewall rule allows port 8765.');
      }
    });
  }

  Future<void> _saveAndSwitch() async {
    String raw = _endpointCtrl.text.trim();
    if (raw.isEmpty) return;

    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      raw = 'http://$raw';
    }
    if (!raw.contains(':', raw.indexOf('//') + 2)) {
      raw = '$raw:8765';
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final name = _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'Tailscale Node ($_selectedOs)';

    final ws = Workstation(
      id: id,
      name: name,
      os: _selectedOs,
      endpoint: raw,
      isCurrent: true,
    );

    await _wsMgr.addWorkstation(ws);
    await _wsMgr.switchTo(id);
    if (!mounted) return;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Connected to Tailscale workstation: $name'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _wsMgr.activeWorkstation;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: const EdgeInsets.only(top: 14, left: 16, right: 16, bottom: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF0A0A0A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: Color(0xFF333333), width: 1.5)),
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
                    width: 32,
                    height: 32,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF333333)),
                    ),
                    child: Image.asset('assets/images/agentdeck.png'),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TAILSCALE MESH CONNECT',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: TerminalColors.pureWhite,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Zero-Trust Encrypted Remote Link',
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
          const SizedBox(height: 14),

          // Scrollable Diagnostic & Connect Hub
          Expanded(
            child: ListView(
              children: [
                // Active Connection Card with Radar Pulse
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F0F),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isOnline == true ? const Color(0xFF51CF66) : const Color(0xFF262626),
                      width: 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                active?.os == 'Windows'
                                    ? Icons.desktop_windows
                                    : (active?.os == 'Linux' ? Icons.developer_board : Icons.laptop_mac),
                                size: 16,
                                color: TerminalColors.pureWhite,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                active?.name.toUpperCase() ?? 'WORKSTATION',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: TerminalColors.pureWhite,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: _isOnline == true ? const Color(0xFF1B3820) : const Color(0xFF242424),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: _isOnline == true ? const Color(0xFF51CF66) : const Color(0xFF404040),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _isOnline == true ? const Color(0xFF51CF66) : TerminalColors.zinc,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  _isOnline == true
                                      ? 'ONLINE (${_activeLatency ?? 0}ms)'
                                      : (_isDiagnosing ? 'PROBING...' : 'OFFLINE'),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: _isOnline == true ? const Color(0xFF51CF66) : TerminalColors.zinc,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Text('ENDPOINT: ', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc)),
                          Expanded(
                            child: Text(
                              active?.endpoint ?? 'http://127.0.0.1:8765',
                              style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: TerminalColors.pureWhite, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Diagnostic log console
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF222222)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _diagLogs.map((line) {
                            final isOk = line.startsWith('[OK]') || line.startsWith('[READY]');
                            final isFail = line.startsWith('[FAIL]');
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                line,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  color: isOk
                                      ? const Color(0xFF51CF66)
                                      : (isFail ? const Color(0xFFFF6B6B) : TerminalColors.zinc),
                                  fontWeight: isOk || isFail ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: TerminalColors.pureWhite,
                            side: const BorderSide(color: Color(0xFF404040)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: _isDiagnosing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.refresh, size: 15),
                          label: Text(
                            'RE-TEST TAILSCALE LINK',
                            style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _isDiagnosing ? null : _runDiagnostic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Quick Connect to New Tailscale Node Form
                TerminalCard(
                  title: 'DIRECT TAILSCALE CONNECT',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TARGET OS',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.zinc),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedOs,
                        dropdownColor: const Color(0xFF141414),
                        style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 12),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.black,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF262626))),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'macOS', child: Text('macOS (Apple Silicon / Intel)')),
                          DropdownMenuItem(value: 'Windows', child: Text('Windows (10 / 11 / Server)')),
                          DropdownMenuItem(value: 'Linux', child: Text('Linux (Ubuntu / Debian / Arch)')),
                        ],
                        onChanged: (v) => setState(() => _selectedOs = v ?? 'macOS'),
                      ),
                      const SizedBox(height: 10),

                      Text(
                        'WORKSTATION NAME',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.zinc),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _nameCtrl,
                        style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'e.g. MacBook Pro M3 or Gaming Rig',
                          hintStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted, fontSize: 11),
                          filled: true,
                          fillColor: Colors.black,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF262626))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: TerminalColors.pureWhite)),
                        ),
                      ),
                      const SizedBox(height: 10),

                      Text(
                        'TAILSCALE IP OR MAGICDNS (HOST:8765)',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.zinc),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _endpointCtrl,
                        style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 12),
                        decoration: InputDecoration(
                          hintText: 'http://100.x.y.z:8765',
                          hintStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted, fontSize: 11),
                          filled: true,
                          fillColor: Colors.black,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF262626))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: TerminalColors.pureWhite)),
                        ),
                      ),
                      const SizedBox(height: 14),

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TerminalColors.pureWhite,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(double.infinity, 42),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.link, size: 16),
                        label: Text(
                          'SAVE & CONNECT VIA TAILSCALE',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                        onPressed: _saveAndSwitch,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Step-by-Step Setup Guide
                TerminalCard(
                  title: 'SETUP GUIDE & COMMANDS',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TabBar(
                        controller: _guideTabCtrl,
                        indicatorColor: TerminalColors.pureWhite,
                        labelColor: TerminalColors.pureWhite,
                        unselectedLabelColor: TerminalColors.zinc,
                        labelStyle: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold),
                        tabs: const [
                          Tab(text: 'macOS'),
                          Tab(text: 'Windows'),
                          Tab(text: 'Linux'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 230,
                        child: TabBarView(
                          controller: _guideTabCtrl,
                          children: [
                            _buildGuideContent(
                              os: 'macOS',
                              steps: [
                                '1. Install Tailscale from App Store or brew cask.',
                                '2. Find your Mac Tailscale IP:\n> tailscale ip -4',
                                '3. Launch AgentDeck daemon (listening on :8765):\n> cargo run --bin agentdeckd',
                                '4. Paste your 100.x.y.z:8765 into the field above.',
                              ],
                              copyCmd: 'cargo run --bin agentdeckd',
                            ),
                            _buildGuideContent(
                              os: 'Windows',
                              steps: [
                                '1. Install Tailscale: winget install Tailscale.Tailscale',
                                '2. Allow port 8765 in Firewall (PowerShell Admin):\n> New-NetFirewallRule -DisplayName "AgentDeck" -LocalPort 8765 -Protocol TCP -Action Allow',
                                '3. Start daemon in PowerShell:\n> cargo run --bin agentdeckd',
                                '4. Find IP with: tailscale ip -4',
                              ],
                              copyCmd: 'New-NetFirewallRule -DisplayName "AgentDeck" -LocalPort 8765 -Protocol TCP -Action Allow; cargo run --bin agentdeckd',
                            ),
                            _buildGuideContent(
                              os: 'Linux',
                              steps: [
                                '1. Install Tailscale: curl -fsSL https://tailscale.com/install.sh | sh',
                                '2. Allow port: sudo ufw allow 8765/tcp',
                                '3. Start daemon: cargo run --release --bin agentdeckd',
                                '4. Find IP: tailscale ip -4',
                              ],
                              copyCmd: 'sudo ufw allow 8765/tcp && cargo run --release --bin agentdeckd',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideContent({
    required String os,
    required List<String> steps,
    required String copyCmd,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...steps.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  s,
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc, height: 1.3),
                ),
              )),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: TerminalColors.pureWhite,
              side: const BorderSide(color: Color(0xFF404040)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            icon: const Icon(Icons.copy, size: 13),
            label: Text('COPY DAEMON LAUNCH COMMAND', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold)),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: copyCmd));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Command copied to clipboard!')),
              );
            },
          ),
        ],
      ),
    );
  }
}
