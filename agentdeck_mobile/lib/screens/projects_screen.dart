import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import '../widgets/terminal_widgets.dart';
import 'session_screen.dart';
import 'files_diff_screen.dart';
import 'git_github_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _projects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    setState(() => _loading = true);
    try {
      final list = await _api.getProjects();
      if (mounted) {
        setState(() {
          _projects = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showAddProjectDialog() {
    final nameCtrl = TextEditingController();
    final pathCtrl = TextEditingController(text: '/Users/arronkianparejas/');
    String defaultAgent = 'antigravity';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: TerminalColors.surface,
          title: Text(
            'REGISTER WORKSPACE',
            style: GoogleFonts.jetBrainsMono(
              color: TerminalColors.pureWhite,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'PROJECT NAME',
                  labelStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 11),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pathCtrl,
                style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'ABSOLUTE WORKSPACE PATH',
                  labelStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 11),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCEL', style: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: TerminalColors.pureWhite,
                foregroundColor: Colors.black,
              ),
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty && pathCtrl.text.isNotEmpty) {
                  await _api.createProject(
                    name: nameCtrl.text,
                    path: pathCtrl.text,
                    defaultAgent: defaultAgent,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  _loadProjects();
                }
              },
              child: Text('REGISTER', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _startSessionDialog(Map<String, dynamic> project) {
    final promptCtrl = TextEditingController(text: 'Analyze this codebase architecture and create an implementation plan');
    String agent = project['default_agent'] ?? 'antigravity';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: TerminalColors.surface,
          title: Text(
            'LAUNCH AGENT ON ${project['name'].toString().toUpperCase()}',
            style: GoogleFonts.jetBrainsMono(
              color: TerminalColors.pureWhite,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: agent,
                dropdownColor: TerminalColors.surface,
                style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'SELECT AI AGENT',
                  labelStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 11),
                ),
                items: const [
                  DropdownMenuItem(value: 'antigravity', child: Text('Antigravity CLI (agy) — Priority')),
                  DropdownMenuItem(value: 'claude', child: Text('Claude Code')),
                  DropdownMenuItem(value: 'gemini', child: Text('Gemini CLI')),
                  DropdownMenuItem(value: 'ollama', child: Text('Ollama Local')),
                ],
                onChanged: (v) => agent = v ?? 'antigravity',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: promptCtrl,
                maxLines: 3,
                style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'INITIAL TASK / PROMPT',
                  labelStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 11),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('CANCEL', style: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: TerminalColors.pureWhite, foregroundColor: Colors.black),
              onPressed: () async {
                Navigator.pop(ctx);
                final res = await _api.startSession(
                  projectId: project['id'],
                  agent: agent,
                  prompt: promptCtrl.text,
                );
                if (mounted && res['id'] != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SessionScreen(
                        sessionId: res['id'],
                        agentName: agent,
                        projectId: project['id'],
                      ),
                    ),
                  );
                }
              },
              child: Text('LAUNCH', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PROJECT WORKSPACES'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: TerminalColors.pureWhite),
            onPressed: _showAddProjectDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: TerminalColors.pureWhite))
          : _projects.isEmpty
              ? Center(
                  child: Text(
                    'No registered project workspaces.\nTap + to add one.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _projects.length,
                  itemBuilder: (ctx, idx) {
                    final p = _projects[idx];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: TerminalCard(
                        title: p['name'],
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            border: Border.all(color: TerminalColors.cardBorderLight),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            p['default_agent'] ?? 'antigravity',
                            style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 10),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p['path'] ?? '',
                              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.zinc),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: TerminalColors.pureWhite,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                    ),
                                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                    label: Text('START AGENT', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11)),
                                    onPressed: () => _startSessionDialog(p),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: TerminalColors.pureWhite,
                                    side: const BorderSide(color: TerminalColors.cardBorderLight),
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  ),
                                  icon: const Icon(Icons.folder_outlined, size: 14),
                                  label: Text('FILES', style: GoogleFonts.jetBrainsMono(fontSize: 11)),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => FilesDiffScreen(projectId: p['id'], projectName: p['name']),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: TerminalColors.pureWhite,
                                    side: const BorderSide(color: TerminalColors.cardBorderLight),
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  ),
                                  icon: const Icon(Icons.commit, size: 14),
                                  label: Text('GIT', style: GoogleFonts.jetBrainsMono(fontSize: 11)),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => GitGitHubScreen(projectId: p['id'], projectName: p['name']),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
