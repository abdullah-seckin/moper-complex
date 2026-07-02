import '../core/security.dart';
import '../domain/models.dart';
import '../repositories/repositories.dart';
import 'id_generator.dart';

class MigrationSummary {
  MigrationSummary({
    required this.usersCreatedOrUpdated,
    required this.eventsCreated,
    required this.deviceSessionsCreated,
  });

  final int usersCreatedOrUpdated;
  final int eventsCreated;
  final int deviceSessionsCreated;

  Map<String, dynamic> toJson() => {
    'usersCreatedOrUpdated': usersCreatedOrUpdated,
    'eventsCreated': eventsCreated,
    'deviceSessionsCreated': deviceSessionsCreated,
  };
}

class LegacyMigrationService {
  LegacyMigrationService({
    required MoperRepositories repositories,
    required PasswordHasher passwordHasher,
    required String defaultWorkplaceId,
  }) : _repositories = repositories,
       _passwordHasher = passwordHasher,
       _defaultWorkplaceId = defaultWorkplaceId;

  final MoperRepositories _repositories;
  final PasswordHasher _passwordHasher;
  final String _defaultWorkplaceId;

  Future<MigrationSummary> migrateSnapshot({
    required List<Map<String, dynamic>> legacyUsers,
    required List<Map<String, dynamic>> legacyDevices,
  }) async {
    var usersTouched = 0;
    var eventsCreated = 0;
    var sessionsCreated = 0;
    final userByLegacyUserName = <String, AppUser>{};

    for (final legacy in legacyUsers) {
      final username = (legacy['uname'] ?? '').toString().trim();
      if (username.isEmpty) continue;

      final existing = await _repositories.users.findByUsername(username);
      final legacyId = _legacyId(legacy);
      final user = AppUser(
        id: existing?.id ?? newId(),
        username: username,
        firstName: (legacy['fName'] ?? '').toString(),
        lastName: (legacy['lName'] ?? '').toString(),
        passwordHash:
            existing?.passwordHash ??
            _passwordHasher.hash(
              (legacy['upassword'] ?? 'changeme').toString(),
            ),
        role: UserRole.fromValue((legacy['role'] ?? 'employee').toString()),
        active: legacy['isActive'] != false,
        currentStatus: _legacyStatus((legacy['state'] ?? '').toString()),
        legacyId: legacyId,
      );
      await _repositories.users.upsertUser(user);
      userByLegacyUserName[username] = user;
      usersTouched++;

      final logDays = legacy['logs'];
      if (logDays is List) {
        for (final day in logDays.whereType<Map>()) {
          final date = (day['date'] ?? '').toString();
          final entries = day['logs'];
          if (entries is! List) continue;
          for (final entry in entries.whereType<Map>()) {
            final legacyKey = [
              legacyId,
              date,
              entry['time'],
              entry['state'],
              entry['Lat'],
              entry['Lng'],
            ].join('|');
            if (await _repositories.attendance.existsLegacyKey(legacyKey)) {
              continue;
            }
            final time =
                DateTime.tryParse((entry['time'] ?? '').toString()) ??
                DateTime.now().toUtc();
            await _repositories.attendance.createEvent(
              AttendanceEvent(
                id: newId(),
                userId: user.id,
                workplaceId: _defaultWorkplaceId,
                type: _legacyType((entry['state'] ?? '').toString()),
                serverTime: time.toUtc(),
                latitude: _toDouble(entry['Lat']),
                longitude: _toDouble(entry['Lng']),
                accuracy: 0,
                source: 'legacy_migration',
                legacyKey: legacyKey,
              ),
            );
            eventsCreated++;
          }
        }
      }
    }

    for (final device in legacyDevices) {
      final username = (device['uID'] ?? '').toString();
      final user =
          userByLegacyUserName[username] ??
          await _repositories.users.findByUsername(username);
      if (user == null) {
        continue;
      }
      final legacyKey =
          '${_legacyId(device)}|${device['uID']}|${device['date']}';
      if (await _repositories.deviceSessions.existsLegacyKey(legacyKey)) {
        continue;
      }
      await _repositories.deviceSessions.createSession(
        DeviceSession(
          id: newId(),
          userId: user.id,
          platform: (device['platform'] ?? 'unknown').toString(),
          deviceInfo: ((device['deviceData'] as Map?) ?? {})
              .cast<String, dynamic>(),
          createdAt: DateTime.now().toUtc(),
          legacyKey: legacyKey,
        ),
      );
      sessionsCreated++;
    }

    return MigrationSummary(
      usersCreatedOrUpdated: usersTouched,
      eventsCreated: eventsCreated,
      deviceSessionsCreated: sessionsCreated,
    );
  }
}

String _legacyId(Map<dynamic, dynamic> value) {
  final id = value['_id'];
  if (id == null) return newId();
  try {
    return id.toHexString() as String;
  } catch (_) {
    return id.toString();
  }
}

WorkStatus _legacyStatus(String value) {
  return value == 'Çalışılıyor' ? WorkStatus.working : WorkStatus.off;
}

AttendanceEventType _legacyType(String value) {
  return value == 'Stopped'
      ? AttendanceEventType.checkOut
      : AttendanceEventType.checkIn;
}

double _toDouble(Object? value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
