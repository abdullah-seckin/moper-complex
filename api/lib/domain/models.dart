enum UserRole {
  employee('employee'),
  admin('admin');

  const UserRole(this.value);

  final String value;

  static UserRole fromValue(String? value) {
    return UserRole.values.firstWhere(
      (role) => role.value == value,
      orElse: () => UserRole.employee,
    );
  }
}

enum WorkStatus {
  off('off'),
  working('working');

  const WorkStatus(this.value);

  final String value;

  static WorkStatus fromValue(String? value) {
    return WorkStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => WorkStatus.off,
    );
  }
}

enum AttendanceEventType {
  checkIn('check_in'),
  checkOut('check_out');

  const AttendanceEventType(this.value);

  final String value;

  static AttendanceEventType fromValue(String? value) {
    return AttendanceEventType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => AttendanceEventType.checkIn,
    );
  }
}

class AppUser {
  AppUser({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.passwordHash,
    required this.role,
    required this.active,
    required this.currentStatus,
    this.legacyId,
  });

  final String id;
  final String username;
  final String firstName;
  final String lastName;
  final String passwordHash;
  final UserRole role;
  final bool active;
  final WorkStatus currentStatus;
  final String? legacyId;

  String get fullName => '$firstName $lastName'.trim();

  AppUser copyWith({
    String? id,
    String? username,
    String? firstName,
    String? lastName,
    String? passwordHash,
    UserRole? role,
    bool? active,
    WorkStatus? currentStatus,
    String? legacyId,
  }) {
    return AppUser(
      id: id ?? this.id,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      active: active ?? this.active,
      currentStatus: currentStatus ?? this.currentStatus,
      legacyId: legacyId ?? this.legacyId,
    );
  }

  Map<String, dynamic> toPublicJson() {
    return {
      'id': id,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'fullName': fullName,
      'role': role.value,
      'active': active,
      'currentStatus': currentStatus.value,
    };
  }

  Map<String, dynamic> toStorageJson() {
    return {
      'id': id,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'passwordHash': passwordHash,
      'role': role.value,
      'active': active,
      'currentStatus': currentStatus.value,
      if (legacyId != null) 'legacyId': legacyId,
    };
  }

  static AppUser fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      username: json['username'] as String,
      firstName: (json['firstName'] ?? '') as String,
      lastName: (json['lastName'] ?? '') as String,
      passwordHash: (json['passwordHash'] ?? '') as String,
      role: UserRole.fromValue(json['role'] as String?),
      active: (json['active'] ?? true) as bool,
      currentStatus: WorkStatus.fromValue(json['currentStatus'] as String?),
      legacyId: json['legacyId'] as String?,
    );
  }
}

class Workplace {
  Workplace({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.qrTokenHash,
    required this.active,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final String qrTokenHash;
  final bool active;

  Map<String, dynamic> toJson({bool includeTokenHash = false}) {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'active': active,
      if (includeTokenHash) 'qrTokenHash': qrTokenHash,
    };
  }

  Map<String, dynamic> toStorageJson() => toJson(includeTokenHash: true);

  static Workplace fromJson(Map<String, dynamic> json) {
    return Workplace(
      id: json['id'] as String,
      name: (json['name'] ?? 'Moper Workplace') as String,
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      radiusMeters: _toDouble(json['radiusMeters']),
      qrTokenHash: (json['qrTokenHash'] ?? '') as String,
      active: (json['active'] ?? true) as bool,
    );
  }
}

class AttendanceEvent {
  AttendanceEvent({
    required this.id,
    required this.userId,
    required this.workplaceId,
    required this.type,
    required this.serverTime,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.source,
    this.legacyKey,
  });

  final String id;
  final String userId;
  final String workplaceId;
  final AttendanceEventType type;
  final DateTime serverTime;
  final double latitude;
  final double longitude;
  final double accuracy;
  final String source;
  final String? legacyKey;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'workplaceId': workplaceId,
      'type': type.value,
      'serverTime': serverTime.toUtc().toIso8601String(),
      'location': {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
      },
      'source': source,
      if (legacyKey != null) 'legacyKey': legacyKey,
    };
  }

  Map<String, dynamic> toStorageJson() => toJson();

  static AttendanceEvent fromJson(Map<String, dynamic> json) {
    final location = (json['location'] as Map?)?.cast<String, dynamic>() ?? {};
    return AttendanceEvent(
      id: json['id'] as String,
      userId: json['userId'] as String,
      workplaceId: (json['workplaceId'] ?? '') as String,
      type: AttendanceEventType.fromValue(json['type'] as String?),
      serverTime: DateTime.parse(json['serverTime'] as String).toUtc(),
      latitude: _toDouble(location['latitude']),
      longitude: _toDouble(location['longitude']),
      accuracy: _toDouble(location['accuracy']),
      source: (json['source'] ?? 'qr') as String,
      legacyKey: json['legacyKey'] as String?,
    );
  }
}

class DeviceSession {
  DeviceSession({
    required this.id,
    required this.userId,
    required this.platform,
    required this.deviceInfo,
    required this.createdAt,
    this.legacyKey,
  });

  final String id;
  final String userId;
  final String platform;
  final Map<String, dynamic> deviceInfo;
  final DateTime createdAt;
  final String? legacyKey;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'platform': platform,
      'deviceInfo': deviceInfo,
      'createdAt': createdAt.toUtc().toIso8601String(),
      if (legacyKey != null) 'legacyKey': legacyKey,
    };
  }

  static DeviceSession fromJson(Map<String, dynamic> json) {
    return DeviceSession(
      id: json['id'] as String,
      userId: json['userId'] as String,
      platform: (json['platform'] ?? 'unknown') as String,
      deviceInfo: ((json['deviceInfo'] as Map?) ?? {}).cast<String, dynamic>(),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      legacyKey: json['legacyKey'] as String?,
    );
  }
}

double _toDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
