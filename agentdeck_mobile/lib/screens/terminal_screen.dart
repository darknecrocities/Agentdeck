import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  String _terminalId = '';
  WebSocketChannel? _wsChannel;
  String _output = 'AgentDeck Interactive Terminal PTY Subsystem v0.1.0\nType commands or tap quick keys below.\n\n';
  bool _connecting = true;

  @override
  void initState() {
    super.initState();
    _initTerminal();
  }

  @override
  void dispose() {
    _wsChannel?.sink.close();
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _initTerminal() async {
    setState(() => _connecting = true);
    try {
      final res = await _api.spawnTerminal();
      _terminalId = res['id'] ?? '';
      if (_terminalId.isNotEmpty) {
        _wsChannel = _api.connectTerminalStream(_terminalId);
        _wsChannel!.stream.listen(
          (data) {
            final text = data is List<int> ? utf8.decode(data, allowMalformed: true) : data.toString();
            if (mounted) {
              setState(() {
                _output += text;
              });
              _scrollToBottom();
            }
          },
          onError: (_) {},
          onDone: () {},
        );
      }
    } catch (e) {
      _output += 'Failed to spawn PTY session: $e\n';
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendInput(String input) {
    if (_wsChannel != null) {
      _wsChannel!.sink.add(input);
    }
  }

  void _submitCommand() {
    final cmd = _inputCtrl.text;
    _sendInput('$cmd\n');
    _inputCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('INTERACTIVE TERMINAL (PTY)'),
        actions: [
          if (_connecting)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: TerminalColors.pureWhite),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: TerminalColors.pureWhite),
            onPressed: () {
              _wsChannel?.sink.close();
              _output = '';
              _initTerminal();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Terminal Canvas
          Expanded(
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.all(12),
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                child: Text(
                  _output,
                  style: GoogleFonts.jetBrainsMono(
                    color: TerminalColors.pureWhite,
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
            ),
          ),

          // Quick Keys Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: const BoxDecoration(
              color: TerminalColors.surface,
              border: Border(top: BorderSide(color: TerminalColors.cardBorder)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildQuickKey('Ctrl+C', () => _sendInput('\x03')),
                  _buildQuickKey('Tab', () => _sendInput('\t')),
                  _buildQuickKey('Esc', () => _sendInput('\x1b')),
                  _buildQuickKey('↑', () => _sendInput('\x1b[A')),
                  _buildQuickKey('↓', () => _sendInput('\x1b[B')),
                  _buildQuickKey('Clear', () => setState(() => _output = '')),
                  _buildQuickKey('git status', () => _sendInput('git status\n')),
                  _buildQuickKey('cargo check', () => _sendInput('cargo check\n')),
                  _buildQuickKey('agy --help', () => _sendInput('agy --help\n')),
                ],
              ),
            ),
          ),

          // Command Input Field
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: TerminalColors.surface,
              border: Border(top: BorderSide(color: TerminalColors.cardBorder)),
            ),
            child: Row(
              children: [
                Text('\$ ', style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontWeight: FontWeight.bold)),
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    style: GoogleFonts.jetBrainsMono(color: TerminalColors.pureWhite, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter shell command...',
                      hintStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted, fontSize: 13),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _submitCommand(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded, color: TerminalColors.pureWhite, size: 20),
                  onPressed: _submitCommand,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickKey(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: TerminalColors.pureWhite,
          side: const BorderSide(color: TerminalColors.cardBorderLight),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
