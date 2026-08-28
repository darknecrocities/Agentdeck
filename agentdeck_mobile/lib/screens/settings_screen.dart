import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/voice_service.dart';
import '../theme/terminal_theme.dart';
import '../widgets/terminal_widgets.dart';
import '../widgets/voice_prompt_modal.dart';

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
      _testStatus = 'Testing connection to workstation...';
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
                  'ACTIVE WORKSTATION TAILSCALE / LOCAL ENDPOINT',
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
                  'Your phone connects directly to your computers over an encrypted WireGuard tunnel provided by Tailscale. No third party ever sees your source code or agent streams.',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.zinc),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Voice Agent & Speech Synthesis (STT / TTS) Card
          TerminalCard(
            title: 'VOICE AGENT & SPEECH SYNTHESIS (STT / TTS)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Text-to-Speech (TTS) Voice Responses',
                            style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, color: TerminalColors.pureWhite, fontSize: 11.5),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Agent speaks summaries & responses out loud',
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: VoiceService().ttsEnabled,
                      activeColor: const Color(0xFF51CF66),
                      onChanged: (val) {
                        setState(() {
                          VoiceService().updateSettings(ttsEnabled: val);
                        });
                      },
                    ),
                  ],
                ),
                const Divider(color: TerminalColors.cardBorder, height: 20),

                // Male Voice Profiles
                Text(
                  'VOICE PERSONA (MALE AI ASSISTANT)',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: TerminalColors.zinc,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildVoiceProfilePill('Deep Male Commander', '0.45x • Deep 0.80'),
                    _buildVoiceProfilePill('Calm Male Assistant', '0.48x • Neutral 0.88'),
                    _buildVoiceProfilePill('Fast Male Agent', '0.55x • Fast 0.85'),
                  ],
                ),
                const SizedBox(height: 16),

                // Speaking Speed Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Speaking Pace (Speed)',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.pureWhite, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${(VoiceService().speechRate * 2.0).toStringAsFixed(2)}x (${VoiceService().speechRate <= 0.46 ? "Natural/Calm" : "Fast"})',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFF51CF66), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Slider(
                  value: VoiceService().speechRate.clamp(0.30, 0.70),
                  min: 0.30,
                  max: 0.70,
                  divisions: 8,
                  activeColor: const Color(0xFF51CF66),
                  inactiveColor: const Color(0xFF222222),
                  onChanged: (val) {
                    setState(() {
                      VoiceService().updateSettings(rate: val);
                    });
                  },
                ),

                // Voice Pitch Slider
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Voice Tone (Pitch)',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.pureWhite, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${VoiceService().speechPitch.toStringAsFixed(2)} (${VoiceService().speechPitch < 0.85 ? "Deep Male" : "Neutral"})',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFF51CF66), fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Slider(
                  value: VoiceService().speechPitch.clamp(0.65, 1.10),
                  min: 0.65,
                  max: 1.10,
                  divisions: 9,
                  activeColor: const Color(0xFF51CF66),
                  inactiveColor: const Color(0xFF222222),
                  onChanged: (val) {
                    setState(() {
                      VoiceService().updateSettings(pitch: val);
                    });
                  },
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: TerminalColors.pureWhite,
                          side: const BorderSide(color: TerminalColors.cardBorderLight),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.volume_up, size: 16),
                        label: Text('TEST MALE VOICE', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          const testMsg = 'AgentDeck male voice synthesizer calibrated. Operating at natural speaking pace.';
                          await VoiceService().speak(testMsg);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  VoiceService().isPluginAvailable.value
                                      ? '🔊 Speaking: "$testMsg"'
                                      : '⚠️ Native audio plugin requires restarting "flutter run" to link Android bindings.',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 11),
                                ),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF143318),
                          foregroundColor: const Color(0xFF51CF66),
                          side: const BorderSide(color: Color(0xFF51CF66)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        icon: const Icon(Icons.mic, size: 16),
                        label: Text('VOICE PROMPTER', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const VoicePromptModal(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildVoiceProfilePill(String name, String sub) {
    final isSelected = VoiceService().selectedVoiceProfile == name;
    return InkWell(
      onTap: () async {
        await VoiceService().setProfile(name);
        setState(() {});
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF143318) : Colors.black,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? const Color(0xFF51CF66) : TerminalColors.cardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  size: 13,
                  color: isSelected ? const Color(0xFF51CF66) : TerminalColors.zinc,
                ),
                const SizedBox(width: 5),
                Text(
                  name,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? TerminalColors.pureWhite : TerminalColors.zinc,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              sub,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 8.5,
                color: isSelected ? const Color(0xFF51CF66) : TerminalColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
