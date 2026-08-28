import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/workstation_manager.dart';
import '../theme/terminal_theme.dart';

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
    final endpointCtrl = TextEditingController(text: 'http://100.94.58.13:8765');
    String selectedOs = 'Windows';
    String? pingStatus;

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
                    style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'TAILSCALE ENDPOINT (HOST:PORT)',
                      hintText: 'http://100.x.y.z:8765',
                      labelStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 11),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: TerminalColors.cardBorder)),
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
            tooltip: 'Add Machine',
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
                  Text(
                    '${ws.os.toUpperCase()} • ${ws.endpoint}',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.textMuted),
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
                  _buildStepRow(
                    '1',
                    'Join Tailscale Network',
                    'Install Tailscale on your Mac, Windows, Linux, and Phone. Sign in to the same account so all devices join your private mesh.',
                  ),
                  const SizedBox(height: 10),
                  _buildStepRow(
                    '2',
                    'Find Your Machine IP',
                    'Run "tailscale ip -4" on your target computer (e.g. 100.114.182.27 on Mac, 100.94.58.13 on Windows).',
                  ),
                  const SizedBox(height: 10),
                  _buildStepRow(
                    '3',
                    'Start AgentDeck Daemon',
                    'Run "cargo run --bin agentdeckd" on your computer. It will automatically bind to port 8765 across Tailscale.',
                  ),
                  const SizedBox(height: 10),
                  _buildStepRow(
                    '4',
                    'Configure in .env or Mobile App',
                    'Define AGENTDECK_WINDOWS_ENDPOINT or AGENTDECK_MAC_ENDPOINT in .env, or tap "+" above to add any custom machine URL.',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepRow(String number, String title, String body) {
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
            ],
          ),
        ),
      ],
    );
  }
}
