import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import '../widgets/terminal_widgets.dart';
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
        setState(() {}); // refresh countdown
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

  String _formatCountdown(int seconds) {
    if (seconds <= 0) return 'Resetting now';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}h ${minutes.toString().padLeft(2, '0')}m ${secs.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    final quotas = (_summary['models_quota'] as List<dynamic>?) ?? [];
    final totalAllTime = _summary['total_tokens_all_time'] ?? 0;
    final totalToday = _summary['total_tokens_today'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'TOKEN & QUOTA MONITOR',
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
                  // Overview Statistics Card
                  TerminalCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TOKEN USAGE OVERVIEW', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: TerminalColors.zinc)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('TOKENS TODAY', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.textMuted)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatNumber(totalToday),
                                    style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 36, color: TerminalColors.cardBorder),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('LIFETIME TOTAL', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.textMuted)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatNumber(totalAllTime),
                                    style: GoogleFonts.jetBrainsMono(fontSize: 18, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Account Switcher Shortcut Action
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TerminalColors.pureWhite,
                      side: const BorderSide(color: TerminalColors.pureWhite, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: Text(
                      'SWITCH & MANAGE AGENT ACCOUNTS',
                      style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AccountSwitcherScreen()),
                      );
                      _loadSummary();
                    },
                  ),
                  const SizedBox(height: 20),

                  // Model Quotas Header
                  Text(
                    'AI MODEL QUOTAS & RESET TIMERS',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: TerminalColors.zinc),
                  ),
                  const SizedBox(height: 10),

                  ...quotas.map((q) {
                    final agent = q['agent'] ?? '';
                    final model = q['model'] ?? '';
                    final tier = q['tier'] ?? '';
                    final activeAccount = q['active_account'] ?? 'Default';
                    final tokensToday = q['tokens_today'] as int? ?? 0;
                    final tokensLimit = q['tokens_daily_limit'] as int? ?? 1;
                    final requestsToday = q['requests_today'] as int? ?? 0;
                    final requestsLimit = q['requests_daily_limit'] as int? ?? 1;
                    final percent = (q['percent_used'] as num? ?? 0).toDouble();
                    final resetSecs = q['reset_countdown_seconds'] as int? ?? 0;
                    final isAvailable = q['is_available'] == true;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: TerminalColors.surface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: TerminalColors.cardBorder),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      agent == 'antigravity'
                                          ? Icons.auto_awesome
                                          : agent == 'claude'
                                              ? Icons.psychology
                                              : agent == 'openai'
                                                  ? Icons.bolt
                                                  : Icons.computer,
                                      size: 16,
                                      color: TerminalColors.pureWhite,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      model,
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: TerminalColors.pureWhite,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isAvailable ? Colors.white : Colors.red,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    isAvailable ? 'AVAILABLE' : 'LIMITED',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Tier & Active Account
                            Row(
                              children: [
                                Text('TIER: $tier', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc)),
                                const SizedBox(width: 12),
                                Text('•', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'ACC: $activeAccount',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.pureWhite),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Progress Bar
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('USAGE', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.textMuted)),
                                Text(
                                  '${_formatNumber(tokensToday)} / ${_formatNumber(tokensLimit)} tokens (${percent.toStringAsFixed(1)}%)',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.pureWhite),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            AsciiProgressBar(percent: percent.clamp(0.0, 100.0).round()),
                            const SizedBox(height: 10),

                            // Reset Timer & Requests Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.timer_outlined, size: 13, color: TerminalColors.zinc),
                                    const SizedBox(width: 4),
                                    Text(
                                      resetSecs > 0 ? 'Resets in ${_formatCountdown(resetSecs)}' : 'No Limit',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: TerminalColors.pureWhite,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '$requestsToday / $requestsLimit reqs',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }

  String _formatNumber(dynamic n) {
    final num val = (n is num) ? n : int.tryParse(n.toString()) ?? 0;
    if (val >= 1000000) {
      return '${(val / 1000000).toStringAsFixed(1)}M';
    } else if (val >= 1000) {
      return '${(val / 1000).toStringAsFixed(1)}K';
    }
    return val.toString();
  }
}
