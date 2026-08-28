import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import '../widgets/terminal_widgets.dart';
import 'session_screen.dart';

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
    } catch (e) {
      if (mounted && !silent) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _deviceInfo == null) {
      return const Center(
        child: CircularProgressIndicator(color: TerminalColors.neonGreen),
      );
    }

    final cpu = (_deviceInfo?['cpu_usage'] as num?)?.toInt() ?? 0;
    final memUsed = _deviceInfo?['memory_used_mb'] ?? 0;
    final memTotal = _deviceInfo?['memory_total_mb'] ?? 1;
    final memPercent = ((memUsed / memTotal) * 100).round();
    final diskFree = (_deviceInfo?['disk_free_gb'] as num?)?.toStringAsFixed(1) ?? '0';
    final host = _deviceInfo?['hostname'] ?? 'MacBook Air';
    final tsStatus = _deviceInfo?['tailscale_status'] ?? 'offline';
    final tsIp = _deviceInfo?['tailscale_ip'] ?? '100.x.x.x';

    return RefreshIndicator(
      color: TerminalColors.neonGreen,
      backgroundColor: TerminalColors.surface,
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Pending Approvals Banner
          if (_approvals.isNotEmpty) ...[
            InkWell(
              onTap: () => widget.onNavigate(4), // Navigate to Approvals
              child: Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: TerminalColors.neonAmber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: TerminalColors.neonAmber, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: TerminalColors.neonAmber, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'APPROVAL REQUIRED (${_approvals.length} PENDING)',
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.bold,
                              color: TerminalColors.neonAmber,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Agent requested dangerous action execution',
                            style: GoogleFonts.jetBrainsMono(
                              color: TerminalColors.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: TerminalColors.neonAmber),
                  ],
                ),
              ),
            ),
          ],

          // Machine & Tailscale Telemetry Card
          TerminalCard(
            title: 'HOST TELEMETRY',
            trailing: const StatusBadge(status: 'ONLINE'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      host,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: TerminalColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, size: 14, color: TerminalColors.electricCyan),
                        const SizedBox(width: 4),
                        Text(
                          'Tailscale: $tsStatus ($tsIp)',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11,
                            color: TerminalColors.electricCyan,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildMetricRow('CPU LOAD', cpu),
                const SizedBox(height: 10),
                _buildMetricRow('MEMORY', memPercent, subtitle: '${(memUsed / 1024).toStringAsFixed(1)} GB / ${(memTotal / 1024).toStringAsFixed(1)} GB'),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('DISK AVAILABLE', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.textSecondary)),
                    Text('$diskFree GB FREE', style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: TerminalColors.textPrimary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Active Sessions / Quick Action
          TerminalCard(
            title: 'ACTIVE SESSIONS',
            trailing: Text(
              '${_sessions.length} TOTAL',
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.textSecondary),
            ),
            child: _sessions.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No agent sessions currently active.\nStart one from Projects or Agents.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.jetBrainsMono(fontSize: 12, color: TerminalColors.textMuted),
                      ),
                    ),
                  )
                : Column(
                    children: _sessions.map((s) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: TerminalColors.background,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: TerminalColors.cardBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (s['agent'] ?? 'agent').toString().toUpperCase(),
                                  style: GoogleFonts.jetBrainsMono(
                                    fontWeight: FontWeight.bold,
                                    color: TerminalColors.neonGreen,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  s['last_task'] ?? 'Executing task...',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: TerminalColors.textSecondary,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios, size: 14, color: TerminalColors.neonGreen),
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
          const SizedBox(height: 16),

          // Agents Fleet
          TerminalCard(
            title: 'AI AGENTS FLEET',
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
                          Icon(
                            Icons.smart_toy_outlined,
                            size: 16,
                            color: isInst ? TerminalColors.neonGreen : TerminalColors.textMuted,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            ag['display_name'] ?? ag['id'],
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isInst ? TerminalColors.textPrimary : TerminalColors.textMuted,
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
          const SizedBox(height: 16),

          // Projects Quick List
          TerminalCard(
            title: 'PROJECT WORKSPACES',
            child: _projects.isEmpty
                ? Text('No projects registered yet.', style: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted))
                : Column(
                    children: _projects.map((p) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p['name'] ?? 'Project',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontWeight: FontWeight.bold,
                                    color: TerminalColors.textPrimary,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  p['path'] ?? '',
                                  style: GoogleFonts.jetBrainsMono(
                                    fontSize: 11,
                                    color: TerminalColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: TerminalColors.electricCyan.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                p['default_agent'] ?? 'antigravity',
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 10,
                                  color: TerminalColors.electricCyan,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
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
            Text(label, style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.textSecondary)),
            if (subtitle != null)
              Text(subtitle, style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.textMuted)),
          ],
        ),
        const SizedBox(height: 4),
        AsciiProgressBar(percent: percent),
      ],
    );
  }
}
