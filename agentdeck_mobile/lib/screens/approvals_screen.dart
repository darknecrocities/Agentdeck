import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../theme/terminal_theme.dart';
import '../widgets/terminal_widgets.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
  final ApiService _api = ApiService();
  List<dynamic> _approvals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadApprovals();
  }

  Future<void> _loadApprovals() async {
    setState(() => _loading = true);
    try {
      final list = await _api.getApprovals();
      if (mounted) {
        setState(() {
          _approvals = list;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleResolve(String id, bool approve) async {
    await _api.resolveApproval(id, approve);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'Action APPROVED' : 'Action DENIED',
            style: GoogleFonts.jetBrainsMono(color: approve ? Colors.black : Colors.white),
          ),
          backgroundColor: approve ? Colors.white : Colors.black,
        ),
      );
      _loadApprovals();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SECURITY APPROVALS'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: TerminalColors.pureWhite), onPressed: _loadApprovals),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: TerminalColors.pureWhite))
          : _approvals.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle_outline, color: TerminalColors.pureWhite, size: 42),
                      const SizedBox(height: 12),
                      Text(
                        'NO PENDING APPROVALS',
                        style: GoogleFonts.jetBrainsMono(
                          color: TerminalColors.pureWhite,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All agent operations are running within safe parameters.',
                        style: GoogleFonts.jetBrainsMono(color: TerminalColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _approvals.length,
                  itemBuilder: (ctx, idx) {
                    final req = _approvals[idx];
                    final risk = req['risk'] ?? 'medium';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: TerminalCard(
                        title: 'SECURITY APPROVAL REQUIRED',
                        borderColor: TerminalColors.pureWhite,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'RISK: ${risk.toString().toUpperCase()}',
                            style: GoogleFonts.jetBrainsMono(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Agent: ${(req['agent'] ?? 'unknown').toString().toUpperCase()}',
                              style: GoogleFonts.jetBrainsMono(
                                fontWeight: FontWeight.bold,
                                color: TerminalColors.pureWhite,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              req['description'] ?? 'High-risk action requested',
                              style: GoogleFonts.jetBrainsMono(
                                color: TerminalColors.zinc,
                                fontSize: 11,
                              ),
                            ),
                            if (req['command'] != null) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: TerminalColors.cardBorderLight),
                                ),
                                child: Text(
                                  req['command'],
                                  style: GoogleFonts.jetBrainsMono(
                                    color: TerminalColors.pureWhite,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: TerminalColors.pureWhite,
                                      side: const BorderSide(color: TerminalColors.cardBorderLight),
                                    ),
                                    onPressed: () => _handleResolve(req['id'], false),
                                    child: Text('DENY', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: TerminalColors.pureWhite,
                                      foregroundColor: Colors.black,
                                    ),
                                    onPressed: () => _handleResolve(req['id'], true),
                                    child: Text('APPROVE', style: GoogleFonts.jetBrainsMono(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
