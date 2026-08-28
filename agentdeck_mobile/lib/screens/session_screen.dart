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

  Future<void> _sendPrompt() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) return;

    setState(() => _sending = true);
    _promptController.clear();

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
            Text('${widget.agentName.toUpperCase()} SESSION'),
            const SizedBox(width: 8),
            StatusBadge(status: _status),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.stop_circle_outlined, color: TerminalColors.neonRed),
            tooltip: 'Stop Agent Process',
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
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: TerminalColors.neonGreen,
                      ),
                    ),
                    Text(
                      'ID: ${widget.sessionId.substring(0, 8)}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _currentTask,
                  style: GoogleFonts.jetBrainsMono(fontSize: 13, color: TerminalColors.textPrimary),
                ),
                const SizedBox(height: 8),
                AsciiProgressBar(percent: _progress),
                if (_modifiedFiles.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _modifiedFiles.map((f) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: TerminalColors.neonGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: TerminalColors.neonGreen.withOpacity(0.4)),
                        ),
                        child: Text(
                          '~ $f',
                          style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.neonGreen),
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
                    child: Text(
                      'Waiting for agent events...\nDaemon is connected.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted),
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
                    style: GoogleFonts.jetBrainsMono(color: TerminalColors.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Send prompt or instruction to agent...',
                      hintStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: TerminalColors.background,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: TerminalColors.cardBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: TerminalColors.neonGreen),
                      ),
                    ),
                    onSubmitted: (_) => _sendPrompt(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: TerminalColors.neonGreen),
                        )
                      : const Icon(Icons.send_rounded, color: TerminalColors.neonGreen),
                  onPressed: _sending ? null : _sendPrompt,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(Map<String, dynamic> record) {
    final payload = record['payload'] ?? record;
    final type = payload['type'] ?? record['event_type'] ?? '';
    final data = payload['data'] ?? payload;

    IconData icon;
    Color iconColor;
    String title;
    String subtitle = '';

    switch (type) {
      case 'ThinkingStarted':
      case 'ThinkingUpdate':
        icon = Icons.psychology_outlined;
        iconColor = TerminalColors.neonPurple;
        title = 'Planning / Reasoning';
        subtitle = data['stage'] ?? 'Analyzing context...';
        break;
      case 'ToolStarted':
        icon = Icons.build_circle_outlined;
        iconColor = TerminalColors.electricCyan;
        title = 'Tool: ${data['tool'] ?? 'unknown'}';
        subtitle = data['input'] ?? '';
        break;
      case 'ToolFinished':
        icon = Icons.check_circle_outline;
        iconColor = TerminalColors.neonGreen;
        title = 'Tool Completed: ${data['tool'] ?? ''}';
        subtitle = data['summary'] ?? (data['success'] == true ? 'Success' : 'Failed');
        break;
      case 'FileCreated':
        icon = Icons.note_add_outlined;
        iconColor = TerminalColors.neonGreen;
        title = 'File Created';
        subtitle = data['path'] ?? '';
        break;
      case 'FileModified':
        icon = Icons.edit_note_rounded;
        iconColor = TerminalColors.neonAmber;
        title = 'File Modified';
        subtitle = data['path'] ?? '';
        break;
      case 'CommandStarted':
        icon = Icons.terminal_rounded;
        iconColor = TerminalColors.electricCyan;
        title = 'Command Started';
        subtitle = data['command'] ?? '';
        break;
      case 'CommandFinished':
        final code = data['exit_code'] ?? 0;
        icon = code == 0 ? Icons.check_circle : Icons.cancel_outlined;
        iconColor = code == 0 ? TerminalColors.neonGreen : TerminalColors.neonRed;
        title = 'Command Finished (exit $code)';
        subtitle = data['output_snippet'] ?? data['command'] ?? '';
        break;
      case 'AgentMessage':
        icon = Icons.chat_bubble_outline;
        iconColor = TerminalColors.neonGreen;
        title = 'Agent Message';
        subtitle = data['content'] ?? '';
        break;
      default:
        icon = Icons.info_outline;
        iconColor = TerminalColors.textSecondary;
        title = type;
        subtitle = data.toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: TerminalColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TerminalColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      color: TerminalColors.textPrimary,
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
