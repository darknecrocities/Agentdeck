import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/workstation_manager.dart';
import '../theme/terminal_theme.dart';

class FileViewerModal extends StatefulWidget {
  final String? initialPath;
  const FileViewerModal({super.key, this.initialPath});

  @override
  State<FileViewerModal> createState() => _FileViewerModalState();
}

class _FileViewerModalState extends State<FileViewerModal> {
  final ApiService _api = ApiService();
  final WorkstationManager _wsMgr = WorkstationManager();

  final TextEditingController _pathCtrl = TextEditingController();
  Map<String, dynamic>? _fileData;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final defaultPath = widget.initialPath ??
        (_wsMgr.activeWorkstation?.os == 'Windows'
            ? r'C:\Users\Arron\Agentdeck\Cargo.toml'
            : '/path/to/your/projects/Cargo.toml');
    _pathCtrl.text = defaultPath;
    _loadFile(defaultPath);
  }

  Future<void> _loadFile(String path) async {
    if (path.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final data = await _api.readSystemFile(path.trim());
    if (mounted) {
      setState(() {
        _loading = false;
        if (data != null) {
          _fileData = data;
        } else {
          _error = 'Unable to read file at "$path". Verify file exists on remote workstation.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeWs = _wsMgr.activeWorkstation;
    final content = _fileData?['content'] as String? ?? '';
    final filename = _fileData?['filename'] as String? ?? 'File';
    final lines = content.split('\n');

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      padding: const EdgeInsets.only(top: 14, left: 14, right: 14, bottom: 20),
      decoration: const BoxDecoration(
        color: Color(0xFF090D16),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: TerminalColors.cyberCyan, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Color(0x3338BDF8),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2338),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: TerminalColors.cyberCyan),
                    ),
                    child: const Icon(Icons.code, color: TerminalColors.cyberCyan, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LIVE REMOTE FILE VIEWER',
                        style: GoogleFonts.jetBrainsMono(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: TerminalColors.pureWhite,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        activeWs?.name ?? 'Host Machine',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.cyberCyan),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: TerminalColors.zinc, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // File Path Input & Refresh
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pathCtrl,
                  style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 11),
                  decoration: InputDecoration(
                    hintText: 'Enter absolute file path on remote PC...',
                    hintStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 10),
                    filled: true,
                    fillColor: Colors.black,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFF1E293B)),
                    ),
                  ),
                  onSubmitted: _loadFile,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F2338),
                  foregroundColor: TerminalColors.cyberCyan,
                  side: const BorderSide(color: TerminalColors.cyberCyan),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onPressed: _loading ? null : () => _loadFile(_pathCtrl.text),
                child: _loading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: TerminalColors.cyberCyan))
                    : const Icon(Icons.refresh, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // File info status bar
          if (_fileData != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0C1322),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$filename (${lines.length} lines, ${_fileData!['size_bytes']} bytes)',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.cyberCyan, fontWeight: FontWeight.bold),
                  ),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('File content copied to clipboard!'), duration: Duration(seconds: 2)),
                      );
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.copy, size: 12, color: TerminalColors.pureWhite),
                        const SizedBox(width: 4),
                        Text('COPY', style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: TerminalColors.pureWhite, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],

          // File Content Viewer
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jetBrainsMono(color: const Color(0xFFF87171), fontSize: 11),
                        ),
                      ),
                    )
                  : _fileData == null
                      ? const Center(
                          child: CircularProgressIndicator(color: TerminalColors.cyberCyan),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: lines.length,
                          itemBuilder: (ctx, index) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1.5),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 34,
                                    child: Text(
                                      '${index + 1}',
                                      style: GoogleFonts.jetBrainsMono(
                                        color: const Color(0xFF475569),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: SelectableText(
                                      lines[index],
                                      style: GoogleFonts.jetBrainsMono(
                                        color: TerminalColors.pureWhite,
                                        fontSize: 10.5,
                                        height: 1.25,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
