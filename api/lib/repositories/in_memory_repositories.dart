import '../domain/models.dart';
import 'repositories.dart';

class InMemoryUserRepository implements UserRepository {
  final Map<String, AppUser> _users = {};

  @override
  Future<AppUser?> findByUsername(String username) async {
    final normalized = username.trim().toLowerCase();
    return _users.values
        .where((user) => user.username.toLowerCase() == normalized)
        .firstOrNull;
  }

  @override
  Future<AppUser?> findById(String id) async => _users[id];

  @override
  Future<List<AppUser>> listUsers() async {
    final users = _users.values.toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    return users;
  }

  @override
  Future<void> upsertUser(AppUser user) async {
    _users[user.id] = user;
  }

  @override
  Future<void> updateStatus(String userId, WorkStatus status) async {
    final user = _users[userId];
    if (user != null) {
      _users[userId] = user.copyWith(currentStatus: status);
    }
  }
}

class InMemoryWorkplaceRepository implements WorkplaceRepository {
  final Map<String, Workplace> _workplaces = {};

  @override
  Future<List<Workplace>> listActive() async {
    return _workplaces.values.where((workplace) => workplace.active).toList();
  }

  @override
  Future<void> upsertWorkplace(Workplace workplace) async {
    _workplaces[workplace.id] = workplace;
  }
}

class InMemoryAttendanceRepository implements AttendanceRepository {
  final List<AttendanceEvent> _events = [];

  @override
  Future<void> createEvent(AttendanceEvent event) async {
    _events.add(event);
  }

  @override
  Future<bool> existsLegacyKey(String legacyKey) async {
    return _events.any((event) => event.legacyKey == legacyKey);
  }

  @override
  Future<List<AttendanceEvent>> listEvents({
    String? userId,
    DateTime? start,
    DateTime? end,
  }) async {
    final events = _events.where((event) {
      if (userId != null && event.userId != userId) return false;
      if (start != null && event.serverTime.isBefore(start)) return false;
      if (end != null && event.serverTime.isAfter(end)) return false;
      return true;
    }).toList()..sort((a, b) => b.serverTime.compareTo(a.serverTime));
    return events;
  }
}

class InMemoryDeviceSessionRepository implements DeviceSessionRepository {
  final List<DeviceSession> _sessions = [];

  @override
  Future<void> createSession(DeviceSession session) async {
    _sessions.add(session);
  }

  @override
  Future<bool> existsLegacyKey(String legacyKey) async {
    return _sessions.any((session) => session.legacyKey == legacyKey);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
