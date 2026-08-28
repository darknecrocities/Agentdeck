import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/voice_service.dart';
import '../services/workstation_manager.dart';
import '../theme/terminal_theme.dart';
import '../screens/session_screen.dart';

class VoicePromptModal extends StatefulWidget {
  final String? projectId;
  final String agent;
  final String model;
  final String effort;

  const VoicePromptModal({
    super.key,
    this.projectId,
    this.agent = 'antigravity',
    this.model = 'gemini-3.7-flash',
    this.effort = 'high',
  });

  @override
  State<VoicePromptModal> createState() => _VoicePromptModalState();
}

class _VoicePromptModalState extends State<VoicePromptModal> with SingleTickerProviderStateMixin {
  final VoiceService _voice = VoiceService();
  final ApiService _api = ApiService();
  final TextEditingController _promptCtrl = TextEditingController();

  late AnimationController _animCtrl;
  bool _isListening = false;
  bool _isDispatching = false;
  String _statusText = 'Tap microphone to speak...';

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _voice.init().then((_) {
      _startVoiceInput();
    });
  }

  @override
  void dispose() {
    _voice.stopListening();
    _animCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  Future<void> _startVoiceInput() async {
    setState(() {
      _isListening = true;
      _statusText = 'Listening to your voice prompt...';
    });

    final started = await _voice.startListening(
      onResult: (text, isFinal) {
        if (mounted) {
          setState(() {
            _promptCtrl.text = text;
            if (isFinal && text.trim().isNotEmpty) {
              _statusText = 'Speech recognized. Ready to dispatch.';
            }
          });
        }
      },
    );

    if (!started && mounted) {
      setState(() {
        _isListening = false;
        _statusText = 'Microphone unavailable. You can type below.';
      });
    }
  }

  Future<void> _stopVoiceInput() async {
    await _voice.stopListening();
    if (mounted) {
      setState(() {
        _isListening = false;
        _statusText = _promptCtrl.text.isNotEmpty ? 'Speech captured.' : 'Tap mic to speak.';
      });
    }
  }

  Future<void> _dispatchPrompt() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) return;

    await _voice.stopListening();
    setState(() {
      _isDispatching = true;
      _statusText = 'Dispatching to Google Antigravity Engine...';
    });

    // Provide immediate TTS confirmation
    _voice.speak('Executing prompt on ${WorkstationManager().currentWorkstation?.name ?? "workstation"}.');

    try {
      String? projId = widget.projectId;
      if (projId == null) {
        final projects = await _api.getProjects();
        if (projects.isNotEmpty) {
          projId = projects.first['id'];
        }
      }

      if (projId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No workspace project attached. Attach a project first.')),
          );
          Navigator.pop(context);
        }
        return;
      }

      final res = await _api.startSession(
        projectId: projId,
        agent: widget.agent,
        prompt: prompt,
        model: widget.model,
        effort: widget.effort,
      );

      if (mounted && res['id'] != null) {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SessionScreen(
              sessionId: res['id'],
              agentName: widget.agent,
              projectId: projId!,
            ),
          ),
        );
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDispatching = false;
          _statusText = 'Failed to dispatch: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeWs = WorkstationManager().currentWorkstation;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: const Border(top: BorderSide(color: Color(0xFF51CF66), width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF51CF66).withValues(alpha: 0.15),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF183018),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF51CF66)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.mic, color: Color(0xFF51CF66), size: 13),
                          const SizedBox(width: 4),
                          Text(
                            'VOICE (STT)',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF51CF66),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '• ${activeWs?.name ?? "Active Machine"}',
                        style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: TerminalColors.zinc),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: TerminalColors.zinc, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Glowing Pulsing Microphone Centerpiece
          GestureDetector(
            onTap: () {
              if (_isListening) {
                _stopVoiceInput();
              } else {
                _startVoiceInput();
              }
            },
            child: AnimatedBuilder(
              animation: _animCtrl,
              builder: (context, child) {
                final scale = _isListening ? 1.0 + (_animCtrl.value * 0.12) : 1.0;
                final glowOpacity = _isListening ? 0.3 + (_animCtrl.value * 0.4) : 0.08;

                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? const Color(0xFF143318) : const Color(0xFF1A1A1A),
                      border: Border.all(
                        color: _isListening ? const Color(0xFF51CF66) : TerminalColors.cardBorderLight,
                        width: _isListening ? 2.5 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF51CF66).withValues(alpha: glowOpacity),
                          blurRadius: _isListening ? 28 : 8,
                          spreadRadius: _isListening ? 6 : 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? const Color(0xFF51CF66) : TerminalColors.pureWhite,
                      size: 34,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Status & Audio feedback
          Text(
            _statusText,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              color: _isListening ? const Color(0xFF51CF66) : TerminalColors.zinc,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Live Recognized Speech Input Field
          TextField(
            controller: _promptCtrl,
            maxLines: 3,
            style: GoogleFonts.jetBrainsMono(fontSize: 12, color: TerminalColors.pureWhite),
            decoration: InputDecoration(
              hintText: 'Speak or type your prompt (e.g. "Build a camera object detection screen with SQLite offline sync")...',
              hintStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted, fontSize: 11),
              filled: true,
              fillColor: Colors.black,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: TerminalColors.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: TerminalColors.pureWhite),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TerminalColors.pureWhite,
                    side: const BorderSide(color: TerminalColors.cardBorderLight),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: Icon(_isListening ? Icons.stop : Icons.mic, size: 16),
                  label: Text(_isListening ? 'STOP MIC' : 'SPEAK AGAIN', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    if (_isListening) {
                      _stopVoiceInput();
                    } else {
                      _startVoiceInput();
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TerminalColors.pureWhite,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: _isDispatching
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.send_rounded, size: 16),
                  label: Text('DISPATCH PROMPT', style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.w900)),
                  onPressed: _isDispatching ? null : _dispatchPrompt,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
