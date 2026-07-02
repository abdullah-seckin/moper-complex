class AppUser {
  AppUser({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.role,
    required this.active,
    required this.currentStatus,
  });

  final String id;
  final String username;
  final String firstName;
  final String lastName;
  final String fullName;
  final String role;
  final bool active;
  final String currentStatus;

  bool get isAdmin => role == 'admin';
  bool get isWorking => currentStatus == 'working';

  String get statusLabel =>
      isWorking ? 'Mesai devam ediyor' : 'Mesai bitirildi';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      username: json['username'] as String,
      firstName: (json['firstName'] ?? '') as String,
      lastName: (json['lastName'] ?? '') as String,
      fullName:
          (json['fullName'] ??
                  '${json['firstName'] ?? ''} ${json['lastName'] ?? ''}')
              .toString()
              .trim(),
      role: (json['role'] ?? 'employee') as String,
      active: (json['active'] ?? true) as bool,
      currentStatus: (json['currentStatus'] ?? 'off') as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'firstName': firstName,
    'lastName': lastName,
    'fullName': fullName,
    'role': role,
    'active': active,
    'currentStatus': currentStatus,
  };
}

class UserSession {
  UserSession({required this.token, required this.user});

  final String token;
  final AppUser user;

  UserSession copyWith({String? token, AppUser? user}) {
    return UserSession(token: token ?? this.token, user: user ?? this.user);
  }
}

class AttendanceEvent {
  AttendanceEvent({
    required this.id,
    required this.userId,
    required this.type,
    required this.serverTime,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.source,
  });

  final String id;
  final String userId;
  final String type;
  final DateTime serverTime;
  final double latitude;
  final double longitude;
  final double accuracy;
  final String source;

  String get typeLabel => type == 'check_in' ? 'Giriş' : 'Çıkış';

  factory AttendanceEvent.fromJson(Map<String, dynamic> json) {
    final location = (json['location'] as Map?)?.cast<String, dynamic>() ?? {};
    return AttendanceEvent(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: (json['type'] ?? 'check_in') as String,
      serverTime: DateTime.parse(json['serverTime'] as String).toLocal(),
      latitude: _toDouble(location['latitude']),
      longitude: _toDouble(location['longitude']),
      accuracy: _toDouble(location['accuracy']),
      source: (json['source'] ?? 'qr') as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'type': type,
    'serverTime': serverTime.toUtc().toIso8601String(),
    'location': {
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
    },
    'source': source,
  };
}

class ReportRow {
  ReportRow({
    required this.fullName,
    required this.username,
    required this.type,
    required this.serverTime,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
  });

  final String fullName;
  final String username;
  final String type;
  final DateTime serverTime;
  final double latitude;
  final double longitude;
  final double accuracy;

  factory ReportRow.fromJson(Map<String, dynamic> json) {
    return ReportRow(
      fullName: (json['fullName'] ?? '') as String,
      username: (json['username'] ?? '') as String,
      type: (json['type'] ?? 'check_in') as String,
      serverTime: DateTime.parse(json['serverTime'] as String).toLocal(),
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      accuracy: _toDouble(json['accuracy']),
    );
  }
}

double _toDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
