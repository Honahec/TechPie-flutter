import 'dart:async';

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/assignment.dart';
import '../models/assignment_overrides.dart';
import '../models/third_party_account.dart';
import 'api_base_url.dart';
import 'auth_service.dart';
import 'http_client.dart';
import 'schedule_service.dart';
import 'storage_service.dart';
import 'third_party_auth_service.dart';

class AssignmentService extends ChangeNotifier {
  final StorageService _storage;
  final LoggingHttpClient _http;
  final AuthService _auth;
  final ThirdPartyAuthService _tpAuth;
  final ScheduleService _schedule;

  List<Assignment> _assignments = [];
  AssignmentOverrides _overrides = AssignmentOverrides();
  bool _loading = false;
  String? _error;
  // Per-platform error messages (keyed by lowercase platform id).
  final Map<String, String> _platformErrors = {};

  String get _baseUrl => apiBaseUrl(_storage);

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

  AssignmentService(
    this._storage,
    this._http,
    this._auth,
    this._tpAuth,
    this._schedule,
  ) {
    // Refetch when bindings or auth change *after* initial app boot.
    // The initial fetch is kicked off explicitly from main.dart so we
    // don't double-fire during service initialization.
    _tpAuth.addListener(_onDepsChanged);
    _auth.addListener(_onDepsChanged);
    _schedule.addListener(_onDepsChanged);
  }

  bool _autoRefetchEnabled = false;

  /// Allow auto-refetch on auth/binding changes. Call after the first
  /// explicit fetch from app boot has been kicked off.
  void enableAutoRefetch() => _autoRefetchEnabled = true;

  void _onDepsChanged() {
    if (!_autoRefetchEnabled) return;
    unawaited(fetchAssignments());
  }

  @override
  void dispose() {
    _tpAuth.removeListener(_onDepsChanged);
    _auth.removeListener(_onDepsChanged);
    _schedule.removeListener(_onDepsChanged);
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

    final successfulResults = <String, List<Assignment>>{};

    final futures = <Future<void>>[];

    if (_auth.isLoggedIn) {
      futures.add(
        _fetchBlackboard().then((items) {
          if (items != null) successfulResults['blackboard'] = items;
        }),
      );
      futures.add(
        _fetchExamTable().then((items) {
          if (items != null) successfulResults['exam'] = items;
        }),
      );
    }

    for (final acc in _tpAuth.accounts) {
      switch (acc.platform) {
        case ThirdPartyPlatform.gradescope:
          futures.add(
            _fetchGradescope(acc).then((items) {
              if (items != null) successfulResults[acc.platform.id] = items;
            }),
          );
          break;
        case ThirdPartyPlatform.hydro:
          futures.add(
            _fetchHydro(acc).then((items) {
              if (items != null) successfulResults[acc.platform.id] = items;
            }),
          );
          break;
      }
    }

    try {
      await Future.wait(futures);
      final merged = _mergeAssignments(
        successfulResults: successfulResults,
      );

      _assignments = merged;
      await _storage.saveCachedAssignments(
        merged.map((a) => a.toJson()).toList(),
      );
    } catch (e) {
      _error = '同步失败，请检查网络或稍后重试';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  List<Assignment> _mergeAssignments({
    required Map<String, List<Assignment>> successfulResults,
  }) {
    final successfulPlatforms =
        successfulResults.keys.map((p) => p.toLowerCase()).toSet();

    final merged = <Assignment>[
      for (final a in _assignments)
        if (!successfulPlatforms.contains(a.platform.toLowerCase())) a,
      ...successfulResults.values.expand((items) => items),
    ]..sort((a, b) => a.due.compareTo(b.due));

    return merged;
  }

  Future<void> fetchPlatform(String platformId) async {
    _loading = true;
    _error = null;
    _platformErrors.remove(platformId);
    notifyListeners();

    final successfulResults = <String, List<Assignment>>{};
    Future<void>? future;

    if (platformId == 'blackboard' && _auth.isLoggedIn) {
      future = _fetchBlackboard().then((items) {
        if (items != null) successfulResults['blackboard'] = items;
      });
    } else if (platformId == 'exam' && _auth.isLoggedIn) {
      future = _fetchExamTable().then((items) {
        if (items != null) successfulResults['exam'] = items;
      });
    } else {
      for (final acc in _tpAuth.accounts) {
        if (acc.platform.id == platformId) {
          if (acc.platform == ThirdPartyPlatform.gradescope) {
            future = _fetchGradescope(acc).then((items) {
              if (items != null) successfulResults[platformId] = items;
            });
          } else if (acc.platform == ThirdPartyPlatform.hydro) {
            future = _fetchHydro(acc).then((items) {
              if (items != null) successfulResults[platformId] = items;
            });
          }
          break;
        }
      }
    }

    if (future != null) {
      try {
        await future;
        final merged = _mergeAssignments(
          successfulResults: successfulResults,
        );

        _assignments = merged;
        await _storage.saveCachedAssignments(
          merged.map((a) => a.toJson()).toList(),
        );
      } catch (e) {
        _error = e.toString();
      }
    }

    _loading = false;
    notifyListeners();
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
      _platformErrors['blackboard'] = '同步失败，请检查网络或稍后重试';
      return null;
    }
  }

  Future<List<Assignment>?> _fetchExamTable() async {
    final session = _auth.session;
    final semesterId = _selectedSemesterId();
    if (session == null || semesterId == null || semesterId.isEmpty) {
      return null;
    }

    Map<String, dynamic> buildBody() => {
          'semester_id': semesterId,
          'cookies': _eamsCookies(),
        };

    try {
      var resp = await _http.post(
        Uri.parse('$_baseUrl/schedule/exam_table'),
        headers: _jsonHeaders(),
        body: jsonEncode(buildBody()),
        tag: 'schedule:exam_table',
      );
      if (resp.statusCode == 401) {
        if (await _auth.tryRenewSession()) {
          resp = await _http.post(
            Uri.parse('$_baseUrl/schedule/exam_table'),
            headers: _jsonHeaders(),
            body: jsonEncode(buildBody()),
            tag: 'schedule:exam_table:retry',
          );
        }
      }
      return _parseExamTableResponse(resp);
    } catch (e) {
      _platformErrors['exam'] = '同步失败，请检查网络或稍后重试';
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
      _platformErrors['gradescope'] = '同步失败，请检查网络或稍后重试';
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
    var hadError = false;
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
        if (items != null) {
          all.addAll(items);
        } else {
          hadError = true;
        }
      } catch (e) {
        _platformErrors['hydro'] = '同步失败，请检查网络或稍后重试';
        hadError = true;
      }
    }
    if (hadError) return null;
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
      _platformErrors[platformKey] = '同步失败，服务器返回异常数据';
      return null;
    }

    if (resp.statusCode != 200 || data['success'] != true) {
      _platformErrors[platformKey] =
          (data['error'] as String?) ?? '同步失败 (HTTP ${resp.statusCode})';
      return null;
    }

    final raw = data['data'] as List<dynamic>? ?? const [];
    return raw
        .map((e) => Assignment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  List<Assignment>? _parseExamTableResponse(http.Response resp) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      _platformErrors['exam'] = '同步失败，服务器返回异常数据';
      return null;
    }

    if (resp.statusCode != 200 || data['success'] != true) {
      _platformErrors['exam'] =
          (data['error'] as String?) ?? '同步失败 (HTTP ${resp.statusCode})';
      return null;
    }

    final payload = data['data'] is Map
        ? (data['data'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final batchId = payload['examBatchId']?.toString() ?? '';
    final batchName = payload['examBatchName']?.toString() ?? '考试';
    final semesterId =
        payload['semesterId']?.toString() ?? _selectedSemesterId() ?? '';
    final raw = payload['exams'] as List<dynamic>? ?? const [];

    return raw
        .map((exam) => exam is Map ? exam.cast<String, dynamic>() : null)
        .whereType<Map<String, dynamic>>()
        .map(
          (exam) => _assignmentFromExam(
            exam,
            batchId: batchId,
            batchName: batchName,
            semesterId: semesterId,
          ),
        )
        .whereType<Assignment>()
        .toList();
  }

  Assignment? _assignmentFromExam(
    Map<String, dynamic> exam, {
    required String batchId,
    required String batchName,
    required String semesterId,
  }) {
    final due = _examDateTime(exam);
    if (due == null) return null;

    final course = _firstString(exam, const [
          'course',
          'courseName',
          'course_name',
          'courseTitle',
          'course_title',
          'name',
        ]) ??
        '未命名课程';
    final examType = _firstString(exam, const [
      'examType',
      'exam_type',
      'type',
      'category',
    ]);
    final title = _firstString(exam, const [
          'title',
          'examName',
          'exam_name',
        ]) ??
        (examType == null || examType.isEmpty
            ? '$course 考试'
            : '$course $examType');

    final location = _firstString(exam, const [
      'location',
      'classroom',
      'room',
      'examRoom',
      'exam_room',
      'place',
    ]);
    final seat = _firstString(exam, const [
      'seat',
      'seatNo',
      'seat_no',
      'seatNumber',
      'seat_number',
    ]);

    final detailParts = [
      if (location != null && location.isNotEmpty) location,
      if (seat != null && seat.isNotEmpty) '座位 $seat',
      if (batchName.isNotEmpty) batchName,
    ];

    return Assignment(
      id: _examId(
        exam,
        batchId: batchId,
        semesterId: semesterId,
        course: course,
        due: due,
      ),
      platform: 'exam',
      kind: DeadlineKind.exam,
      title: title,
      course:
          detailParts.isEmpty ? course : '$course · ${detailParts.join(' · ')}',
      due: due,
      status: 'Exam',
    );
  }

  String _examId(
    Map<String, dynamic> exam, {
    required String batchId,
    required String semesterId,
    required String course,
    required DateTime due,
  }) {
    final explicit = _firstString(exam, const [
      'id',
      'examId',
      'exam_id',
      'scheduleId',
      'schedule_id',
    ]);
    if (explicit != null && explicit.isNotEmpty) {
      return '$semesterId:$batchId:$explicit';
    }
    final courseCode = _firstString(exam, const [
          'courseCode',
          'course_code',
          'code',
        ]) ??
        course;
    return '$semesterId:$batchId:$courseCode:${due.toIso8601String()}';
  }

  DateTime? _examDateTime(Map<String, dynamic> exam) {
    for (final key in const [
      'due',
      'startAt',
      'start_at',
      'beginAt',
      'begin_at',
      'dateTime',
      'datetime',
      'examDateTime',
      'exam_datetime',
      'examTime',
      'exam_time',
      'time',
    ]) {
      final parsed = _parseDateTimeValue(exam[key]);
      if (parsed != null) return parsed;
    }

    final date = _firstString(exam, const [
      'date',
      'examDate',
      'exam_date',
      'day',
    ]);
    if (date == null) return null;

    final time = _firstString(exam, const [
      'startTime',
      'start_time',
      'beginTime',
      'begin_time',
      'time',
      'examTime',
      'exam_time',
    ]);
    return _parseDateTimeValue(
      time == null || time.isEmpty ? date : '$date ${_firstTime(time)}',
    );
  }

  DateTime? _parseDateTimeValue(dynamic value) {
    if (value == null) return null;
    if (value is num) {
      final raw = value.toInt();
      final millis = raw > 100000000000 ? raw : raw * 1000;
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }

    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final numeric = num.tryParse(text);
    if (numeric != null) return _parseDateTimeValue(numeric);

    final normalized = text
        .replaceAll('年', '-')
        .replaceAll('月', '-')
        .replaceAll('日', ' ')
        .replaceFirst(' ', 'T');
    final parsed = DateTime.tryParse(normalized);
    if (parsed != null) return parsed;

    final match = RegExp(
      r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:\D+(\d{1,2}):(\d{2}))?',
    ).firstMatch(text);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final hour = int.tryParse(match.group(4) ?? '') ?? 0;
    final minute = int.tryParse(match.group(5) ?? '') ?? 0;
    return DateTime(year, month, day, hour, minute);
  }

  String? _firstString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String _firstTime(String text) {
    final match = RegExp(r'(\d{1,2}:\d{2})').firstMatch(text);
    return match?.group(1) ?? text;
  }

  String? _selectedSemesterId() =>
      _schedule.selectedSemesterId ??
      _storage.selectedSemester ??
      _schedule.semesterInfo?.defaultSemester;

  String _eamsCookies() {
    final session = _auth.session!;
    final baseCookies = session.cookies;
    final tgc = session.tgc;
    return tgc.isNotEmpty
        ? (baseCookies.isNotEmpty ? '$baseCookies; CASTGC=$tgc' : 'CASTGC=$tgc')
        : baseCookies;
  }
}
