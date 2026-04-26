import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/assignments_page.dart';
import 'pages/home_page.dart';
import 'pages/schedule_page.dart';
import 'pages/settings_page.dart';
import 'services/auth_service.dart';
import 'services/debug_logger.dart';
import 'services/http_client.dart';
import 'services/service_provider.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService(prefs);
  final debugLogger = DebugLogger()..enabled = storageService.debugMode;
  final httpClient = LoggingHttpClient(debugLogger);
  final authService = AuthService(storageService, httpClient);

  await authService.initialize();

  runApp(TechPieApp(
    authService: authService,
    debugLogger: debugLogger,
    storageService: storageService,
  ));
}

class TechPieApp extends StatelessWidget {
  final AuthService authService;
  final DebugLogger debugLogger;
  final StorageService storageService;

  const TechPieApp({
    super.key,
    required this.authService,
    required this.debugLogger,
    required this.storageService,
  });

  @override
  Widget build(BuildContext context) {
    return ServiceProvider(
      authService: authService,
      debugLogger: debugLogger,
      storageService: storageService,
      child: MaterialApp(
        title: 'TechPie',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.deepPurple,
            brightness: Brightness.dark,
          ),
        ),
        home: const AppShell(),
      ),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  static const List<Widget> _pages = [
    HomePage(),
    SchedulePage(),
    AssignmentsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Schedule',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: 'Assignments',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
