import "dart:convert";

import "package:flutter/foundation.dart";
import "package:http/http.dart" as http;

import "../models/oa_gym.dart";
import "../models/user_session.dart";
import "auth_service.dart";
import "storage_service.dart";

const _idsBaseUrl = "https://ids.shanghaitech.edu.cn";
const _oaBaseUrl = "https://oa.shanghaitech.edu.cn";
const _oaTargetUrl =
    "$_oaBaseUrl/workflow/request/AddRequest.jsp?workflowid=14862";
const _availabilityUrl =
    "$_oaBaseUrl/formmode/tree/treebrowser/CustomTreeBrowserAjax.jsp";
const _reservationUrl = "$_oaBaseUrl/workflow/request/RequestOperation.jsp";
const _userAgent =
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36";

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
  final _CookieJar _cookies = _CookieJar();

  bool _sessionReady = false;
  bool _metadataReady = false;
  bool _loading = false;
  Map<String, String> _venues = {};
  Map<String, String> _allVenues = {};
  Map<String, String> _timeSlots = {};

  OaGymService(this._auth, this._storage, {http.Client? client})
      : _client = client ?? http.Client();

  bool get loading => _loading;
  bool get sessionReady => _sessionReady;
  Map<String, String> get venues => Map.unmodifiable(_venues);
  Map<String, String> get allVenues => Map.unmodifiable(_allVenues);
  Map<String, String> get timeSlots => Map.unmodifiable(_timeSlots);

  void clearSession() {
    _cookies.clear();
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
      await _ensureOaSession();
      await _ensureMetadata();
    });
  }

  Future<List<OaAvailability>> checkAvailability({
    required Set<OaSport> sports,
    required String date,
    required int startSlot,
    required int endSlot,
  }) async {
    await _withLoading(() async {
      await _ensureOaSession();
    });

    final result = <OaAvailability>[];
    for (final sport in sports) {
      for (var slot = startSlot; slot <= endSlot; slot++) {
        final config = oaSportConfigs[sport]!;
        final available = await _queryAvailability(
          field32340: config.field32340,
          date: date,
          timeSlot: slot,
          parentName: config.parentName,
          prefix: config.courtNamePrefix,
          suffix: config.courtNameSuffix,
        );
        result.add(
          OaAvailability(
            sport: sport,
            date: date,
            timeSlot: slot,
            availableCourts: available,
            totalCourts: config.courtCount,
          ),
        );
      }
    }
    return result;
  }

  Future<OaBookingResult> bookCourt({
    required OaSport sport,
    required String date,
    required int timeSlot,
    required int courtNumber,
    required int playersCount,
  }) async {
    final session = _requireSession();
    await _withLoading(_ensureOaSession);

    final config = oaSportConfigs[sport]!;
    if (courtNumber < 1 || courtNumber > config.courtCount) {
      throw OaGymException("场地编号必须在 1-${config.courtCount} 之间");
    }

    final profile = bookingProfile();
    final studentId =
        session.studentId.isNotEmpty ? session.studentId : session.userId;
    final userName = profile.name.isNotEmpty ? profile.name : session.userName;
    final phone =
        profile.phone.isNotEmpty ? profile.phone : session.phoneNumber;
    final email = profile.email;
    if (userName.isEmpty || phone.isEmpty) {
      throw OaGymException("请先在「个人信息」里补全姓名和手机号");
    }

    final slot = oaTimeSlots.firstWhere((item) => item.id == timeSlot);
    final today = _formatDate(DateTime.now());
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final loginId =
        _cookies.get("oa.shanghaitech.edu.cn", "loginidweaver") ?? "16293";
    final realCourtId =
        sport == OaSport.pickleball ? 43 : config.courtOffset + courtNumber;

    final form = <String, String>{
      "requestname": "学生和教工场馆借用申请-$userName-$today",
      "field31876": loginId,
      "field31877": "885",
      "field34283": studentId,
      "field31879": phone,
      "field31880": email,
      "field32340": config.field32340,
      "field31901": date,
      "field31902": "$timeSlot",
      "field31883": "63_$realCourtId",
      "field31884": "$playersCount",
      "field31885": "0",
      "field31888": userName,
      "field31889": phone,
      "field31892": "1",
      "field31904": slot.start,
      "field31905": slot.end,
      "field31878": today,
      "mainId": "41",
      "subId": "11482",
      "secId": "11483",
      "workflowid": "14862",
      "workflowtype": "61",
      "nodeid": "16385",
      "nodetype": "0",
      "src": "submit",
      "iscreate": "1",
      "formid": "-248",
      "isbill": "1",
      "needcheck": ",requestname,field31883,field31884,field31885,field31888,"
          "field31889,field31892,field31901,field31902,field32340,,,,",
      "requestid": "-1",
      "rand": timestamp,
      "needwfback": "1",
      "f_weaver_belongto_userid": "null",
      "f_weaver_belongto_usertype": "null",
      "${loginId}_14862_addrequest_submit_token": "${int.parse(timestamp) + 1}",
      "freeNode": "0",
      "freeDuty": "1",
    };

    final response = await _post(
      Uri.parse(_reservationUrl),
      body: form,
      headers: const {
        "Content-Type": "application/x-www-form-urlencoded",
        "Referer": "$_oaBaseUrl/",
      },
    );
    final ok = response.body.contains(
      "wfforward('/workflow/request/WorkflowDirection.jsp?",
    );
    final courtLabel = sport == OaSport.pickleball
        ? "匹克球1号场地"
        : "${config.courtNamePrefix}$courtNumber${config.courtNameSuffix}";
    return OaBookingResult(
      success: ok,
      message: ok
          ? "${sport.label} $courtLabel ${slot.range} 预约成功"
          : "${sport.label} $courtLabel ${slot.range} 提交失败，请检查 OA 系统状态",
    );
  }

  Future<List<OaCourtSearchResult>> searchCourts({
    required String startDate,
    required String endDate,
    required Set<String> venueNames,
    required List<String> timeRanges,
  }) async {
    await _withLoading(() async {
      await _ensureOaSession();
      await _ensureMetadata();
    });

    final actualVenues = _resolveSearchVenues(venueNames);
    if (actualVenues.isEmpty) {
      throw OaGymException("未找到可查询场地，请刷新数据后重试");
    }
    final actualTimes = timeRanges.contains("")
        ? <String>[""]
        : (timeRanges.isEmpty ? <String>[""] : timeRanges.toSet().toList());
    final results = <OaCourtSearchResult>[];
    final errors = <String>[];

    for (final venue in actualVenues) {
      for (final range in actualTimes) {
        try {
          final rows = await _searchSingleVenue(
            startDate: startDate,
            endDate: endDate,
            venueName: venue,
            timeRange: range.isEmpty ? null : range,
          );
          results.add(
            OaCourtSearchResult(
              venue: venue,
              timeRange: range,
              rows: rows,
            ),
          );
        } catch (e) {
          // Match the original app's behavior: one failed venue/time does not
          // discard the whole query.
          errors.add('${range.isEmpty ? '全部时间' : range} $venue: $e');
        }
      }
    }
    if (results.isEmpty && errors.isNotEmpty) {
      throw OaGymException('查询失败：${errors.take(3).join('；')}');
    }
    return results;
  }

  Set<String> _resolveSearchVenues(Set<String> venueNames) {
    final requested = venueNames.isEmpty ? {"所有场地"} : venueNames;
    final resolved = <String>{};
    for (final venue in requested) {
      if (venue == "所有场地") {
        resolved.addAll(
          _venues.keys.where((v) => !_isVenueGroup(v)),
        );
      } else if (venue == "室内羽毛球场") {
        resolved.addAll(
          _allVenues.keys
              .where((v) => v.contains("羽毛球") && _venues.containsKey(v)),
        );
      } else if (venue == "室内乒乓球场") {
        resolved.addAll(
          _allVenues.keys
              .where((v) => v.contains("乒乓球") && _venues.containsKey(v)),
        );
      } else if (venue == "网球场") {
        resolved.addAll(
          _allVenues.keys
              .where((v) => v.contains("网球") && _venues.containsKey(v)),
        );
      } else if (venue == "匹克球场") {
        resolved.addAll(
          _allVenues.keys
              .where((v) => v.contains("匹克球") && _venues.containsKey(v)),
        );
      } else if (_venues.containsKey(venue)) {
        resolved.add(venue);
      }
    }
    return resolved;
  }

  bool _isVenueGroup(String venue) => const {
        "所有场地",
        "室内羽毛球场",
        "室内乒乓球场",
        "网球场",
        "匹克球场",
      }.contains(venue);

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

  UserSession _requireSession() {
    final session = _auth.session;
    if (session == null) {
      throw OaGymException("请先登录 TechPie 主账号");
    }
    if (session.tgc.isEmpty) {
      throw OaGymException("当前登录态缺少 CASTGC，请重新登录或使用短信登录刷新会话");
    }
    return session;
  }

  Future<void> _ensureOaSession() async {
    if (_sessionReady &&
        _cookies.has("oa.shanghaitech.edu.cn", "shkjdx_session")) {
      return;
    }

    final session = _requireSession();
    _cookies.clear();
    _seedIdsCookies(session);

    final serviceUrl = Uri.parse(
      "$_idsBaseUrl/authserver/login?service=${Uri.encodeComponent(_oaTargetUrl)}",
    );
    await _get(serviceUrl);

    if (!_cookies.has("oa.shanghaitech.edu.cn", "shkjdx_session")) {
      throw OaGymException("未能获取 OA 会话，请重新登录 TechPie 后再试");
    }
    _sessionReady = true;
  }

  void _seedIdsCookies(UserSession session) {
    if (session.tgc.isNotEmpty) {
      _cookies.set("ids.shanghaitech.edu.cn", "CASTGC", session.tgc);
    }
    for (final entry in _parseCookieHeader(session.cookies).entries) {
      _cookies.set("ids.shanghaitech.edu.cn", entry.key, entry.value);
    }
  }

  Future<void> _ensureMetadata() async {
    if (_metadataReady) return;

    final ts = DateTime.now().millisecondsSinceEpoch;
    final timeUrl = Uri.parse(
      "$_oaBaseUrl/formmode/browser/CommonSingleBrowser.jsp"
      "?customid=7102&browsertype=browser.sysjd&sqlwhere=&workflowid=-1"
      "&currenttime=$ts&sqlcondition=",
    );
    final venueUrl = Uri.parse(
      "$_oaBaseUrl/formmode/browser/CommonSingleBrowser.jsp"
      "?customid=7101&browsertype=browser.tygcg&sqlwhere=&workflowid=-1"
      "&currenttime=$ts&sqlcondition=",
    );
    const metadataHeaders = {
      "Referer": "$_oaBaseUrl/",
      "Origin": _oaBaseUrl,
    };

    final timeTable = _extractTableString(
      (await _get(timeUrl, headers: metadataHeaders)).body,
    );
    final venueTable = _extractTableString(
      (await _get(venueUrl, headers: metadataHeaders)).body,
    );
    if (timeTable.isEmpty || venueTable.isEmpty) {
      final missing = [
        if (timeTable.isEmpty) "时间段表",
        if (venueTable.isEmpty) "场地表",
      ].join("、");
      throw OaGymException("加载 OA 场馆数据失败：未获取到$missing，请重新登录后重试");
    }

    final nextTimeSlots = <String, String>{};
    final nextAllVenues = <String, String>{};

    final timeRows = await _fetchXmlData(timeTable);
    final venueRows = await _fetchXmlData(venueTable);
    for (final row in timeRows) {
      if (row.length > 2) {
        final id = row[0];
        final name = _normalizeTimeRange(_cleanHtml(row[2]));
        if (id.isNotEmpty && name.isNotEmpty) nextTimeSlots[name] = id;
      }
    }
    for (final row in venueRows) {
      if (row.length > 2) {
        final id = row[0];
        final name = _cleanHtml(row[2]);
        if (id.isNotEmpty && name.isNotEmpty) nextAllVenues[name] = id;
      }
    }

    final nextVenues = _filterVenues(nextAllVenues);
    final concreteVenueCount =
        nextVenues.keys.where((v) => !_isVenueGroup(v)).length;
    if (nextTimeSlots.isEmpty || concreteVenueCount == 0) {
      throw OaGymException(
        "加载 OA 场馆数据失败：解析到 ${nextTimeSlots.length} 个时间段、"
        "${nextAllVenues.length} 个场地、$concreteVenueCount 个可查询场地，请稍后重试",
      );
    }

    _timeSlots = nextTimeSlots;
    _allVenues = nextAllVenues;
    _venues = nextVenues;
    _metadataReady = true;
  }

  Map<String, String> _filterVenues(Map<String, String> all) {
    final result = <String, String>{
      "所有场地": "all",
      "室内羽毛球场": "badminton_group",
      "室内乒乓球场": "pingpong_group",
      "网球场": "tennis_group",
      "匹克球场": "pickleball_group",
    };
    final used = <String>{};

    void addMatch(String canonical, bool Function(String normalized) matches) {
      final actual = _findVenue(all, canonical, matches);
      if (actual == null || !used.add(actual)) return;
      result[actual] = all[actual]!;
    }

    for (var number = 1; number <= 6; number++) {
      addMatch(
        "羽毛球场地$number号",
        (name) => name.contains("羽毛球") && _venueNumberMatches(name, number),
      );
      addMatch(
        "乒乓球场$number号",
        (name) => name.contains("乒乓") && _venueNumberMatches(name, number),
      );
    }

    for (var number = 1; number <= 3; number++) {
      addMatch(
        "网球场$number号",
        (name) =>
            name.contains("网球") &&
            _venueNumberMatches(name, number) &&
            (number != 3 || !name.contains("多功能")),
      );
    }
    addMatch(
      "网球场3号（多功能）",
      (name) =>
          name.contains("网球") &&
          name.contains("多功能") &&
          _venueNumberMatches(name, 3),
    );
    addMatch(
      "匹克球1号场地",
      (name) => name.contains("匹克") && _venueNumberMatches(name, 1),
    );

    if (!result.keys.any((name) => !_isVenueGroup(name))) {
      for (final entry in all.entries) {
        final normalized = _normalizeVenueName(entry.key);
        if (normalized.contains("羽毛球") ||
            normalized.contains("乒乓") ||
            normalized.contains("网球") ||
            normalized.contains("匹克")) {
          result[entry.key] = entry.value;
        }
      }
    }
    return result;
  }

  String? _findVenue(
    Map<String, String> venues,
    String canonical,
    bool Function(String normalized) matches,
  ) {
    if (venues.containsKey(canonical)) return canonical;
    final target = _normalizeVenueName(canonical);
    for (final venue in venues.keys) {
      if (_normalizeVenueName(venue) == target) return venue;
    }
    for (final venue in venues.keys) {
      if (matches(_normalizeVenueName(venue))) return venue;
    }
    return null;
  }

  bool _venueNumberMatches(String normalized, int number) {
    final ascii = number.toString();
    final chinese = const {
      1: "一",
      2: "二",
      3: "三",
      4: "四",
      5: "五",
      6: "六",
    }[number];
    return normalized.contains("$ascii号") ||
        normalized.contains("场地$ascii") ||
        normalized.contains("第$ascii") ||
        (chinese != null &&
            (normalized.contains("$chinese号") ||
                normalized.contains("场地$chinese") ||
                normalized.contains("第$chinese")));
  }

  String _normalizeVenueName(String value) {
    final cleaned = _cleanHtml(value);
    final chars = <int>[];
    for (final rune in cleaned.runes) {
      if (rune >= 0xff10 && rune <= 0xff19) {
        chars.add(rune - 0xff10 + 0x30);
      } else {
        chars.add(rune);
      }
    }
    return String.fromCharCodes(chars)
        .replaceAll(RegExp(r"\s+"), "")
        .replaceAll("（", "(")
        .replaceAll("）", ")")
        .replaceAll("號", "号")
        .replaceAll("場", "场")
        .replaceAll("館", "馆")
        .toLowerCase();
  }

  Future<List<int>> _queryAvailability({
    required String field32340,
    required String date,
    required int timeSlot,
    required String parentName,
    required String prefix,
    required String suffix,
  }) async {
    final params = {
      "id": "63",
      "init": "false",
      "showtype": "1",
      "isselsub": "0",
      "isonlyleaf": "1",
      "dataconditionParam":
          "_sfn_31901_sfv_${date}_sfn_31902_sfv_${timeSlot}_sfn_32340_sfv_$field32340",
      "treerootnode": "",
      "selectedids": "",
      "time": DateTime.now().millisecondsSinceEpoch.toString(),
    };
    final url = Uri.parse(_availabilityUrl).replace(queryParameters: params);
    final headers = const {
      "Accept": "text/plain, */*; q=0.01",
      "Content-Type": "application/x-www-form-urlencoded",
      "X-Requested-With": "XMLHttpRequest",
      "Referer": "$_oaBaseUrl/wui/main.jsp?templateId=1",
    };

    final r1 = await _post(
      url,
      body: const {"pid": "63_1", "name": "体育馆"},
      headers: headers,
    );
    final parents = jsonDecode(_stripBom(r1.body)) as List<dynamic>;
    Map<String, dynamic>? target;
    for (final item in parents.cast<Map<String, dynamic>>()) {
      if (item["name"] == parentName) {
        target = item;
        break;
      }
    }
    if (target == null || target["isParent"] == "false") return const [];

    final r2 = await _post(
      url,
      body: {"pid": target["id"] as String? ?? "", "name": parentName},
      headers: headers,
    );
    final courts = jsonDecode(_stripBom(r2.body)) as List<dynamic>;
    final available = <int>[];
    for (final item in courts.cast<Map<String, dynamic>>()) {
      final name = item["name"] as String? ?? "";
      if (!name.startsWith(prefix)) continue;
      final number =
          int.tryParse(name.replaceFirst(prefix, "").replaceAll(suffix, ""));
      if (number != null) available.add(number);
    }
    available.sort();
    if (field32340 == "11") {
      return available.where((n) => n == 1).toList();
    }
    return available;
  }

  Future<List<List<String>>> _searchSingleVenue({
    required String startDate,
    required String endDate,
    required String venueName,
    String? timeRange,
  }) async {
    final venueId = _venues[venueName];
    if (venueId == null) throw OaGymException("找不到场地: $venueName");

    // Keep duplicated form keys by encoding from ordered pairs directly.
    final pairs = <MapEntry<String, String>>[
      const MapEntry("customid", "16201"),
      const MapEntry("viewtype", "0"),
      const MapEntry("issimple", "true"),
      const MapEntry("formmodeid", "11684"),
      const MapEntry("formid", "-247"),
      const MapEntry("template", "-1"),
      const MapEntry("check_con", "31869"),
      const MapEntry("con31869_htmltype", "3"),
      const MapEntry("con31869_type", "161"),
      const MapEntry("con31869_colname", "sycd"),
      const MapEntry("con31869_viewtype", "0"),
      const MapEntry("con31869_opt", "1"),
      MapEntry("con31869_value", venueId),
      MapEntry("con31869_name", venueName),
      const MapEntry("check_con", "31870"),
      const MapEntry("con31870_htmltype", "3"),
      const MapEntry("con31870_type", "2"),
      const MapEntry("con31870_colname", "syrq"),
      const MapEntry("con31870_viewtype", "0"),
      const MapEntry("datetype_31870_opt", "6"),
      const MapEntry("con31870_opt", "2"),
      MapEntry("con31870_value", startDate),
      const MapEntry("con31870_opt1", "4"),
      MapEntry("con31870_value1", endDate),
      const MapEntry("tableMax", "20"),
    ];

    if (timeRange != null && timeRange.isNotEmpty) {
      final normalizedTimeRange = _normalizeTimeRange(timeRange);
      final timeId = _timeSlots[normalizedTimeRange];
      if (timeId == null) throw OaGymException("找不到时间段: $timeRange");
      pairs.addAll([
        const MapEntry("check_con", "31871"),
        const MapEntry("con31871_htmltype", "3"),
        const MapEntry("con31871_type", "161"),
        const MapEntry("con31871_colname", "sysjd"),
        const MapEntry("con31871_viewtype", "0"),
        const MapEntry("con31871_opt", "1"),
        MapEntry("con31871_value", timeId),
        MapEntry("con31871_name", normalizedTimeRange),
      ]);
    }
    final encodedBody = pairs
        .map(
          (e) =>
              "${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}",
        )
        .join("&");
    final response = await _postRaw(
      Uri.parse("$_oaBaseUrl/formmode/search/CustomSearchBySimpleIframe.jsp"
          "?customid=16201&mainid=0"),
      body: encodedBody,
      headers: const {
        "Content-Type": "application/x-www-form-urlencoded",
        "Referer": "$_oaBaseUrl/",
        "Origin": _oaBaseUrl,
      },
    );
    final tableString = _extractTableString(response.body);
    if (tableString.isEmpty) {
      throw OaGymException("查询失败，请检查 OA 登录状态");
    }
    return _fetchXmlData(tableString);
  }

  Future<List<List<String>>> _fetchXmlData(String tableString) async {
    if (tableString.isEmpty) return const [];
    final rows = <List<String>>[];
    for (var page = 0; page <= 20; page++) {
      final response = await _fetchXmlPage(
        tableString: tableString,
        page: page,
      );
      final body = response.body.trim();
      if (body.isEmpty) break;
      final pageRows = _parseXmlRows(body);
      if (pageRows.isEmpty) break;
      rows.addAll(pageRows);
      if (pageRows.length < 10) break;
    }
    return rows;
  }

  Future<http.Response> _fetchXmlPage({
    required String tableString,
    required int page,
  }) async {
    final url = Uri.parse(
      "$_oaBaseUrl/weaver/weaver.common.util.taglib.SplitPageXmlServlet",
    );
    final body = {
      "tableString": tableString,
      "pageIndex": "$page",
      "mode": "run",
    };
    final headers = const {
      "Referer": "$_oaBaseUrl/",
      "Origin": _oaBaseUrl,
    };

    final response = await _post(url, body: body, headers: headers);
    if (_parseXmlRows(response.body).isNotEmpty ||
        response.body.trim().isEmpty) {
      return response;
    }

    // The React app sends these as POST body fields. The older Python script
    // uses query params. Try both so TechPie tolerates either OA behavior.
    return _post(
      url.replace(queryParameters: body),
      body: const {},
      headers: headers,
    );
  }

  List<List<String>> _parseXmlRows(String xml) {
    final result = <List<String>>[];
    final rowPattern = RegExp(
      r"<row\b[^>]*>([\s\S]*?)<\/row>",
      multiLine: true,
      caseSensitive: false,
    );
    final colPattern = RegExp(
      r"<col\b([^>]*?)(?:\/>|>([\s\S]*?)<\/col>)",
      multiLine: true,
      caseSensitive: false,
    );
    for (final rowMatch in rowPattern.allMatches(xml)) {
      final rowBody = rowMatch.group(1) ?? "";
      final row = <String>[];
      for (final colMatch in colPattern.allMatches(rowBody)) {
        final attrs = colMatch.group(1) ?? "";
        final show = _attributeValue(attrs, "showvalue");
        row.add(_cleanHtml(show ?? colMatch.group(2) ?? ""));
      }
      if (row.isNotEmpty) result.add(row);
    }
    return result;
  }

  String? _attributeValue(String attrs, String name) {
    final pattern = RegExp(
      '$name\\s*=\\s*([\\\'"])(.*?)\\1',
      caseSensitive: false,
    );
    return pattern.firstMatch(attrs)?.group(2);
  }

  Future<http.Response> _get(
    Uri uri, {
    Map<String, String>? headers,
    bool followRedirects = true,
  }) async {
    final request = http.Request("GET", uri)
      ..followRedirects = followRedirects
      ..headers.addAll(_headersFor(uri, headers));
    return _send(request);
  }

  Future<http.Response> _post(
    Uri uri, {
    required Map<String, String> body,
    Map<String, String>? headers,
    bool followRedirects = true,
  }) {
    final encodedBody = body.entries
        .map(
          (e) =>
              "${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}",
        )
        .join("&");
    return _postRaw(
      uri,
      body: encodedBody,
      headers: headers,
      followRedirects: followRedirects,
    );
  }

  Future<http.Response> _postRaw(
    Uri uri, {
    required String body,
    Map<String, String>? headers,
    bool followRedirects = true,
  }) async {
    final request = http.Request("POST", uri)
      ..followRedirects = followRedirects
      ..headers.addAll(_headersFor(uri, headers))
      ..body = body;
    request.headers.putIfAbsent(
      "Content-Type",
      () => "application/x-www-form-urlencoded; charset=UTF-8",
    );
    return _send(request);
  }

  Map<String, String> _headersFor(Uri uri, Map<String, String>? extra) {
    final headers = <String, String>{
      "User-Agent": _userAgent,
      ...?extra,
    };
    final cookie = _cookies.headerFor(uri.host);
    if (cookie.isNotEmpty) headers["Cookie"] = cookie;
    return headers;
  }

  Future<http.Response> _send(http.BaseRequest request) async {
    final shouldFollowRedirects = request.followRedirects;
    final original = request is http.Request ? request : null;
    if (original != null) {
      var current = _cloneRequest(original, followRedirects: false);
      for (var redirect = 0; redirect <= 10; redirect++) {
        final response = await _sendOnce(current);
        if (!shouldFollowRedirects || !_isRedirect(response.statusCode)) {
          return response;
        }
        final next = _location(response, current.url);
        if (next == null) return response;
        current = _redirectRequest(current, next, response.statusCode);
      }
      throw OaGymException("OA 登录跳转次数过多，请重新登录后重试");
    }
    return _sendOnce(request);
  }

  Future<http.Response> _sendOnce(http.BaseRequest request) async {
    final streamed = await _client.send(request).timeout(
          const Duration(seconds: 20),
        );
    final bytes = await streamed.stream.toBytes();
    final response = http.Response.bytes(
      bytes,
      streamed.statusCode,
      request: streamed.request,
      headers: _headersForResponseBody(streamed.headers),
      isRedirect: streamed.isRedirect,
      persistentConnection: streamed.persistentConnection,
      reasonPhrase: streamed.reasonPhrase,
    );
    _cookies.capture(request.url.host, response.headers);
    return response;
  }

  http.Request _cloneRequest(
    http.Request source, {
    required bool followRedirects,
  }) {
    final request = http.Request(source.method, source.url)
      ..followRedirects = followRedirects
      ..headers.addAll(source.headers)
      ..bodyBytes = source.bodyBytes;
    return request;
  }

  http.Request _redirectRequest(http.Request source, Uri next, int statusCode) {
    final switchToGet = source.method == "POST" &&
        (statusCode == 301 || statusCode == 302 || statusCode == 303);
    final method = switchToGet ? "GET" : source.method;
    final headers = Map<String, String>.from(source.headers)
      ..removeWhere(
        (key, _) =>
            key.toLowerCase() == "cookie" ||
            key.toLowerCase() == "content-length" ||
            (switchToGet && key.toLowerCase() == "content-type"),
      );
    final request = http.Request(method, next)
      ..followRedirects = false
      ..headers.addAll(_headersFor(next, headers));
    if (!switchToGet) request.bodyBytes = source.bodyBytes;
    return request;
  }

  bool _isRedirect(int statusCode) =>
      statusCode == 301 ||
      statusCode == 302 ||
      statusCode == 303 ||
      statusCode == 307 ||
      statusCode == 308;

  Map<String, String> _headersForResponseBody(Map<String, String> headers) {
    final result = Map<String, String>.from(headers);
    final contentType = headers.entries
            .where((entry) => entry.key.toLowerCase() == "content-type")
            .firstOrNull
            ?.value ??
        "";
    final hasCharset = RegExp(
      r"charset=([^;\s]+)",
      caseSensitive: false,
    ).hasMatch(contentType);
    result.removeWhere((key, _) => key.toLowerCase() == "content-type");
    result["content-type"] = hasCharset
        ? contentType
        : (contentType.isEmpty
            ? "text/plain; charset=utf-8"
            : "$contentType; charset=utf-8");
    return result;
  }

  Uri? _location(http.Response response, Uri base) {
    final raw = response.headers["location"];
    if (raw == null || raw.isEmpty) return null;
    return base.resolve(raw);
  }

  String _extractTableString(String text) {
    final patterns = [
      RegExp(
        r'''var\s+__tableStringKey__\s*=\s*['"]([0-9A-F]+)['"]''',
        caseSensitive: false,
      ),
      RegExp(
        r'''name=["']?tableString["']?\s+value=["']?([0-9A-F]+)["']?''',
        caseSensitive: false,
      ),
      RegExp(
        r'''tableString\s*=\s*["']?([0-9A-F]+)["']?''',
        caseSensitive: false,
      ),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null) return match.group(1) ?? "";
    }
    return "";
  }

  String _normalizeTimeRange(String value) => _cleanHtml(value)
      .replaceAll("–", "-")
      .replaceAll("—", "-")
      .replaceAll("－", "-")
      .replaceAll(RegExp(r"\s+"), "");

  String _cleanHtml(String value) {
    final decoded = _decodeEntities(value)
        .replaceAll("<![CDATA[", "")
        .replaceAll("]]>", "")
        .replaceAll(RegExp(r"<[^>]+>"), "");
    return _decodeEntities(decoded).replaceAll(RegExp(r"\s+"), " ").trim();
  }

  String _decodeEntities(String value) => value
      .replaceAll("&nbsp;", " ")
      .replaceAll("&amp;", "&")
      .replaceAll("&lt;", "<")
      .replaceAll("&gt;", ">")
      .replaceAll("&quot;", '"')
      .replaceAll("&apos;", "'")
      .replaceAll("&#39;", "'")
      .replaceAllMapped(
        RegExp(r"&#x([0-9a-fA-F]+);"),
        (match) => String.fromCharCode(int.parse(match.group(1)!, radix: 16)),
      )
      .replaceAllMapped(
        RegExp(r"&#(\d+);"),
        (match) => String.fromCharCode(int.parse(match.group(1)!)),
      );

  String _stripBom(String value) => value.replaceFirst("\ufeff", "");

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  Map<String, String> _parseCookieHeader(String header) {
    final result = <String, String>{};
    for (final part in header.split(";")) {
      final idx = part.indexOf("=");
      if (idx <= 0) continue;
      final key = part.substring(0, idx).trim();
      final value = part.substring(idx + 1).trim();
      if (key.isNotEmpty && value.isNotEmpty) result[key] = value;
    }
    return result;
  }
}

class _CookieJar {
  final Map<String, Map<String, String>> _values = {};

  void clear() => _values.clear();

  void set(String domain, String key, String value) {
    _values.putIfAbsent(domain, () => {})[key] = value;
  }

  String? get(String domain, String key) => _values[domain]?[key];

  bool has(String domain, String key) =>
      _values[domain]?.containsKey(key) ?? false;

  String headerFor(String domain) {
    final cookies = <String, String>{};
    for (final entry in _values.entries) {
      if (domain == entry.key || domain.endsWith(".${entry.key}")) {
        cookies.addAll(entry.value);
      }
    }
    return cookies.entries.map((e) => "${e.key}=${e.value}").join("; ");
  }

  void capture(String domain, Map<String, String> headers) {
    final raw = headers["set-cookie"];
    if (raw == null || raw.isEmpty) return;
    final parts = raw.split(RegExp(r",\s*(?=[A-Za-z_][A-Za-z0-9_-]*=)"));
    for (final part in parts) {
      final match = RegExp(r"^\s*([^=\s]+)=([^;]*)").firstMatch(part);
      if (match == null) continue;
      final key = match.group(1)?.trim() ?? "";
      final value = match.group(2)?.trim() ?? "";
      if (key.isEmpty || key == "Max-Age") continue;
      set(domain, key, value);
    }
  }
}
