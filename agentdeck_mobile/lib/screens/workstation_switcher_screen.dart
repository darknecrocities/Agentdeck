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
  final Map<String, bool> _pingResults = {};
  bool _testingPings = false;

  @override
  void initState() {
    super.initState();
    _refreshPings();
  }

  Future<void> _refreshPings() async {
    setState(() => _testingPings = true);
    for (var ws in _mgr.workstations) {
      final ok = await _mgr.pingWorkstation(ws.endpoint);
      if (mounted) {
        setState(() {
          _pingResults[ws.id] = ok;
        });
      }
    }
    if (mounted) setState(() => _testingPings = false);
  }

  void _showAddMachineDialog() {
    final nameCtrl = TextEditingController(text: 'Windows PC (Dev)');
    final endpointCtrl = TextEditingController(text: 'http://100.114.182.');
    String selectedOs = 'Windows';
    String? pingStatus;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: TerminalColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(top: BorderSide(color: TerminalColors.cardBorderLight, width: 1.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ADD WORKSTATION / COMPUTER',
                        style: GoogleFonts.jetBrainsMono(
                          color: TerminalColors.pureWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: TerminalColors.zinc, size: 18),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // OS Dropdown
                  Text('OPERATING SYSTEM', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.zinc)),
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
                    items: const [
                      DropdownMenuItem(value: 'Windows', child: Text('🪟 Windows (10 / 11 / Server)')),
                      DropdownMenuItem(value: 'macOS', child: Text('🍏 macOS (Apple Silicon / Intel)')),
                      DropdownMenuItem(value: 'Linux', child: Text('🐧 Linux (Ubuntu / Debian / Arch)')),
                    ],
                    onChanged: (v) => setModalState(() => selectedOs = v ?? 'Windows'),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: nameCtrl,
                    style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'WORKSTATION NAME',
                      hintText: 'e.g. Windows Gaming PC, Work Linux Rig',
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
                    Text(
                      pingStatus!,
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, color: pingStatus!.contains('ONLINE') ? Colors.green : Colors.red),
                    ),
                    const SizedBox(height: 10),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: TerminalColors.pureWhite,
                            side: const BorderSide(color: TerminalColors.cardBorderLight),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            setModalState(() => pingStatus = 'Testing ping...');
                            final ok = await _mgr.pingWorkstation(endpointCtrl.text.trim());
                            setModalState(() {
                              pingStatus = ok ? '● ONLINE & REACHABLE' : '○ UNREACHABLE (Check Tailscale)';
                            });
                          },
                          child: Text('TEST PING', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TerminalColors.pureWhite,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
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
                          child: Text('SAVE WORKSTATION', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w900, fontSize: 11)),
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
            icon: const Icon(Icons.add, color: TerminalColors.pureWhite),
            tooltip: 'Add Machine',
            onPressed: _showAddMachineDialog,
          ),
          if (_testingPings)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: TerminalColors.pureWhite),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: TerminalColors.pureWhite),
            onPressed: _refreshPings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
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
                      Row(
                        children: [
                          Icon(
                            ws.os == 'Windows'
                                ? Icons.window
                                : ws.os == 'macOS'
                                    ? Icons.laptop_mac
                                    : Icons.terminal,
                            color: TerminalColors.pureWhite,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            ws.name,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: TerminalColors.pureWhite,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.white : Colors.transparent,
                          border: Border.all(color: isOnline ? Colors.white : TerminalColors.cardBorderLight),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          isOnline ? 'ONLINE' : 'OFFLINE',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: isOnline ? Colors.black : TerminalColors.zinc,
                          ),
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
                          child: Text(
                            'CURRENTLY CONNECTED',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        )
                      else
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TerminalColors.pureWhite,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            minimumSize: const Size(100, 32),
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
                          child: Text(
                            'SWITCH TO THIS MACHINE',
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w900),
                          ),
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
}
