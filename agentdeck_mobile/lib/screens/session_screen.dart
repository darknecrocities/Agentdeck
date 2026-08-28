import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import '../widgets/terminal_widgets.dart';

class SessionScreen extends StatefulWidget {
  final String sessionId;
  final String agentName;
  final String projectId;

  const SessionScreen({
    super.key,
    required this.sessionId,
    required this.agentName,
    required this.projectId,
  });

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _events = [];
  final Set<String> _modifiedFiles = {};
  WebSocketChannel? _wsChannel;
  bool _sending = false;
  String _status = 'running';
  String _currentTask = 'Initializing session...';
  int _progress = 75;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _wsChannel?.sink.close();
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final sess = await _api.getSession(widget.sessionId);
      final evts = await _api.getSessionEvents(widget.sessionId);

      if (mounted) {
        setState(() {
          _status = sess['status'] ?? 'running';
          _currentTask = sess['last_task'] ?? 'Processing instructions';
          for (var e in evts) {
            _handleEventRecord(e);
          }
        });
      }
    } catch (_) {}
  }

  void _connectWebSocket() {
    try {
      _wsChannel = _api.connectSessionStream(widget.sessionId);
      _wsChannel!.stream.listen(
        (data) {
          try {
            final decoded = jsonDecode(data);
            if (mounted) {
              setState(() {
                _handleEventRecord(decoded);
              });
              _scrollToBottom();
            }
          } catch (_) {}
        },
        onError: (_) {},
        onDone: () {},
      );
    } catch (_) {}
  }

  void _handleEventRecord(Map<String, dynamic> record) {
    _events.add(record);
    final payload = record['payload'] ?? record;
    final type = payload['type'] ?? record['event_type'] ?? '';
    final data = payload['data'] ?? payload;

    if (type == 'FileCreated' || type == 'FileModified') {
      final path = data['path'] ?? '';
      if (path.isNotEmpty) {
        final basename = path.split('/').last;
        _modifiedFiles.add(basename);
      }
    } else if (type == 'ThinkingUpdate') {
      _currentTask = data['stage'] ?? _currentTask;
    } else if (type == 'SessionCompleted') {
      _status = 'completed';
      _progress = 100;
    } else if (type == 'SessionFailed') {
      _status = 'failed';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendPrompt([String? customPrompt]) async {
    final prompt = (customPrompt ?? _promptController.text).trim();
    if (prompt.isEmpty) return;

    setState(() => _sending = true);
    if (customPrompt == null) _promptController.clear();

    try {
      await _api.sendPrompt(widget.sessionId, prompt);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send prompt: $e', style: GoogleFonts.jetBrainsMono())),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _continueAgent() async {
    await _api.continueSession(widget.sessionId);
    setState(() => _status = 'running');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Agent conversation resumed with agy --continue')),
    );
  }

  Future<void> _stopAgent() async {
    await _api.stopSession(widget.sessionId);
    setState(() => _status = 'stopped');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text('${widget.agentName.toUpperCase()} CONTROLLER'),
            const SizedBox(width: 8),
            StatusBadge(status: _status),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.play_arrow_outlined, color: TerminalColors.pureWhite),
            tooltip: 'Resume with --continue',
            onPressed: _continueAgent,
          ),
          IconButton(
            icon: const Icon(Icons.stop_outlined, color: TerminalColors.pureWhite),
            tooltip: 'Stop Agent',
            onPressed: _stopAgent,
          ),
        ],
      ),
      body: Column(
        children: [
          // Current Task & Plan Checklist
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: TerminalColors.surface,
              border: Border(bottom: BorderSide(color: TerminalColors.cardBorder)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CURRENT TASK',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: TerminalColors.zinc,
                      ),
                    ),
                    Text(
                      'SESSION: ${widget.sessionId.substring(0, 8)}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _currentTask,
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600, color: TerminalColors.pureWhite),
                ),
                const SizedBox(height: 8),
                AsciiProgressBar(percent: _progress),
                if (_modifiedFiles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _modifiedFiles.map((f) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(3),
                          border: Border.all(color: TerminalColors.cardBorderLight),
                        ),
                        child: Text(
                          '~ $f',
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.pureWhite),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),

          // Live Event Feed
          Expanded(
            child: _events.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/agentdeck_thinking.png',
                          height: 120,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Awaiting agent reasoning & outputs...\nConnection is live.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: _events.length,
                    itemBuilder: (context, idx) {
                      final item = _events[idx];
                      return _buildEventTile(item);
                    },
                  ),
          ),

          // Quick Action Prompt Injection Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: TerminalColors.surfaceElevated,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickActionBtn(Icons.play_arrow, 'Proceed', () => _sendPrompt('Proceed with the implementation.')),
                  _buildQuickActionBtn(Icons.bug_report, 'Run Tests', () => _sendPrompt('Run all tests and report results.')),
                  _buildQuickActionBtn(Icons.build, 'Fix Errors', () => _sendPrompt('Analyze and fix all error outputs.')),
                  _buildQuickActionBtn(Icons.cloud_upload, 'Commit & Push', () => _sendPrompt('Commit the changes and push.')),
                ],
              ),
            ),
          ),

          // Bottom Prompt Input Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: TerminalColors.surface,
              border: Border(top: BorderSide(color: TerminalColors.cardBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Send prompt or instruction to agent...',
                      hintStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted, fontSize: 12),
                      filled: true,
                      fillColor: Colors.black,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: TerminalColors.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: TerminalColors.pureWhite),
                      ),
                    ),
                    onSubmitted: (_) => _sendPrompt(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: TerminalColors.pureWhite),
                        )
                      : const Icon(Icons.arrow_upward_rounded, color: TerminalColors.pureWhite),
                  onPressed: _sending ? null : () => _sendPrompt(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionBtn(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: TerminalColors.cardBorderLight),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: TerminalColors.pureWhite),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEventTile(Map<String, dynamic> record) {
    final payload = record['payload'] ?? record;
    final type = payload['type'] ?? record['event_type'] ?? '';
    final data = payload['data'] ?? payload;

    IconData icon;
    String title;
    String subtitle = '';

    switch (type) {
      case 'ThinkingStarted':
      case 'ThinkingUpdate':
        icon = Icons.psychology_outlined;
        title = 'Planning & Inspection';
        subtitle = data['stage'] ?? 'Analyzing context...';
        break;
      case 'ToolStarted':
        icon = Icons.build_outlined;
        title = 'Tool: ${data['tool'] ?? 'unknown'}';
        subtitle = data['input'] ?? '';
        break;
      case 'ToolFinished':
        icon = Icons.check_circle_outline;
        title = 'Tool Completed: ${data['tool'] ?? ''}';
        subtitle = data['summary'] ?? (data['success'] == true ? 'Success' : 'Failed');
        break;
      case 'FileCreated':
        icon = Icons.note_add_outlined;
        title = 'File Created';
        subtitle = data['path'] ?? '';
        break;
      case 'FileModified':
        icon = Icons.edit_note_outlined;
        title = 'File Modified';
        subtitle = data['path'] ?? '';
        break;
      case 'CommandStarted':
        icon = Icons.terminal_outlined;
        title = 'Command Started';
        subtitle = data['command'] ?? '';
        break;
      case 'CommandFinished':
        final code = data['exit_code'] ?? 0;
        icon = code == 0 ? Icons.check : Icons.close;
        title = 'Command Finished (exit $code)';
        subtitle = data['output_snippet'] ?? data['command'] ?? '';
        break;
      case 'AgentMessage':
        icon = Icons.chat_bubble_outline;
        title = 'Agent Output';
        subtitle = data['content'] ?? '';
        break;
      default:
        icon = Icons.info_outline;
        title = type;
        subtitle = data.toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: TerminalColors.surface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TerminalColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: TerminalColors.pureWhite),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: TerminalColors.pureWhite,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 11,
                      color: TerminalColors.zinc,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
