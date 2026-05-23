import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:techpie/models/oa_gym.dart';
import 'package:techpie/models/user_session.dart';
import 'package:techpie/services/auth_service.dart';
import 'package:techpie/services/debug_logger.dart';
import 'package:techpie/services/http_client.dart';
import 'package:techpie/services/oa_gym_service.dart';
import 'package:techpie/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses TechPie CASTGC to establish OA session and query availability',
      () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);
    await storage.saveSession(
      UserSession(
        sessionToken: 'session',
        tgc: 'tgc-value',
        userId: 'user',
        userName: 'User',
        schoolName: 'School',
        tenantId: 'tenant',
        phoneNumber: '13800000000',
        cookies: 'happyVoyage=happy',
        studentId: '20240001',
        createdAt: DateTime.utc(2026),
      ),
    );
    final auth = AuthService(storage, LoggingHttpClient(DebugLogger()));
    await auth.loadSession();

    final client = _FakeClient((request) async {
      if (request.url.host == 'ids.shanghaitech.edu.cn') {
        expect(request.headers['Cookie'], contains('CASTGC=tgc-value'));
        return http.Response(
          '',
          302,
          headers: {
            'location': 'https://oa.shanghaitech.edu.cn/sso?ticket=ST-123',
          },
        );
      }
      if (request.url.host == 'oa.shanghaitech.edu.cn' &&
          request.url.path == '/sso') {
        return http.Response(
          '',
          302,
          headers: {
            'set-cookie':
                'shkjdx_session=session-value; Path=/, loginidweaver=16293; Path=/',
            'location':
                'https://oa.shanghaitech.edu.cn/workflow/request/AddRequest.jsp',
          },
        );
      }
      if (request.url.path.endsWith('AddRequest.jsp')) {
        return http.Response('ok', 200);
      }
      if (request.url.path.endsWith('CustomTreeBrowserAjax.jsp')) {
        final body = await request.finalize().bytesToString();
        expect(request.headers['Cookie'],
            contains('shkjdx_session=session-value'));
        if (body.contains('pid=63_1')) {
          return _utf8Response(
            '[{"name":"室内羽毛球场","id":"63_4","isParent":"true"}]',
            200,
          );
        }
        return _utf8Response(
          '[{"name":"羽毛球场地1号"},{"name":"羽毛球场地3号"}]',
          200,
        );
      }
      return http.Response('not found', 404);
    });

    final service = OaGymService(auth, storage, client: client);
    final result = await service.checkAvailability(
      sports: {OaSport.badminton},
      date: '2026-05-23',
      startSlot: 8,
      endSlot: 8,
    );

    expect(result, hasLength(1));
    expect(result.single.availableCourts, [1, 3]);
  });

  test('searches courts with metadata and posts split-page params in body',
      () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);
    await storage.saveSession(
      UserSession(
        sessionToken: 'session',
        tgc: 'tgc-value',
        userId: 'user',
        userName: 'User',
        schoolName: 'School',
        tenantId: 'tenant',
        phoneNumber: '13800000000',
        cookies: '',
        studentId: '20240001',
        createdAt: DateTime.utc(2026),
      ),
    );
    final auth = AuthService(storage, LoggingHttpClient(DebugLogger()));
    await auth.loadSession();

    final splitPageBodies = <String>[];
    final requestCookies = <String>[];
    final client = _FakeClient((request) async {
      final body = await request.finalize().bytesToString();
      requestCookies.add(request.headers['Cookie'] ?? '');
      if (request.url.host == 'ids.shanghaitech.edu.cn') {
        return http.Response(
          '',
          302,
          headers: {
            'location': 'https://oa.shanghaitech.edu.cn/sso?ticket=ST-123',
          },
        );
      }
      if (request.url.host == 'oa.shanghaitech.edu.cn' &&
          request.url.path == '/sso') {
        return http.Response(
          '',
          302,
          headers: {
            'set-cookie':
                'shkjdx_session=session-value; Path=/, weaver-extra=extra-value; Path=/',
            'location':
                'https://oa.shanghaitech.edu.cn/workflow/request/AddRequest.jsp',
          },
        );
      }
      if (request.url.path.endsWith('AddRequest.jsp')) {
        return http.Response('ok', 200);
      }
      if (request.url.path.endsWith('CommonSingleBrowser.jsp')) {
        expect(request.headers['Referer'], 'https://oa.shanghaitech.edu.cn/');
        expect(request.headers['Origin'], 'https://oa.shanghaitech.edu.cn');
        expect(
          request.headers['Cookie'],
          contains('weaver-extra=extra-value'),
        );
        if (request.url.queryParameters['customid'] == '7102') {
          return _utf8Response('var __tableStringKey__ = "A11";', 200);
        }
        return _utf8Response('var __tableStringKey__ = "B22";', 200);
      }
      if (request.url.path.endsWith('SplitPageXmlServlet')) {
        expect(request.url.queryParameters, isEmpty);
        splitPageBodies.add(body);
        if (body.contains('tableString=A11')) {
          return _utf8NoCharsetResponse(
            '<root><row><col showvalue="8"/><col/><col showvalue="18:00-19:00"/></row></root>',
            200,
          );
        }
        if (body.contains('tableString=B22')) {
          return _utf8NoCharsetResponse(
            '<root><row><col showvalue="13"/><col/><col showvalue="&#x7FBD;&#x6BDB;&#x7403;&#x573A;&#x5730; &#xFF11; &#x53F7;&#xFF08;&#x4E1C;&#x9986;&#xFF09;"/></row></root>',
            200,
          );
        }
        if (body.contains('tableString=C33')) {
          return _utf8NoCharsetResponse(
            '<root><row>'
            '<col showvalue="1"/><col/><col showvalue="2026-05-23"/>'
            '<col/><col/><col/><col showvalue="已通过"/>'
            '<col showvalue="User"/><col/><col showvalue="2026-05-24"/>'
            '</row></root>',
            200,
          );
        }
      }
      if (request.url.path.endsWith('CustomSearchBySimpleIframe.jsp')) {
        expect(body, contains('con31869_name=%E7%BE%BD%E6%AF%9B'));
        expect(body, contains('con31871_value=8'));
        return _utf8Response('var __tableStringKey__ = "C33";', 200);
      }
      return http.Response('not found', 404);
    });

    final service = OaGymService(auth, storage, client: client);
    final result = await service.searchCourts(
      startDate: '2026-05-23',
      endDate: '2026-05-23',
      venueNames: {'室内羽毛球场'},
      timeRanges: const ['18:00-19:00'],
    );

    expect(result, hasLength(1));
    expect(result.single.venue, '羽毛球场地 １ 号（东馆）');
    expect(result.single.rows.single[6], '已通过');
    expect(splitPageBodies, contains(contains('tableString=C33')));
    expect(
      requestCookies,
      contains(contains('weaver-extra=extra-value')),
    );
  });
}

http.Response _utf8Response(String body, int statusCode) => http.Response.bytes(
      utf8.encode(body),
      statusCode,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.Response _utf8NoCharsetResponse(String body, int statusCode) =>
    http.Response.bytes(
      utf8.encode(body),
      statusCode,
      headers: {'content-type': 'text/xml'},
    );

class _FakeClient extends http.BaseClient {
  _FakeClient(this._handler);

  final Future<http.Response> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}
