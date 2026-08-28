import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final ApiService _api = ApiService();
  final List<Map<String, dynamic>> _events = [];
  WebSocketChannel? _channel;
  bool _loading = true;
  int _lastEventId = 0;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _connectWebSocket();
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    // Load historical events from all sessions
    try {
      final sessions = await _api.getSessions();
      for (var s in sessions) {
        final evts = await _api.getSessionEvents(s['id'], afterEventId: 0);
        for (var e in evts) {
          _events.add(e);
          final eid = e['event_id'] as int? ?? 0;
          if (eid > _lastEventId) _lastEventId = eid;
        }
      }
      _events.sort((a, b) => (b['event_id'] as int? ?? 0).compareTo(a['event_id'] as int? ?? 0));
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  void _connectWebSocket() {
    try {
      _channel = _api.connectEventsStream(afterEventId: _lastEventId);
      _channel!.stream.listen((data) {
        try {
          final decoded = jsonDecode(data);
          if (mounted) {
            setState(() {
              _events.insert(0, decoded);
              final eid = decoded['event_id'] as int? ?? 0;
              if (eid > _lastEventId) _lastEventId = eid;
            });
          }
        } catch (_) {}
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ACTIVITY TIMELINE'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: TerminalColors.neonGreen))
          : _events.isEmpty
              ? Center(
                  child: Text(
                    'No historical activity recorded yet.',
                    style: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _events.length,
                  itemBuilder: (ctx, idx) {
                    final e = _events[idx];
                    return _buildTimelineItem(e);
                  },
                ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> item) {
    final payload = item['payload'] ?? item;
    final type = payload['type'] ?? item['event_type'] ?? '';
    final data = payload['data'] ?? payload;
    final tsStr = item['timestamp'] as String? ?? '';
    String time = '';
    if (tsStr.isNotEmpty) {
      try {
        final dt = DateTime.parse(tsStr);
        time = DateFormat('HH:mm:ss').format(dt);
      } catch (_) {
        time = tsStr;
      }
    }

    IconData icon = Icons.bolt;
    Color iconColor = TerminalColors.pureWhite;
    String title = type;
    String detail = '';

    switch (type) {
      case 'ThinkingStarted':
      case 'ThinkingUpdate':
        icon = Icons.psychology;
        iconColor = const Color(0xFFDA77F2);
        title = 'Agent Planning';
        detail = data['stage'] ?? '';
        break;
      case 'FileCreated':
        icon = Icons.note_add;
        iconColor = const Color(0xFF51CF66);
        title = 'File Created';
        detail = data['path'] ?? '';
        break;
      case 'FileModified':
        icon = Icons.edit_document;
        iconColor = const Color(0xFFFCC419);
        title = 'File Modified';
        detail = data['path'] ?? '';
        break;
      case 'CommandStarted':
        icon = Icons.terminal;
        iconColor = const Color(0xFF339AF0);
        title = 'Command Started';
        detail = data['command'] ?? '';
        break;
      case 'CommandFinished':
        final code = data['exit_code'] ?? 0;
        icon = code == 0 ? Icons.check_circle : Icons.error_outline;
        iconColor = code == 0 ? const Color(0xFF51CF66) : const Color(0xFFFF6B6B);
        title = 'Command Finished';
        detail = '${data['command'] ?? ''} -> Exit $code';
        break;
      case 'AgentMessage':
        icon = Icons.chat_bubble_outline;
        iconColor = TerminalColors.pureWhite;
        title = 'Agent Message';
        detail = data['content'] ?? '';
        break;
      case 'SessionStarted':
        icon = Icons.play_arrow_rounded;
        iconColor = const Color(0xFF20C997);
        title = 'Session Started';
        detail = 'Agent: ${data['agent'] ?? ''}';
        break;
      default:
        icon = Icons.push_pin_outlined;
        iconColor = TerminalColors.zinc;
        detail = data.toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TerminalColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: TerminalColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: TerminalColors.textPrimary,
                      ),
                    ),
                    if (time.isNotEmpty)
                      Text(
                        time,
                        style: GoogleFonts.jetBrainsMono(fontSize: 11, color: TerminalColors.textMuted),
                      ),
                  ],
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail,
                    style: GoogleFonts.jetBrainsMono(fontSize: 12, color: TerminalColors.textSecondary),
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
