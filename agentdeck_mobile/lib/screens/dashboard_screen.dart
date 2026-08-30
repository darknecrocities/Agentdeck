import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/workstation_manager.dart';
import '../theme/terminal_theme.dart';
import '../widgets/terminal_widgets.dart';
import '../widgets/tailscale_modal.dart';
import '../widgets/model_selector_modal.dart';
import '../widgets/voice_prompt_modal.dart';
import '../widgets/remote_machine_modal.dart';
import '../widgets/file_viewer_modal.dart';
import '../widgets/live_ide_chat_modal.dart';
import 'session_screen.dart';
import 'terminal_screen.dart';
import 'token_monitor_screen.dart';
import 'account_switcher_screen.dart';
import 'workstation_switcher_screen.dart';
import 'file_uploader_screen.dart';
import 'approvals_screen.dart';

class DashboardScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const DashboardScreen({super.key, required this.onNavigate});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiService _api = ApiService();
  final WorkstationManager _wsMgr = WorkstationManager();

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
    _wsMgr.addListener(_onWorkstationChanged);
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _loadData(silent: true));
  }

  void _onWorkstationChanged() {
    if (mounted) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _wsMgr.removeListener(_onWorkstationChanged);
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

  void _openTailscaleHub() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TailscaleModal(),
    ).then((_) => _loadData());
  }

  @override
  Widget build(BuildContext context) {
    final activeWs = _wsMgr.activeWorkstation;
    final defaultHost = activeWs?.name ?? 'Workstation';
    final defaultTs = activeWs?.endpoint.replaceFirst(RegExp(r'^https?://'), '').split(':').first ?? '127.0.0.1';
    final host = _deviceInfo?['hostname'] ?? defaultHost;
    final tsIp = _deviceInfo?['tailscale_ip'] ?? defaultTs;

    final cpu = (_deviceInfo?['cpu_usage'] as num?)?.toInt() ?? 0;
    final memUsed = _deviceInfo?['memory_used_mb'] ?? 0;
    final memTotal = _deviceInfo?['memory_total_mb'] ?? 1;
    final memPercent = ((memUsed / memTotal) * 100).round();
    final diskFree = (_deviceInfo?['disk_free_gb'] as num?)?.toStringAsFixed(1) ?? '0';
    final isOnline = _deviceInfo != null;
    final activeLatency = _wsMgr.activeLatency;

    final bool hasActiveSession = _sessions.any((s) => s['status'] == 'running' || s['status'] == 'executing');

    return Scaffold(
      appBar: AppBar(
        title: const AgentDeckLogoHeader(size: 26),
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
          // Tailscale Radar Pulse indicator with latency
          TailscaleRadarPulse(
            isConnected: isOnline,
            latencyMs: activeLatency,
            onTap: _openTailscaleHub,
          ),
          const SizedBox(width: 6),

          // Active Workstation Switcher Pill
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WorkstationSwitcherScreen()),
            ).then((_) => _loadData()),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF141414),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF333333)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    activeWs?.os == 'Windows'
                        ? Icons.desktop_windows
                        : (activeWs?.os == 'Linux' ? Icons.developer_board : Icons.laptop_mac),
                    size: 13,
                    color: TerminalColors.pureWhite,
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down, color: TerminalColors.zinc, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),

          // Consolidated Menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: TerminalColors.pureWhite, size: 20),
            color: const Color(0xFF141414),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xFF333333)),
            ),
            onSelected: (val) {
              if (val == 'tailscale') {
                _openTailscaleHub();
              } else if (val == 'upload') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FileUploaderScreen()));
              } else if (val == 'tokens') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const TokenMonitorScreen()));
              } else if (val == 'accounts') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountSwitcherScreen()));
              } else if (val == 'approvals') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ApprovalsScreen()));
              } else if (val == 'settings') {
                widget.onNavigate(6);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'tailscale',
                child: Row(
                  children: [
                    const Icon(Icons.vpn_lock, size: 16, color: TerminalColors.pureWhite),
                    const SizedBox(width: 10),
                    Text('Tailscale Mesh Hub', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.pureWhite)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'approvals',
                child: Row(
                  children: [
                    const Icon(Icons.security, size: 16, color: TerminalColors.pureWhite),
                    const SizedBox(width: 10),
                    Text('Security Approvals', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.pureWhite)),
                  ],
                ),
              ),
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
            // Tailscale Mesh Link Quick Bar
            InkWell(
              onTap: _openTailscaleHub,
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0D0D),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isOnline ? const Color(0xFF2E5E35) : const Color(0xFF262626),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.shield_outlined,
                          size: 15,
                          color: isOnline ? const Color(0xFF51CF66) : TerminalColors.zinc,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'TAILSCALE MESH: ',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: TerminalColors.zinc,
                          ),
                        ),
                        CensoredEndpointBadge(
                          text: tsIp,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: TerminalColors.pureWhite,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          isOnline ? 'ENCRYPTED' : 'SETUP',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: isOnline ? const Color(0xFF51CF66) : TerminalColors.pureWhite,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, size: 14, color: TerminalColors.zinc),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Live Interactive Mascot Assistant Card
            if (hasActiveSession)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: AgentDeckMascotThinking(
                  speechText: 'Autonomous coding agent executing task on ${activeWs?.name ?? "workstation"}...',
                  onTap: () => widget.onNavigate(3),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: AgentDeckMascotPointing(
                  speechText: 'AgentDeck mission control ready. Tap below to dispatch Antigravity prompts.',
                  buttonText: 'QUICK PROMPT',
                  onButtonTap: () {
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
              title: '${activeWs?.os.toUpperCase() ?? "HOST"} WORKSTATION TELEMETRY',
              trailing: StatusBadge(status: isOnline ? 'ONLINE' : 'OFFLINE'),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const RemoteMachineModal(),
                );
              },
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
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: TerminalColors.pureWhite,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      CensoredEndpointBadge(
                        prefix: 'TS: ',
                        text: tsIp,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: TerminalColors.silver,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (_deviceInfo != null) ...[
                    const SizedBox(height: 12),
                    MetricBar(label: 'CPU LOAD', percent: cpu),
                    const SizedBox(height: 10),
                    MetricBar(
                      label: 'MEMORY USAGE',
                      percent: memPercent,
                      subtitle: '${(memUsed / 1024).toStringAsFixed(1)}GB / ${(memTotal / 1024).toStringAsFixed(1)}GB',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('DISK AVAILABLE', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc, fontWeight: FontWeight.bold)),
                        Text('$diskFree GB FREE', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFF1E1E1E), height: 1),
                    const SizedBox(height: 10),

                    // Quick Action Row
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildRemoteQuickActionPill(
                            Icons.apps,
                            'REMOTE APPS',
                            () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const RemoteMachineModal(),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildRemoteQuickActionPill(
                            Icons.desktop_windows,
                            'SCREEN LIVE',
                            () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const RemoteMachineModal(),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildRemoteQuickActionPill(
                            Icons.videocam,
                            'WEBCAM',
                            () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const RemoteMachineModal(),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildRemoteQuickActionPill(
                            Icons.forum,
                            'LIVE IDE CHAT',
                            () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const LiveIdeChatModal(),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildRemoteQuickActionPill(
                            Icons.description,
                            'LIVE FILES',
                            () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const FileViewerModal(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF333333)),
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
                            'Start daemon on host:\n> cargo run --bin agentdeckd',
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

            // Live Antigravity Quota Card
            _buildLiveAntigravityQuotaCard(),
            const SizedBox(height: 14),

            // Antigravity Prompt Center
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
                  // Model Selector Row
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
                        border: Border.all(color: const Color(0xFF262626)),
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
                                    'EFFORT: ${_selectedEffort.toUpperCase()}',
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

                  // Quick prompt chips
                  Text(
                    'DISPATCH ACTIONS',
                    style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: TerminalColors.zinc),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      _buildQuickPromptChip(Icons.search, 'Analyze Arch', 'Analyze this codebase architecture and create an implementation plan.', 'antigravity'),
                      _buildQuickPromptChip(Icons.code, 'Implement', 'Proceed with the implementation and wire up all services.', 'antigravity'),
                      _buildQuickPromptChip(Icons.bug_report, 'Fix Tests', 'Run all tests, analyze any failure, and fix them automatically.', 'antigravity'),
                      _buildQuickPromptChip(Icons.cloud_upload, 'Git Push', 'Commit all changes with a descriptive message and push.', 'antigravity'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: TerminalColors.pureWhite,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.record_voice_over_rounded, size: 16),
                          label: Text(
                            'VOICE PROMPTER',
                            style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w900, fontSize: 11),
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
                            side: const BorderSide(color: Color(0xFF404040), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          icon: const Icon(Icons.terminal, size: 16),
                          label: Text(
                            'PTY TERMINAL',
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
                        return InkWell(
                          onTap: () {
                            if (s['agent'] == 'antigravity') {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => LiveIdeChatModal(initialConversationId: s['id']),
                              );
                            } else {
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
                            }
                          },
                          child: Container(
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
                                const Icon(Icons.arrow_forward_ios, size: 13, color: TerminalColors.pureWhite),
                              ],
                            ),
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
          border: Border.all(color: const Color(0xFF262626)),
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
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF262626)),
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
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: TerminalColors.pureWhite,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ANTIGRAVITY QUOTAS',
                        style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.w900,
                          color: TerminalColors.pureWhite,
                          fontSize: 10.5,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'DETAILS',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: TerminalColors.pureWhite,
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: TerminalColors.pureWhite, size: 14),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF080808),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF1E1E1E)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gemini Quota',
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: TerminalColors.pureWhite,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Weekly: $geminiWeekly% left', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: TerminalColors.zinc)),
                          const SizedBox(height: 2),
                          Text('5-Hour: $gemini5h% left', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: TerminalColors.zinc)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF080808),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF1E1E1E)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Claude / GPT',
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: TerminalColors.pureWhite,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('Weekly: $claudeWeekly% left', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: TerminalColors.zinc)),
                          const SizedBox(height: 2),
                          Text('Tier: Pro / Standard', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: TerminalColors.zinc)),
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

  Widget _buildRemoteQuickActionPill(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: TerminalColors.pureWhite),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                color: TerminalColors.pureWhite,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
