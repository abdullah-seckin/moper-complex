import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class ApiFailure implements Exception {
  ApiFailure(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? client})
    : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  final _demo = _DemoStore();

  bool isDemoToken(String token) => _demo.isDemoToken(token);

  Future<UserSession> login({
    required String username,
    required String password,
    required Map<String, dynamic> deviceInfo,
    required String platform,
  }) async {
    try {
      final data = await _post(
        '/auth/login',
        body: {
          'username': username,
          'password': password,
          'platform': platform,
          'deviceInfo': deviceInfo,
        },
      );
      return UserSession(
        token: data['token'] as String,
        user: AppUser.fromJson((data['user'] as Map).cast<String, dynamic>()),
      );
    } on http.ClientException {
      return _demo.login(username: username, password: password);
    }
  }

  Future<AppUser> me(String token) async {
    if (_demo.isDemoToken(token)) return _demo.me(token);
    final data = await _get('/me', token: token);
    return AppUser.fromJson((data as Map).cast<String, dynamic>());
  }

  Future<String> attendanceStatus(String token) async {
    if (_demo.isDemoToken(token)) return _demo.attendanceStatus(token);
    final data = await _get('/attendance/status', token: token);
    return (data['currentStatus'] ?? 'off') as String;
  }

  Future<Map<String, dynamic>> scanAttendance({
    required String token,
    required String qrPayload,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    if (_demo.isDemoToken(token)) {
      return _demo.scanAttendance(
        token: token,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
      );
    }
    final data = await _post(
      '/attendance/scan',
      token: token,
      body: {
        'qrPayload': qrPayload,
        'location': {
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
        },
      },
    );
    return (data as Map).cast<String, dynamic>();
  }

  Future<List<AppUser>> adminUsers(String token) async {
    if (_demo.isDemoToken(token)) return _demo.adminUsers(token);
    final data = await _get('/admin/users', token: token);
    return (data as List)
        .whereType<Map>()
        .map((item) => AppUser.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<List<AttendanceEvent>> userEvents({
    required String token,
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_demo.isDemoToken(token)) {
      return _demo.userEvents(
        token: token,
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );
    }
    final data = await _get(
      '/admin/users/$userId/events',
      token: token,
      query: _dateQuery(startDate, endDate),
    );
    return (data as List)
        .whereType<Map>()
        .map((item) => AttendanceEvent.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<List<ReportRow>> attendanceReport({
    required String token,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (_demo.isDemoToken(token)) {
      return _demo.attendanceReport(
        token: token,
        startDate: startDate,
        endDate: endDate,
      );
    }
    final data = await _get(
      '/admin/reports/attendance',
      token: token,
      query: _dateQuery(startDate, endDate),
    );
    return (data as List)
        .whereType<Map>()
        .map((item) => ReportRow.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<dynamic> _get(
    String path, {
    String? token,
    Map<String, String>? query,
  }) {
    return _send('GET', path, token: token, query: query);
  }

  Future<dynamic> _post(
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) {
    return _send('POST', path, token: token, body: body);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: query?.isEmpty == true ? null : query);
    final headers = {
      'content-type': 'application/json',
      if (token != null) 'authorization': 'Bearer $token',
    };
    final response = method == 'GET'
        ? await _client.get(uri, headers: headers)
        : await _client.post(
            uri,
            headers: headers,
            body: jsonEncode(body ?? {}),
          );
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = (decoded['error'] as Map?)?.cast<String, dynamic>();
      throw ApiFailure(
        (error?['message'] ?? 'Sunucu isteği tamamlanamadı').toString(),
        statusCode: response.statusCode,
      );
    }
    return decoded['data'];
  }

  Map<String, String> _dateQuery(DateTime? startDate, DateTime? endDate) {
    return {
      if (startDate != null) 'startDate': _dateOnly(startDate),
      if (endDate != null) 'endDate': _dateOnly(endDate),
    };
  }

  String _dateOnly(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  }
}

class _DemoStore {
  _DemoStore() {
    _seedEvents();
  }

  static const _password = 'moper123';
  static const _tokenPrefix = 'demo-token:';

  final Map<String, AppUser> _users = {
    'admin': AppUser(
      id: 'demo-admin',
      username: 'admin',
      firstName: 'IK',
      lastName: 'Yoneticisi',
      fullName: 'IK Yoneticisi',
      role: 'admin',
      active: true,
      currentStatus: 'off',
    ),
    'personel': AppUser(
      id: 'demo-personel',
      username: 'personel',
      firstName: 'Demo',
      lastName: 'Personel',
      fullName: 'Demo Personel',
      role: 'employee',
      active: true,
      currentStatus: 'off',
    ),
    'selin': AppUser(
      id: 'demo-selin',
      username: 'selin',
      firstName: 'Selin',
      lastName: 'Kara',
      fullName: 'Selin Kara',
      role: 'employee',
      active: true,
      currentStatus: 'working',
    ),
  };

  final List<AttendanceEvent> _events = [];

  bool isDemoToken(String token) => token.startsWith(_tokenPrefix);

  UserSession login({required String username, required String password}) {
    final normalized = username.trim().toLowerCase();
    final user = _users[normalized];
    if (user == null || password != _password) {
      throw ApiFailure('Demo kullanıcı adı veya şifre hatalı.');
    }
    return UserSession(token: '$_tokenPrefix$normalized', user: user);
  }

  AppUser me(String token) => _userFromToken(token);

  String attendanceStatus(String token) => _userFromToken(token).currentStatus;

  Map<String, dynamic> scanAttendance({
    required String token,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) {
    final user = _userFromToken(token);
    if (user.isAdmin) {
      throw ApiFailure('Admin kullanıcı için giriş/çıkış işlemi yok.');
    }

    final nextType = user.currentStatus == 'working' ? 'check_out' : 'check_in';
    final nextStatus = nextType == 'check_in' ? 'working' : 'off';
    final updatedUser = AppUser.fromJson({
      ...user.toJson(),
      'currentStatus': nextStatus,
    });
    _users[user.username] = updatedUser;

    final event = AttendanceEvent(
      id: 'demo-event-${DateTime.now().microsecondsSinceEpoch}',
      userId: user.id,
      type: nextType,
      serverTime: DateTime.now(),
      latitude: latitude == 0 ? 40.9862 : latitude,
      longitude: longitude == 0 ? 29.1244 : longitude,
      accuracy: accuracy == 0 ? 8 : accuracy,
      source: 'demo',
    );
    _events.insert(0, event);

    return {
      'currentStatus': nextStatus,
      'event': event.toJson(),
      'workplace': {
        'id': 'demo-workplace',
        'name': 'Moper Demo HQ',
        'latitude': 40.9862,
        'longitude': 29.1244,
        'radiusMeters': 250,
        'active': true,
      },
      'distanceMeters': 0,
    };
  }

  List<AppUser> adminUsers(String token) {
    _requireAdmin(token);
    return _users.values.toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  List<AttendanceEvent> userEvents({
    required String token,
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    _requireAdmin(token);
    return _filterEvents(
      userId: userId,
      startDate: startDate,
      endDate: endDate,
    );
  }

  List<ReportRow> attendanceReport({
    required String token,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    _requireAdmin(token);
    final usersById = {for (final user in _users.values) user.id: user};
    return _filterEvents(startDate: startDate, endDate: endDate).map((event) {
      final user = usersById[event.userId];
      return ReportRow(
        fullName: user?.fullName ?? event.userId,
        username: user?.username ?? '',
        type: event.type,
        serverTime: event.serverTime,
        latitude: event.latitude,
        longitude: event.longitude,
        accuracy: event.accuracy,
      );
    }).toList();
  }

  AppUser _userFromToken(String token) {
    if (!isDemoToken(token)) throw ApiFailure('Demo oturumu geçersiz.');
    final username = token.substring(_tokenPrefix.length);
    final user = _users[username];
    if (user == null) throw ApiFailure('Demo kullanıcı bulunamadı.');
    return user;
  }

  void _requireAdmin(String token) {
    final user = _userFromToken(token);
    if (!user.isAdmin) throw ApiFailure('Admin yetkisi gerekli.');
  }

  List<AttendanceEvent> _filterEvents({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return _events.where((event) {
      if (userId != null && event.userId != userId) return false;
      if (startDate != null &&
          event.serverTime.isBefore(_dayStart(startDate))) {
        return false;
      }
      if (endDate != null && event.serverTime.isAfter(_dayEnd(endDate))) {
        return false;
      }
      return true;
    }).toList()..sort((a, b) => b.serverTime.compareTo(a.serverTime));
  }

  DateTime _dayStart(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _dayEnd(DateTime value) {
    return DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
  }

  void _seedEvents() {
    final now = DateTime.now();
    _events.addAll([
      AttendanceEvent(
        id: 'demo-1',
        userId: 'demo-personel',
        type: 'check_in',
        serverTime: DateTime(now.year, now.month, now.day, 8, 42),
        latitude: 40.9862,
        longitude: 29.1244,
        accuracy: 7,
        source: 'demo',
      ),
      AttendanceEvent(
        id: 'demo-2',
        userId: 'demo-personel',
        type: 'check_out',
        serverTime: DateTime(now.year, now.month, now.day, 17, 18),
        latitude: 40.9861,
        longitude: 29.1246,
        accuracy: 9,
        source: 'demo',
      ),
      AttendanceEvent(
        id: 'demo-3',
        userId: 'demo-selin',
        type: 'check_in',
        serverTime: DateTime(now.year, now.month, now.day, 9, 03),
        latitude: 40.9863,
        longitude: 29.1245,
        accuracy: 6,
        source: 'demo',
      ),
      AttendanceEvent(
        id: 'demo-4',
        userId: 'demo-selin',
        type: 'check_in',
        serverTime: DateTime(now.year, now.month, now.day - 1, 8, 55),
        latitude: 40.9862,
        longitude: 29.1244,
        accuracy: 8,
        source: 'demo',
      ),
      AttendanceEvent(
        id: 'demo-5',
        userId: 'demo-selin',
        type: 'check_out',
        serverTime: DateTime(now.year, now.month, now.day - 1, 18, 04),
        latitude: 40.9862,
        longitude: 29.1243,
        accuracy: 8,
        source: 'demo',
      ),
    ]);
  }
}
