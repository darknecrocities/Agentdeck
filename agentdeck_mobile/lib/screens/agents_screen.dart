import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import '../widgets/terminal_widgets.dart';

class AgentsScreen extends StatefulWidget {
  const AgentsScreen({super.key});

  @override
  State<AgentsScreen> createState() => _AgentsScreenState();
}

class _AgentsScreenState extends State<AgentsScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _agents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAgents();
  }

  Future<void> _loadAgents() async {
    setState(() => _loading = true);
    try {
      final list = await _api.getAgents();
      if (mounted) {
        setState(() {
          _agents = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI AGENTS DIRECTORY'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: TerminalColors.pureWhite))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _agents.length,
              itemBuilder: (ctx, idx) {
                final a = _agents[idx];
                final installed = a['installed'] == true;
                final caps = a['capabilities'] as Map<String, dynamic>? ?? {};

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: TerminalCard(
                    title: a['display_name'] ?? a['id'],
                    trailing: StatusBadge(status: installed ? 'INSTALLED' : 'NOT DETECTED'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Adapter: ${a['id']}',
                              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.zinc),
                            ),
                            Text(
                              'v${a['version'] ?? 'N/A'}',
                              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.pureWhite, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        if (a['binary_path'] != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            a['binary_path'],
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.textMuted),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Text(
                          'CAPABILITIES MATRIX',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: TerminalColors.zinc,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildCapChip('STREAMING JSON', caps['streaming'] == true),
                            _buildCapChip('HEADLESS', caps['headless'] == true),
                            _buildCapChip('CONTINUATION', caps['conversation_continuation'] == true),
                            _buildCapChip('SUBAGENTS', caps['subagents'] == true),
                            _buildCapChip('FILE WATCHING', caps['file_watching'] == true),
                            _buildCapChip('APPROVALS', caps['approvals'] == true),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildCapChip(String label, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: active ? TerminalColors.surfaceElevated : Colors.black,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: active ? TerminalColors.cardBorderLight : TerminalColors.cardBorder,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: active ? TerminalColors.pureWhite : TerminalColors.textMuted,
        ),
      ),
    );
  }
}
