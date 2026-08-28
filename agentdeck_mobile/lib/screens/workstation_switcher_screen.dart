import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/workstation_manager.dart';
import '../theme/terminal_theme.dart';
import '../widgets/terminal_widgets.dart';

class WorkstationSwitcherScreen extends StatefulWidget {
  const WorkstationSwitcherScreen({super.key});

  @override
  State<WorkstationSwitcherScreen> createState() => _WorkstationSwitcherScreenState();
}

class _WorkstationSwitcherScreenState extends State<WorkstationSwitcherScreen> {
  final WorkstationManager _mgr = WorkstationManager();
  Map<String, bool> _pingResults = {};
  bool _testingPings = false;
  bool _showGuide = false;
  String _guideSelectedOs = 'Windows';

  @override
  void initState() {
    super.initState();
    _refreshPings();
  }

  Future<void> _refreshPings() async {
    setState(() => _testingPings = true);
    final results = await _mgr.pingAll();
    if (mounted) {
      setState(() {
        _pingResults = results;
        _testingPings = false;
      });
    }
  }

  void _showAddMachineDialog() {
    final nameCtrl = TextEditingController();
    final endpointCtrl = TextEditingController(text: 'http://127.0.0.1:8765');
    String selectedOs = 'Windows';
    String? pingStatus;
    bool obscureEndpoint = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 16,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF0C0C0C),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(top: BorderSide(color: TerminalColors.cardBorderLight, width: 1.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.add_to_queue, color: TerminalColors.pureWhite, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'ADD WORKSTATION / COMPUTER',
                            style: GoogleFonts.jetBrainsMono(
                              color: TerminalColors.pureWhite,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: TerminalColors.zinc, size: 18),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // OS Dropdown
                  Text(
                    'OPERATING SYSTEM',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.zinc),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedOs,
                    dropdownColor: TerminalColors.surface,
                    style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 12),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: TerminalColors.cardBorder)),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: 'Windows',
                        child: Row(
                          children: [
                            const Icon(Icons.desktop_windows, size: 16, color: TerminalColors.pureWhite),
                            const SizedBox(width: 8),
                            Text('Windows (10 / 11 / Server)', style: GoogleFonts.jetBrainsMono()),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'macOS',
                        child: Row(
                          children: [
                            const Icon(Icons.laptop_mac, size: 16, color: TerminalColors.pureWhite),
                            const SizedBox(width: 8),
                            Text('macOS (Apple Silicon / Intel)', style: GoogleFonts.jetBrainsMono()),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Linux',
                        child: Row(
                          children: [
                            const Icon(Icons.developer_board, size: 16, color: TerminalColors.pureWhite),
                            const SizedBox(width: 8),
                            Text('Linux (Ubuntu / Debian / Arch)', style: GoogleFonts.jetBrainsMono()),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (v) => setModalState(() => selectedOs = v ?? 'Windows'),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: nameCtrl,
                    style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'WORKSTATION NAME',
                      hintText: 'e.g. Windows PC (darknecrocities)',
                      labelStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 11),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: TerminalColors.cardBorder)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: endpointCtrl,
                    obscureText: obscureEndpoint,
                    style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'TAILSCALE ENDPOINT (HOST:PORT)',
                      hintText: 'http://100.x.y.z:8765',
                      labelStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 11),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: TerminalColors.cardBorder)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureEndpoint ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: obscureEndpoint ? TerminalColors.zinc : TerminalColors.pureWhite,
                          size: 18,
                        ),
                        onPressed: () => setModalState(() => obscureEndpoint = !obscureEndpoint),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (pingStatus != null) ...[
                    Row(
                      children: [
                        Icon(
                          pingStatus!.contains('ONLINE') ? Icons.check_circle : Icons.error_outline,
                          size: 14,
                          color: pingStatus!.contains('ONLINE') ? const Color(0xFF51CF66) : const Color(0xFFFF6B6B),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          pingStatus!,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: pingStatus!.contains('ONLINE') ? const Color(0xFF51CF66) : const Color(0xFFFF6B6B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: TerminalColors.pureWhite,
                            side: const BorderSide(color: TerminalColors.cardBorderLight),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.network_ping, size: 14),
                          label: Text('TEST PING', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11)),
                          onPressed: () async {
                            setModalState(() => pingStatus = 'Testing ping...');
                            final ok = await _mgr.pingWorkstation(endpointCtrl.text.trim());
                            setModalState(() {
                              pingStatus = ok ? 'ONLINE & REACHABLE' : 'UNREACHABLE (Check Tailscale)';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TerminalColors.pureWhite,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          icon: const Icon(Icons.save, size: 15),
                          label: Text('SAVE WORKSTATION', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w900, fontSize: 11)),
                          onPressed: () async {
                            if (nameCtrl.text.isNotEmpty && endpointCtrl.text.isNotEmpty) {
                              final newWs = Workstation(
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                name: nameCtrl.text.trim(),
                                os: selectedOs,
                                endpoint: endpointCtrl.text.trim(),
                                isCurrent: false,
                              );
                              await _mgr.addWorkstation(newWs);
                              if (ctx.mounted) Navigator.pop(ctx);
                              _refreshPings();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final workstations = _mgr.workstations;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'WORKSTATION FLEET SWITCHER',
          style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: TerminalColors.pureWhite),
            tooltip: 'Setup Guide',
            onPressed: () => setState(() => _showGuide = !_showGuide),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: TerminalColors.pureWhite),
            tooltip: 'Add Workstation',
            onPressed: _showAddMachineDialog,
          ),
          IconButton(
            icon: _testingPings
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: TerminalColors.pureWhite),
                  )
                : const Icon(Icons.refresh, color: TerminalColors.pureWhite),
            onPressed: _testingPings ? null : _refreshPings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: TerminalColors.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: TerminalColors.cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.devices, color: TerminalColors.pureWhite, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Switch control dynamically across all your Mac, Windows, and Linux machines running AgentDeck.',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.zinc),
                  ),
                ),
              ],
            ),
          ),

          // Setup Guide Card (Collapsible)
          _buildSetupGuideCard(),

          const SizedBox(height: 4),

          ...workstations.map((ws) {
            final isOnline = _pingResults[ws.id] == true;
            final isCurrent = ws.isCurrent;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: TerminalColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isCurrent ? TerminalColors.pureWhite : TerminalColors.cardBorder,
                  width: isCurrent ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              ws.os == 'Windows'
                                  ? Icons.desktop_windows
                                  : ws.os == 'macOS'
                                      ? Icons.laptop_mac
                                      : Icons.developer_board,
                              color: TerminalColors.pureWhite,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                ws.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: TerminalColors.pureWhite,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFF1B3820) : const Color(0xFF2B2B2B),
                          border: Border.all(
                            color: isOnline ? const Color(0xFF51CF66) : TerminalColors.cardBorderLight,
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOnline ? Icons.check_circle : Icons.circle_outlined,
                              size: 10,
                              color: isOnline ? const Color(0xFF51CF66) : TerminalColors.zinc,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isOnline ? 'ONLINE' : 'OFFLINE',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                                color: isOnline ? const Color(0xFF51CF66) : TerminalColors.zinc,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${ws.os.toUpperCase()} • ',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.textMuted),
                      ),
                      Flexible(
                        child: CensoredEndpointBadge(
                          text: ws.endpoint,
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.link, color: Colors.black, size: 13),
                              const SizedBox(width: 5),
                              Text(
                                'CURRENTLY CONNECTED',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TerminalColors.pureWhite,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            minimumSize: const Size(100, 32),
                          ),
                          icon: const Icon(Icons.swap_horiz, size: 14),
                          label: Text(
                            'SWITCH TO THIS MACHINE',
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                          onPressed: () async {
                            await _mgr.switchTo(ws.id);
                            setState(() {});
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Switched control plane to ${ws.name}')),
                              );
                            }
                          },
                        ),
                      if (workstations.length > 1 && !isCurrent)
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: TerminalColors.textMuted, size: 18),
                          onPressed: () async {
                            await _mgr.removeWorkstation(ws.id);
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSetupGuideCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TerminalColors.cardBorderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _showGuide = !_showGuide),
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.menu_book_outlined, color: TerminalColors.pureWhite, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'TAILSCALE & WORKSTATION SETUP GUIDE',
                        style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          color: TerminalColors.pureWhite,
                        ),
                      ),
                    ],
                  ),
                  Icon(
                    _showGuide ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: TerminalColors.zinc,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          if (_showGuide) ...[
            const Divider(color: TerminalColors.cardBorder, height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // OS Tab Selector
                  Row(
                    children: [
                      _buildOsTabPill('Windows', Icons.desktop_windows),
                      const SizedBox(width: 8),
                      _buildOsTabPill('macOS', Icons.laptop_mac),
                      const SizedBox(width: 8),
                      _buildOsTabPill('Linux', Icons.developer_board),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_guideSelectedOs == 'Windows') ...[
                    _buildStepRow(
                      '1',
                      'Install Tailscale & Rust on Windows',
                      'Install Tailscale and the Rust toolchain in 1 command using Windows Package Manager (winget):',
                      code: 'winget install Tailscale.Tailscale\nwinget install Rustlang.Rustup',
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      '2',
                      'Allow Port 8765 in Windows Firewall',
                      'Run this in PowerShell as Administrator so your phone can reach port 8765:',
                      code: 'New-NetFirewallRule -DisplayName "AgentDeck Daemon" -Direction Inbound -LocalPort 8765 -Protocol TCP -Action Allow',
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      '3',
                      'Clone & Start AgentDeck Daemon',
                      'Open PowerShell in your user directory and run:',
                      code: 'cd \$env:USERPROFILE\ngit clone https://github.com/darknecrocities/Agentdeck.git\ncd Agentdeck\ncargo run --bin agentdeckd',
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      '4',
                      'Get Your Windows Tailscale IP',
                      'Find your private 100.x.y.z IP address to paste into AgentDeck:',
                      code: 'tailscale ip -4',
                    ),
                  ] else if (_guideSelectedOs == 'macOS') ...[
                    _buildStepRow(
                      '1',
                      'Install Tailscale on Mac',
                      'Install Tailscale from the Mac App Store or via Homebrew, and log in with your account:',
                      code: 'brew install --cask tailscale',
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      '2',
                      'Clone & Start AgentDeck Daemon',
                      'Open Terminal and launch the daemon (listening on http://0.0.0.0:8765):',
                      code: 'cd ~\ngit clone https://github.com/darknecrocities/Agentdeck.git\ncd Agentdeck\ncargo run --bin agentdeckd',
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      '3',
                      'Get Your Mac Tailscale IP',
                      'Find your private 100.x.y.z IP address:',
                      code: 'tailscale ip -4',
                    ),
                  ] else ...[
                    _buildStepRow(
                      '1',
                      'Install Tailscale on Linux',
                      'Install and connect Tailscale on Ubuntu, Debian, Arch, or Fedora:',
                      code: 'curl -fsSL https://tailscale.com/install.sh | sh\nsudo tailscale up',
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      '2',
                      'Allow Port 8765 in Firewall',
                      'Allow inbound TCP traffic on port 8765:',
                      code: 'sudo ufw allow 8765/tcp',
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      '3',
                      'Clone & Start AgentDeck Daemon',
                      'Clone and run the daemon binary in release mode:',
                      code: 'cd ~\ngit clone https://github.com/darknecrocities/Agentdeck.git\ncd Agentdeck\ncargo run --release --bin agentdeckd',
                    ),
                    const SizedBox(height: 12),
                    _buildStepRow(
                      '4',
                      'Get Your Linux Tailscale IP',
                      'Find your private 100.x.y.z IP address:',
                      code: 'tailscale ip -4',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOsTabPill(String osName, IconData icon) {
    final isSelected = _guideSelectedOs == osName;
    return InkWell(
      onTap: () => setState(() => _guideSelectedOs = osName),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? TerminalColors.pureWhite : Colors.black,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? TerminalColors.pureWhite : TerminalColors.cardBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.black : TerminalColors.pureWhite),
            const SizedBox(width: 6),
            Text(
              osName,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.black : TerminalColors.pureWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepRow(String number, String title, String body, {String? code}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: TerminalColors.surfaceElevated,
            shape: BoxShape.circle,
            border: Border.all(color: TerminalColors.cardBorderLight),
          ),
          child: Center(
            child: Text(
              number,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: TerminalColors.pureWhite,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: TerminalColors.pureWhite,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10.5,
                  color: TerminalColors.zinc,
                  height: 1.3,
                ),
              ),
              if (code != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: TerminalColors.cardBorder),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          code,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9.5,
                            color: const Color(0xFF51CF66),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: code));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Command copied to clipboard!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: TerminalColors.cardBorderLight),
                          ),
                          child: Text(
                            'COPY',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: TerminalColors.pureWhite,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
