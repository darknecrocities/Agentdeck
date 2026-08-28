import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import '../widgets/terminal_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiService _api = ApiService();
  late TextEditingController _urlCtrl;
  late TextEditingController _tokenCtrl;
  String _testStatus = '';
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: _api.baseUrl);
    _tokenCtrl = TextEditingController(text: _api.authToken ?? '');
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    _api.updateConfig(url: _urlCtrl.text.trim(), token: _tokenCtrl.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Daemon connection settings saved!')),
    );
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testStatus = 'Testing connection...';
    });

    _api.updateConfig(url: _urlCtrl.text.trim(), token: _tokenCtrl.text.trim());

    try {
      final res = await _api.getHealth();
      setState(() {
        _testStatus = 'CONNECTED! Service: ${res['service']} v${res['version']}';
        _testing = false;
      });
    } catch (e) {
      setState(() {
        _testStatus = 'FAILED: $e';
        _testing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CONTROL PLANE SETTINGS'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TerminalCard(
            title: 'DAEMON CONNECTIVITY',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TAILSCALE / LOCALHOST ENDPOINT',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: TerminalColors.electricCyan,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _urlCtrl,
                  style: GoogleFonts.jetBrainsMono(color: TerminalColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'http://100.x.x.x:8765 or http://127.0.0.1:8765',
                    filled: true,
                    fillColor: TerminalColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'AUTH TOKEN (BEARER)',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: TerminalColors.electricCyan,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _tokenCtrl,
                  obscureText: true,
                  style: GoogleFonts.jetBrainsMono(color: TerminalColors.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Optional bearer token',
                    filled: true,
                    fillColor: TerminalColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: TerminalColors.electricCyan,
                          side: const BorderSide(color: TerminalColors.electricCyan),
                        ),
                        onPressed: _testing ? null : _testConnection,
                        child: Text('TEST PING', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TerminalColors.neonGreen,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: _saveSettings,
                        child: Text('SAVE CONFIG', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                if (_testStatus.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _testStatus.startsWith('CONNECTED')
                            ? TerminalColors.neonGreen
                            : TerminalColors.neonRed,
                      ),
                    ),
                    child: Text(
                      _testStatus,
                      style: GoogleFonts.jetBrainsMono(
                        color: _testStatus.startsWith('CONNECTED')
                            ? TerminalColors.neonGreen
                            : TerminalColors.neonRed,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Security Policy Info
          TerminalCard(
            title: 'SECURITY ARCHITECTURE',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local-First & Zero Cloud Mesh',
                  style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: TerminalColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Traffic never traverses third-party servers. Communications are routed directly through your private Tailscale WireGuard mesh directly to your Mac.',
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, color: TerminalColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
