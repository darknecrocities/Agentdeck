import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
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
  bool _loading = true;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadSummary();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _summary.isNotEmpty) {
        setState(() {}); // live ticking countdown
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getTokenSummary();
      if (mounted) {
        setState(() {
          _summary = res;
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
                  // 1. Gemini Models Section
                  _buildSectionHeader('Gemini Models'),
                  const SizedBox(height: 8),
                  _buildLimitCard(
                    title: 'Weekly Limit Remaining',
                    subtitle: 'You have used some of your weekly limit, it will fully refresh in 3 days, 3 hours.',
                    percentage: 25,
                    color: const Color(0xFF51CF66),
                  ),
                  const SizedBox(height: 10),
                  _buildLimitCard(
                    title: 'Five Hour Limit Remaining',
                    subtitle: 'You have used some of your 5-hour limit, it will fully refresh in 2 hours, 36 minutes.',
                    percentage: 54,
                    color: const Color(0xFF51CF66),
                  ),
                  const SizedBox(height: 20),

                  // 2. Claude and GPT models Section
                  _buildSectionHeader('Claude and GPT models'),
                  const SizedBox(height: 8),
                  _buildLimitCard(
                    title: 'Weekly Limit Remaining',
                    subtitle: 'You have hit your weekly limit, it refreshes in 3 days, 5 hours. If on a supported paid plan, you can use AI credits in the interim or upgrade to a higher tier.',
                    percentage: 0,
                    color: const Color(0xFF555555),
                  ),
                  const SizedBox(height: 10),
                  _buildLimitCard(
                    title: 'Five Hour Limit Remaining',
                    subtitle: 'You have hit your weekly limit, the 5-hour limit does not currently apply. Your weekly limit will fully refresh in 3 days, 5 hours.',
                    percentage: 0,
                    color: const Color(0xFF555555),
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

                  _buildModelQuotaItem('Gemini 3.7 Flash', 'Google Antigravity Engine', 'High Effort • Fast', 85, true),
                  _buildModelQuotaItem('Gemini 3.6 Flash', 'Google Antigravity Engine', 'Medium Effort • Fast', 92, true),
                  _buildModelQuotaItem('Gemini 3.5 Flash', 'Google Antigravity Engine', 'Medium Effort • Fast', 100, true),
                  _buildModelQuotaItem('Gemini 3.1 Pro', 'Google Antigravity Engine', 'Low Effort • Architect', 78, true),
                  _buildModelQuotaItem('Claude Sonnet 4.6', 'Anthropic (Thinking)', 'High Effort • Precision', 0, false, warning: 'Weekly limit reached'),
                  _buildModelQuotaItem('Claude Opus 4.6', 'Anthropic (Thinking)', 'High Effort • Deep Reason', 0, false, warning: 'Weekly limit reached'),
                  _buildModelQuotaItem('GPT-OSS 120B', 'OpenAI / OSS', 'Medium Effort • Logic', 0, false, warning: 'Quota exhausted'),
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
              Text(
                name,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: available ? TerminalColors.pureWhite : TerminalColors.textMuted,
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
                  available ? 'AVAILABLE' : 'LIMIT REACHED',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
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
              Text(
                details,
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc),
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
