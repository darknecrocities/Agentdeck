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
  Map<String, dynamic>? _tokenSummary;
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
      final results = await Future.wait([
        _api.getAuthProfiles().catchError((_) => <dynamic>[]),
        _api.getAntigravityAccount().catchError((_) => <String, dynamic>{}),
        _api.getTokenSummary().catchError((_) => <String, dynamic>{}),
      ]);

      if (mounted) {
        setState(() {
          _profiles = results[0] as List<dynamic>;
          _antigravityAccount = results[1] as Map<String, dynamic>;
          _tokenSummary = results[2] as Map<String, dynamic>;
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
    if (ok) {
      await _api.syncIdeQuota();
    }
    await _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? '✓ Switched active Antigravity account to $email & synced quotas'
              : 'Failed to switch Antigravity account'),
          backgroundColor: ok ? const Color(0xFF1F2937) : Colors.red.shade900,
        ),
      );
    }
  }

  Future<void> _removeAntigravityAccount(String email) async {
    setState(() => _loading = true);
    final ok = await _api.removeAntigravityAccount(email);
    await _loadAll();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Removed account $email from Antigravity profile'
              : 'Failed to remove account'),
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
            color: Color(0xFF0C0C0C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(top: BorderSide(color: Color(0xFF404040), width: 1.5)),
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
                      const Icon(Icons.account_circle, color: TerminalColors.pureWhite, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'ADD / SWITCH GOOGLE ACCOUNT',
                        style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: TerminalColors.pureWhite,
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
              Text(
                'Enter the Google account email configured with Antigravity IDE on host:',
                style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: TerminalColors.zinc),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.jetBrainsMono(fontSize: 12, color: TerminalColors.pureWhite),
                decoration: InputDecoration(
                  labelText: 'Google Email Address',
                  labelStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 11),
                  hintText: 'developer@example.com',
                  hintStyle: GoogleFonts.jetBrainsMono(color: const Color(0xFF444444), fontSize: 11),
                  filled: true,
                  fillColor: Colors.black,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0xFF333333)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                  child: Text(
                    'SWITCH & ACTIVATE ACCOUNT',
                    style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w900, fontSize: 11),
                  ),
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
                color: Color(0xFF0C0C0C),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(top: BorderSide(color: Color(0xFF404040), width: 1.5)),
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
                          const Icon(Icons.key, color: TerminalColors.pureWhite, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'ADD API KEY / AUTH PROFILE',
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: TerminalColors.pureWhite,
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
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedAgent,
                    dropdownColor: TerminalColors.surfaceElevated,
                    style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 12),
                    decoration: InputDecoration(
                      labelText: 'Agent Service',
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
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
                    decoration: InputDecoration(
                      labelText: 'Profile / Account Name',
                      hintText: 'e.g. Work Pro / Personal',
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: tokenCtrl,
                    obscureText: obscure,
                    style: GoogleFonts.jetBrainsMono(fontSize: 12, color: TerminalColors.pureWhite),
                    decoration: InputDecoration(
                      labelText: 'API Key / Auth Token / Cookie',
                      filled: true,
                      fillColor: Colors.black,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                      suffixIcon: IconButton(
                        icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: TerminalColors.zinc, size: 18),
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
    final activeEmail = _antigravityAccount?['active_account'] ?? 'developer@example.com';
    final accounts = (_antigravityAccount?['accounts'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
        [activeEmail];

    final gemini = _tokenSummary?['gemini_quota'] as Map<String, dynamic>?;
    final geminiWeekly = (gemini?['weekly_limit_remaining'] as num?)?.toInt() ?? 25;
    final gemini5h = (gemini?['five_hour_limit_remaining'] as num?)?.toInt() ?? 54;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
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
                    'ANTIGRAVITY GOOGLE AUTH',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11.5,
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

          // Active Account Details
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF262626)),
            ),
            child: Row(
              children: [
                const Icon(Icons.account_circle, color: TerminalColors.pureWhite, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeEmail,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: TerminalColors.pureWhite,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Google OAuth (Personal) • Quotas Active',
                        style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: const Color(0xFF51CF66)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Quota preview strip
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'Gemini Weekly: $geminiWeekly% left',
                    style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: TerminalColors.zinc),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141414),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    '5-Hour Limit: $gemini5h% left',
                    style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: TerminalColors.zinc),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Configured Accounts List
          Text('STORED WORKSTATION ACCOUNTS:', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: TerminalColors.zinc)),
          const SizedBox(height: 6),

          ...accounts.map((acc) {
            final isCurrent = acc == activeEmail;
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isCurrent ? const Color(0xFF141414) : Colors.black,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: isCurrent ? TerminalColors.pureWhite : const Color(0xFF222222)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCurrent ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 14,
                        color: isCurrent ? TerminalColors.pureWhite : TerminalColors.zinc,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        acc,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          color: isCurrent ? TerminalColors.pureWhite : TerminalColors.zinc,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      if (!isCurrent) ...[
                        InkWell(
                          onTap: () => _switchAntigravity(acc),
                          borderRadius: BorderRadius.circular(3),
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
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => _removeAntigravityAccount(acc),
                          child: const Icon(Icons.close, size: 14, color: TerminalColors.zinc),
                        ),
                      ] else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: Text(
                            'ACTIVE',
                            style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.w900, color: Colors.black),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TerminalColors.pureWhite,
                    side: const BorderSide(color: Color(0xFF333333)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.add, size: 14),
                  label: Text('LINK GOOGLE ACCOUNT', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold)),
                  onPressed: _showAddGoogleAccountDialog,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TerminalColors.pureWhite,
                    side: const BorderSide(color: Color(0xFF333333)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: const Icon(Icons.sync, size: 14),
                  label: Text('REFRESH AUTH', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold)),
                  onPressed: _loadAll,
                ),
              ),
            ],
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
          'AUTH & ACCOUNT SWITCHER',
          style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: TerminalColors.pureWhite),
            onPressed: _showAddAccountDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: TerminalColors.zinc),
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: TerminalColors.pureWhite,
          unselectedLabelColor: TerminalColors.textMuted,
          indicatorColor: TerminalColors.pureWhite,
          tabs: _agents.map((a) => Tab(text: a)).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: TerminalColors.pureWhite))
          : TabBarView(
              controller: _tabController,
              children: _agents.map((agent) {
                final filtered = agent == 'ALL'
                    ? _profiles
                    : _profiles.where((p) => (p['agent_id'] as String).toLowerCase() == agent.toLowerCase()).toList();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (agent == 'ALL' || agent == 'ANTIGRAVITY') _buildAntigravityAccountCard(),
                    if (filtered.isEmpty && agent != 'ANTIGRAVITY')
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Text(
                            'No custom API key profiles for $agent.\nTap + to add a credential profile.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted, fontSize: 11),
                          ),
                        ),
                      )
                    else
                      ...filtered.map((profile) {
                        final isActive = profile['is_active'] == true;
                        final agentId = (profile['agent_id'] ?? '').toString().toUpperCase();
                        final accountName = profile['account_name'] ?? 'Default';
                        final masked = profile['token_masked'] ?? '••••••••';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isActive ? const Color(0xFF141414) : Colors.black,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: isActive ? TerminalColors.pureWhite : const Color(0xFF262626),
                              width: isActive ? 1.2 : 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        accountName,
                                        style: GoogleFonts.jetBrainsMono(
                                          fontWeight: FontWeight.bold,
                                          color: TerminalColors.pureWhite,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1C1C1C),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                        child: Text(
                                          agentId,
                                          style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: TerminalColors.zinc),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Token: $masked',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  if (!isActive)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: TerminalColors.pureWhite,
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        minimumSize: const Size(60, 28),
                                      ),
                                      onPressed: () => _activateProfile(profile['id']),
                                      child: Text(
                                        'ACTIVATE',
                                        style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                      child: Text(
                                        'ACTIVE',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: TerminalColors.zinc),
                                    onPressed: () => _deleteProfile(profile['id']),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                );
              }).toList(),
            ),
    );
  }
}
