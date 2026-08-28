import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/api_service.dart';
import 'services/workstation_manager.dart';
import 'theme/terminal_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/projects_screen.dart';
import 'screens/agents_screen.dart';
import 'screens/timeline_screen.dart';
import 'screens/terminal_screen.dart';
import 'screens/approvals_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize workstations & saved daemon endpoint (Tailscale IP: 100.114.182.27)
  await WorkstationManager().init();
  await ApiService().initFromPrefs();

  // Globally hide the mobile system navigation bar (Immersive Sticky Mode)
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const AgentDeckApp());
}

class AgentDeckApp extends StatelessWidget {
  const AgentDeckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgentDeck Control Plane',
      debugShowCheckedModeBanner: false,
      theme: TerminalTheme.darkTheme,
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardScreen(onNavigate: _setIndex),
      const ProjectsScreen(),
      const AgentsScreen(),
      const TimelineScreen(),
      const TerminalScreen(),
      const ApprovalsScreen(),
      const SettingsScreen(),
    ];
  }

  void _setIndex(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: TerminalColors.cardBorder, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex > 4 ? 0 : _currentIndex,
          onTap: (idx) => _setIndex(idx),
          selectedItemColor: TerminalColors.pureWhite,
          unselectedItemColor: TerminalColors.textMuted,
          backgroundColor: TerminalColors.surface,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold),
          unselectedLabelStyle: GoogleFonts.jetBrainsMono(fontSize: 10),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard, color: TerminalColors.pureWhite),
              label: 'DASH',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_outlined),
              activeIcon: Icon(Icons.folder, color: TerminalColors.pureWhite),
              label: 'WORKSPACES',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy_outlined),
              activeIcon: Icon(Icons.smart_toy, color: TerminalColors.pureWhite),
              label: 'AGENTS',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_outlined),
              activeIcon: Icon(Icons.history, color: TerminalColors.pureWhite),
              label: 'TIMELINE',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.terminal_outlined),
              activeIcon: Icon(Icons.terminal, color: TerminalColors.pureWhite),
              label: 'TERMINAL',
            ),
          ],
        ),
      ),
    );
  }
}
