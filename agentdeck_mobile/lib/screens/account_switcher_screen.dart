import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/workstation_manager.dart';
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
  Map<String, dynamic>? _antigravityAccount;
  bool _loading = true;

  final List<String> _agents = ['ALL', 'ANTIGRAVITY', 'CLAUDE', 'OPENAI', 'GEMINI'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _agents.length, vsync: this);
    _loadAll();
    WorkstationManager().addListener(_onWorkstationChanged);
  }

  void _onWorkstationChanged() {
    if (mounted) {
      _loadAll();
    }
  }

  @override
  void dispose() {
    WorkstationManager().removeListener(_onWorkstationChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getAuthProfiles();
      final agy = await _api.getAntigravityAccount();
      if (mounted) {
        setState(() {
          _profiles = res;
          _antigravityAccount = agy;
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
      _loadAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Active account profile updated successfully')),
        );
      }
    }
  }

  Future<void> _deleteProfile(String id) async {
    final ok = await _api.deleteAuthProfile(id);
    if (ok) _loadAll();
  }

  Future<void> _switchAntigravity(String email) async {
    setState(() => _loading = true);
    final ok = await _api.switchAntigravityAccount(email);
    await _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Switched active Antigravity account to $email'
              : 'Failed to switch Antigravity account'),
        ),
      );
    }
  }

  void _showAddGoogleAccountDialog() {
    final emailCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
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
                    'SWITCH / ADD GOOGLE ACCOUNT',
                    style: GoogleFonts.jetBrainsMono(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: TerminalColors.pureWhite,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: TerminalColors.zinc, size: 18),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Enter the Google account email used with Antigravity IDE:',
                style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: TerminalColors.zinc),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.jetBrainsMono(fontSize: 12, color: TerminalColors.pureWhite),
                decoration: const InputDecoration(
                  labelText: 'Google Email Address',
                  hintText: 'user@gmail.com',
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TerminalColors.pureWhite,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    if (emailCtrl.text.trim().isNotEmpty) {
                      Navigator.pop(ctx);
                      await _switchAntigravity(emailCtrl.text.trim());
                    }
                  },
                  child: Text('SWITCH ANTIGRAVITY ACCOUNT',
                      style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
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
                        'ADD API TOKEN / PROFILE',
                        style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: TerminalColors.pureWhite,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: TerminalColors.zinc, size: 18),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedAgent,
                    dropdownColor: TerminalColors.surfaceElevated,
                    style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 12),
                    decoration: const InputDecoration(labelText: 'Agent Service'),
                    items: const [
                      DropdownMenuItem(value: 'antigravity', child: Text('Antigravity IDE / CLI')),
                      DropdownMenuItem(value: 'claude', child: Text('Claude Code')),
                      DropdownMenuItem(value: 'openai', child: Text('OpenAI API / Codex')),
                      DropdownMenuItem(value: 'gemini', child: Text('Google Gemini API')),
                    ],
                    onChanged: (val) => setModalState(() => selectedAgent = val ?? 'antigravity'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: nameCtrl,
                    style: GoogleFonts.jetBrainsMono(fontSize: 12, color: TerminalColors.pureWhite),
                    decoration: const InputDecoration(labelText: 'Account / Key Label', hintText: 'Personal / Work'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: tokenCtrl,
                    obscureText: obscure,
                    style: GoogleFonts.jetBrainsMono(fontSize: 12, color: TerminalColors.pureWhite),
                    decoration: InputDecoration(
                      labelText: 'API Token / Auth Secret',
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility : Icons.visibility_off, color: TerminalColors.zinc),
                        onPressed: () => setModalState(() => obscure = !obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
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
                              _loadAll();
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

  Widget _buildAntigravityAccountCard() {
    final activeEmail = _antigravityAccount?['active_account'] ?? 'parejasarronkian@gmail.com';
    final accounts = (_antigravityAccount?['accounts'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        [activeEmail];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TerminalColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF51CF66), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFF51CF66), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'ANTIGRAVITY IDE ACTIVE ACCOUNT',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: TerminalColors.pureWhite,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B3820),
                  border: Border.all(color: const Color(0xFF51CF66)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  'AUTHENTICATED',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF51CF66),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.account_circle, color: TerminalColors.pureWhite, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  activeEmail,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: TerminalColors.pureWhite,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Additional known accounts if any
          if (accounts.length > 1) ...[
            Text('SWITCH ACCOUNT:', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: TerminalColors.zinc)),
            const SizedBox(height: 6),
            ...accounts.where((e) => e != activeEmail).map((acc) {
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1B),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: TerminalColors.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(acc,
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.zinc),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    InkWell(
                      onTap: () => _switchAntigravity(acc),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: TerminalColors.pureWhite,
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          'SWITCH',
                          style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.black),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: TerminalColors.pureWhite,
                side: const BorderSide(color: TerminalColors.cardBorderLight),
                padding: const EdgeInsets.symmetric(vertical: 8),
              ),
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: Text('SWITCH / ADD GOOGLE ACCOUNT', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold)),
              onPressed: _showAddGoogleAccountDialog,
            ),
          ),
        ],
      ),
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
            tooltip: 'Add Account / Token',
            onPressed: _showAddAccountDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: TerminalColors.pureWhite),
            onPressed: _loadAll,
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

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (agentFilter == 'ALL' || agentFilter == 'ANTIGRAVITY')
                      _buildAntigravityAccountCard(),

                    if (filtered.isNotEmpty) ...[
                      Text(
                        'SAVED PROFILES (${filtered.length})',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.zinc),
                      ),
                      const SizedBox(height: 8),
                      ...filtered.map((p) {
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
                      }),
                    ] else if (agentFilter != 'ALL' && agentFilter != 'ANTIGRAVITY') ...[
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              const Icon(Icons.account_circle_outlined, size: 48, color: TerminalColors.zinc),
                              const SizedBox(height: 12),
                              Text(
                                'No profile saved for $agentFilter.',
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
                        ),
                      ),
                    ],
                  ],
                );
              }).toList(),
            ),
    );
  }
}
