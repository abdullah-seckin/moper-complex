import '../domain/models.dart';

abstract class UserRepository {
  Future<AppUser?> findByUsername(String username);
  Future<AppUser?> findById(String id);
  Future<List<AppUser>> listUsers();
  Future<void> upsertUser(AppUser user);
  Future<void> updateStatus(String userId, WorkStatus status);
}

abstract class WorkplaceRepository {
  Future<List<Workplace>> listActive();
  Future<void> upsertWorkplace(Workplace workplace);
}

abstract class AttendanceRepository {
  Future<void> createEvent(AttendanceEvent event);
  Future<List<AttendanceEvent>> listEvents({
    String? userId,
    DateTime? start,
    DateTime? end,
  });
  Future<bool> existsLegacyKey(String legacyKey);
}

abstract class DeviceSessionRepository {
  Future<void> createSession(DeviceSession session);
  Future<bool> existsLegacyKey(String legacyKey);
}

class MoperRepositories {
  MoperRepositories({
    required this.users,
    required this.workplaces,
    required this.attendance,
    required this.deviceSessions,
  });

  final UserRepository users;
  final WorkplaceRepository workplaces;
  final AttendanceRepository attendance;
  final DeviceSessionRepository deviceSessions;
}
