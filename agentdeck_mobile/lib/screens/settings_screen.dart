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
      _testStatus = 'Testing connection to Mac...';
    });

    _api.updateConfig(url: _urlCtrl.text.trim(), token: _tokenCtrl.text.trim());

    try {
      final res = await _api.getHealth();
      setState(() {
        _testStatus = 'CONNECTED: ${res['service']} v${res['version']}';
        _testing = false;
      });
    } catch (e) {
      setState(() {
        _testStatus = 'FAILED TO CONNECT: $e';
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
          // Connection Card
          TerminalCard(
            title: 'DAEMON CONNECTIVITY (TAILSCALE)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MAC TAILSCALE / LOCAL ENDPOINT',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: TerminalColors.zinc,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _urlCtrl,
                  style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'http://127.0.0.1:8765 or http://127.0.0.1:8765',
                    filled: true,
                    fillColor: Colors.black,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: TerminalColors.cardBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: TerminalColors.pureWhite)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'AUTH TOKEN (BEARER)',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: TerminalColors.zinc,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _tokenCtrl,
                  obscureText: true,
                  style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Optional bearer token',
                    filled: true,
                    fillColor: Colors.black,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: TerminalColors.cardBorder)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: TerminalColors.pureWhite)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: TerminalColors.pureWhite,
                          side: const BorderSide(color: TerminalColors.cardBorderLight),
                        ),
                        onPressed: _testing ? null : _testConnection,
                        child: Text('TEST PING', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: TerminalColors.pureWhite,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: _saveSettings,
                        child: Text('SAVE CONFIG', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11)),
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
                        color: _testStatus.startsWith('CONNECTED') ? Colors.white : TerminalColors.cardBorderLight,
                      ),
                    ),
                    child: Text(
                      _testStatus,
                      style: GoogleFonts.jetBrainsMono(
                        color: TerminalColors.pureWhite,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Security Card
          TerminalCard(
            title: 'SECURITY ARCHITECTURE',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Local-First & Private Mesh Tunnel',
                  style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: TerminalColors.pureWhite, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your phone connects directly to your Mac over an encrypted WireGuard tunnel provided by Tailscale. No third party ever sees your source code or agent streams.',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.zinc),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
