import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/oa_gym.dart';
import '../models/user_session.dart';
import 'api_base_url.dart';
import 'auth_service.dart';
import 'storage_service.dart';

class OaGymException implements Exception {
  final String message;
  OaGymException(this.message);

  @override
  String toString() => message;
}

class OaGymService extends ChangeNotifier {
  final AuthService _auth;
  final StorageService _storage;
  final http.Client _client;

  bool _sessionReady = false;
  bool _metadataReady = false;
  bool _loading = false;
  Map<String, String> _venues = {};
  Map<String, String> _allVenues = {};
  Map<String, String> _timeSlots = {};

  OaGymService(this._auth, this._storage, {http.Client? client})
      : _client = client ?? http.Client();

  String get _baseUrl => apiBaseUrl(_storage);

  bool get loading => _loading;
  bool get sessionReady => _sessionReady;
  Map<String, String> get venues => Map.unmodifiable(_venues);
  Map<String, String> get allVenues => Map.unmodifiable(_allVenues);
  Map<String, String> get timeSlots => Map.unmodifiable(_timeSlots);

  void clearSession() {
    _sessionReady = false;
    _metadataReady = false;
    _venues = {};
    _allVenues = {};
    _timeSlots = {};
    notifyListeners();
  }

  OaBookingProfile bookingProfile() {
    final saved = _storage.loadOaBookingProfile();
    final session = _auth.session;
    return saved.copyWith(
      name: saved.name.isNotEmpty ? saved.name : session?.userName,
      phone: saved.phone.isNotEmpty ? saved.phone : session?.phoneNumber,
    );
  }

  Future<void> saveBookingProfile(OaBookingProfile profile) async {
    await _storage.saveOaBookingProfile(profile);
    notifyListeners();
  }

  Future<void> ensureReady() async {
    await _withLoading(() async {
      await _ensureMetadata();
      _sessionReady = true;
    });
  }

  Future<List<OaAvailability>> checkAvailability({
    required Set<OaSport> sports,
    required String date,
    required int startSlot,
    required int endSlot,
  }) async {
    final data = await _withLoadingResult(
      () => _postJson(
        'oa/gym/availability',
        {
          'auth': _authPayload(),
          'sports': sports.map((sport) => sport.id).toList(),
          'date': date,
          'startSlot': startSlot,
          'endSlot': endSlot,
        },
      ),
    );
    final rows = data['data'] as List<dynamic>? ?? const [];
    _sessionReady = true;
    return rows.map((item) {
      final json = (item as Map).cast<String, dynamic>();
      final sport = _sportFromId(json['sport'] as String? ?? '');
      return OaAvailability(
        sport: sport,
        date: json['date'] as String? ?? date,
        timeSlot: (json['timeSlot'] as num?)?.toInt() ?? 0,
        availableCourts: (json['availableCourts'] as List<dynamic>? ?? const [])
            .map((value) => (value as num).toInt())
            .toList(),
        totalCourts: (json['totalCourts'] as num?)?.toInt() ??
            oaSportConfigs[sport]!.courtCount,
      );
    }).toList();
  }

  Future<OaBookingResult> bookCourt({
    required OaSport sport,
    required String date,
    required int timeSlot,
    required int courtNumber,
    required int playersCount,
  }) async {
    final session = _requireSession();
    final profile = bookingProfile();
    final studentId =
        session.studentId.isNotEmpty ? session.studentId : session.userId;
    final userName = profile.name.isNotEmpty ? profile.name : session.userName;
    final phone =
        profile.phone.isNotEmpty ? profile.phone : session.phoneNumber;
    if (userName.isEmpty || phone.isEmpty) {
      throw OaGymException('请先在「个人信息」里补全姓名和手机号');
    }

    final data = await _withLoadingResult(
      () => _postJson(
        'oa/gym/book',
        {
          'auth': _authPayload(),
          'booking': {
            'sport': sport.id,
            'date': date,
            'timeSlot': timeSlot,
            'courtNumber': courtNumber,
            'playersCount': playersCount,
            'studentId': studentId,
            'userName': userName,
            'phone': phone,
            'email': profile.email,
          },
        },
      ),
    );
    final payload = (data['data'] as Map?)?.cast<String, dynamic>() ?? data;
    _sessionReady = true;
    return OaBookingResult(
      success: payload['success'] == true,
      message: payload['message'] as String? ?? '提交完成',
    );
  }

  Future<List<OaCourtSearchResult>> searchCourts({
    required String startDate,
    required String endDate,
    required Set<String> venueNames,
    required List<String> timeRanges,
  }) async {
    await _withLoading(() async {
      await _ensureMetadata();
    });
    final data = await _withLoadingResult(
      () => _postJson(
        'oa/gym/search',
        {
          'auth': _authPayload(),
          'startDate': startDate,
          'endDate': endDate,
          'venueNames': venueNames.toList(),
          'timeRanges': timeRanges,
        },
      ),
    );
    final rows = data['data'] as List<dynamic>? ?? const [];
    _sessionReady = true;
    return rows.map((item) {
      final json = (item as Map).cast<String, dynamic>();
      return OaCourtSearchResult(
        venue: json['venue'] as String? ?? '',
        timeRange: json['timeRange'] as String? ?? '',
        rows: (json['rows'] as List<dynamic>? ?? const [])
            .map(
              (row) => (row as List<dynamic>)
                  .map((value) => value?.toString() ?? '')
                  .toList(),
            )
            .toList(),
      );
    }).toList();
  }

  Future<void> _ensureMetadata() async {
    if (_metadataReady) return;
    final data = await _postJson('oa/gym/metadata', {'auth': _authPayload()});
    final payload = (data['data'] as Map?)?.cast<String, dynamic>() ?? data;
    _venues = _stringMap(payload['venues']);
    _allVenues = _stringMap(payload['allVenues']);
    _timeSlots = _stringMap(payload['timeSlots']);
    if (_venues.isEmpty || _timeSlots.isEmpty) {
      throw OaGymException('加载 OA 场馆数据失败，请稍后重试');
    }
    _metadataReady = true;
    _sessionReady = true;
  }

  Future<void> _withLoading(Future<void> Function() task) async {
    _loading = true;
    notifyListeners();
    try {
      await task();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<T> _withLoadingResult<T>(Future<T> Function() task) async {
    _loading = true;
    notifyListeners();
    try {
      return await task();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  UserSession _requireSession() {
    final session = _auth.session;
    if (session == null) {
      throw OaGymException('请先登录 TechPie 主账号');
    }
    if (session.tgc.isEmpty) {
      throw OaGymException('当前登录态缺少 CASTGC，请重新登录或使用短信登录刷新会话');
    }
    return session;
  }

  Map<String, dynamic> _authPayload() {
    final session = _requireSession();
    return {
      'tgc': session.tgc,
      'cookies': session.cookies,
      'sessionToken': session.sessionToken,
      'userId': session.userId,
      'tenantId': session.tenantId,
    };
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/$path'),
          headers: const {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : (jsonDecode(response.body) as Map).cast<String, dynamic>();
    if (response.statusCode == 401) {
      _sessionReady = false;
      if (await _auth.tryRenewSession()) {
        return _postJson(path, body..['auth'] = _authPayload());
      }
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        decoded['success'] == false) {
      throw OaGymException(
        decoded['error'] as String? ?? 'OA 场馆服务请求失败，请稍后重试',
      );
    }
    return decoded;
  }

  Map<String, String> _stringMap(Object? value) {
    if (value is! Map) return {};
    return value.map(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );
  }

  OaSport _sportFromId(String id) {
    for (final sport in OaSport.values) {
      if (sport.id == id) return sport;
    }
    throw OaGymException('未知运动类型: $id');
  }
}
