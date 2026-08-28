import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'widgets/radial_bottom_nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Parallel initialize workstations & saved daemon endpoint for fast startup
  await Future.wait([
    WorkstationManager().init(),
    ApiService().initFromPrefs(),
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
  ]);

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
  final Set<int> _loadedTabs = {0}; // Lazy loading: Only mount Dashboard on startup!

  void _setIndex(int index) {
    setState(() {
      _currentIndex = index;
      _loadedTabs.add(index);
    });
  }

  Widget _buildScreen(int index) {
    if (!_loadedTabs.contains(index)) {
      return const SizedBox.shrink();
    }
    switch (index) {
      case 0:
        return DashboardScreen(onNavigate: _setIndex);
      case 1:
        return const ProjectsScreen();
      case 2:
        return const AgentsScreen();
      case 3:
        return const TimelineScreen();
      case 4:
        return const TerminalScreen();
      case 5:
        return const ApprovalsScreen();
      case 6:
        return const SettingsScreen();
      default:
        return DashboardScreen(onNavigate: _setIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 64),
            child: IndexedStack(
              index: _currentIndex,
              children: List.generate(7, (i) => _buildScreen(i)),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: RadialBottomNav(
              currentIndex: _currentIndex,
              onTabSelected: _setIndex,
            ),
          ),
        ],
      ),
    );
  }
}
