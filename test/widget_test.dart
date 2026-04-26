import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:techpie/main.dart';
import 'package:techpie/services/auth_service.dart';
import 'package:techpie/services/debug_logger.dart';
import 'package:techpie/services/http_client.dart';
import 'package:techpie/services/schedule_service.dart';
import 'package:techpie/services/storage_service.dart';
import 'package:techpie/services/theme_service.dart';

void main() {
  testWidgets('App shell renders with navigation bar', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);
    final logger = DebugLogger();
    final http = LoggingHttpClient(logger);
    final auth = AuthService(storage, http);
    final theme = ThemeService(storage);
    final schedule = ScheduleService(storage, http, auth);

    await tester.pumpWidget(
      TechPieApp(
        authService: auth,
        debugLogger: logger,
        storageService: storage,
        themeService: theme,
        scheduleService: schedule,
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Schedule'), findsWidgets);
    expect(find.text('Assignments'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('Navigation switches pages', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);
    final logger = DebugLogger();
    final http = LoggingHttpClient(logger);
    final auth = AuthService(storage, http);
    final schedule = ScheduleService(storage, http, auth);

    await tester.pumpWidget(
      TechPieApp(
        authService: auth,
        debugLogger: logger,
        storageService: storage,
        themeService: ThemeService(storage),
        scheduleService: schedule,
      ),
    );

    // Starts on Home
    expect(find.text('Welcome to TechPie'), findsOneWidget);

    // Tap Schedule
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.today), findsOneWidget);
    // Not logged in, so shows login prompt
    expect(find.text('登录以查看课表'), findsOneWidget);

    // Tap Assignments
    await tester.tap(find.text('Assignments'));
    await tester.pumpAndSettle();
    expect(find.text('No assignments yet'), findsOneWidget);

    // Tap Settings
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);
  });
}
