import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import '../widgets/terminal_widgets.dart';
import 'session_screen.dart';
import 'token_monitor_screen.dart';
import 'account_switcher_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _deviceInfo;
  List<dynamic> _agents = [];
  List<dynamic> _projects = [];
  List<dynamic> _approvals = [];
  List<dynamic> _sessions = [];
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 4), (_) => _loadData(silent: true));
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final dev = await _api.getDevice();
      final ag = await _api.getAgents();
      final proj = await _api.getProjects();
      final app = await _api.getApprovals();
      final sess = await _api.getSessions();

      if (mounted) {
        setState(() {
          _deviceInfo = dev;
          _agents = ag;
          _projects = proj;
          _approvals = app;
          _sessions = sess;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && !silent) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _deviceInfo == null) {
      return const Center(
        child: CircularProgressIndicator(color: TerminalColors.pureWhite),
      );
    }

    final cpu = (_deviceInfo?['cpu_usage'] as num?)?.toInt() ?? 0;
    final memUsed = _deviceInfo?['memory_used_mb'] ?? 0;
    final memTotal = _deviceInfo?['memory_total_mb'] ?? 1;
    final memPercent = ((memUsed / memTotal) * 100).round();
    final diskFree = (_deviceInfo?['disk_free_gb'] as num?)?.toStringAsFixed(1) ?? '0';
    final host = _deviceInfo?['hostname'] ?? 'MacBook Air';
    final tsIp = _deviceInfo?['tailscale_ip'] ?? '100.114.182.27';

    return Scaffold(
      appBar: AppBar(
        title: const AgentDeckLogoHeader(size: 26),
        actions: [
          IconButton(
            icon: const Icon(Icons.token_outlined, color: TerminalColors.pureWhite, size: 20),
            tooltip: 'Token & Quota Monitor',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TokenMonitorScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.manage_accounts_outlined, color: TerminalColors.pureWhite, size: 20),
            tooltip: 'Switch Accounts',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AccountSwitcherScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: TerminalColors.pureWhite, size: 20),
            onPressed: () => widget.onNavigate(6),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: TerminalColors.pureWhite,
        backgroundColor: TerminalColors.surface,
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Token & Quota Quick Pill
            InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TokenMonitorScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: TerminalColors.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: TerminalColors.cardBorderLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.speed, color: TerminalColors.pureWhite, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ANTIGRAVITY QUOTA: ACTIVE & READY',
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.bold,
                              color: TerminalColors.pureWhite,
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            'Gemini 2.5 Pro (Thinking) • Resets at 00:00 UTC',
                            style: GoogleFonts.jetBrainsMono(
                              color: TerminalColors.zinc,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: TerminalColors.zinc, size: 16),
                  ],
                ),
              ),
            ),
            // Approvals Alert Banner
            if (_approvals.isNotEmpty) ...[
              InkWell(
                onTap: () => widget.onNavigate(5),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.black, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'SECURITY APPROVAL REQUIRED (${_approvals.length} PENDING)',
                          style: GoogleFonts.jetBrainsMono(
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_forward, color: Colors.black, size: 16),
                    ],
                  ),
                ),
              ),
            ],

            // Host Telemetry Card
            TerminalCard(
              title: 'MAC WORKSTATION TELEMETRY',
              trailing: const StatusBadge(status: 'ONLINE'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        host.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: TerminalColors.pureWhite,
                        ),
                      ),
                      Text(
                        'TS: $tsIp',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: TerminalColors.silver,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildMetricRow('CPU LOAD', cpu),
                  const SizedBox(height: 10),
                  _buildMetricRow(
                    'MEMORY',
                    memPercent,
                    subtitle: '${(memUsed / 1024).toStringAsFixed(1)}G / ${(memTotal / 1024).toStringAsFixed(1)}G',
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('DISK AVAILABLE', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc)),
                      Text('$diskFree GB FREE', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Antigravity Quick Command & Prompt Bar
            TerminalCard(
              title: 'ANTIGRAVITY CLI PROMPT CENTER',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: TerminalColors.cardBorderLight),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text('FIRST-CLASS', style: GoogleFonts.jetBrainsMono(fontSize: 9, color: TerminalColors.pureWhite)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'QUICK PROMPT DISPATCHER',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.zinc),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _buildQuickPromptChip('🔍 Analyze Architecture', 'Analyze this codebase architecture and create an implementation plan.', 'antigravity'),
                      _buildQuickPromptChip('⚡ Implement Feature', 'Proceed with the implementation and wire up all services.', 'antigravity'),
                      _buildQuickPromptChip('🧪 Run & Fix Tests', 'Run all tests, analyze any failure, and fix them automatically.', 'antigravity'),
                      _buildQuickPromptChip('📦 Git Commit & Push', 'Commit all changes with a descriptive message and push.', 'antigravity'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Active Sessions
            TerminalCard(
              title: 'ACTIVE SESSIONS',
              trailing: Text(
                '${_sessions.length} ACTIVE',
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc),
              ),
              child: _sessions.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          'No agent processes running.\nLaunch an Antigravity prompt above.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.textMuted),
                        ),
                      ),
                    )
                  : Column(
                      children: _sessions.map((s) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: TerminalColors.cardBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          (s['agent'] ?? 'agent').toString().toUpperCase(),
                                          style: GoogleFonts.jetBrainsMono(
                                            fontWeight: FontWeight.w900,
                                            color: TerminalColors.pureWhite,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        StatusBadge(status: s['status'] ?? 'running'),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      s['last_task'] ?? 'Processing...',
                                      style: GoogleFonts.jetBrainsMono(
                                        color: TerminalColors.zinc,
                                        fontSize: 11,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.arrow_forward_ios, size: 13, color: TerminalColors.pureWhite),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SessionScreen(
                                        sessionId: s['id'],
                                        agentName: s['agent'],
                                        projectId: s['project_id'],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 14),

            // AI Agents Fleet
            TerminalCard(
              title: 'SUPPORTED AI AGENTS',
              child: Column(
                children: _agents.map((ag) {
                  final isInst = ag['installed'] == true;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.terminal, size: 15, color: TerminalColors.pureWhite),
                            const SizedBox(width: 8),
                            Text(
                              ag['display_name'] ?? ag['id'],
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isInst ? TerminalColors.pureWhite : TerminalColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        StatusBadge(status: isInst ? 'ONLINE' : 'OFFLINE'),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPromptChip(String label, String prompt, String agent) {
    return InkWell(
      onTap: () async {
        if (_projects.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Please register a workspace first in Workspaces tab', style: GoogleFonts.jetBrainsMono())),
          );
          return;
        }
        final proj = _projects.first;
        final res = await _api.startSession(
          projectId: proj['id'],
          agent: agent,
          prompt: prompt,
        );
        if (mounted && res['id'] != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SessionScreen(
                sessionId: res['id'],
                agentName: agent,
                projectId: proj['id'],
              ),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: TerminalColors.cardBorderLight),
        ),
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: TerminalColors.pureWhite,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricRow(String label, int percent, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc)),
            if (subtitle != null)
              Text(subtitle, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.textMuted)),
          ],
        ),
        const SizedBox(height: 4),
        AsciiProgressBar(percent: percent),
      ],
    );
  }
}
