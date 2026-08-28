import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/api_service.dart';
import '../services/workstation_manager.dart';
import '../theme/terminal_theme.dart';
import '../widgets/ansi_text_view.dart';

class TerminalScreen extends StatefulWidget {
  final String? initialCommand;

  const TerminalScreen({super.key, this.initialCommand});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _inputCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  String _terminalId = '';
  WebSocketChannel? _wsChannel;
  String _output = '';
  bool _connecting = true;
  bool _initialCommandExecuted = false;

  final List<String> _history = [];
  int _historyIndex = -1;

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
      final res = await _api.spawnTerminal(cols: 80, rows: 28);
      _terminalId = res['id'] ?? '';
      if (_terminalId.isNotEmpty) {
        _wsChannel = _api.connectTerminalStream(_terminalId);
        _wsChannel!.stream.listen(
          (data) {
            final text = data is List<int> ? utf8.decode(data, allowMalformed: true) : data.toString();
            if (mounted) {
              setState(() {
                _output += text;
                // keep output buffer from growing infinitely
                if (_output.length > 50000) {
                  _output = _output.substring(_output.length - 30000);
                }
              });
              _scrollToBottom();

              // Auto-run initial command once prompt is ready
              if (widget.initialCommand != null && !_initialCommandExecuted) {
                _initialCommandExecuted = true;
                Future.delayed(const Duration(milliseconds: 300), () {
                  _submitCommand(widget.initialCommand);
                });
              }
            }
          },
          onError: (_) {
            if (mounted) setState(() => _connecting = false);
          },
          onDone: () {
            if (mounted) setState(() => _connecting = false);
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _output += 'Failed to spawn PTY session: $e\n';
        });
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 60),
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

  void _submitCommand([String? directCmd]) {
    final cmd = directCmd ?? _inputCtrl.text;
    if (cmd.isNotEmpty) {
      _history.add(cmd);
      _historyIndex = _history.length;
    }
    _sendInput('$cmd\n');
    _inputCtrl.clear();
  }

  void _cycleHistory(bool up) {
    if (_history.isEmpty) return;
    if (up) {
      if (_historyIndex > 0) {
        _historyIndex--;
        _inputCtrl.text = _history[_historyIndex];
      }
    } else {
      if (_historyIndex < _history.length - 1) {
        _historyIndex++;
        _inputCtrl.text = _history[_historyIndex];
      } else {
        _historyIndex = _history.length;
        _inputCtrl.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'INTERACTIVE TERMINAL (PTY)',
          style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold, fontSize: 13),
        ),
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
            tooltip: 'Restart Shell Session',
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
          // Terminal Output Screen
          Expanded(
            child: Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width - 20,
                    ),
                    child: SelectableText.rich(
                      TextSpan(
                        children: _output.isEmpty
                            ? [
                                TextSpan(
                                  text: 'AgentDeck Remote ${(WorkstationManager().currentWorkstation?.os ?? "Host")} Terminal Connected (${WorkstationManager().currentWorkstation?.name ?? "Workstation"}).\nType commands or tap shortcuts below.\n\n',
                                  style: GoogleFonts.jetBrainsMono(color: TerminalColors.zinc, fontSize: 11.5),
                                )
                              ]
                            : AnsiParser.parse(_output, fontSize: 11.5),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Quick Keys Modifier Bar
          Container(
            color: TerminalColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTouchKey('Ctrl+C', () => _sendInput('\x03')),
                  _buildTouchKey('Tab', () => _sendInput('\t')),
                  _buildTouchKey('Esc', () => _sendInput('\x1b')),
                  _buildTouchKey('↑', () => _cycleHistory(true)),
                  _buildTouchKey('↓', () => _cycleHistory(false)),
                  _buildTouchKey('Clear', () {
                    setState(() => _output = '');
                    _sendInput('clear\n');
                  }),
                  _buildTouchKey('ls -la', () => _submitCommand('ls -la')),
                  _buildTouchKey('git status', () => _submitCommand('git status')),
                  _buildTouchKey('pwd', () => _submitCommand('pwd')),
                  _buildTouchKey('top', () => _submitCommand('top -l 1 | head -n 12')),
                ],
              ),
            ),
          ),

          // Interactive Input Field
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                Text(
                  '\$ ',
                  style: GoogleFonts.jetBrainsMono(
                    color: TerminalColors.pureWhite,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    style: GoogleFonts.jetBrainsMono(
                      color: TerminalColors.pureWhite,
                      fontSize: 12.5,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter command (e.g. ls, git status, agy)...',
                      hintStyle: GoogleFonts.jetBrainsMono(
                        color: TerminalColors.textMuted,
                        fontSize: 11.5,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (_) => _submitCommand(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_upward_rounded, color: TerminalColors.pureWhite, size: 20),
                  onPressed: () => _submitCommand(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTouchKey(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: TerminalColors.cardBorderLight),
          ),
          child: Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: TerminalColors.pureWhite,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
