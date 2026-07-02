import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../core/http.dart';
import '../domain/models.dart';
import 'app_services.dart';

Handler createHandler(AppServices services) {
  final router = Router()
    ..get('/health', (Request request) => jsonResponse({'status': 'ok'}))
    ..post('/auth/login', (request) => _login(request, services))
    ..get('/me', (request) => _me(request, services))
    ..get(
      '/attendance/status',
      (request) => _attendanceStatus(request, services),
    )
    ..post('/attendance/scan', (request) => _scan(request, services))
    ..get('/admin/users', (request) => _adminUsers(request, services))
    ..get(
      '/admin/users/<id>/events',
      (request, String id) => _adminUserEvents(request, services, id),
    )
    ..get(
      '/admin/reports/attendance',
      (request) => _adminReport(request, services),
    )
    ..post(
      '/migration/legacy-mongo',
      (request) => _migration(request, services),
    );

  return Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(apiMiddleware())
      .addHandler(router.call);
}

Future<Response> _login(Request request, AppServices services) async {
  final body = await readJson(request);
  final result = await services.auth.login(
    username: (body['username'] ?? '').toString(),
    password: (body['password'] ?? '').toString(),
    platform: (body['platform'] ?? 'unknown').toString(),
    deviceInfo: (body['deviceInfo'] as Map?)?.cast<String, dynamic>(),
  );
  return jsonResponse(result.toJson());
}

Future<Response> _me(Request request, AppServices services) async {
  final user = await _requireUser(request, services);
  return jsonResponse(user.toPublicJson());
}

Future<Response> _attendanceStatus(
  Request request,
  AppServices services,
) async {
  final user = await _requireUser(request, services);
  return jsonResponse(await services.attendance.status(user));
}

Future<Response> _scan(Request request, AppServices services) async {
  final user = await _requireUser(request, services);
  final body = await readJson(request);
  final location = (body['location'] as Map?)?.cast<String, dynamic>() ?? {};
  final response = await services.attendance.scan(
    user: user,
    qrPayload: (body['qrPayload'] ?? '').toString(),
    latitude: _toDouble(location['latitude']),
    longitude: _toDouble(location['longitude']),
    accuracy: _toDouble(location['accuracy']),
  );
  return jsonResponse(response);
}

Future<Response> _adminUsers(Request request, AppServices services) async {
  final user = await _requireUser(request, services);
  services.admin.requireAdmin(user);
  return jsonResponse(await services.admin.listUsers());
}

Future<Response> _adminUserEvents(
  Request request,
  AppServices services,
  String id,
) async {
  final user = await _requireUser(request, services);
  services.admin.requireAdmin(user);
  final range = _rangeFromQuery(request);
  return jsonResponse(
    await services.admin.listEvents(
      userId: id,
      start: range.start,
      end: range.end,
    ),
  );
}

Future<Response> _adminReport(Request request, AppServices services) async {
  final user = await _requireUser(request, services);
  services.admin.requireAdmin(user);
  final range = _rangeFromQuery(request);
  final userId = request.url.queryParameters['userId'];
  return jsonResponse(
    await services.admin.report(
      userId: userId,
      start: range.start,
      end: range.end,
    ),
  );
}

Future<Response> _migration(Request request, AppServices services) async {
  final migrationKey = request.headers['x-migration-key'];
  if (migrationKey != services.config.migrationKey) {
    final user = await _requireUser(request, services);
    services.admin.requireAdmin(user);
  }
  final body = await readJson(request);
  final users = (body['legacyUsers'] as List? ?? [])
      .whereType<Map>()
      .map((value) => value.cast<String, dynamic>())
      .toList();
  final devices = (body['legacyDevices'] as List? ?? [])
      .whereType<Map>()
      .map((value) => value.cast<String, dynamic>())
      .toList();
  final summary = await services.migration.migrateSnapshot(
    legacyUsers: users,
    legacyDevices: devices,
  );
  return jsonResponse(summary.toJson());
}

Future<AppUser> _requireUser(Request request, AppServices services) async {
  final header = request.headers['authorization'] ?? '';
  if (!header.toLowerCase().startsWith('bearer ')) {
    throw ApiException(401, 'Bearer token required.');
  }
  return services.auth.userFromToken(header.substring(7).trim());
}

({DateTime? start, DateTime? end}) _rangeFromQuery(Request request) {
  final query = request.url.queryParameters;
  final start = DateTime.tryParse(query['startDate'] ?? '');
  final rawEnd = DateTime.tryParse(query['endDate'] ?? '');
  final end = rawEnd == null
      ? null
      : DateTime(rawEnd.year, rawEnd.month, rawEnd.day, 23, 59, 59).toUtc();
  return (start: start?.toUtc(), end: end);
}

double _toDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
