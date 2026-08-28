import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import '../widgets/terminal_widgets.dart';
import '../widgets/directory_browser_modal.dart';
import 'session_screen.dart';
import 'files_diff_screen.dart';
import 'git_github_screen.dart';

import '../services/workstation_manager.dart';

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
    WorkstationManager().addListener(_onWorkstationChanged);
  }

  void _onWorkstationChanged() {
    if (mounted) {
      _loadProjects();
    }
  }

  @override
  void dispose() {
    WorkstationManager().removeListener(_onWorkstationChanged);
    super.dispose();
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
      if (mounted) {
        setState(() {
          _projects = [];
          _loading = false;
        });
      }
    }
  }

  void _showAddProjectDialog() {
    int mode = 0; // 0 = Scaffold New App, 1 = Attach Existing
    final isWin = WorkstationManager().currentWorkstation?.os == 'Windows';
    final defaultParent = isWin ? 'C:\\projects' : '/Users/arronkianparejas';
    final defaultPath = isWin ? 'C:\\projects\\my_app' : '/path/to/your/projects';

    final nameCtrl = TextEditingController(text: 'my_new_app');
    final parentCtrl = TextEditingController(text: defaultParent);
    final pathCtrl = TextEditingController(text: defaultPath);
    final promptCtrl = TextEditingController(text: 'Analyze requirements, build the project structure, and implement core features.');
    String template = 'flutter';
    String defaultAgent = 'antigravity';
    bool creating = false;

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
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: TerminalColors.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                border: Border(top: BorderSide(color: TerminalColors.cardBorderLight, width: 1.5)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          mode == 0 ? 'AUTOMATED APP CREATOR (MAC)' : 'ATTACH EXISTING WORKSPACE',
                          style: GoogleFonts.jetBrainsMono(
                            color: TerminalColors.pureWhite,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: TerminalColors.zinc, size: 18),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Mode Switcher Tabs
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => mode = 0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: mode == 0 ? TerminalColors.pureWhite : Colors.black,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: TerminalColors.cardBorderLight),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_circle_outline, size: 14, color: mode == 0 ? Colors.black : TerminalColors.pureWhite),
                                  const SizedBox(width: 6),
                                  Text(
                                    'CREATE NEW APP',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: mode == 0 ? Colors.black : TerminalColors.pureWhite,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () => setModalState(() => mode = 1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: mode == 1 ? TerminalColors.pureWhite : Colors.black,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: TerminalColors.cardBorderLight),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.folder_open, size: 14, color: mode == 1 ? Colors.black : TerminalColors.pureWhite),
                                  const SizedBox(width: 6),
                                  Text(
                                    'ATTACH FOLDER',
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: mode == 1 ? Colors.black : TerminalColors.pureWhite,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (mode == 0) ...[
                      // App Template Selector
                      Text('SELECT PROJECT TEMPLATE', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.zinc)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: template,
                        dropdownColor: TerminalColors.surface,
                        style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 12),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.black,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: TerminalColors.cardBorder)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'flutter', child: Text('Flutter Mobile App (iOS / Android)')),
                          DropdownMenuItem(value: 'rust', child: Text('Rust Application / Backend')),
                          DropdownMenuItem(value: 'python', child: Text('Python Script / Service')),
                          DropdownMenuItem(value: 'node', child: Text('Node.js / Web Application')),
                          DropdownMenuItem(value: 'empty', child: Text('Clean Git Workspace')),
                        ],
                        onChanged: (v) => setModalState(() => template = v ?? 'flutter'),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: nameCtrl,
                        style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'NEW APP / FOLDER NAME',
                          labelStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 11),
                          filled: true,
                          fillColor: Colors.black,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: TerminalColors.cardBorder)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: parentCtrl,
                              style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 11),
                              decoration: InputDecoration(
                                labelText: 'PARENT DESTINATION FOLDER',
                                labelStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 10),
                                filled: true,
                                fillColor: Colors.black,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: TerminalColors.cardBorder)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.folder_open, color: TerminalColors.pureWhite),
                            onPressed: () async {
                              final selected = await showModalBottomSheet<Map<String, dynamic>>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => DirectoryBrowserModal(initialPath: parentCtrl.text),
                              );
                              if (selected != null) {
                                setModalState(() => parentCtrl.text = selected['path'] ?? parentCtrl.text);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: promptCtrl,
                        maxLines: 3,
                        style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'INITIAL AI GENERATION PROMPT',
                          labelStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 11),
                          hintText: 'e.g. Build a camera object detection app with offline SQLite sync...',
                          hintStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted, fontSize: 11),
                          filled: true,
                          fillColor: Colors.black,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: TerminalColors.cardBorder)),
                        ),
                      ),
                    ] else ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: TerminalColors.pureWhite,
                          side: const BorderSide(color: TerminalColors.pureWhite, width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                          minimumSize: const Size(double.infinity, 44),
                        ),
                        icon: const Icon(Icons.folder_open, size: 18, color: TerminalColors.pureWhite),
                        label: Text(
                          'BROWSE MAC COMPUTER FOLDERS',
                          style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w900, fontSize: 11),
                        ),
                        onPressed: () async {
                          final selected = await showModalBottomSheet<Map<String, dynamic>>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => DirectoryBrowserModal(initialPath: pathCtrl.text),
                          );
                          if (selected != null) {
                            setModalState(() {
                              pathCtrl.text = selected['path'] ?? pathCtrl.text;
                              nameCtrl.text = selected['name'] ?? nameCtrl.text;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: nameCtrl,
                        style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'PROJECT NAME',
                          labelStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 11),
                          filled: true,
                          fillColor: Colors.black,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: TerminalColors.cardBorder)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: pathCtrl,
                        style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 12),
                        decoration: InputDecoration(
                          labelText: 'WORKSPACE PATH ON MAC',
                          labelStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 11),
                          filled: true,
                          fillColor: Colors.black,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: TerminalColors.cardBorder)),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: TerminalColors.pureWhite,
                              side: const BorderSide(color: TerminalColors.cardBorderLight),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: Text('CANCEL', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: TerminalColors.pureWhite,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            onPressed: creating
                                ? null
                                : () async {
                                    setModalState(() => creating = true);
                                    if (mode == 0) {
                                      final res = await _api.scaffoldProject(
                                        name: nameCtrl.text,
                                        parentPath: parentCtrl.text,
                                        template: template,
                                        initialPrompt: promptCtrl.text,
                                        defaultAgent: defaultAgent,
                                      );
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      _loadProjects();

                                      if (mounted && res['session_id'] != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SessionScreen(
                                              sessionId: res['session_id'],
                                              agentName: defaultAgent,
                                              projectId: res['project']['id'],
                                            ),
                                          ),
                                        );
                                      }
                                    } else {
                                      if (nameCtrl.text.isNotEmpty && pathCtrl.text.isNotEmpty) {
                                        await _api.createProject(
                                          name: nameCtrl.text,
                                          path: pathCtrl.text,
                                          defaultAgent: defaultAgent,
                                        );
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        _loadProjects();
                                      }
                                    }
                                  },
                            child: Text(
                              mode == 0 ? 'CREATE & LAUNCH AGENT' : 'REGISTER WORKSPACE',
                              style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w900, fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
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
