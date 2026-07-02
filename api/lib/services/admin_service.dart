import '../core/http.dart';
import '../domain/models.dart';
import '../repositories/repositories.dart';

class AdminService {
  AdminService({
    required UserRepository users,
    required AttendanceRepository attendance,
  }) : _users = users,
       _attendance = attendance;

  final UserRepository _users;
  final AttendanceRepository _attendance;

  void requireAdmin(AppUser user) {
    if (user.role != UserRole.admin) {
      throw ApiException(403, 'Admin role required.');
    }
  }

  Future<List<Map<String, dynamic>>> listUsers() async {
    final users = await _users.listUsers();
    return users.map((user) => user.toPublicJson()).toList();
  }

  Future<List<Map<String, dynamic>>> listEvents({
    String? userId,
    DateTime? start,
    DateTime? end,
  }) async {
    final events = await _attendance.listEvents(
      userId: userId,
      start: start,
      end: end,
    );
    return events.map((event) => event.toJson()).toList();
  }

  Future<List<Map<String, dynamic>>> report({
    String? userId,
    DateTime? start,
    DateTime? end,
  }) async {
    final users = await _users.listUsers();
    final userMap = {for (final user in users) user.id: user};
    final events = await _attendance.listEvents(
      userId: userId,
      start: start,
      end: end,
    );
    return events.map((event) {
      final user = userMap[event.userId];
      return {
        'userId': event.userId,
        'fullName': user?.fullName ?? event.userId,
        'username': user?.username ?? '',
        'type': event.type.value,
        'serverTime': event.serverTime.toUtc().toIso8601String(),
        'latitude': event.latitude,
        'longitude': event.longitude,
        'accuracy': event.accuracy,
      };
    }).toList();
  }
}
