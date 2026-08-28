import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/workstation_manager.dart';
import '../theme/terminal_theme.dart';
import 'voice_prompt_modal.dart';

class LiveIdeChatModal extends StatefulWidget {
  final String? initialConversationId;

  const LiveIdeChatModal({super.key, this.initialConversationId});

  @override
  State<LiveIdeChatModal> createState() => _LiveIdeChatModalState();
}

class _LiveIdeChatModalState extends State<LiveIdeChatModal> {
  final ApiService _api = ApiService();
  final WorkstationManager _wsMgr = WorkstationManager();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _promptController = TextEditingController();

  List<dynamic> _messages = [];
  List<dynamic> _conversations = [];
  String? _activeConvId;
  bool _loading = true;
  bool _autoRefresh = true;
  bool _sending = false;
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _activeConvId = widget.initialConversationId;
    _fetchChatLogs();
    _startPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _scrollController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (t) {
      if (_autoRefresh && mounted) {
        _fetchChatLogs(silent: true);
      }
    });
  }

  Future<void> _fetchChatLogs({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);

    final res = await _api.getAntigravityLiveChat(conversationId: _activeConvId);
    if (mounted) {
      setState(() {
        _loading = false;
        if (res['success'] == true) {
          _activeConvId = res['active_conversation_id'] as String?;
          _conversations = res['conversations'] as List<dynamic>? ?? [];
          _messages = res['messages'] as List<dynamic>? ?? [];
        }
      });
      if (!silent) _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendPrompt() async {
    final text = _promptController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    _promptController.clear();

    try {
      final defaultProj = (await _api.getProjects()).firstOrNull;
      if (defaultProj != null) {
        await _api.startSession(
          projectId: defaultProj['id'],
          agent: 'antigravity',
          prompt: text,
        );
      }
      await _fetchChatLogs();
    } catch (_) {}

    if (mounted) setState(() => _sending = false);
  }

  void _showConversationPicker() {
    if (_conversations.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF090D16),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SELECT ANTIGRAVITY IDE CONVERSATION',
                style: GoogleFonts.jetBrainsMono(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: TerminalColors.cyberCyan,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _conversations.length,
                  itemBuilder: (context, idx) {
                    final conv = _conversations[idx];
                    final convId = conv['id'] as String? ?? '';
                    final isActive = convId == _activeConvId;

                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Text(
                        convId,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          color: isActive ? TerminalColors.cyberCyan : TerminalColors.pureWhite,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: isActive
                          ? const Icon(Icons.check_circle, color: TerminalColors.cyberCyan, size: 16)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        setState(() => _activeConvId = convId);
                        _fetchChatLogs();
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeWs = _wsMgr.activeWorkstation;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Color(0xFF070B12),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: TerminalColors.cyberCyan, width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Color(0x3338BDF8),
            blurRadius: 32,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF0A101C),
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F2338),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: TerminalColors.cyberCyan),
                      ),
                      child: const Icon(Icons.forum_outlined, color: TerminalColors.cyberCyan, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ANTIGRAVITY LIVE IDE CHATLOG',
                          style: GoogleFonts.jetBrainsMono(
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                            color: TerminalColors.pureWhite,
                            letterSpacing: 0.8,
                          ),
                        ),
                        InkWell(
                          onTap: _showConversationPicker,
                          child: Row(
                            children: [
                              Text(
                                'Host: ${activeWs?.name ?? "Workstation"} | ID: ${_activeConvId != null && _activeConvId!.length > 8 ? _activeConvId!.substring(0, 8) : _activeConvId ?? "Live"}',
                                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.cyberCyan),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_drop_down, color: TerminalColors.cyberCyan, size: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    // Auto-refresh toggle pill
                    InkWell(
                      onTap: () {
                        setState(() => _autoRefresh = !_autoRefresh);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: _autoRefresh ? const Color(0xFF0F2338) : Colors.black,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _autoRefresh ? TerminalColors.cyberCyan : const Color(0xFF334155)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _autoRefresh ? TerminalColors.cyberCyan : Colors.grey,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _autoRefresh ? 'LIVE SYNC' : 'PAUSED',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: _autoRefresh ? TerminalColors.cyberCyan : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: TerminalColors.pureWhite, size: 18),
                      tooltip: 'Refresh Logs',
                      onPressed: () => _fetchChatLogs(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: TerminalColors.zinc, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Messages List View
          Expanded(
            child: _loading && _messages.isEmpty
                ? const Center(child: CircularProgressIndicator(color: TerminalColors.cyberCyan))
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No Antigravity IDE transcripts found on host workstation.\nStart an agy session to stream live.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 11),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, idx) {
                          final msg = _messages[idx];
                          return _buildMessageTile(msg);
                        },
                      ),
          ),

          // Bottom Prompt Input Box
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF090D16),
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.mic, color: TerminalColors.cyberCyan, size: 20),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const VoicePromptModal(),
                    );
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _promptController,
                    style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 11.5),
                    decoration: InputDecoration(
                      hintText: 'Prompt agent remotely (e.g. continue, fix, build)...',
                      hintStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 10.5),
                      filled: true,
                      fillColor: Colors.black,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: Color(0xFF1E293B)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: TerminalColors.cyberCyan),
                      ),
                    ),
                    onSubmitted: (_) => _sendPrompt(),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  icon: _sending
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: TerminalColors.cyberCyan))
                      : const Icon(Icons.send_rounded, color: TerminalColors.cyberCyan, size: 20),
                  onPressed: _sending ? null : _sendPrompt,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageTile(Map<String, dynamic> msg) {
    final role = msg['role'] as String? ?? 'agent';
    final content = msg['content'] as String? ?? '';
    final type = msg['type'] as String? ?? '';
    final timestamp = msg['timestamp'] as String? ?? '';
    final tools = msg['tools'] as List<dynamic>? ?? [];

    if (role == 'user') {
      return Container(
        margin: const EdgeInsets.only(bottom: 12, left: 24),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: TerminalColors.cyberCyan.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, size: 12, color: TerminalColors.cyberCyan),
                    const SizedBox(width: 4),
                    Text(
                      'USER PROMPT',
                      style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.w900, color: TerminalColors.cyberCyan),
                    ),
                  ],
                ),
                if (timestamp.isNotEmpty)
                  Text(
                    timestamp.split('T').last.split('.').first,
                    style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: TerminalColors.zinc),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SelectableText(
              content,
              style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 11, height: 1.3),
            ),
          ],
        ),
      );
    } else if (role == 'thought') {
      return Container(
        margin: const EdgeInsets.only(bottom: 10, right: 24),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF0B111E),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(top: 6),
          title: Row(
            children: [
              const Icon(Icons.psychology, size: 13, color: Color(0xFF60A5FA)),
              const SizedBox(width: 6),
              Text(
                'AGENT THINKING PROCESS',
                style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF60A5FA)),
              ),
            ],
          ),
          children: [
            SelectableText(
              content,
              style: GoogleFonts.jetBrainsMono(color: const Color(0xFF94A3B8), fontSize: 10, height: 1.25),
            ),
          ],
        ),
      );
    } else if (role == 'tool_call') {
      return Container(
        margin: const EdgeInsets.only(bottom: 8, right: 20),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.build_circle_outlined, size: 12, color: Color(0xFFFBBF24)),
                const SizedBox(width: 5),
                Text(
                  'TOOL EXECUTION (${tools.length} CALLS)',
                  style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFFBBF24)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...tools.map((t) {
              final toolName = t['name'] ?? 'tool';
              final args = t['args']?.toString() ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('> $toolName', style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite)),
                      if (args.isNotEmpty)
                        Text(args, style: GoogleFonts.jetBrainsMono(fontSize: 9, color: TerminalColors.zinc), maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      );
    } else if (role == 'tool_output') {
      return Container(
        margin: const EdgeInsets.only(bottom: 8, right: 20),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF06090E),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OUTPUT [$type]',
              style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 4),
            SelectableText(
              content.length > 500 ? '${content.substring(0, 500)}... (truncated)' : content,
              style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: const Color(0xFFCBD5E1)),
            ),
          ],
        ),
      );
    } else {
      // Agent Message
      return Container(
        margin: const EdgeInsets.only(bottom: 12, right: 24),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF090E17),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.smart_toy, size: 13, color: TerminalColors.pureWhite),
                    const SizedBox(width: 6),
                    Text(
                      'ANTIGRAVITY AGENT',
                      style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.w900, color: TerminalColors.pureWhite),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Agent message copied!'), duration: Duration(seconds: 2)),
                    );
                  },
                  child: const Icon(Icons.copy, size: 12, color: TerminalColors.zinc),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              content,
              style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 11, height: 1.35),
            ),
          ],
        ),
      );
    }
  }
}
