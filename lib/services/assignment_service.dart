import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/assignment.dart';
import '../models/third_party_account.dart';
import 'auth_service.dart';
import 'http_client.dart';
import 'storage_service.dart';
import 'third_party_auth_service.dart';

const String _devBaseUrl = 'http://localhost:3000/api';
const String _prodBaseUrl = 'https://techpie.geekpie.club/api';

class AssignmentService extends ChangeNotifier {
  final StorageService _storage;
  final LoggingHttpClient _http;
  final AuthService _auth;
  final ThirdPartyAuthService _tpAuth;

  List<Assignment> _assignments = [];
  bool _loading = false;
  String? _error;
  // Per-platform error messages (keyed by lowercase platform id).
  final Map<String, String> _platformErrors = {};

  String get _baseUrl => _storage.useLocalhost ? _devBaseUrl : _prodBaseUrl;

  List<Assignment> get assignments => _assignments;
  bool get loading => _loading;
  String? get error => _error;
  Map<String, String> get platformErrors => Map.unmodifiable(_platformErrors);

  AssignmentService(this._storage, this._http, this._auth, this._tpAuth) {
    // Refetch when bindings or auth change *after* initial app boot.
    // The initial fetch is kicked off explicitly from main.dart so we
    // don't double-fire during service initialization.
    _tpAuth.addListener(_onDepsChanged);
    _auth.addListener(_onDepsChanged);
  }

  bool _autoRefetchEnabled = false;

  /// Allow auto-refetch on auth/binding changes. Call after the first
  /// explicit fetch from app boot has been kicked off.
  void enableAutoRefetch() => _autoRefetchEnabled = true;

  void _onDepsChanged() {
    if (!_autoRefetchEnabled) return;
    fetchAssignments();
  }

  @override
  void dispose() {
    _tpAuth.removeListener(_onDepsChanged);
    _auth.removeListener(_onDepsChanged);
    super.dispose();
  }

  /// Clear cached + in-memory deadlines (called on primary logout).
  Future<void> clearCache() async {
    _assignments = [];
    _platformErrors.clear();
    _error = null;
    await _storage.clearCachedAssignments();
    notifyListeners();
  }

  /// Hydrate from local cache so the UI doesn't flash empty on app start
  /// or tab switch. Safe to call before login.
  void loadCached() {
    final raw = _storage.loadCachedAssignments();
    if (raw.isEmpty) return;
    _assignments = raw.map((e) => Assignment.fromJson(e)).toList()
      ..sort((a, b) => a.due.compareTo(b.due));
    notifyListeners();
  }

  Map<String, String> _jsonHeaders() => {
    'Content-Type': 'application/json; charset=UTF-8',
  };

  Future<void> fetchAssignments() async {
    _loading = true;
    _error = null;
    _platformErrors.clear();
    notifyListeners();

    final results = <List<Assignment>>[];

    final futures = <Future<void>>[];

    if (_auth.isLoggedIn) {
      futures.add(_fetchBlackboard().then((items) {
        if (items != null) results.add(items);
      }));
    }

    for (final acc in _tpAuth.accounts) {
      switch (acc.platform) {
        case ThirdPartyPlatform.gradescope:
          futures.add(_fetchGradescope(acc).then((items) {
            if (items != null) results.add(items);
          }));
          break;
        case ThirdPartyPlatform.hydro:
          futures.add(_fetchHydro(acc).then((items) {
            if (items != null) results.add(items);
          }));
          break;
      }
    }

    try {
      await Future.wait(futures);
      final merged = results.expand((e) => e).toList()
        ..sort((a, b) => a.due.compareTo(b.due));

      // If every per-platform fetch failed, keep the previously rendered
      // list to avoid flashing an empty state; otherwise replace + persist.
      final allFailed =
          futures.isNotEmpty && results.isEmpty && _platformErrors.isNotEmpty;
      if (!allFailed) {
        _assignments = merged;
        await _storage.saveCachedAssignments(
          merged.map((a) => a.toJson()).toList(),
        );
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // -- Per-platform fetchers --

  Future<List<Assignment>?> _fetchBlackboard() async {
    final session = _auth.session;
    if (session == null || session.tgc.isEmpty) return null;

    Future<http.Response> doFetch() => _http.post(
      Uri.parse('$_baseUrl/deadlines/blackboard'),
      headers: _jsonHeaders(),
      body: jsonEncode({'token': session.tgc}),
      tag: 'deadlines:blackboard',
    );

    try {
      var resp = await doFetch();
      if (resp.statusCode == 401) {
        if (await _auth.tryRenewSession()) {
          resp = await _http.post(
            Uri.parse('$_baseUrl/deadlines/blackboard'),
            headers: _jsonHeaders(),
            body: jsonEncode({'token': _auth.session!.tgc}),
            tag: 'deadlines:blackboard:retry',
          );
        }
      }
      return _parseDeadlinesResponse(resp, 'blackboard');
    } catch (e) {
      _platformErrors['blackboard'] = e.toString();
      return null;
    }
  }

  Future<List<Assignment>?> _fetchGradescope(ThirdPartyAccount acc) async {
    try {
      final resp = await _http.post(
        Uri.parse('$_baseUrl/deadlines/gradescope'),
        headers: _jsonHeaders(),
        body: jsonEncode({'token': acc.token}),
        tag: 'deadlines:gradescope',
      );
      if (resp.statusCode == 401) {
        await _tpAuth.unbind(ThirdPartyPlatform.gradescope);
        _platformErrors['gradescope'] = 'token 已失效,请重新绑定';
        return null;
      }
      return _parseDeadlinesResponse(resp, 'gradescope');
    } catch (e) {
      _platformErrors['gradescope'] = e.toString();
      return null;
    }
  }

  Future<List<Assignment>?> _fetchHydro(ThirdPartyAccount acc) async {
    final origin = acc.hydroOrigin ?? 'https://acm.shanghaitech.edu.cn';
    final domains = acc.hydroDomains ?? const <String>[];
    if (domains.isEmpty) {
      _platformErrors['hydro'] = '未配置 Hydro 课程域 (domain),前往设置补全';
      return null;
    }

    final all = <Assignment>[];
    for (final domain in domains) {
      final url = '${origin.replaceAll(RegExp(r'/+$'), '')}/d/$domain';
      try {
        final resp = await _http.post(
          Uri.parse('$_baseUrl/deadlines/hydro'),
          headers: _jsonHeaders(),
          body: jsonEncode({
            'token': acc.token,
            'args': {'url': url},
          }),
          tag: 'deadlines:hydro:$domain',
        );
        if (resp.statusCode == 401) {
          await _tpAuth.unbind(ThirdPartyPlatform.hydro);
          _platformErrors['hydro'] = 'token 已失效,请重新绑定';
          return null;
        }
        final items = _parseDeadlinesResponse(resp, 'hydro');
        if (items != null) all.addAll(items);
      } catch (e) {
        _platformErrors['hydro'] = e.toString();
      }
    }
    return all;
  }

  List<Assignment>? _parseDeadlinesResponse(
    http.Response resp,
    String platformKey,
  ) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      _platformErrors[platformKey] =
          'Invalid response (status ${resp.statusCode})';
      return null;
    }

    if (resp.statusCode != 200 || data['success'] != true) {
      _platformErrors[platformKey] = (data['error'] as String?) ??
          'failed (status ${resp.statusCode})';
      return null;
    }

    final raw = data['data'] as List<dynamic>? ?? const [];
    return raw
        .map((e) => Assignment.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
