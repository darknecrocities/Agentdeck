import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/terminal_theme.dart';

class AntigravityModelOption {
  final String id;
  final String name;
  final String provider;
  final String description;
  final bool hasThinking;

  const AntigravityModelOption({
    required this.id,
    required this.name,
    required this.provider,
    required this.description,
    this.hasThinking = false,
  });
}

const List<AntigravityModelOption> kAntigravityModels = [
  AntigravityModelOption(
    id: 'gemini-2.5-pro',
    name: 'Gemini 2.5 Pro',
    provider: 'Google Antigravity Engine',
    description: 'Deep reasoning, multi-phase planning & code verification (Recommended)',
    hasThinking: true,
  ),
  AntigravityModelOption(
    id: 'gemini-2.5-flash',
    name: 'Gemini 2.5 Flash',
    provider: 'Google Antigravity Engine',
    description: 'Ultra-low latency, high throughput code generation',
    hasThinking: false,
  ),
  AntigravityModelOption(
    id: 'claude-3-7-sonnet',
    name: 'Claude 3.7 Sonnet',
    provider: 'Anthropic',
    description: 'Hybrid reasoning and extended chain of thought',
    hasThinking: true,
  ),
  AntigravityModelOption(
    id: 'claude-3-5-sonnet',
    name: 'Claude 3.5 Sonnet',
    provider: 'Anthropic',
    description: 'State of the art precision coding and tool execution',
    hasThinking: false,
  ),
  AntigravityModelOption(
    id: 'gpt-4o',
    name: 'GPT-4o',
    provider: 'OpenAI',
    description: 'Omni-modal reasoning and general coding',
    hasThinking: false,
  ),
  AntigravityModelOption(
    id: 'o3-mini',
    name: 'o3-mini',
    provider: 'OpenAI',
    description: 'Specialized STEM, logic, and algorithmic reasoning',
    hasThinking: true,
  ),
  AntigravityModelOption(
    id: 'deepseek-r1',
    name: 'DeepSeek R1',
    provider: 'DeepSeek / Ollama Local',
    description: 'Open-weights deep reasoning engine',
    hasThinking: true,
  ),
  AntigravityModelOption(
    id: 'deepseek-v3',
    name: 'DeepSeek V3',
    provider: 'DeepSeek / Ollama Local',
    description: 'Fast open-weights coding model',
    hasThinking: false,
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
                              Text(
                                m.name,
                                style: GoogleFonts.jetBrainsMono(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: TerminalColors.pureWhite,
                                ),
                              ),
                              if (m.hasThinking)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: TerminalColors.cardBorderLight),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    'THINKING',
                                    style: GoogleFonts.jetBrainsMono(fontSize: 9, color: TerminalColors.pureWhite),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            m.provider,
                            style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: TerminalColors.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            m.description,
                            style: GoogleFonts.jetBrainsMono(fontSize: 10, color: TerminalColors.zinc),
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
