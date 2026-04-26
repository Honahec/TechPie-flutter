import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/course_table.dart';
import '../models/user_session.dart';

class StorageService {
  static const _sessionKey = 'user_session';
  static const _debugModeKey = 'debug_mode';
  static const _schoolNameKey = 'cached_school_name';
  static const _phoneKey = 'cached_phone';
  static const _themeModeKey = 'theme_mode';

  final FlutterSecureStorage _secure;
  final SharedPreferences _prefs;

  StorageService(this._prefs)
      : _secure = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  // Secure session storage
  Future<void> saveSession(UserSession session) async {
    await _secure.write(key: _sessionKey, value: jsonEncode(session.toJson()));
  }

  Future<UserSession?> loadSession() async {
    final raw = await _secure.read(key: _sessionKey);
    if (raw == null) return null;
    return UserSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> clearSession() async {
    await _secure.delete(key: _sessionKey);
  }

  // SharedPreferences for non-sensitive data
  bool get debugMode => _prefs.getBool(_debugModeKey) ?? false;
  Future<void> setDebugMode(bool value) => _prefs.setBool(_debugModeKey, value);

  String get cachedSchoolName => _prefs.getString(_schoolNameKey) ?? '';
  Future<void> setCachedSchoolName(String name) =>
      _prefs.setString(_schoolNameKey, name);

  String get cachedPhone => _prefs.getString(_phoneKey) ?? '';
  Future<void> setCachedPhone(String phone) =>
      _prefs.setString(_phoneKey, phone);

  String get themeMode => _prefs.getString(_themeModeKey) ?? 'system';
  Future<void> setThemeMode(String mode) =>
      _prefs.setString(_themeModeKey, mode);

  // Schedule cache
  static const _semestersKey = 'schedule_semesters';
  static const _courseTablePrefix = 'schedule_course_table_';
  static const _termBeginPrefix = 'schedule_term_begin_';
  static const _selectedSemesterKey = 'schedule_selected_semester';

  Future<void> saveSemesters(SemesterInfo info) =>
      _prefs.setString(_semestersKey, jsonEncode(info.toJson()));

  SemesterInfo? loadSemesters() {
    final raw = _prefs.getString(_semestersKey);
    if (raw == null) return null;
    return SemesterInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveCourseTable(String semesterId, CourseTable table) =>
      _prefs.setString(
          '$_courseTablePrefix$semesterId', jsonEncode(table.toJson()));

  CourseTable? loadCourseTable(String semesterId) {
    final raw = _prefs.getString('$_courseTablePrefix$semesterId');
    if (raw == null) return null;
    return CourseTable.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> saveTermBegin(String key, DateTime date) =>
      _prefs.setString('$_termBeginPrefix$key', date.toIso8601String());

  DateTime? loadTermBegin(String key) {
    final raw = _prefs.getString('$_termBeginPrefix$key');
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  String? get selectedSemester => _prefs.getString(_selectedSemesterKey);
  Future<void> setSelectedSemester(String id) =>
      _prefs.setString(_selectedSemesterKey, id);
}
