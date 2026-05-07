import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/assignment.dart';
import '../models/assignment_overrides.dart';
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
  AssignmentOverrides _overrides = AssignmentOverrides();
  bool _loading = false;
  String? _error;
  // Per-platform error messages (keyed by lowercase platform id).
  final Map<String, String> _platformErrors = {};

  String get _baseUrl => _storage.useLocalhost ? _devBaseUrl : _prodBaseUrl;

  List<Assignment> get assignments => _assignments;

  /// Same list as [assignments] but with locally hidden ids filtered out.
  /// Use this in UI; use [assignments] only for places that need the raw
  /// (e.g. the hidden-list screen).
  List<Assignment> get visibleAssignments =>
      _assignments.where((a) => !_overrides.isHidden(a)).toList();

  AssignmentOverrides get overrides => _overrides;

  bool get loading => _loading;
  String? get error => _error;
  Map<String, String> get platformErrors => Map.unmodifiable(_platformErrors);

  bool isCompleted(Assignment a) => _overrides.effectiveCompleted(a);
  bool hasCompletionOverride(Assignment a) =>
      _overrides.hasCompletionOverride(a);
  bool isHidden(Assignment a) => _overrides.isHidden(a);

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
  /// or tab switch. Safe to call before login. Also loads overrides.
  void loadCached() {
    _overrides = _storage.loadAssignmentOverrides();
    final raw = _storage.loadCachedAssignments();
    if (raw.isEmpty) {
      notifyListeners();
      return;
    }
    _assignments = raw.map((e) => Assignment.fromJson(e)).toList()
      ..sort((a, b) => a.due.compareTo(b.due));
    notifyListeners();
  }

  // -- Override mutators --

  Future<void> _persistOverrides() =>
      _storage.saveAssignmentOverrides(_overrides);

  Future<void> setCompleted(Assignment a, bool completed) async {
    _overrides.completed[AssignmentOverrides.keyFor(a)] = completed;
    await _persistOverrides();
    notifyListeners();
  }

  Future<void> toggleCompleted(Assignment a) async {
    final cur = _overrides.effectiveCompleted(a);
    return setCompleted(a, !cur);
  }

  Future<void> clearCompletionOverride(Assignment a) async {
    _overrides.completed.remove(AssignmentOverrides.keyFor(a));
    await _persistOverrides();
    notifyListeners();
  }

  Future<void> resetOverrides(Iterable<String> keys) async {
    var changed = false;
    for (final k in keys) {
      if (_overrides.completed.remove(k) != null) changed = true;
    }
    if (!changed) return;
    await _persistOverrides();
    notifyListeners();
  }

  Future<void> hide(Assignment a) async {
    _overrides.hidden.add(AssignmentOverrides.keyFor(a));
    await _persistOverrides();
    notifyListeners();
  }

  Future<void> unhide(String key) async {
    if (_overrides.hidden.remove(key)) {
      await _persistOverrides();
      notifyListeners();
    }
  }

  Future<void> unhideAll() async {
    if (_overrides.hidden.isEmpty) return;
    _overrides.hidden.clear();
    await _persistOverrides();
    notifyListeners();
  }

  Future<void> clearAllOverrides() async {
    _overrides = AssignmentOverrides();
    await _storage.clearAssignmentOverrides();
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
