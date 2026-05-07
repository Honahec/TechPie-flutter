import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/assignment_service.dart';
import 'services/auth_service.dart';
import 'services/debug_logger.dart';
import 'services/http_client.dart';
import 'services/schedule_service.dart';
import 'services/service_provider.dart';
import 'services/storage_service.dart';
import 'services/theme_service.dart';
import 'services/third_party_auth_service.dart';
import 'widgets/app_shell/app_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();

  final storageService = StorageService(prefs);
  final debugLogger = DebugLogger()..enabled = storageService.debugMode;
  final httpClient = LoggingHttpClient(debugLogger);
  final authService = AuthService(storageService, httpClient);
  final themeService = ThemeService(storageService);
  final scheduleService = ScheduleService(
    storageService,
    httpClient,
    authService,
  );
  final thirdPartyAuthService = ThirdPartyAuthService(storageService, httpClient);
  final assignmentService = AssignmentService(
    storageService,
    httpClient,
    authService,
    thirdPartyAuthService,
  );

  authService.onLogout = () async {
    await thirdPartyAuthService.clearAll();
    await assignmentService.clearCache();
    await assignmentService.clearAllOverrides();
  };

  await authService.initialize();
  await thirdPartyAuthService.initialize();
  // Hydrate from cache before runApp so the Deadlines tab paints with data.
  assignmentService.loadCached();
  // Best-effort: silently refresh any third-party token expiring within 48h.
  // Fire-and-forget; UI will reflect new state via notifyListeners.
  unawaited(thirdPartyAuthService.autoRenewIfNeeded());

  // Load cached schedule data so widgets (e.g. home page) render immediately
  await scheduleService.loadCachedData();

  // Fetch fresh data in the background.
  if (authService.isLoggedIn) {
    scheduleService.fetchAll(); // fire-and-forget, UI uses cache first
  }
  if (authService.isLoggedIn || thirdPartyAuthService.boundPlatforms.isNotEmpty) {
    assignmentService.fetchAssignments(); // fire-and-forget, UI uses cache first
  }
  // After the explicit boot fetch, allow auto-refetch on auth/binding changes
  // (login, bind, unbind, logout).
  assignmentService.enableAutoRefetch();

  runApp(
    TechPieApp(
      authService: authService,
      debugLogger: debugLogger,
      storageService: storageService,
      themeService: themeService,
      scheduleService: scheduleService,
      assignmentService: assignmentService,
      thirdPartyAuthService: thirdPartyAuthService,
    ),
  );
}

class TechPieApp extends StatefulWidget {
  final AuthService authService;
  final DebugLogger debugLogger;
  final StorageService storageService;
  final ThemeService themeService;
  final ScheduleService scheduleService;
  final AssignmentService assignmentService;
  final ThirdPartyAuthService thirdPartyAuthService;

  const TechPieApp({
    super.key,
    required this.authService,
    required this.debugLogger,
    required this.storageService,
    required this.themeService,
    required this.scheduleService,
    required this.assignmentService,
    required this.thirdPartyAuthService,
  });

  @override
  State<TechPieApp> createState() => _TechPieAppState();
}

class _TechPieAppState extends State<TechPieApp> {
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.themeService,
      builder: (context, _) => ServiceProvider(
        authService: widget.authService,
        debugLogger: widget.debugLogger,
        storageService: widget.storageService,
        themeService: widget.themeService,
        scheduleService: widget.scheduleService,
        assignmentService: widget.assignmentService,
        thirdPartyAuthService: widget.thirdPartyAuthService,
        child: MaterialApp(
          title: 'TechPie',
          theme: widget.themeService.lightTheme,
          darkTheme: widget.themeService.darkTheme,
          themeMode: widget.themeService.themeMode,
          home: const AppShell(),
        ),
      ),
    );
  }
}
