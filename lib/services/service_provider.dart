import 'package:flutter/widgets.dart';

import 'auth_service.dart';
import 'debug_logger.dart';
import 'schedule_service.dart';
import 'storage_service.dart';
import 'theme_service.dart';

class ServiceProvider extends InheritedWidget {
  final AuthService authService;
  final DebugLogger debugLogger;
  final StorageService storageService;
  final ThemeService themeService;
  final ScheduleService scheduleService;

  const ServiceProvider({
    super.key,
    required this.authService,
    required this.debugLogger,
    required this.storageService,
    required this.themeService,
    required this.scheduleService,
    required super.child,
  });

  static ServiceProvider of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<ServiceProvider>();
    assert(result != null, 'No ServiceProvider found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(ServiceProvider oldWidget) =>
      authService != oldWidget.authService ||
      debugLogger != oldWidget.debugLogger ||
      storageService != oldWidget.storageService ||
      themeService != oldWidget.themeService ||
      scheduleService != oldWidget.scheduleService;
}
