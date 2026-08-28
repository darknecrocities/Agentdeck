import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  String _searchQuery = '';
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
      if (mounted) {
        setState(() {
          _fileEntries = res['entries'] ?? [];
          _currentPath = res['current_path'] ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDiff() async {
    try {
      final diff = await _api.getGitDiff(widget.projectId);
      if (mounted) {
        setState(() {
          _diffText = diff.isEmpty ? 'No uncommitted changes in working tree.' : diff;
        });
      }
    } catch (_) {}
  }

  Future<void> _openFile(String path) async {
    try {
      final content = await _api.getFileContent(widget.projectId, path);
      if (mounted) {
        setState(() {
          _activeFilePath = path;
          _activeFileContent = content;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.projectName.toUpperCase()} SOURCE CODE'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: TerminalColors.pureWhite),
            onPressed: () {
              _loadFiles();
              _loadDiff();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: TerminalColors.pureWhite,
          labelColor: TerminalColors.pureWhite,
          unselectedLabelColor: TerminalColors.zinc,
          labelStyle: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 11),
          tabs: const [
            Tab(text: 'SOURCE TREE'),
            Tab(text: 'GIT WORKING DIFF'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Files Browser & Code Viewer
          _loading
              ? const Center(child: CircularProgressIndicator(color: TerminalColors.pureWhite))
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
    final filtered = _searchQuery.isEmpty
        ? _fileEntries
        : _fileEntries.where((e) => (e['name'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Path Navigation Breadcrumbs
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: TerminalColors.surface,
          child: Row(
            children: [
              const Icon(Icons.folder_open, size: 16, color: TerminalColors.pureWhite),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _currentPath,
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.zinc),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),

        // Search Filter
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.black,
          child: TextField(
            style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 12),
            decoration: InputDecoration(
              hintText: 'Search files in workspace...',
              hintStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted, fontSize: 12),
              prefixIcon: const Icon(Icons.search, size: 16, color: TerminalColors.zinc),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: InputBorder.none,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),

        // File List
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Text(
                    'No files found.',
                    style: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted, fontSize: 12),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final e = filtered[idx];
                    final isDir = e['is_dir'] == true;
                    final size = e['size'] as int? ?? 0;
                    final name = e['name'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        color: TerminalColors.surface,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                          isDir ? Icons.folder : _getFileIcon(name),
                          color: isDir ? TerminalColors.pureWhite : TerminalColors.zinc,
                          size: 18,
                        ),
                        title: Text(
                          name,
                          style: GoogleFonts.jetBrainsMono(
                            color: TerminalColors.pureWhite,
                            fontWeight: isDir ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                        trailing: isDir
                            ? const Icon(Icons.chevron_right, size: 14, color: TerminalColors.zinc)
                            : Text(
                                size > 1024 ? '${(size / 1024).toStringAsFixed(1)} KB' : '$size B',
                                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.textMuted),
                              ),
                        onTap: () {
                          if (isDir) {
                            _loadFiles(subpath: e['path']);
                          } else {
                            _openFile(e['path']);
                          }
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFileContentViewer() {
    final lines = _activeFileContent.split('\n');
    final filename = _activeFilePath.split('/').last;

    return Column(
      children: [
        // File Header Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: TerminalColors.surface,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Icon(_getFileIcon(filename), size: 16, color: TerminalColors.pureWhite),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        filename,
                        style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.bold,
                          color: TerminalColors.pureWhite,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${lines.length} lines)',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy, size: 16, color: TerminalColors.pureWhite),
                    tooltip: 'Copy Code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _activeFileContent));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('File content copied to clipboard')),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: TerminalColors.pureWhite),
                    onPressed: () => setState(() => _activeFilePath = ''),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Line-numbered Code Canvas
        Expanded(
          child: Container(
            color: Colors.black,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: lines.length,
              itemBuilder: (ctx, idx) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line Number
                    Container(
                      width: 44,
                      padding: const EdgeInsets.only(right: 10),
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${idx + 1}',
                        style: GoogleFonts.jetBrainsMono(
                          color: TerminalColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    // Code Line
                    Expanded(
                      child: SelectableText(
                        lines[idx],
                        style: GoogleFonts.jetBrainsMono(
                          color: TerminalColors.pureWhite,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                );
              },
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
          Color color = TerminalColors.pureWhite;
          Color? bg;

          if (line.startsWith('+') && !line.startsWith('+++')) {
            color = TerminalColors.pureWhite;
            bg = const Color(0xFF1E2E1E);
          } else if (line.startsWith('-') && !line.startsWith('---')) {
            color = const Color(0xFFA3A3A3);
            bg = const Color(0xFF2E1E1E);
          } else if (line.startsWith('@@')) {
            color = TerminalColors.zinc;
          } else if (line.startsWith('diff --git')) {
            color = TerminalColors.pureWhite;
          }

          return Container(
            color: bg,
            padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
            child: SelectableText(
              line,
              style: GoogleFonts.jetBrainsMono(
                color: color,
                fontSize: 11,
                height: 1.25,
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getFileIcon(String filename) {
    if (filename.endsWith('.dart')) return Icons.flutter_dash;
    if (filename.endsWith('.rs')) return Icons.code;
    if (filename.endsWith('.js') || filename.endsWith('.ts') || filename.endsWith('.jsx') || filename.endsWith('.tsx')) return Icons.javascript;
    if (filename.endsWith('.py')) return Icons.terminal;
    if (filename.endsWith('.json') || filename.endsWith('.yaml') || filename.endsWith('.toml')) return Icons.data_object;
    if (filename.endsWith('.md')) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }
}
