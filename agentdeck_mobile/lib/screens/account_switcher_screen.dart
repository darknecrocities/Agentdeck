import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';

class AccountSwitcherScreen extends StatefulWidget {
  const AccountSwitcherScreen({super.key});

  @override
  State<AccountSwitcherScreen> createState() => _AccountSwitcherScreenState();
}

class _AccountSwitcherScreenState extends State<AccountSwitcherScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  List<dynamic> _profiles = [];
  bool _loading = true;

  final List<String> _agents = ['ALL', 'ANTIGRAVITY', 'CLAUDE', 'OPENAI', 'GEMINI'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _agents.length, vsync: this);
    _loadProfiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getAuthProfiles();
      if (mounted) {
        setState(() {
          _profiles = res;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _activateProfile(String id) async {
    final ok = await _api.activateAuthProfile(id);
    if (ok) {
      _loadProfiles();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Active account profile updated successfully')),
        );
      }
    }
  }

  Future<void> _deleteProfile(String id) async {
    final ok = await _api.deleteAuthProfile(id);
    if (ok) _loadProfiles();
  }

  void _showAddAccountDialog() {
    String selectedAgent = 'antigravity';
    final nameCtrl = TextEditingController();
    final tokenCtrl = TextEditingController();
    bool obscure = true;

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
                        'ADD ACCOUNT / TOKEN',
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

                  // Agent Selector
                  Text('SELECT AI AGENT', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.zinc)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: selectedAgent,
                    dropdownColor: TerminalColors.surface,
                    style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 12),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: TerminalColors.cardBorder)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'antigravity', child: Text('Antigravity CLI (Google)')),
                      DropdownMenuItem(value: 'claude', child: Text('Claude Code (Anthropic)')),
                      DropdownMenuItem(value: 'openai', child: Text('OpenAI / Codex')),
                      DropdownMenuItem(value: 'gemini', child: Text('Gemini CLI (Google AI)')),
                    ],
                    onChanged: (v) => setModalState(() => selectedAgent = v ?? 'antigravity'),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: nameCtrl,
                    style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'ACCOUNT NICKNAME',
                      hintText: 'e.g. Personal Pro, Work Cloud, Team Key',
                      labelStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 11),
                      hintStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted, fontSize: 11),
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: TerminalColors.cardBorder)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: tokenCtrl,
                    obscureText: obscure,
                    style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'SECRET API KEY / TOKEN',
                      labelStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 11),
                      filled: true,
                      fillColor: Colors.black,
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, color: TerminalColors.zinc, size: 18),
                        onPressed: () => setModalState(() => obscure = !obscure),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: TerminalColors.cardBorder)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: TerminalColors.pureWhite,
                            side: const BorderSide(color: TerminalColors.cardBorderLight),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('CANCEL', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TerminalColors.pureWhite,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () async {
                            if (nameCtrl.text.isNotEmpty && tokenCtrl.text.isNotEmpty) {
                              await _api.createAuthProfile(
                                agentId: selectedAgent,
                                accountName: nameCtrl.text,
                                tokenValue: tokenCtrl.text,
                                setActive: true,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              _loadProfiles();
                            }
                          },
                          child: Text('SAVE & ACTIVATE', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ACCOUNT & TOKEN SWITCHER',
          style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: TerminalColors.pureWhite),
            tooltip: 'Add Account',
            onPressed: _showAddAccountDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: TerminalColors.pureWhite),
            onPressed: _loadProfiles,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: TerminalColors.pureWhite,
          labelColor: TerminalColors.pureWhite,
          unselectedLabelColor: TerminalColors.zinc,
          isScrollable: true,
          labelStyle: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11),
          tabs: _agents.map((a) => Tab(text: a)).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: TerminalColors.pureWhite))
          : TabBarView(
              controller: _tabController,
              children: _agents.map((agentFilter) {
                final filtered = agentFilter == 'ALL'
                    ? _profiles
                    : _profiles.where((p) => (p['agent_id'] ?? '').toString().toUpperCase() == agentFilter).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.account_circle_outlined, size: 48, color: TerminalColors.zinc),
                        const SizedBox(height: 12),
                        Text(
                          'No account profiles saved for $agentFilter.',
                          style: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted, fontSize: 12),
                        ),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: TerminalColors.pureWhite,
                            side: const BorderSide(color: TerminalColors.cardBorderLight),
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: Text('ADD ACCOUNT PROFILE', style: GoogleFonts.jetBrainsMono(fontSize: 11)),
                          onPressed: _showAddAccountDialog,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final p = filtered[idx];
                    final isActive = p['is_active'] == true;
                    final agent = p['agent_id'] ?? '';
                    final name = p['account_name'] ?? '';
                    final masked = p['token_masked'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: TerminalColors.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isActive ? TerminalColors.pureWhite : TerminalColors.cardBorder,
                          width: isActive ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            agent == 'antigravity'
                                ? Icons.auto_awesome
                                : agent == 'claude'
                                    ? Icons.psychology
                                    : Icons.bolt,
                            color: TerminalColors.pureWhite,
                            size: 24,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      name,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: TerminalColors.pureWhite,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      agent.toUpperCase(),
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9,
                                        color: TerminalColors.zinc,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  masked,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            )
                          else
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: TerminalColors.pureWhite,
                                side: const BorderSide(color: TerminalColors.cardBorderLight),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: const Size(60, 30),
                              ),
                              onPressed: () => _activateProfile(p['id']),
                              child: Text('ACTIVATE', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: TerminalColors.textMuted, size: 18),
                            onPressed: () => _deleteProfile(p['id']),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }).toList(),
            ),
    );
  }
}
