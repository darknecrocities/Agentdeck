import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import '../widgets/terminal_widgets.dart';

class GitGitHubScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const GitGitHubScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<GitGitHubScreen> createState() => _GitGitHubScreenState();
}

class _GitGitHubScreenState extends State<GitGitHubScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _commitMsgCtrl = TextEditingController();

  Map<String, dynamic>? _gitStatus;
  Map<String, dynamic>? _githubOverview;
  List<dynamic> _gitLogs = [];
  bool _loading = true;
  bool _operating = false;

  @override
  void initState() {
    super.initState();
    _loadGitData();
  }

  @override
  void dispose() {
    _commitMsgCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadGitData() async {
    setState(() => _loading = true);
    try {
      final status = await _api.getGitStatus(widget.projectId);
      final logs = await _api.getGitLog(widget.projectId);
      final gh = await _api.getGitHubOverview(widget.projectId);

      if (mounted) {
        setState(() {
          _gitStatus = status;
          _gitLogs = logs;
          _githubOverview = gh;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleCommit() async {
    final msg = _commitMsgCtrl.text.trim();
    if (msg.isEmpty) return;

    setState(() => _operating = true);
    final ok = await _api.commitGit(widget.projectId, msg);
    _commitMsgCtrl.clear();
    setState(() => _operating = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Commit created successfully!')),
      );
      _loadGitData();
    }
  }

  Future<void> _handlePush() async {
    setState(() => _operating = true);
    final ok = await _api.pushGit(widget.projectId);
    setState(() => _operating = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Git push completed!')),
      );
      _loadGitData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('${widget.projectName.toUpperCase()} GIT / GITHUB')),
        body: const Center(child: CircularProgressIndicator(color: TerminalColors.neonGreen)),
      );
    }

    final branch = _gitStatus?['branch'] ?? 'main';
    final isClean = _gitStatus?['is_clean'] == true;
    final modified = (_gitStatus?['modified_files'] as List?) ?? [];
    final staged = (_gitStatus?['staged_files'] as List?) ?? [];
    final prs = (_githubOverview?['pull_requests'] as List?) ?? [];
    final issues = (_githubOverview?['issues'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.projectName.toUpperCase()} GIT & GITHUB'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadGitData),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Git Status Card
          TerminalCard(
            title: 'GIT REPOSITORY STATE',
            trailing: StatusBadge(status: isClean ? 'CLEAN' : 'DIRTY'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.fork_right, color: TerminalColors.neonGreen, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          branch,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: TerminalColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Ahead: ${_gitStatus?['ahead'] ?? 0} | Behind: ${_gitStatus?['behind'] ?? 0}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.textMuted),
                    ),
                  ],
                ),
                if (modified.isNotEmpty || staged.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'CHANGED FILES (${modified.length + staged.length})',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: TerminalColors.neonAmber),
                  ),
                  const SizedBox(height: 4),
                  ...modified.map((f) => Text(' ~ $f', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.neonAmber))),
                  ...staged.map((f) => Text(' + $f', style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.neonGreen))),
                ],
                const SizedBox(height: 14),
                // Commit Box
                TextField(
                  controller: _commitMsgCtrl,
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, color: TerminalColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Commit message...',
                    hintStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted, fontSize: 12),
                    filled: true,
                    fillColor: TerminalColors.background,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: TerminalColors.neonGreen, foregroundColor: Colors.black),
                        icon: const Icon(Icons.check, size: 16),
                        label: Text('COMMIT ALL', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 12)),
                        onPressed: _operating ? null : _handleCommit,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: TerminalColors.electricCyan, foregroundColor: Colors.black),
                      icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                      label: Text('PUSH', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 12)),
                      onPressed: _operating ? null : _handlePush,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // GitHub Pull Requests
          if (prs.isNotEmpty) ...[
            TerminalCard(
              title: 'GITHUB PULL REQUESTS',
              child: Column(
                children: prs.map((pr) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.merge_type, color: TerminalColors.neonPurple, size: 18),
                    title: Text('#${pr['number']} ${pr['title']}', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: TerminalColors.textPrimary)),
                    subtitle: Text('Author: ${pr['author']?['login'] ?? ''}', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.textMuted)),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // GitHub Issues
          if (issues.isNotEmpty) ...[
            TerminalCard(
              title: 'GITHUB ISSUES',
              child: Column(
                children: issues.map((issue) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.bug_report_outlined, color: TerminalColors.neonAmber, size: 18),
                    title: Text('#${issue['number']} ${issue['title']}', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: TerminalColors.textPrimary)),
                    subtitle: Text('State: ${issue['state'] ?? 'open'}', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.textMuted)),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Recent Git Commits Log
          TerminalCard(
            title: 'RECENT COMMITS',
            child: _gitLogs.isEmpty
                ? Text('No recent commits found.', style: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted))
                : Column(
                    children: _gitLogs.take(5).map((log) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (log['hash'] as String? ?? '').substring(0, 7),
                              style: GoogleFonts.jetBrainsMono(
                                color: TerminalColors.neonAmber,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                log['message'] ?? '',
                                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
}
