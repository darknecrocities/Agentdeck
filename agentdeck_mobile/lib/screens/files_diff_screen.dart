import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';

class FilesDiffScreen extends StatefulWidget {
  final String projectId;
  final String projectName;

  const FilesDiffScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<FilesDiffScreen> createState() => _FilesDiffScreenState();
}

class _FilesDiffScreenState extends State<FilesDiffScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  List<dynamic> _fileEntries = [];
  String _currentPath = '';
  String _activeFileContent = '';
  String _activeFilePath = '';
  String _diffText = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFiles();
    _loadDiff();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles({String? subpath}) async {
    setState(() => _loading = true);
    try {
      final res = await _api.getProjectFiles(widget.projectId, path: subpath);
      setState(() {
        _fileEntries = res['entries'] ?? [];
        _currentPath = res['current_path'] ?? '';
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _loadDiff() async {
    try {
      final diff = await _api.getGitDiff(widget.projectId);
      setState(() {
        _diffText = diff.isEmpty ? 'No uncommitted changes in working tree.' : diff;
      });
    } catch (_) {}
  }

  Future<void> _openFile(String path) async {
    try {
      final content = await _api.getFileContent(widget.projectId, path);
      setState(() {
        _activeFilePath = path;
        _activeFileContent = content;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.projectName.toUpperCase()} FILES & DIFF'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: TerminalColors.neonGreen,
          labelColor: TerminalColors.neonGreen,
          unselectedLabelColor: TerminalColors.textMuted,
          labelStyle: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'PROJECT FILES'),
            Tab(text: 'GIT DIFF'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Files Browser
          _loading
              ? const Center(child: CircularProgressIndicator(color: TerminalColors.neonGreen))
              : _activeFilePath.isNotEmpty
                  ? _buildFileContentViewer()
                  : _buildFileTree(),

          // Diff Viewer
          _buildDiffViewer(),
        ],
      ),
    );
  }

  Widget _buildFileTree() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_currentPath.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: TerminalColors.surface,
            width: double.infinity,
            child: Text(
              _currentPath,
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.textMuted),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _fileEntries.length,
            itemBuilder: (ctx, idx) {
              final e = _fileEntries[idx];
              final isDir = e['is_dir'] == true;
              return ListTile(
                leading: Icon(
                  isDir ? Icons.folder : Icons.insert_drive_file_outlined,
                  color: isDir ? TerminalColors.electricCyan : TerminalColors.textPrimary,
                ),
                title: Text(
                  e['name'] ?? '',
                  style: GoogleFonts.jetBrainsMono(
                    color: isDir ? TerminalColors.electricCyan : TerminalColors.textPrimary,
                    fontWeight: isDir ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                onTap: () {
                  if (isDir) {
                    _loadFiles(subpath: e['path']);
                  } else {
                    _openFile(e['path']);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFileContentViewer() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: TerminalColors.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _activeFilePath.split('/').last,
                style: GoogleFonts.jetBrainsMono(
                  fontWeight: FontWeight.bold,
                  color: TerminalColors.neonGreen,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _activeFilePath = ''),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: Colors.black,
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              child: Text(
                _activeFileContent,
                style: GoogleFonts.jetBrainsMono(
                  color: TerminalColors.textPrimary,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDiffViewer() {
    final lines = _diffText.split('\n');
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(12),
      child: ListView.builder(
        itemCount: lines.length,
        itemBuilder: (ctx, idx) {
          final line = lines[idx];
          Color color = TerminalColors.textPrimary;
          Color? bg;

          if (line.startsWith('+') && !line.startsWith('+++')) {
            color = TerminalColors.neonGreen;
            bg = TerminalColors.neonGreen.withOpacity(0.08);
          } else if (line.startsWith('-') && !line.startsWith('---')) {
            color = TerminalColors.neonRed;
            bg = TerminalColors.neonRed.withOpacity(0.08);
          } else if (line.startsWith('@@')) {
            color = TerminalColors.electricCyan;
          } else if (line.startsWith('diff --git')) {
            color = TerminalColors.neonAmber;
          }

          return Container(
            color: bg,
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text(
              line,
              style: GoogleFonts.jetBrainsMono(
                color: color,
                fontSize: 12,
                height: 1.2,
              ),
            ),
          );
        },
      ),
    );
  }
}
