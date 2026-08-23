import 'package:flutter/material.dart';

import 'storage_service.dart';

enum AppThemeMode {
  system('System', Icons.brightness_auto_outlined),
  light('Light', Icons.light_mode_outlined),
  dark('Dark', Icons.dark_mode_outlined),
  amoled('Dark AMOLED', Icons.brightness_2_outlined);

  const AppThemeMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

enum AppColorScheme {
  system('System', Icons.colorize_outlined),
  techRed('TechRed', Icons.palette_outlined);

  const AppColorScheme(this.label, this.icon);
  final String label;
  final IconData icon;
}

class ThemeService extends ChangeNotifier {
  static const _techRedSeed = Color(0xFFA30B19);

  final StorageService _storage;

  ThemeService(this._storage)
      : _mode = AppThemeMode.values.firstWhere(
          (m) => m.name == _storage.themeMode,
          orElse: () => AppThemeMode.system,
        ),
        _colorScheme = AppColorScheme.values.firstWhere(
          (s) => s.name == _storage.colorScheme,
          orElse: () => AppColorScheme.system,
        );

  AppThemeMode _mode;
  AppThemeMode get mode => _mode;

  AppColorScheme _colorScheme;
  AppColorScheme get colorScheme => _colorScheme;

  ColorScheme? _systemLight;
  ColorScheme? _systemDark;

  Future<void> setMode(AppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await _storage.setThemeMode(mode.name);
  }

  Future<void> setColorScheme(AppColorScheme scheme) async {
    if (_colorScheme == scheme) return;
    _colorScheme = scheme;
    notifyListeners();
    await _storage.setColorScheme(scheme.name);
  }

  void updateSystemSchemes(ColorScheme? light, ColorScheme? dark) {
    if (_systemLight == light && _systemDark == dark) return;
    _systemLight = light;
    _systemDark = dark;
    notifyListeners();
  }

  bool get systemDynamicColorAvailable =>
      _systemLight != null || _systemDark != null;

  ThemeMode get themeMode {
    switch (_mode) {
      case AppThemeMode.system:
        return ThemeMode.system;
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
      case AppThemeMode.amoled:
        return ThemeMode.dark;
    }
  }

  bool get supportsColorSchemeSelection => true;

  ColorScheme _resolveScheme(Brightness brightness) {
    if (_colorScheme == AppColorScheme.system) {
      final system =
          brightness == Brightness.light ? _systemLight : _systemDark;
      if (system != null) return system;
    }
    return ColorScheme.fromSeed(
      seedColor: _techRedSeed,
      brightness: brightness,
    );
  }

  ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: _resolveScheme(Brightness.light),
    );

    return _buildDesktopTheme(base);
  }

  ThemeData get darkTheme {
    final base = _resolveScheme(Brightness.dark);

    if (_mode == AppThemeMode.amoled) {
      return ThemeData(
        useMaterial3: true,
        colorScheme: base.copyWith(
          surface: Colors.black,
          onSurface: Colors.white,
          surfaceContainerLowest: Colors.black,
          surfaceContainerLow: const Color(0xFF0A0A0A),
          surfaceContainer: const Color(0xFF121212),
          surfaceContainerHigh: const Color(0xFF1A1A1A),
          surfaceContainerHighest: const Color(0xFF222222),
        ),
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0.5,
          scrolledUnderElevation: 0.5,
          surfaceTintColor: Colors.transparent,
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: _snackBarShape,
          insetPadding: _snackBarInsets,
        ),
      );
    }

    final theme = ThemeData(useMaterial3: true, colorScheme: base);

    return _buildDesktopTheme(theme);
  }

  /// Snackbars float as rounded cards above the glass bottom nav (which is a
  /// 56dp capsule with 8dp margins) instead of a full-width strip glued to it.
  static const _snackBarShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );
  static const _snackBarInsets = EdgeInsets.fromLTRB(12, 0, 12, 12);

  ThemeData _buildDesktopTheme(ThemeData base) {
    return base.copyWith(
      appBarTheme: base.appBarTheme.copyWith(
        centerTitle: false,
        elevation: 0.5,
        scrolledUnderElevation: 0.5,
        surfaceTintColor: Colors.transparent,
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        behavior: SnackBarBehavior.floating,
        shape: _snackBarShape,
        insetPadding: _snackBarInsets,
      ),
    );
  }
}
