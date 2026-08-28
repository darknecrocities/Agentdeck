import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/workstation_manager.dart';
import '../theme/terminal_theme.dart';

class DirectoryBrowserModal extends StatefulWidget {
  final String? initialPath;

  const DirectoryBrowserModal({super.key, this.initialPath});

  @override
  State<DirectoryBrowserModal> createState() => _DirectoryBrowserModalState();
}

class _DirectoryBrowserModalState extends State<DirectoryBrowserModal> {
  final ApiService _api = ApiService();
  String _currentPath = '';
  String? _parentPath;
  List<dynamic> _entries = [];
  List<dynamic> _shortcuts = [];
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadDirectory(widget.initialPath);
  }

  Future<void> _loadDirectory(String? path) async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final res = await _api.browseDirectories(path: path);
      if (mounted) {
        final cur = res['current_path'] as String?;
        if (cur != null && cur.isNotEmpty) {
          setState(() {
            _currentPath = cur;
            _parentPath = res['parent_path'];
            _entries = res['entries'] ?? [];
            _shortcuts = res['shortcuts'] ?? [];
            _loading = false;
            _error = false;
          });
        } else {
          final isWin = WorkstationManager().currentWorkstation?.os == 'Windows';
          setState(() {
            _currentPath = path ?? (isWin ? 'C:\\projects' : '/Users/arronkianparejas');
            _entries = [];
            _shortcuts = isWin
                ? [
                    {'label': 'C:\\', 'path': 'C:\\'},
                    {'label': 'Projects', 'path': 'C:\\projects'},
                  ]
                : [
                    {'label': 'Home', 'path': '/Users/arronkianparejas'},
                    {'label': 'AgentDeck', 'path': '/path/to/your/projects'},
                  ];
            _loading = false;
            _error = true;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        final isWin = WorkstationManager().currentWorkstation?.os == 'Windows';
        setState(() {
          _currentPath = path ?? (isWin ? 'C:\\projects' : '/Users/arronkianparejas');
          _loading = false;
          _error = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeWs = WorkstationManager().currentWorkstation;
    final osName = activeWs?.os.toUpperCase() ?? 'REMOTE';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: TerminalColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: TerminalColors.cardBorderLight, width: 1.5)),
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: TerminalColors.cardBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      activeWs?.os == 'Windows' ? Icons.desktop_windows : Icons.folder_open_outlined,
                      color: TerminalColors.pureWhite,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'BROWSE $osName COMPUTER FOLDERS',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: TerminalColors.pureWhite,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: TerminalColors.zinc, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Current Path & Up Navigation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: Colors.black,
            child: Row(
              children: [
                if (_parentPath != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => _loadDirectory(_parentPath),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: TerminalColors.cardBorderLight),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.arrow_upward, size: 12, color: TerminalColors.pureWhite),
                            const SizedBox(width: 4),
                            Text('UP', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite)),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    _currentPath.isNotEmpty ? _currentPath : 'Root',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.pureWhite),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Quick Shortcuts Bar
          if (_shortcuts.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: TerminalColors.cardBorder)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _shortcuts.map((sc) {
                    final path = sc['path'] ?? '';
                    final isSel = _currentPath == path;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: InkWell(
                        onTap: () => _loadDirectory(path),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSel ? TerminalColors.pureWhite : Colors.black,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: TerminalColors.cardBorderLight),
                          ),
                          child: Text(
                            sc['label'] ?? '',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSel ? Colors.black : TerminalColors.pureWhite,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

          // Folder List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: TerminalColors.pureWhite))
                : _entries.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _error ? Icons.cloud_off : Icons.folder_open,
                                size: 36,
                                color: _error ? const Color(0xFFFFD43B) : TerminalColors.zinc,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _error
                                    ? 'Cannot browse $osName filesystem:\nDaemon is not reachable at ${activeWs?.endpoint ?? "endpoint"}'
                                    : 'No subdirectories found in $_currentPath',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.jetBrainsMono(
                                  color: _error ? const Color(0xFFFFD43B) : TerminalColors.textMuted,
                                  fontSize: 11,
                                ),
                              ),
                              if (_error) ...[
                                const SizedBox(height: 10),
                                Text(
                                  'Run `cargo run --bin agentdeckd` on $osName to browse files live.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: TerminalColors.zinc),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: _entries.length,
                        itemBuilder: (ctx, idx) {
                          final e = _entries[idx];
                          final isGit = e['is_git_repo'] == true;

                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.folder, color: TerminalColors.pureWhite, size: 20),
                            title: Text(
                              e['name'] ?? '',
                              style: GoogleFonts.jetBrainsMono(
                                color: TerminalColors.pureWhite,
                                fontWeight: isGit ? FontWeight.bold : FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                            trailing: isGit
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      'GIT REPO',
                                      style: GoogleFonts.jetBrainsMono(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.black,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.chevron_right, size: 16, color: TerminalColors.zinc),
                            onTap: () => _loadDirectory(e['path']),
                          );
                        },
                      ),
          ),

          // Bottom Selection Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(top: BorderSide(color: TerminalColors.cardBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TerminalColors.pureWhite,
                      side: const BorderSide(color: TerminalColors.cardBorderLight),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
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
                    onPressed: () {
                      final selectedPath = _currentPath.isNotEmpty
                          ? _currentPath
                          : (activeWs?.os == 'Windows' ? 'C:\\projects' : '/Users/arronkianparejas');
                      final folder = selectedPath.replaceAll('\\', '/').split('/').where((s) => s.isNotEmpty).isNotEmpty
                          ? selectedPath.replaceAll('\\', '/').split('/').where((s) => s.isNotEmpty).last
                          : 'Folder';
                      Navigator.pop(context, {
                        'path': selectedPath,
                        'name': folder,
                      });
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check, size: 16, color: Colors.black),
                        const SizedBox(width: 6),
                        Text('SELECT THIS FOLDER', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
