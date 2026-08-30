import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import 'voice_prompt_modal.dart';
import '../screens/account_switcher_screen.dart';

class LiveIdeChatModal extends StatefulWidget {
  final String? initialConversationId;

  const LiveIdeChatModal({super.key, this.initialConversationId});

  @override
  State<LiveIdeChatModal> createState() => _LiveIdeChatModalState();
}

class _LiveIdeChatModalState extends State<LiveIdeChatModal> {
  final ApiService _api = ApiService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _promptController = TextEditingController();

  List<dynamic> _messages = [];
  List<dynamic> _conversations = [];
  List<dynamic> _changedFiles = [];
  String? _activeConvId;
  String _activeModel = 'Gemini 3.7 Flash';
  String _activeEffort = 'High';
  String _activeAccount = 'developer@example.com';
  bool _isGenerating = false;
  bool _loading = true;
  bool _autoRefresh = true;
  bool _sending = false;
  bool _showChangesSheet = true;
  final Set<int> _expandedSteps = {};
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _activeConvId = widget.initialConversationId;
    _fetchChatLogs();
    _fetchAccountInfo();
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
    // Adaptive high-frequency poller: 400ms when generating, 1.5s when idle
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 450), (t) {
      if (_autoRefresh && mounted) {
        _fetchChatLogs(silent: true);
      }
    });
  }

  Future<void> _fetchAccountInfo() async {
    try {
      final acc = await _api.getAntigravityAccount();
      if (mounted && acc['active_account'] != null) {
        setState(() {
          _activeAccount = acc['active_account'].toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchChatLogs({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);

    final res = await _api.getAntigravityLiveChat(conversationId: _activeConvId);
    if (mounted) {
      final rawChanged = res['changed_files'] as List<dynamic>? ?? [];

      setState(() {
        _loading = false;
        if (res['success'] == true) {
          _activeConvId = res['active_conversation_id'] as String?;
          _conversations = res['conversations'] as List<dynamic>? ?? [];
          _messages = res['messages'] as List<dynamic>? ?? [];
          _changedFiles = rawChanged;
          _activeModel = res['active_model'] as String? ?? _activeModel;
          _activeEffort = res['active_effort'] as String? ?? _activeEffort;
          _isGenerating = res['is_generating'] as bool? ?? false;
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
          projectId: defaultProj['id'] ?? 'default',
          agent: 'antigravity',
          prompt: text,
          conversationId: _activeConvId,
          model: _activeModel,
          effort: _activeEffort,
        );
      }
    } catch (_) {}

    if (mounted) {
      setState(() => _sending = false);
      _fetchChatLogs();
    }
  }

  Future<void> _handleDecision(String action, {String? filePath}) async {
    setState(() => _sending = true);
    final res = await _api.sendAntigravityDecision(action: action, filePath: filePath);
    await _fetchChatLogs();
    if (mounted) {
      setState(() => _sending = false);
      final msg = res['message'] ?? 'Decision executed: $action';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.toString())),
      );
    }
  }

  void _showModelPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF0C0C0C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(top: BorderSide(color: Color(0xFF333333), width: 1.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SELECT MODEL & REASONING EFFORT',
                style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite),
              ),
              const SizedBox(height: 12),
              _buildModelOption(ctx, 'Gemini 3.7 Flash', 'High (Adaptive Reasoning)', 'Active Google AI Pro Tier'),
              _buildModelOption(ctx, 'Claude 3.7 Sonnet', 'High (Extended Thinking)', 'Active in Google AI Pro'),
              _buildModelOption(ctx, 'Gemini 3.6 Flash', 'Medium (High Speed)', 'Active in Google AI Pro'),
              _buildModelOption(ctx, 'Gemini 3.1 Pro', 'High (Deep Architecture)', 'Active in Google AI Pro'),
              _buildModelOption(ctx, 'GPT-4o / Codex', 'Standard', 'Multi-Model Leasing'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModelOption(BuildContext ctx, String model, String effort, String desc) {
    final isCurrent = _activeModel.contains(model.split(' ').first);
    return InkWell(
      onTap: () {
        setState(() {
          _activeModel = model;
          _activeEffort = effort.split(' ').first;
        });
        Navigator.pop(ctx);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFF171717) : Colors.black,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isCurrent ? TerminalColors.pureWhite : const Color(0xFF262626)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$model ($effort)',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(desc, style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: TerminalColors.zinc)),
                ],
              ),
            ),
            if (isCurrent) const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.check_circle, color: Color(0xFF51CF66), size: 16),
            ),
          ],
        ),
      ),
    );
  }

  void _showConversationsList() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF0C0C0C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            border: Border(top: BorderSide(color: Color(0xFF333333), width: 1.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CONVERSATION SESSIONS (BRAIN LOGS)',
                style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _conversations.length,
                  itemBuilder: (context, idx) {
                    final item = _conversations[idx];
                    final id = item['id']?.toString() ?? '';
                    final isActive = item['is_active'] == true || id == _activeConvId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF171717) : Colors.black,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: isActive ? TerminalColors.pureWhite : const Color(0xFF262626)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              id,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                color: isActive ? TerminalColors.pureWhite : TerminalColors.zinc,
                                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (!isActive)
                            InkWell(
                              onTap: () {
                                Navigator.pop(ctx);
                                setState(() => _activeConvId = id);
                                _fetchChatLogs();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: TerminalColors.pureWhite,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(
                                  'LOAD',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.black),
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF51CF66),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: Text(
                                'ACTIVE',
                                style: GoogleFonts.jetBrainsMono(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.black),
                              ),
                            ),
                        ],
                      ),
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
    final title = _activeConvId != null && _activeConvId!.length > 12
        ? 'Session ${_activeConvId!.substring(0, 12)}'
        : 'Tailscale Integration & Control';

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: Color(0xFF333333), width: 1.5)),
      ),
      child: Column(
        children: [
          // 1. Top IDE Cascade Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0C0C0C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Color(0xFF1E1E1E))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Image.asset(
                        'assets/images/agentdeck.png',
                        height: 18,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: TerminalColors.pureWhite,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_changedFiles.isNotEmpty)
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        icon: Icon(
                          _showChangesSheet ? Icons.rate_review : Icons.rate_review_outlined,
                          color: _showChangesSheet ? const Color(0xFF51CF66) : TerminalColors.zinc,
                          size: 16,
                        ),
                        tooltip: 'Toggle File Changes Review Bar',
                        onPressed: () => setState(() => _showChangesSheet = !_showChangesSheet),
                      ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      icon: const Icon(Icons.history, color: TerminalColors.zinc, size: 16),
                      tooltip: 'Session History',
                      onPressed: _showConversationsList,
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      icon: Icon(
                        _autoRefresh ? Icons.sync : Icons.sync_disabled,
                        color: _autoRefresh ? const Color(0xFF51CF66) : TerminalColors.zinc,
                        size: 16,
                      ),
                      tooltip: _autoRefresh ? 'Live Polling Active' : 'Polling Paused',
                      onPressed: () {
                        setState(() => _autoRefresh = !_autoRefresh);
                        if (_autoRefresh) _startPolling();
                      },
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                      icon: const Icon(Icons.close, color: TerminalColors.zinc, size: 16),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Main Live Trajectory Stream
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: TerminalColors.pureWhite))
                : _messages.isEmpty
                    ? Center(
                        child: Text(
                          'No messages or agent actions in this session.',
                          style: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted, fontSize: 11),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length + (_isGenerating ? 1 : 0),
                        itemBuilder: (context, idx) {
                          if (idx == _messages.length && _isGenerating) {
                            return _buildWorkingIndicator();
                          }
                          final msg = _messages[idx];
                          return _buildTrajectoryStep(msg, idx);
                        },
                      ),
          ),

          // 3. Bottom Decision Bar ("X Files With Changes")
          if (_changedFiles.isNotEmpty && _showChangesSheet) _buildDecisionReviewBar(),

          // 4. Bottom Control Bar & Prompt Input
          _buildBottomControlBar(),
        ],
      ),
    );
  }

  Widget _buildWorkingIndicator() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF262626)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: TerminalColors.pureWhite),
          ),
          const SizedBox(width: 10),
          Text(
            'Working..',
            style: GoogleFonts.jetBrainsMono(fontSize: 11.5, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite),
          ),
        ],
      ),
    );
  }

  Widget _buildTrajectoryStep(Map<String, dynamic> msg, int index) {
    final type = msg['type'] ?? '';
    final role = msg['role'] ?? '';
    final content = msg['content']?.toString() ?? '';

    if (type == 'USER_INPUT' || role == 'user') {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF101010),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2E2E2E)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, size: 14, color: TerminalColors.pureWhite),
                const SizedBox(width: 6),
                Text(
                  'USER REQUEST',
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.zinc),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              content,
              style: GoogleFonts.jetBrainsMono(fontSize: 12, color: TerminalColors.pureWhite, height: 1.4),
            ),
          ],
        ),
      );
    }

    if (type == 'THINKING' || role == 'thought') {
      final isExpanded = _expandedSteps.contains(index);
      final firstLine = content.split('\n').first;

      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF080808),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF222222)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedSteps.remove(index);
                  } else {
                    _expandedSteps.add(index);
                  }
                });
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology, size: 14, color: Color(0xFFFFD43B)),
                      const SizedBox(width: 6),
                      Text(
                        'Thinking..',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFFFD43B)),
                      ),
                    ],
                  ),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 16, color: TerminalColors.zinc),
                ],
              ),
            ),
            if (isExpanded) ...[
              const SizedBox(height: 6),
              Text(
                content,
                style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: TerminalColors.zinc, height: 1.4),
              ),
            ] else ...[
              const SizedBox(height: 2),
              Text(
                firstLine,
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF666666)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      );
    }

    if (type == 'TOOL_CALLS' && msg['tools'] is List) {
      final tools = msg['tools'] as List<dynamic>;
      return Column(
        children: tools.map((t) => _buildSingleToolCard(t, index)).toList(),
      );
    }

    if (type == 'RUN_COMMAND' || type == 'REPLACE_FILE_CONTENT' || type == 'WRITE_TO_FILE') {
      final isExpanded = _expandedSteps.contains(index);
      final exitCode = msg['exit_code'] ?? 0;
      final isOk = exitCode == 0;

      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isOk ? const Color(0xFF222222) : const Color(0xFFFF6B6B)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (isExpanded) {
                    _expandedSteps.remove(index);
                  } else {
                    _expandedSteps.add(index);
                  }
                });
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(type == 'RUN_COMMAND' ? Icons.terminal : Icons.code, size: 13, color: isOk ? const Color(0xFF51CF66) : const Color(0xFFFF6B6B)),
                      const SizedBox(width: 6),
                      Text(
                        type == 'RUN_COMMAND' ? 'Command Output (exit $exitCode)' : 'Execution Result',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite),
                      ),
                    ],
                  ),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more, size: 14, color: TerminalColors.zinc),
                ],
              ),
            ),
            if (isExpanded) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                color: const Color(0xFF0C0C0C),
                child: Text(
                  content,
                  style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Standard Agent Message
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0C),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF222222)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF51CF66)),
              const SizedBox(width: 6),
              Text(
                'AGENT RESPONSE',
                style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF51CF66)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: TerminalColors.pureWhite, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleToolCard(dynamic t, int parentIndex) {
    final cat = t['category']?.toString() ?? '';
    final name = t['name']?.toString() ?? '';
    final file = t['file_name']?.toString() ?? t['file_path']?.toString() ?? '';
    final cmd = t['command']?.toString() ?? '';
    final diff = t['diff_snippet']?.toString() ?? '';
    final desc = t['description']?.toString() ?? '';

    if (cat == 'FILE_EDIT' || cat == 'FILE_CREATE') {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C0C),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.edit_document, size: 13, color: Color(0xFF51CF66)),
                      const SizedBox(width: 5),
                      Text(
                        'Edited ',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: TerminalColors.zinc),
                      ),
                      Expanded(
                        child: Text(
                          file,
                          style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B3820),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    cat == 'FILE_CREATE' ? 'CREATED' : '+EDIT',
                    style: GoogleFonts.jetBrainsMono(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF51CF66)),
                  ),
                ),
              ],
            ),
            if (desc.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(desc, style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc)),
            ],
            if (diff.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: const Color(0xFF1E1E1E)),
                ),
                child: Text(
                  diff,
                  style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: const Color(0xFF51CF66)),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (cat == 'COMMAND') {
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C0C),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF262626)),
        ),
        child: Row(
          children: [
            const Icon(Icons.terminal, size: 14, color: TerminalColors.pureWhite),
            const SizedBox(width: 6),
            Text(
              'Ran ',
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.zinc),
            ),
            Expanded(
              child: Text(
                cmd,
                style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    if (cat == 'INSPECTION') {
      final target = t['target']?.toString() ?? '';
      return Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF080808),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0xFF1E1E1E)),
        ),
        child: Row(
          children: [
            const Icon(Icons.search, size: 13, color: TerminalColors.zinc),
            const SizedBox(width: 6),
            Text(
              'Explored ',
              style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: TerminalColors.zinc),
            ),
            Expanded(
              child: Text(
                target.isNotEmpty ? target : name,
                style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: TerminalColors.pureWhite),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDecisionReviewBar() {
    final count = _changedFiles.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0E0E0E),
        border: Border(
          top: BorderSide(color: Color(0xFF2E2E2E), width: 1.2),
          bottom: BorderSide(color: Color(0xFF2E2E2E), width: 1.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Changed files summary header row
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.edit_document, color: TerminalColors.pureWhite, size: 14),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '$count Files Changed',
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reject All Button
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: const Color(0xFF121212),
                          title: Text('REVERT ALL CHANGES?', style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 13)),
                          content: Text('This will discard all uncommitted file edits in your workspace.', style: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 11)),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6B6B), foregroundColor: Colors.black),
                              onPressed: () {
                                Navigator.pop(ctx);
                                _handleDecision('reject_all');
                              },
                              child: const Text('REVERT ALL'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF200F0F),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFFFF6B6B)),
                      ),
                      child: Text(
                        'Reject all',
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFFF6B6B)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Accept All Button
                  InkWell(
                    onTap: () => _handleDecision('accept_all'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: TerminalColors.pureWhite,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check, size: 12, color: Colors.black),
                          const SizedBox(width: 3),
                          Text(
                            'Accept all',
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),

          // File List Rows
          ..._changedFiles.take(3).map((f) {
            final name = f['file_name']?.toString() ?? '';
            final path = f['file_path']?.toString() ?? '';
            final added = f['additions'] ?? 0;
            final deleted = f['deletions'] ?? 0;

            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: const Color(0xFF1E1E1E)),
              ),
              child: Row(
                children: [
                  Text(
                    '+$added -$deleted',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF51CF66),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            path,
                            style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: const Color(0xFF666666)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _handleDecision('revert_file', filePath: path),
                    child: const Icon(Icons.close, size: 13, color: TerminalColors.zinc),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomControlBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF0C0C0C),
        border: Border(top: BorderSide(color: Color(0xFF222222))),
      ),
      child: Column(
        children: [
          // Prompt Input Row
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.add, color: TerminalColors.zinc, size: 18),
                tooltip: 'Quick Actions',
                onPressed: () {
                  _promptController.text = '/fix ';
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: _promptController,
                  style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: TerminalColors.pureWhite),
                  decoration: InputDecoration(
                    hintText: 'Ask anything, @ to mention, / for actions',
                    hintStyle: GoogleFonts.jetBrainsMono(color: const Color(0xFF555555), fontSize: 10.5),
                    filled: true,
                    fillColor: Colors.black,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                      borderSide: const BorderSide(color: Color(0xFF262626)),
                    ),
                  ),
                  onSubmitted: (_) => _sendPrompt(),
                ),
              ),
              const SizedBox(width: 4),
              // Mic / Voice Button
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: const Icon(Icons.mic, color: TerminalColors.pureWhite, size: 18),
                tooltip: 'Voice Prompt',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const VoicePromptModal(
                      projectId: 'default',
                      agent: 'antigravity',
                    ),
                  );
                },
              ),
              // Stop Agent / Send Action Button
              if (_isGenerating || _sending)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(Icons.stop_circle, color: Color(0xFFFF6B6B), size: 20),
                  tooltip: 'Stop Agent',
                  onPressed: () => _handleDecision('stop'),
                )
              else
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  icon: const Icon(Icons.arrow_upward, color: TerminalColors.pureWhite, size: 18),
                  tooltip: 'Send',
                  onPressed: _sendPrompt,
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Bottom Model & MCP Indicator Ribbon
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _showModelPicker,
                  borderRadius: BorderRadius.circular(3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFF262626)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 11, color: Color(0xFF51CF66)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$_activeModel $_activeEffort',
                            style: GoogleFonts.jetBrainsMono(fontSize: 9.5, fontWeight: FontWeight.bold, color: TerminalColors.pureWhite),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, size: 12, color: TerminalColors.zinc),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFF262626)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.shield_outlined, size: 10, color: Color(0xFF51CF66)),
                        const SizedBox(width: 3),
                        Text(
                          'MCP',
                          style: GoogleFonts.jetBrainsMono(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF51CF66)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 5),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AccountSwitcherScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141414),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: const Color(0xFF262626)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.account_circle, size: 10, color: TerminalColors.pureWhite),
                          const SizedBox(width: 3),
                          Text(
                            _activeAccount.split('@').first,
                            style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: TerminalColors.zinc),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
