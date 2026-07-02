import 'package:mongo_dart/mongo_dart.dart' as mongo;

import '../domain/models.dart';
import 'repositories.dart';

class MongoUserRepository implements UserRepository {
  MongoUserRepository(mongo.Db db) : _collection = db.collection('moper_users');

  final mongo.DbCollection _collection;

  @override
  Future<AppUser?> findByUsername(String username) async {
    final doc = await _collection.findOne(
      mongo.where.eq('username', username.trim()),
    );
    return doc == null ? null : AppUser.fromJson(doc);
  }

  @override
  Future<AppUser?> findById(String id) async {
    final doc = await _collection.findOne(mongo.where.eq('id', id));
    return doc == null ? null : AppUser.fromJson(doc);
  }

  @override
  Future<List<AppUser>> listUsers() async {
    final docs = await _collection
        .find(mongo.where.sortBy('firstName'))
        .toList();
    return docs.map(AppUser.fromJson).toList();
  }

  @override
  Future<void> upsertUser(AppUser user) async {
    await _collection.updateOne(mongo.where.eq('id', user.id), {
      r'$set': user.toStorageJson(),
    }, upsert: true);
  }

  @override
  Future<void> updateStatus(String userId, WorkStatus status) async {
    await _collection.updateOne(mongo.where.eq('id', userId), {
      r'$set': {'currentStatus': status.value},
    });
  }
}

class MongoWorkplaceRepository implements WorkplaceRepository {
  MongoWorkplaceRepository(mongo.Db db)
    : _collection = db.collection('moper_workplaces');

  final mongo.DbCollection _collection;

  @override
  Future<List<Workplace>> listActive() async {
    final docs = await _collection
        .find(mongo.where.eq('active', true))
        .toList();
    return docs.map(Workplace.fromJson).toList();
  }

  @override
  Future<void> upsertWorkplace(Workplace workplace) async {
    await _collection.updateOne(mongo.where.eq('id', workplace.id), {
      r'$set': workplace.toStorageJson(),
    }, upsert: true);
  }
}

class MongoAttendanceRepository implements AttendanceRepository {
  MongoAttendanceRepository(mongo.Db db)
    : _collection = db.collection('moper_attendance_events');

  final mongo.DbCollection _collection;

  @override
  Future<void> createEvent(AttendanceEvent event) async {
    await _collection.insertOne(event.toStorageJson());
  }

  @override
  Future<bool> existsLegacyKey(String legacyKey) async {
    final doc = await _collection.findOne(
      mongo.where.eq('legacyKey', legacyKey),
    );
    return doc != null;
  }

  @override
  Future<List<AttendanceEvent>> listEvents({
    String? userId,
    DateTime? start,
    DateTime? end,
  }) async {
    final selector = <String, dynamic>{};
    if (userId != null) selector['userId'] = userId;
    if (start != null || end != null) {
      selector['serverTime'] = {
        if (start != null) r'$gte': start.toUtc().toIso8601String(),
        if (end != null) r'$lte': end.toUtc().toIso8601String(),
      };
    }
    final docs = await _collection.find(selector).toList();
    final events = docs.map(AttendanceEvent.fromJson).toList()
      ..sort((a, b) => b.serverTime.compareTo(a.serverTime));
    return events;
  }
}

class MongoDeviceSessionRepository implements DeviceSessionRepository {
  MongoDeviceSessionRepository(mongo.Db db)
    : _collection = db.collection('moper_device_sessions');

  final mongo.DbCollection _collection;

  @override
  Future<void> createSession(DeviceSession session) async {
    await _collection.insertOne(session.toJson());
  }

  @override
  Future<bool> existsLegacyKey(String legacyKey) async {
    final doc = await _collection.findOne(
      mongo.where.eq('legacyKey', legacyKey),
    );
    return doc != null;
  }
}

MoperRepositories createMongoRepositories(mongo.Db db) {
  return MoperRepositories(
    users: MongoUserRepository(db),
    workplaces: MongoWorkplaceRepository(db),
    attendance: MongoAttendanceRepository(db),
    deviceSessions: MongoDeviceSessionRepository(db),
  );
}
