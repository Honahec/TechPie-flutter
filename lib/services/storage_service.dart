import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_session.dart';

class StorageService {
  static const _sessionKey = 'user_session';
  static const _debugModeKey = 'debug_mode';
  static const _schoolNameKey = 'cached_school_name';
  static const _phoneKey = 'cached_phone';

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
}
