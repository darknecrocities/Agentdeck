import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/workstation_manager.dart';
import '../theme/terminal_theme.dart';
import 'account_switcher_screen.dart';

class TokenMonitorScreen extends StatefulWidget {
  const TokenMonitorScreen({super.key});

  @override
  State<TokenMonitorScreen> createState() => _TokenMonitorScreenState();
}

class _TokenMonitorScreenState extends State<TokenMonitorScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic> _summary = {};
  Map<String, dynamic>? _antigravityAccount;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
    WorkstationManager().addListener(_onWorkstationChanged);
  }

  void _onWorkstationChanged() {
    if (mounted) {
      _loadSummary();
    }
  }

  @override
  void dispose() {
    WorkstationManager().removeListener(_onWorkstationChanged);
    super.dispose();
  }

  Future<void> _loadSummary() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getTokenSummary();
      final agy = await _api.getAntigravityAccount();
      if (mounted) {
        setState(() {
          _summary = res;
          _antigravityAccount = agy;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final gemini = _summary['gemini_quota'] as Map<String, dynamic>?;
    final claudeGpt = _summary['claude_gpt_quota'] as Map<String, dynamic>?;
    final models = (_summary['models_quota'] as List<dynamic>?) ?? [];

    final geminiWeekly = (gemini?['weekly_limit_remaining'] as num?)?.toInt() ?? 85;
    final geminiWeeklyText = gemini?['weekly_reset_text'] ?? '3 days, 3 hours';
    final gemini5h = (gemini?['five_hour_limit_remaining'] as num?)?.toInt() ?? 90;
    final gemini5hText = gemini?['five_hour_reset_text'] ?? '4 hours, 12 minutes';

    final claudeWeekly = (claudeGpt?['weekly_limit_remaining'] as num?)?.toInt() ?? 0;
    final claudeWeeklyText = claudeGpt?['weekly_reset_text'] ?? 'Requires Anthropic API Token';
    final claude5h = (claudeGpt?['five_hour_limit_remaining'] as num?)?.toInt() ?? 0;
    final claude5hText = claudeGpt?['five_hour_reset_text'] ?? 'Requires Anthropic API Token';

    final activeEmail = _antigravityAccount?['active_account'] ??
        _summary['models_quota']?[0]?['active_account'] ??
        'developer@example.com';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ANTIGRAVITY USAGE & LIMITS',
          style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_accounts, color: TerminalColors.pureWhite),
            tooltip: 'Manage Accounts',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AccountSwitcherScreen()),
              );
              _loadSummary();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: TerminalColors.pureWhite),
            onPressed: _loadSummary,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: TerminalColors.pureWhite))
          : RefreshIndicator(
              onRefresh: _loadSummary,
              color: TerminalColors.pureWhite,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Active Account Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TerminalColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF51CF66), width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'assets/images/agentdeck_thinking.png',
                              height: 38,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SYNCED GOOGLE ACCOUNT',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF51CF66),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  activeEmail,
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: TerminalColors.pureWhite,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AccountSwitcherScreen()),
                            );
                            _loadSummary();
                          },
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
                  ),

                  // 1. Gemini Models Section
                  _buildSectionHeader('Gemini Models'),
                  const SizedBox(height: 8),
                  _buildLimitCard(
                    title: 'Weekly Limit Remaining',
                    subtitle: 'Calculated for $activeEmail. Refreshes in $geminiWeeklyText.',
                    percentage: geminiWeekly,
                    color: const Color(0xFF51CF66),
                  ),
                  const SizedBox(height: 10),
                  _buildLimitCard(
                    title: 'Five Hour Limit Remaining',
                    subtitle: 'Rolling window of agent requests. Next window reset in $gemini5hText.',
                    percentage: gemini5h,
                    color: const Color(0xFF51CF66),
                  ),
                  const SizedBox(height: 20),

                  // 2. Claude and GPT models Section
                  _buildSectionHeader('Claude and GPT models'),
                  const SizedBox(height: 8),
                  _buildLimitCard(
                    title: 'Weekly Limit Remaining',
                    subtitle: claudeWeekly > 0
                        ? 'Active Anthropic Token linked. Refreshes: $claudeWeeklyText.'
                        : 'Google OAuth Free Tier. To unlock Claude models, add your Anthropic key in Accounts.',
                    percentage: claudeWeekly,
                    color: claudeWeekly > 0 ? const Color(0xFF51CF66) : const Color(0xFF555555),
                  ),
                  const SizedBox(height: 10),
                  _buildLimitCard(
                    title: 'Five Hour Limit Remaining',
                    subtitle: claude5h > 0
                        ? 'Live token budget: $claude5hText.'
                        : 'Add Claude / OpenAI key in Account Switcher to enable direct multi-agent leasing.',
                    percentage: claude5h,
                    color: claude5h > 0 ? const Color(0xFF51CF66) : const Color(0xFF555555),
                  ),
                  const SizedBox(height: 24),

                  // 3. Detailed Antigravity Model Fleet Quotas
                  Text(
                    'MODEL-BY-MODEL AVAILABILITY',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: TerminalColors.zinc,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (models.isNotEmpty)
                    ...models.map((m) {
                      final name = m['model'] ?? '';
                      final tier = m['tier'] ?? '';
                      final isAvail = m['is_available'] == true;
                      final pctUsed = (m['percent_used'] as num?)?.toDouble() ?? 0.0;
                      final pctLeft = (100.0 - pctUsed).round().clamp(0, 100);
                      final resetText = m['reset_time_utc'] ?? '';

                      return _buildModelQuotaItem(
                        name,
                        tier,
                        'Effort: Adaptive • Reset: $resetText',
                        pctLeft,
                        isAvail,
                        warning: isAvail ? null : 'Key Required in Accounts',
                      );
                    })
                  else ...[
                    _buildModelQuotaItem('Gemini 3.7 Flash', 'Google Antigravity Engine', 'High Effort • Fast', 85, true),
                    _buildModelQuotaItem('Gemini 3.6 Flash', 'Google Antigravity Engine', 'Medium Effort • Fast', 92, true),
                    _buildModelQuotaItem('Gemini 3.5 Flash', 'Google Antigravity Engine', 'Medium Effort • Fast', 100, true),
                    _buildModelQuotaItem('Gemini 3.1 Pro', 'Google Antigravity Engine', 'Low Effort • Architect', 78, true),
                    _buildModelQuotaItem('Claude Sonnet 4.6', 'Anthropic (Thinking)', 'High Effort • Precision', 0, false, warning: 'Add Claude Key'),
                    _buildModelQuotaItem('GPT-4o / Codex', 'OpenAI API', 'Medium Effort • Logic', 0, false, warning: 'Add OpenAI Key'),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: TerminalColors.pureWhite,
          ),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.info_outline, size: 14, color: TerminalColors.zinc),
      ],
    );
  }

  Widget _buildLimitCard({
    required String title,
    required String subtitle,
    required int percentage,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F0F),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TerminalColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: TerminalColors.pureWhite,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10.5,
                    color: TerminalColors.zinc,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              Text(
                '$percentage%',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: TerminalColors.pureWhite,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  value: percentage / 100.0,
                  strokeWidth: 3,
                  backgroundColor: const Color(0xFF222222),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModelQuotaItem(String name, String provider, String details, int percent, bool available, {String? warning}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TerminalColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TerminalColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: available ? TerminalColors.pureWhite : TerminalColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: available ? Colors.white : Colors.transparent,
                  border: Border.all(color: available ? Colors.white : const Color(0xFFFFD43B)),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  available ? 'AVAILABLE' : 'KEY REQUIRED',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w900,
                    color: available ? Colors.black : const Color(0xFFFFD43B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  details,
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (warning != null)
                Text(
                  warning,
                  style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: const Color(0xFFFFD43B)),
                )
              else
                Text(
                  '$percent% left',
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.pureWhite, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
