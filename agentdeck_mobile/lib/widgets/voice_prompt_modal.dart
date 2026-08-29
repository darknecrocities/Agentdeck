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
  String _statusText = 'Tap microphone to speak to Vibe Agent...';

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
      _statusText = 'Vibe Agent is listening to your prompt...';
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
        _statusText = _promptCtrl.text.isNotEmpty ? 'Prompt captured.' : 'Tap mic to speak to Vibe Agent.';
      });
    }
  }

  Future<void> _speakOnWorkstation() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) return;

    await _voice.stopListening();
    setState(() {
      _isDispatching = true;
      _statusText = 'Speaking on workstation speakers...';
    });

    try {
      final res = await _api.speakOnWorkstation(text: prompt, action: 'speak');
      if (mounted) {
        setState(() {
          _isDispatching = false;
          _statusText = res['success'] == true ? 'Spoken on workstation speakers.' : 'Failed to speak.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDispatching = false;
          _statusText = 'Failed to speak on workstation: $e';
        });
      }
    }
  }

  Future<void> _dispatchPrompt() async {
    final prompt = _promptCtrl.text.trim();
    if (prompt.isEmpty) return;

    await _voice.stopListening();
    setState(() {
      _isDispatching = true;
      _statusText = 'Dispatching to ${widget.agent}...';
    });

    try {
      var projId = widget.projectId;
      if (projId == null) {
        final projects = await _api.getProjects();
        projId = projects.isNotEmpty ? projects.first['id'] : 'default-proj';
      }

      final res = await _api.startSession(
        projectId: projId!,
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
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0xFF404040), width: 1.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black,
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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF171717),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: TerminalColors.pureWhite),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.record_voice_over_rounded, color: TerminalColors.pureWhite, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            'VIBE AGENT',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: TerminalColors.pureWhite,
                              letterSpacing: 0.6,
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
                      color: _isListening ? const Color(0xFF222222) : const Color(0xFF141414),
                      border: Border.all(
                        color: _isListening ? TerminalColors.pureWhite : TerminalColors.cardBorderLight,
                        width: _isListening ? 2.5 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: glowOpacity),
                          blurRadius: _isListening ? 28 : 8,
                          spreadRadius: _isListening ? 6 : 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: TerminalColors.pureWhite,
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
              color: _isListening ? TerminalColors.pureWhite : TerminalColors.zinc,
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
              hintText: 'Speak or type your vibe prompt (e.g. "Build an object detection screen with SQLite offline sync")...',
              hintStyle: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted, fontSize: 11),
              filled: true,
              fillColor: const Color(0xFF0C0C0C),
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
                  label: Text(_isListening ? 'STOP MIC' : 'SPEAK AGAIN', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    if (_isListening) {
                      _stopVoiceInput();
                    } else {
                      _startVoiceInput();
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: TerminalColors.pureWhite,
                  side: const BorderSide(color: TerminalColors.cardBorderLight),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                ),
                icon: const Icon(Icons.volume_up_rounded, size: 15),
                label: Text('SPEAK', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.w900)),
                onPressed: _isDispatching ? null : _speakOnWorkstation,
              ),
              const SizedBox(width: 8),
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
                      : const Icon(Icons.auto_awesome, size: 16),
                  label: Text('DISPATCH PROMPT', style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.w900)),
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
