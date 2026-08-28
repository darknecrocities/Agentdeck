import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/terminal_theme.dart';

class AntigravityModelOption {
  final String id;
  final String name;
  final String provider;
  final String description;
  final String defaultEffort;
  final bool isFast;
  final bool hasQuotaWarning;

  const AntigravityModelOption({
    required this.id,
    required this.name,
    required this.provider,
    required this.description,
    this.defaultEffort = 'High',
    this.isFast = false,
    this.hasQuotaWarning = false,
  });
}

const List<AntigravityModelOption> kAntigravityModels = [
  AntigravityModelOption(
    id: 'gemini-3.7-flash',
    name: 'Gemini 3.7 Flash',
    provider: 'Google Antigravity Engine',
    description: 'Ultra-fast deep reasoning with adaptive thinking budget',
    defaultEffort: 'High',
    isFast: true,
    hasQuotaWarning: false,
  ),
  AntigravityModelOption(
    id: 'gemini-3.6-flash',
    name: 'Gemini 3.6 Flash',
    provider: 'Google Antigravity Engine',
    description: 'High throughput fast reasoning and code execution',
    defaultEffort: 'Medium',
    isFast: true,
    hasQuotaWarning: false,
  ),
  AntigravityModelOption(
    id: 'gemini-3.5-flash',
    name: 'Gemini 3.5 Flash',
    provider: 'Google Antigravity Engine',
    description: 'Balanced speed and context comprehension',
    defaultEffort: 'Medium',
    isFast: true,
    hasQuotaWarning: false,
  ),
  AntigravityModelOption(
    id: 'gemini-3.1-pro',
    name: 'Gemini 3.1 Pro',
    provider: 'Google Antigravity Engine',
    description: 'Architectural reasoning & large-scale codebase planning',
    defaultEffort: 'Low',
    isFast: false,
    hasQuotaWarning: false,
  ),
  AntigravityModelOption(
    id: 'claude-sonnet-4.6',
    name: 'Claude Sonnet 4.6 (Thinking)',
    provider: 'Anthropic',
    description: 'Extended chain of thought with state-of-the-art coding precision',
    defaultEffort: 'High',
    isFast: false,
    hasQuotaWarning: true,
  ),
  AntigravityModelOption(
    id: 'claude-opus-4.6',
    name: 'Claude Opus 4.6 (Thinking)',
    provider: 'Anthropic',
    description: 'Maximum depth reasoning for mission-critical engineering',
    defaultEffort: 'High',
    isFast: false,
    hasQuotaWarning: true,
  ),
  AntigravityModelOption(
    id: 'gpt-oss-120b',
    name: 'GPT-OSS 120B (Medium)',
    provider: 'OpenAI / OSS',
    description: 'Open-weights high parameter logic engine',
    defaultEffort: 'Medium',
    isFast: false,
    hasQuotaWarning: true,
  ),
];

class ModelSelectorModal extends StatefulWidget {
  final String currentModel;
  final String currentEffort;
  final Function(String model, String effort) onSelected;

  const ModelSelectorModal({
    super.key,
    required this.currentModel,
    required this.currentEffort,
    required this.onSelected,
  });

  @override
  State<ModelSelectorModal> createState() => _ModelSelectorModalState();
}

class _ModelSelectorModalState extends State<ModelSelectorModal> {
  late String _selectedModel;
  late String _selectedEffort;

  @override
  void initState() {
    super.initState();
    _selectedModel = widget.currentModel.isNotEmpty ? widget.currentModel : 'gemini-2.5-pro';
    _selectedEffort = widget.currentEffort.isNotEmpty ? widget.currentEffort : 'high';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: TerminalColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: TerminalColors.cardBorderLight, width: 1.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ANTIGRAVITY MODEL & REASONING',
                style: GoogleFonts.jetBrainsMono(
                  color: TerminalColors.pureWhite,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: TerminalColors.zinc, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Reasoning Effort Bar
          Text(
            'THINKING & REASONING EFFORT',
            style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.zinc),
          ),
          const SizedBox(height: 6),
          Row(
            children: ['low', 'medium', 'high'].map((effort) {
              final active = _selectedEffort == effort;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: InkWell(
                    onTap: () => setState(() => _selectedEffort = effort),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? TerminalColors.pureWhite : Colors.black,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: active ? TerminalColors.pureWhite : TerminalColors.cardBorder),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        effort.toUpperCase(),
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: active ? Colors.black : TerminalColors.pureWhite,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Models List
          Text(
            'SELECT AI MODEL',
            style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: TerminalColors.zinc),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: ListView.builder(
              itemCount: kAntigravityModels.length,
              itemBuilder: (ctx, idx) {
                final m = kAntigravityModels[idx];
                final isSelected = _selectedModel == m.id;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedModel = m.id),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : TerminalColors.surface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSelected ? TerminalColors.pureWhite : TerminalColors.cardBorder,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    m.name,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                      color: TerminalColors.pureWhite,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    m.defaultEffort,
                                    style: GoogleFonts.jetBrainsMono(
                                      fontSize: 11,
                                      color: TerminalColors.zinc,
                                    ),
                                  ),
                                  if (m.isFast) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF222222),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: TerminalColors.cardBorder),
                                      ),
                                      child: Text(
                                        'Fast ⓘ',
                                        style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: TerminalColors.zinc),
                                      ),
                                    ),
                                  ],
                                  if (m.hasQuotaWarning) ...[
                                    const SizedBox(width: 8),
                                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFD43B), size: 16),
                                  ],
                                ],
                              ),
                              const Icon(Icons.chevron_right, color: TerminalColors.zinc, size: 18),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            m.description,
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: TerminalColors.pureWhite,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size(double.infinity, 42),
            ),
            onPressed: () {
              widget.onSelected(_selectedModel, _selectedEffort);
              Navigator.pop(context);
            },
            child: Text(
              'APPLY MODEL & EFFORT',
              style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.w900, fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}
