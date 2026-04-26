import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/user_session.dart';
import 'http_client.dart';
import 'storage_service.dart';

const String _devBaseUrl = 'http://localhost:3000/api';
const String _prodBaseUrl = 'https://techpie.geekpie.club/api';

String get _baseUrl => kDebugMode ? _devBaseUrl : _prodBaseUrl;

class AuthService extends ChangeNotifier {
  final StorageService _storage;
  final LoggingHttpClient _http;

  UserSession? _session;
  bool _loading = false;

  // Context returned by send-sms, needed for mobile/login
  Map<String, dynamic>? _smsContext;

  UserSession? get session => _session;
  bool get isLoggedIn => _session != null;
  bool get loading => _loading;

  AuthService(this._storage, this._http);

  // -- Initialization & token renewal --

  Future<void> initialize() async {
    _session = await _storage.loadSession();
    if (_session != null) {
      await tryRenewSession();
    }
    notifyListeners();
  }

  Future<bool> tryRenewSession() async {
    if (_session == null) return false;
    try {
      final resp = await _http.post(
        Uri.parse('$_baseUrl/auth/renew'),
        headers: _jsonHeaders(),
        body: jsonEncode({
          'sessionToken': _session!.sessionToken,
          'tgc': _session!.tgc,
          'userId': _session!.userId,
          'tenantId': _session!.tenantId,
        }),
        tag: 'tokenRenew',
      );

      if (resp.statusCode != 200) return false;

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['success'] != true) return false;

      _session = _session!.copyWith(
        sessionToken: data['sessionToken'] as String? ?? _session!.sessionToken,
        tgc: data['tgc'] as String? ?? _session!.tgc,
        userId: data['userId'] as String? ?? _session!.userId,
        userName: data['name'] as String? ?? _session!.userName,
        tenantId: data['tenantId'] as String? ?? _session!.tenantId,
        cookies: data['cookies'] as String? ?? _session!.cookies,
        studentId: data['openId'] as String? ?? _session!.studentId,
      );
      await _storage.saveSession(_session!);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // -- SMS Login Flow --

  Future<void> sendSmsCode(String phone) async {
    final resp = await _http.post(
      Uri.parse('$_baseUrl/auth/mobile/send-sms'),
      headers: _jsonHeaders(),
      body: jsonEncode({'phone': phone}),
      tag: 'sendSms',
    );

    final data = jsonDecode(resp.body) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['error'] as String? ?? 'Failed to send SMS');
    }

    // Store context for the login step
    _smsContext = data['context'] as Map<String, dynamic>?;
  }

  Future<UserSession> smsLogin(String phone, String code) async {
    if (_smsContext == null) {
      throw Exception('Send SMS code first');
    }

    _loading = true;
    notifyListeners();
    try {
      final resp = await _http.post(
        Uri.parse('$_baseUrl/auth/mobile/login'),
        headers: _jsonHeaders(),
        body: jsonEncode({
          'phone': phone,
          'code': code,
          'context': _smsContext,
        }),
        tag: 'smsLogin',
      );

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(data['error'] as String? ?? 'Login failed');
      }

      final loginResult =
          data['loginResult'] as Map<String, dynamic>? ?? const {};

      _session = UserSession(
        sessionToken: data['sessionToken'] as String? ?? '',
        tgc: data['tgc'] as String? ?? '',
        userId: data['userId'] as String? ?? '',
        userName: loginResult['name'] as String? ?? '',
        schoolName: '上海科技大学',
        tenantId: data['tenantId'] as String? ?? '',
        phoneNumber: phone,
        cookies: data['cookies'] as String? ?? '',
        studentId: data['openId'] as String? ?? '',
        createdAt: DateTime.now(),
      );

      _smsContext = null;
      await _storage.saveSession(_session!);
      await _storage.setCachedPhone(phone);
      notifyListeners();
      return _session!;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // -- eGate Login Flow --

  Future<UserSession> egateLogin(String username, String password) async {
    _loading = true;
    notifyListeners();
    try {
      final resp = await _http.post(
        Uri.parse('$_baseUrl/auth/egate'),
        headers: _jsonHeaders(),
        body: jsonEncode({'username': username, 'password': password}),
        tag: 'egateLogin',
      );

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      if (data['success'] != true) {
        throw Exception(data['error'] as String? ?? 'Login failed');
      }

      final loginResult =
          data['loginResult'] as Map<String, dynamic>? ?? const {};

      _session = UserSession(
        sessionToken: data['sessionToken'] as String? ?? '',
        tgc: data['tgc'] as String? ?? '',
        userId: data['userId'] as String? ?? username,
        userName: loginResult['name'] as String? ?? '',
        schoolName: '上海科技大学',
        tenantId: data['tenantId'] as String? ?? '',
        phoneNumber: '',
        cookies: data['cookies'] as String? ?? '',
        createdAt: DateTime.now(),
        studentId: data['openId'] as String? ?? '',
      );

      await _storage.saveSession(_session!);
      notifyListeners();
      return _session!;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // -- Logout --

  Future<void> logout() async {
    await _storage.clearSession();
    _session = null;
    notifyListeners();
  }

  // -- Private helpers --

  Map<String, String> _jsonHeaders() => {
    'Content-Type': 'application/json; charset=UTF-8',
  };
}
