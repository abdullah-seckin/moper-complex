import '../core/geo.dart';
import '../core/http.dart';
import '../core/security.dart';
import '../domain/models.dart';
import '../repositories/repositories.dart';
import 'id_generator.dart';

class AttendanceService {
  AttendanceService({
    required UserRepository users,
    required WorkplaceRepository workplaces,
    required AttendanceRepository attendance,
    required TokenHasher tokenHasher,
  }) : _users = users,
       _workplaces = workplaces,
       _attendance = attendance,
       _tokenHasher = tokenHasher;

  final UserRepository _users;
  final WorkplaceRepository _workplaces;
  final AttendanceRepository _attendance;
  final TokenHasher _tokenHasher;

  Future<Map<String, dynamic>> status(AppUser user) async {
    final freshUser = await _users.findById(user.id) ?? user;
    return {'currentStatus': freshUser.currentStatus.value};
  }

  Future<Map<String, dynamic>> scan({
    required AppUser user,
    required String qrPayload,
    required double latitude,
    required double longitude,
    required double accuracy,
  }) async {
    final workplaces = await _workplaces.listActive();
    final qrHash = _tokenHasher.hash(qrPayload);
    final workplace = workplaces
        .where((item) => item.qrTokenHash == qrHash)
        .firstOrNull;
    if (workplace == null) throw ApiException(400, 'Invalid QR code.');

    final distance = distanceMeters(
      fromLatitude: latitude,
      fromLongitude: longitude,
      toLatitude: workplace.latitude,
      toLongitude: workplace.longitude,
    );
    if (distance > workplace.radiusMeters) {
      throw ApiException(
        422,
        'Location is outside the workplace boundary.',
        details: {
          'distanceMeters': distance,
          'radiusMeters': workplace.radiusMeters,
        },
      );
    }

    final freshUser = await _users.findById(user.id) ?? user;
    final nextType = freshUser.currentStatus == WorkStatus.working
        ? AttendanceEventType.checkOut
        : AttendanceEventType.checkIn;
    final nextStatus = nextType == AttendanceEventType.checkIn
        ? WorkStatus.working
        : WorkStatus.off;

    final event = AttendanceEvent(
      id: newId(),
      userId: user.id,
      workplaceId: workplace.id,
      type: nextType,
      serverTime: DateTime.now().toUtc(),
      latitude: latitude,
      longitude: longitude,
      accuracy: accuracy,
      source: 'qr',
    );
    await _attendance.createEvent(event);
    await _users.updateStatus(user.id, nextStatus);

    return {
      'currentStatus': nextStatus.value,
      'event': event.toJson(),
      'workplace': workplace.toJson(),
      'distanceMeters': distance,
    };
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
