import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:techpie/main.dart';
import 'package:techpie/services/auth_service.dart';
import 'package:techpie/services/debug_logger.dart';
import 'package:techpie/services/http_client.dart';
import 'package:techpie/services/storage_service.dart';

void main() {
  testWidgets('App shell renders with navigation bar',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);
    final logger = DebugLogger();
    final http = LoggingHttpClient(logger);
    final auth = AuthService(storage, http);

    await tester.pumpWidget(TechPieApp(
      authService: auth,
      debugLogger: logger,
      storageService: storage,
    ));

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

    await tester.pumpWidget(TechPieApp(
      authService: auth,
      debugLogger: logger,
      storageService: storage,
    ));

    // Starts on Home
    expect(find.text('Welcome to TechPie'), findsOneWidget);

    // Tap Schedule
    await tester.tap(find.text('Schedule'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.today), findsOneWidget);
    expect(find.text('植物保护学通论(B)'), findsOneWidget);

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
