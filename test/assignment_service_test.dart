import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:techpie/models/third_party_account.dart';
import 'package:techpie/models/user_session.dart';
import 'package:techpie/services/assignment_service.dart';
import 'package:techpie/services/auth_service.dart';
import 'package:techpie/services/debug_logger.dart';
import 'package:techpie/services/http_client.dart';
import 'package:techpie/services/storage_service.dart';
import 'package:techpie/services/third_party_auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('failed platform fetch keeps that platform cache', () async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = StorageService(prefs);

    final oldBlackboard = _assignmentJson(
      id: 'blackboard-old',
      platform: 'blackboard',
      due: DateTime.utc(2026, 1, 10),
    );
    final oldGradescope = _assignmentJson(
      id: 'gradescope-old',
      platform: 'gradescope',
      due: DateTime.utc(2026, 1, 20),
    );
    await storage.saveCachedAssignments([oldBlackboard, oldGradescope]);
    await storage.saveSession(
      UserSession(
        sessionToken: 'session',
        tgc: 'tgc',
        userId: 'user',
        userName: 'User',
        schoolName: 'School',
        tenantId: 'tenant',
        phoneNumber: '',
        studentId: 'student',
        createdAt: DateTime.utc(2026),
      ),
    );
    await storage.saveThirdPartyAccount(
      ThirdPartyAccount(
        platform: ThirdPartyPlatform.gradescope,
        account: 'gradescope@example.com',
        token: 'gradescope-token',
        boundAt: DateTime.utc(2026),
      ),
    );

    final httpClient = _AssignmentHttpClient((url) {
      if (url.path.endsWith('/deadlines/blackboard')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              _assignmentJson(
                id: 'blackboard-new',
                platform: 'blackboard',
                due: DateTime.utc(2026, 1, 5),
              ),
            ],
          }),
          200,
        );
      }
      if (url.path.endsWith('/deadlines/gradescope')) {
        return http.Response(
          jsonEncode({'success': false, 'error': 'upstream failed'}),
          502,
        );
      }
      return http.Response('not found', 404);
    });
    final auth = AuthService(storage, httpClient);
    final tpAuth = ThirdPartyAuthService(storage, httpClient);
    await auth.loadSession();
    await tpAuth.initialize();

    final service = AssignmentService(storage, httpClient, auth, tpAuth)
      ..loadCached();

    await service.fetchAssignments();

    expect(
      service.assignments.map((a) => a.id),
      containsAll(['blackboard-new', 'gradescope-old']),
    );
    expect(
      service.assignments.map((a) => a.id),
      isNot(contains('blackboard-old')),
    );
    expect(service.platformErrors['gradescope'], 'upstream failed');

    final cachedIds =
        storage.loadCachedAssignments().map((a) => a['id']).toList();
    expect(cachedIds, containsAll(['blackboard-new', 'gradescope-old']));
    expect(cachedIds, isNot(contains('blackboard-old')));
  });
}

Map<String, dynamic> _assignmentJson({
  required String id,
  required String platform,
  required DateTime due,
}) =>
    {
      'id': id,
      'platform': platform,
      'title': id,
      'course': 'Course',
      'due': due.millisecondsSinceEpoch ~/ 1000,
    };

class _AssignmentHttpClient extends LoggingHttpClient {
  _AssignmentHttpClient(this._handler) : super(DebugLogger());

  final http.Response Function(Uri url) _handler;

  @override
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    Encoding? encoding,
    String? tag,
  }) async =>
      _handler(url);
}
