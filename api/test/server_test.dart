import 'dart:convert';

import 'package:moper_complex_api/config/app_config.dart';
import 'package:moper_complex_api/core/security.dart';
import 'package:moper_complex_api/domain/models.dart';
import 'package:moper_complex_api/repositories/in_memory_repositories.dart';
import 'package:moper_complex_api/repositories/repositories.dart';
import 'package:moper_complex_api/server/app_services.dart';
import 'package:moper_complex_api/server/router.dart';
import 'package:moper_complex_api/services/demo_seed.dart';
import 'package:moper_complex_api/services/id_generator.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  late _Harness harness;

  setUp(() async {
    harness = await _Harness.create();
  });

  test('login succeeds with demo employee credentials', () async {
    final response = await harness.post('/auth/login', {
      'username': demoEmployeeUsername,
      'password': demoPassword,
    });

    expect(response.statusCode, 200);
    final data = await _data(response);
    expect(data['token'], isA<String>());
    expect(data['user']['role'], 'employee');
  });

  test('inactive users cannot log in', () async {
    await harness.repositories.users.upsertUser(
      AppUser(
        id: newId(),
        username: 'inactive',
        firstName: 'Inactive',
        lastName: 'User',
        passwordHash: harness.passwordHasher.hash('secret'),
        role: UserRole.employee,
        active: false,
        currentStatus: WorkStatus.off,
      ),
    );

    final response = await harness.post('/auth/login', {
      'username': 'inactive',
      'password': 'secret',
    });

    expect(response.statusCode, 401);
  });

  test('admin endpoints reject employee tokens', () async {
    final token = await harness.login(demoEmployeeUsername);
    final response = await harness.get('/admin/users', token: token);

    expect(response.statusCode, 403);
  });

  test('scan rejects invalid QR token', () async {
    final token = await harness.login(demoEmployeeUsername);
    final response = await harness.post('/attendance/scan', {
      'qrPayload': 'bad-token',
      'location': {
        'latitude': harness.config.defaultLatitude,
        'longitude': harness.config.defaultLongitude,
        'accuracy': 8,
      },
    }, token: token);

    expect(response.statusCode, 400);
  });

  test('scan rejects locations outside the geofence', () async {
    final token = await harness.login(demoEmployeeUsername);
    final response = await harness.post('/attendance/scan', {
      'qrPayload': harness.config.defaultQrToken,
      'location': {'latitude': 0, 'longitude': 0, 'accuracy': 8},
    }, token: token);

    expect(response.statusCode, 422);
  });

  test('valid scan toggles check-in and check-out', () async {
    final token = await harness.login(demoEmployeeUsername);

    final first = await harness.scan(token);
    expect(first.statusCode, 200);
    expect((await _data(first))['currentStatus'], 'working');

    final second = await harness.scan(token);
    expect(second.statusCode, 200);
    expect((await _data(second))['currentStatus'], 'off');

    final adminToken = await harness.login(demoAdminUsername);
    final users = await _data(
      await harness.get('/admin/users', token: adminToken),
    );
    final employee = (users as List).cast<Map<String, dynamic>>().firstWhere(
      (user) => user['username'] == demoEmployeeUsername,
    );
    final events = await _data(
      await harness.get(
        '/admin/users/${employee['id']}/events',
        token: adminToken,
      ),
    );
    expect(events, hasLength(2));
  });

  test('legacy migration does not duplicate already migrated events', () async {
    final legacyUsers = [
      {
        '_id': 'legacy-user-1',
        'uname': 'legacy.personel',
        'upassword': 'legacy123',
        'fName': 'Legacy',
        'lName': 'Personel',
        'isActive': true,
        'state': 'Çalışılmıyor',
        'logs': [
          {
            'date': '2026-07-01',
            'logs': [
              {
                'time': '2026-07-01T08:15:00.000Z',
                'Lat': harness.config.defaultLatitude,
                'Lng': harness.config.defaultLongitude,
                'state': 'Started',
              },
            ],
          },
        ],
      },
    ];

    final first = await harness.services.migration.migrateSnapshot(
      legacyUsers: legacyUsers,
      legacyDevices: const [],
    );
    final second = await harness.services.migration.migrateSnapshot(
      legacyUsers: legacyUsers,
      legacyDevices: const [],
    );

    expect(first.eventsCreated, 1);
    expect(second.eventsCreated, 0);
  });
}

class _Harness {
  _Harness({
    required this.config,
    required this.repositories,
    required this.services,
    required this.passwordHasher,
    required Handler handler,
  }) : _handler = handler;

  final AppConfig config;
  final MoperRepositories repositories;
  final AppServices services;
  final PasswordHasher passwordHasher;
  final Handler _handler;

  static Future<_Harness> create() async {
    final config = AppConfig(
      port: 8080,
      mongoUri: '',
      jwtSecret: 'test-secret',
      migrationKey: 'test-migration',
      defaultQrToken: 'TEST_QR',
      defaultWorkplaceName: 'Test HQ',
      defaultLatitude: 41,
      defaultLongitude: 29,
      defaultRadiusMeters: 200,
      useMemoryStore: true,
    );
    final repositories = MoperRepositories(
      users: InMemoryUserRepository(),
      workplaces: InMemoryWorkplaceRepository(),
      attendance: InMemoryAttendanceRepository(),
      deviceSessions: InMemoryDeviceSessionRepository(),
    );
    final passwordHasher = PasswordHasher(iterations: 1);
    final tokenHasher = TokenHasher();
    await seedDemoData(
      config: config,
      repositories: repositories,
      passwordHasher: passwordHasher,
      tokenHasher: tokenHasher,
    );
    final services = AppServices.create(
      config: config,
      repositories: repositories,
      passwordHasher: passwordHasher,
      tokenHasher: tokenHasher,
    );
    return _Harness(
      config: config,
      repositories: repositories,
      services: services,
      passwordHasher: passwordHasher,
      handler: createHandler(services),
    );
  }

  Future<String> login(String username) async {
    final response = await post('/auth/login', {
      'username': username,
      'password': demoPassword,
    });
    return (await _data(response))['token'] as String;
  }

  Future<Response> scan(String token) {
    return post('/attendance/scan', {
      'qrPayload': config.defaultQrToken,
      'location': {
        'latitude': config.defaultLatitude,
        'longitude': config.defaultLongitude,
        'accuracy': 8,
      },
    }, token: token);
  }

  Future<Response> get(String path, {String? token}) {
    return _request('GET', path, token: token);
  }

  Future<Response> post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) {
    return _request('POST', path, body: body, token: token);
  }

  Future<Response> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
  }) {
    return Future.value(
      _handler(
        Request(
          method,
          Uri.parse('http://localhost$path'),
          headers: {
            'content-type': 'application/json',
            if (token != null) 'authorization': 'Bearer $token',
          },
          body: body == null ? null : jsonEncode(body),
        ),
      ),
    );
  }
}

Future<dynamic> _data(Response response) async {
  final decoded =
      jsonDecode(await response.readAsString()) as Map<String, dynamic>;
  return decoded['data'];
}
