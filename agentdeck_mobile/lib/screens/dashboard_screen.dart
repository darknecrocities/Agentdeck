import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import '../widgets/terminal_widgets.dart';
import 'session_screen.dart';
import 'terminal_screen.dart';
import 'token_monitor_screen.dart';
import 'account_switcher_screen.dart';
import 'workstation_switcher_screen.dart';
import 'file_uploader_screen.dart';
import '../services/workstation_manager.dart';
import '../widgets/model_selector_modal.dart';
import '../widgets/voice_prompt_modal.dart';

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

  String _selectedModel = 'gemini-3.7-flash';
  String _selectedEffort = 'high';
  Map<String, dynamic>? _tokenSummary;

  @override
  void initState() {
    super.initState();
    _loadData();
    WorkstationManager().addListener(_onWorkstationChanged);
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _loadData(silent: true));
  }

  void _onWorkstationChanged() {
    if (mounted) {
      _loadData();
    }
  }

  @override
  void dispose() {
    WorkstationManager().removeListener(_onWorkstationChanged);
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool silent = false}) async {
    if (!silent && _deviceInfo == null) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.getDevice().catchError((_) => <String, dynamic>{}),
        _api.getAgents().catchError((_) => <dynamic>[]),
        _api.getProjects().catchError((_) => <dynamic>[]),
        _api.getApprovals().catchError((_) => <dynamic>[]),
        _api.getSessions().catchError((_) => <dynamic>[]),
        _api.getTokenSummary().catchError((_) => <String, dynamic>{}),
      ]);

      if (mounted) {
        final dev = results[0] as Map<String, dynamic>;
        setState(() {
          _deviceInfo = dev.isNotEmpty ? dev : null;
          _agents = results[1] as List<dynamic>;
          _projects = results[2] as List<dynamic>;
          _approvals = results[3] as List<dynamic>;
          _sessions = results[4] as List<dynamic>;
          _tokenSummary = results[5] as Map<String, dynamic>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _deviceInfo = null;
          _agents = [];
          _projects = [];
          _approvals = [];
          _sessions = [];
          _tokenSummary = null;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeWs = WorkstationManager().currentWorkstation;
    final defaultHost = activeWs?.name ?? 'Workstation';
    final defaultTs = activeWs?.endpoint.replaceFirst(RegExp(r'^https?://'), '').split(':').first ?? '127.0.0.1';
    final host = _deviceInfo?['hostname'] ?? defaultHost;
    final tsIp = _deviceInfo?['tailscale_ip'] ?? defaultTs;

    final cpu = (_deviceInfo?['cpu_usage'] as num?)?.toInt() ?? 0;
    final memUsed = _deviceInfo?['memory_used_mb'] ?? 0;
    final memTotal = _deviceInfo?['memory_total_mb'] ?? 1;
    final memPercent = ((memUsed / memTotal) * 100).round();
    final diskFree = (_deviceInfo?['disk_free_gb'] as num?)?.toStringAsFixed(1) ?? '0';

    return Scaffold(
      appBar: AppBar(
        title: const AgentDeckLogoHeader(size: 24),
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: TerminalColors.pureWhite,
                  backgroundColor: Colors.transparent,
                ),
              )
            : null,
        actions: [
          // Active Workstation Quick Switcher Pill
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WorkstationSwitcherScreen()),
            ).then((_) => _loadData()),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: TerminalColors.surfaceElevated,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: TerminalColors.cardBorderLight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    WorkstationManager().currentWorkstation?.os == 'Windows'
                        ? Icons.desktop_windows
                        : Icons.laptop_mac,
                    size: 13,
                    color: TerminalColors.pureWhite,
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF51CF66),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: TerminalColors.zinc, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Consolidated Quick Actions Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: TerminalColors.pureWhite, size: 20),
            color: const Color(0xFF141414),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: TerminalColors.cardBorderLight),
            ),
            onSelected: (val) {
              if (val == 'upload') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FileUploaderScreen()));
              } else if (val == 'tokens') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TokenMonitorScreen()));
              } else if (val == 'accounts') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSwitcherScreen()));
              } else if (val == 'settings') {
                widget.onNavigate(6);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'upload',
                child: Row(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 16, color: TerminalColors.pureWhite),
                    const SizedBox(width: 10),
                    Text('Upload Files & Media', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.pureWhite)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'tokens',
                child: Row(
                  children: [
                    const Icon(Icons.speed, size: 16, color: TerminalColors.pureWhite),
                    const SizedBox(width: 10),
                    Text('Antigravity Quotas', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.pureWhite)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'accounts',
                child: Row(
                  children: [
                    const Icon(Icons.manage_accounts_outlined, size: 16, color: TerminalColors.pureWhite),
                    const SizedBox(width: 10),
                    Text('Auth & Accounts', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.pureWhite)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    const Icon(Icons.settings_outlined, size: 16, color: TerminalColors.zinc),
                    const SizedBox(width: 10),
                    Text('Settings', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.zinc)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: RefreshIndicator(
        color: TerminalColors.pureWhite,
        backgroundColor: TerminalColors.surface,
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Live Antigravity Model Usage Card
            _buildLiveAntigravityQuotaCard(),
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
              title: '${(WorkstationManager().currentWorkstation?.os ?? "HOST").toUpperCase()} WORKSTATION TELEMETRY',
              trailing: StatusBadge(status: _deviceInfo != null ? 'ONLINE' : 'CONNECTING'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          host.toUpperCase(),
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: TerminalColors.pureWhite,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'TS: $tsIp',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          color: TerminalColors.silver,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (_deviceInfo != null) ...[
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
                  ] else ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF181818),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: TerminalColors.cardBorderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.info_outline, size: 14, color: Color(0xFFFFD43B)),
                              const SizedBox(width: 6),
                              Text(
                                'DAEMON NOT RUNNING ON ${activeWs?.os.toUpperCase() ?? "THIS NODE"}',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFFFD43B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Start the daemon on this machine:\n> cargo run --bin agentdeckd',
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  // Active Model & Reasoning Level Selector
                  InkWell(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => ModelSelectorModal(
                          currentModel: _selectedModel,
                          currentEffort: _selectedEffort,
                          onSelected: (model, effort) {
                            setState(() {
                              _selectedModel = model;
                              _selectedEffort = effort;
                            });
                          },
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: TerminalColors.cardBorderLight),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.psychology, color: TerminalColors.pureWhite, size: 16),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selectedModel.toUpperCase(),
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: TerminalColors.pureWhite,
                                    ),
                                  ),
                                  Text(
                                    'REASONING EFFORT: ${_selectedEffort.toUpperCase()}',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 9.5,
                                      color: TerminalColors.zinc,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: TerminalColors.pureWhite,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Text(
                              'CHANGE',
                              style: GoogleFonts.jetBrainsMono(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'QUICK PROMPT DISPATCHER',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.zinc),
                                ),
                                InkWell(
                                  onTap: () {
                                    showModalBottomSheet(
                                      context: context,
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      builder: (_) => VoicePromptModal(
                                        model: _selectedModel,
                                        effort: _selectedEffort,
                                      ),
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF143318),
                                      borderRadius: BorderRadius.circular(3),
                                      border: Border.all(color: const Color(0xFF51CF66)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.mic, size: 11, color: Color(0xFF51CF66)),
                                        const SizedBox(width: 3),
                                        Text(
                                          'VOICE STT',
                                          style: GoogleFonts.jetBrainsMono(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFF51CF66),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _buildQuickPromptChip(Icons.search, 'Analyze Architecture', 'Analyze this codebase architecture and create an implementation plan.', 'antigravity'),
                                _buildQuickPromptChip(Icons.code, 'Implement Feature', 'Proceed with the implementation and wire up all services.', 'antigravity'),
                                _buildQuickPromptChip(Icons.bug_report, 'Run & Fix Tests', 'Run all tests, analyze any failure, and fix them automatically.', 'antigravity'),
                                _buildQuickPromptChip(Icons.cloud_upload, 'Git Commit & Push', 'Commit all changes with a descriptive message and push.', 'antigravity'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Bigger Mascot with Luminous Ambient Aura
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF51CF66).withValues(alpha: 0.28),
                              blurRadius: 28,
                              spreadRadius: 4,
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.12),
                              blurRadius: 16,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/agentdeck_pointing.png',
                          height: 110,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF143318),
                            foregroundColor: const Color(0xFF51CF66),
                            side: const BorderSide(color: Color(0xFF51CF66), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.mic, size: 16),
                          label: Text(
                            'VOICE PROMPT (STT)',
                            style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w900, fontSize: 10.5),
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => VoicePromptModal(
                                model: _selectedModel,
                                effort: _selectedEffort,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: TerminalColors.pureWhite,
                            side: const BorderSide(color: TerminalColors.pureWhite, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.terminal, size: 16),
                          label: Text(
                            'LIVE TERMINAL',
                            style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w900, fontSize: 10.5),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TerminalScreen(
                                  initialCommand: 'agy --model $_selectedModel --effort $_selectedEffort',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
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

  Widget _buildQuickPromptChip(IconData icon, String label, String prompt, String agent) {
    return InkWell(
      onTap: () async {
        final proj = _projects.isNotEmpty ? _projects.first : null;
        if (proj == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No workspace project attached.')),
          );
          return;
        }
        final res = await _api.startSession(
          projectId: proj['id'],
          agent: agent,
          prompt: prompt,
          model: _selectedModel,
          effort: _selectedEffort,
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: TerminalColors.pureWhite),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: TerminalColors.pureWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveAntigravityQuotaCard() {
    final gemini = _tokenSummary?['gemini_quota'] as Map<String, dynamic>?;
    final claudeGpt = _tokenSummary?['claude_gpt_quota'] as Map<String, dynamic>?;

    final geminiWeekly = (gemini?['weekly_limit_remaining'] as num?)?.toInt() ?? 25;
    final gemini5h = (gemini?['five_hour_limit_remaining'] as num?)?.toInt() ?? 54;
    final claudeWeekly = (claudeGpt?['weekly_limit_remaining'] as num?)?.toInt() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TerminalColors.cardBorderLight),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TokenMonitorScreen()),
        ),
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF51CF66),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ANTIGRAVITY LIVE MODEL USAGE',
                        style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.w900,
                          color: TerminalColors.pureWhite,
                          fontSize: 11,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF141414),
                          border: Border.all(color: const Color(0xFF51CF66).withValues(alpha: 0.6), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF51CF66).withValues(alpha: 0.35),
                              blurRadius: 16,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/images/agentdeck_thinking.png',
                          height: 42,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'DETAILS',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: TerminalColors.pureWhite,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right, color: TerminalColors.pureWhite, size: 14),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Two Column Cards
              Row(
                children: [
                  // 1. Gemini Models
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: TerminalColors.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: TerminalColors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gemini Models',
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: TerminalColors.pureWhite,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Weekly Limit',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 9, color: TerminalColors.zinc),
                                  ),
                                  Text(
                                    '$geminiWeekly% left',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF51CF66),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  value: geminiWeekly / 100.0,
                                  strokeWidth: 2.5,
                                  backgroundColor: const Color(0xFF222222),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF51CF66)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '5-Hour Limit',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 9, color: TerminalColors.zinc),
                                  ),
                                  Text(
                                    '$gemini5h% left',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF51CF66),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  value: gemini5h / 100.0,
                                  strokeWidth: 2.5,
                                  backgroundColor: const Color(0xFF222222),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF51CF66)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 2. Claude & GPT Models
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
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
                                'Claude / GPT',
                                style: GoogleFonts.jetBrainsMono(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  color: TerminalColors.pureWhite,
                                ),
                              ),
                              const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFD43B), size: 14),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Weekly Limit',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 9, color: TerminalColors.zinc),
                                  ),
                                  Text(
                                    '$claudeWeekly% left',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFFF8787),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  value: claudeWeekly / 100.0,
                                  strokeWidth: 2.5,
                                  backgroundColor: const Color(0xFF222222),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF555555)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF221111),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: const Color(0xFF552222)),
                            ),
                            child: Text(
                              'LIMIT REACHED',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFFF8787),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
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
