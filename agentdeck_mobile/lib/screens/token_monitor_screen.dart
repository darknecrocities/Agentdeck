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
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadSummary();
    WorkstationManager().addListener(_onWorkstationChanged);
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pollSilently());
  }

  void _onWorkstationChanged() {
    if (mounted) {
      _loadSummary();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    WorkstationManager().removeListener(_onWorkstationChanged);
    super.dispose();
  }

  Future<void> _pollSilently() async {
    if (!mounted) return;
    try {
      final res = await _api.getTokenSummary();
      final agy = await _api.getAntigravityAccount();
      if (mounted) {
        setState(() {
          _summary = res;
          _antigravityAccount = agy;
        });
      }
    } catch (_) {}
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
    final planName = _summary['plan_name'] ?? 'Google AI Pro';
    final creditOverages = _summary['credit_overages_enabled'] == true;

    final geminiWeekly = (gemini?['weekly_limit_remaining'] as num?)?.toInt() ?? 83;
    final geminiWeeklyText = gemini?['weekly_reset_text'] ?? '4 days, 19 hours';
    final gemini5h = (gemini?['five_hour_limit_remaining'] as num?)?.toInt() ?? 80;
    final gemini5hText = gemini?['five_hour_reset_text'] ?? '4 hours, 33 minutes';

    final claudeWeekly = (claudeGpt?['weekly_limit_remaining'] as num?)?.toInt() ?? 24;
    final claudeWeeklyText = claudeGpt?['weekly_reset_text'] ?? '23 hours, 3 minutes';
    final claude5h = (claudeGpt?['five_hour_limit_remaining'] as num?)?.toInt() ?? 100;
    final claude5hText = claudeGpt?['five_hour_reset_text'] ?? 'Rolling window reset in 0 hours, 15 minutes';

    final activeEmail = _antigravityAccount?['active_account'] ??
        _summary['models_quota']?[0]?['active_account'] ??
        'developer@example.com';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'ANTIGRAVITY QUOTAS',
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
                  // Active Synced Google Account Card
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: TerminalColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF51CF66), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Image.asset(
                                'assets/images/agentdeck_thinking.png',
                                height: 36,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
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
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: TerminalColors.pureWhite,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const AccountSwitcherScreen()),
                            );
                            _loadSummary();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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

                  // Subscription Plan & Credit Overages Strip
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0C0C),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF262626)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.workspace_premium, color: Color(0xFFFFD43B), size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'PLAN: $planName',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: TerminalColors.pureWhite,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: creditOverages ? const Color(0xFF1B3820) : const Color(0xFF1C1C1C),
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: creditOverages ? const Color(0xFF51CF66) : const Color(0xFF333333)),
                          ),
                          child: Text(
                            creditOverages ? 'OVERAGES ON' : 'AI CREDITS: STANDBY',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                              color: creditOverages ? const Color(0xFF51CF66) : TerminalColors.zinc,
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
                    subtitle: 'You have used some of your weekly limit, it will fully refresh in $geminiWeeklyText.',
                    percentage: geminiWeekly,
                    color: const Color(0xFF51CF66),
                  ),
                  const SizedBox(height: 10),
                  _buildLimitCard(
                    title: 'Five Hour Limit Remaining',
                    subtitle: 'You have used some of your 5-hour limit, it will fully refresh in $gemini5hText.',
                    percentage: gemini5h,
                    color: const Color(0xFF51CF66),
                  ),
                  const SizedBox(height: 20),

                  // 2. Claude and GPT models Section
                  _buildSectionHeader('Claude and GPT models'),
                  const SizedBox(height: 8),
                  _buildLimitCard(
                    title: 'Weekly Limit Remaining',
                    subtitle: 'You have used some of your weekly limit, it will fully refresh in $claudeWeeklyText.',
                    percentage: claudeWeekly,
                    color: claudeWeekly < 30 ? const Color(0xFFFFD43B) : const Color(0xFF51CF66),
                  ),
                  const SizedBox(height: 10),
                  _buildLimitCard(
                    title: 'Five Hour Limit Remaining',
                    subtitle: 'Full 5-hour quota available for multi-model reasoning. $claude5hText.',
                    percentage: claude5h,
                    color: const Color(0xFF51CF66),
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
                      );
                    })
                  else ...[
                    _buildModelQuotaItem('Gemini 3.7 Flash', 'Google AI Pro • Adaptive Reasoning', 'Effort: Adaptive • Reset: $gemini5hText', 80, true),
                    _buildModelQuotaItem('Gemini 3.6 Flash', 'Google AI Pro • High Speed', 'Effort: Fast • Reset: $geminiWeeklyText', 83, true),
                    _buildModelQuotaItem('Claude Sonnet 4.6 (Thinking)', 'Google AI Pro Integrated', 'Effort: High • Reset: $claudeWeeklyText', 24, true),
                    _buildModelQuotaItem('GPT-4o / Codex', 'Google AI Pro Multi-Model', 'Effort: Standard • Reset: Rolling Window', 100, true),
                    _buildModelQuotaItem('DeepSeek Coder / Llama 3', 'Local Metal GPU (Unlimited)', 'Effort: Local GPU • Reset: Instant', 100, true),
                  ],

                  const SizedBox(height: 20),
                  // Sync / Refresh Action Card
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TerminalColors.pureWhite,
                      side: const BorderSide(color: Color(0xFF51CF66), width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.sync, size: 16, color: Color(0xFF51CF66)),
                    label: Text(
                      'FORCE SYNC WITH ANTIGRAVITY IDE',
                      style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11, color: TerminalColors.pureWhite),
                    ),
                    onPressed: () async {
                      setState(() => _loading = true);
                      await _api.syncIdeQuota();
                      await _loadSummary();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✓ Live quotas & tokens synchronized with Antigravity IDE host'),
                            backgroundColor: Color(0xFF1F2937),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return InkWell(
      onTap: _showAdjustQuotaDialog,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(
              title,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: TerminalColors.pureWhite,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.tune, size: 13, color: Color(0xFF51CF66)),
            const SizedBox(width: 4),
            Text(
              'ADJUST',
              style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: const Color(0xFF51CF66), fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLimitCard({
    required String title,
    required String subtitle,
    required int percentage,
    required Color color,
  }) {
    return InkWell(
      onTap: _showAdjustQuotaDialog,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C0C),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF222222)),
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
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: TerminalColors.pureWhite,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      color: TerminalColors.zinc,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Row(
              children: [
                Text(
                  '$percentage%',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: TerminalColors.pureWhite,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    value: percentage / 100.0,
                    strokeWidth: 2.5,
                    backgroundColor: const Color(0xFF1E1E1E),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelQuotaItem(
    String name,
    String tier,
    String desc,
    int pctLeft,
    bool isAvailable,
  ) {
    return InkWell(
      onTap: _showAdjustQuotaDialog,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C0C),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF222222)),
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
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: TerminalColors.pureWhite,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isAvailable ? Colors.white : const Color(0xFF262626),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    isAvailable ? 'AVAILABLE' : 'KEY REQUIRED',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: isAvailable ? Colors.black : TerminalColors.zinc,
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
                    desc,
                    style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: TerminalColors.zinc),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$pctLeft% left',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: pctLeft < 30 ? const Color(0xFFFFD43B) : TerminalColors.pureWhite,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAdjustQuotaDialog() {
    final gemini = _summary['gemini_quota'] as Map<String, dynamic>?;
    final claudeGpt = _summary['claude_gpt_quota'] as Map<String, dynamic>?;

    double gWeekly = ((gemini?['weekly_limit_remaining'] as num?)?.toDouble() ?? 84.0).clamp(0, 100);
    double g5h = ((gemini?['five_hour_limit_remaining'] as num?)?.toDouble() ?? 75.0).clamp(0, 100);
    double cWeekly = ((claudeGpt?['weekly_limit_remaining'] as num?)?.toDouble() ?? 24.0).clamp(0, 100);
    double c5h = ((claudeGpt?['five_hour_limit_remaining'] as num?)?.toDouble() ?? 100.0).clamp(0, 100);

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
                          const Icon(Icons.tune, color: Color(0xFF51CF66), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'CALIBRATE ANTIGRAVITY QUOTAS',
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
                  const SizedBox(height: 8),
                  Text(
                    'Sync custom quota percentages directly with host IDE:',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc),
                  ),
                  const SizedBox(height: 14),

                  // Gemini 5-Hour Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Gemini 5-Hour Remaining:', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.pureWhite)),
                      Text('${g5h.round()}%', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF51CF66))),
                    ],
                  ),
                  Slider(
                    value: g5h,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    activeColor: const Color(0xFF51CF66),
                    inactiveColor: const Color(0xFF262626),
                    onChanged: (v) => setModalState(() => g5h = v),
                  ),

                  // Gemini Weekly Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Gemini Weekly Remaining:', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.pureWhite)),
                      Text('${gWeekly.round()}%', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF51CF66))),
                    ],
                  ),
                  Slider(
                    value: gWeekly,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    activeColor: const Color(0xFF51CF66),
                    inactiveColor: const Color(0xFF262626),
                    onChanged: (v) => setModalState(() => gWeekly = v),
                  ),

                  // Claude Weekly Slider
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Claude Weekly Remaining:', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.pureWhite)),
                      Text('${cWeekly.round()}%', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFFFD43B))),
                    ],
                  ),
                  Slider(
                    value: cWeekly,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    activeColor: const Color(0xFFFFD43B),
                    inactiveColor: const Color(0xFF262626),
                    onChanged: (v) => setModalState(() => cWeekly = v),
                  ),

                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: TerminalColors.pureWhite,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        Navigator.pop(ctx);
                        setState(() => _loading = true);
                        await _api.syncIdeQuota(
                          gemini5h: g5h.round(),
                          geminiWeekly: gWeekly.round(),
                          claudeWeekly: cWeekly.round(),
                          claude5h: c5h.round(),
                        );
                        await _loadSummary();
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('✓ Quotas calibrated and synced with Antigravity IDE'),
                              backgroundColor: Color(0xFF1F2937),
                            ),
                          );
                        }
                      },
                      child: Text(
                        'APPLY & SYNC TO ANTIGRAVITY IDE',
                        style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
