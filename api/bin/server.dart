import 'dart:io';

import 'package:shelf/shelf_io.dart';
import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:moper_complex_api/config/app_config.dart';
import 'package:moper_complex_api/core/security.dart';
import 'package:moper_complex_api/repositories/in_memory_repositories.dart';
import 'package:moper_complex_api/repositories/mongo_repositories.dart';
import 'package:moper_complex_api/repositories/repositories.dart';
import 'package:moper_complex_api/server/app_services.dart';
import 'package:moper_complex_api/server/router.dart';
import 'package:moper_complex_api/services/demo_seed.dart';

void main(List<String> args) async {
  final config = AppConfig.load();
  final passwordHasher = PasswordHasher();
  final tokenHasher = TokenHasher();
  late final MoperRepositories repositories;
  mongo.Db? db;

  if (config.mongoUri.isNotEmpty && !config.useMemoryStore) {
    db = mongo.Db(config.mongoUri);
    await db.open();
    repositories = createMongoRepositories(db);
  } else {
    repositories = MoperRepositories(
      users: InMemoryUserRepository(),
      workplaces: InMemoryWorkplaceRepository(),
      attendance: InMemoryAttendanceRepository(),
      deviceSessions: InMemoryDeviceSessionRepository(),
    );
  }

  await seedDemoData(
    config: config,
    repositories: repositories,
    passwordHasher: passwordHasher,
    tokenHasher: tokenHasher,
  );

  final services = AppServices.create(
    config: config,
    repositories: repositories,
    passwordHasher: passwordHasher,
    tokenHasher: tokenHasher,
  );
  final server = await serve(
    createHandler(services),
    InternetAddress.anyIPv4,
    config.port,
  );
  print('Moper Complex API listening on port ${server.port}');
  if (db == null) {
    print(
      'Running with in-memory demo data. Set MONGO_URI in .env for MongoDB.',
    );
    print('Demo users: admin/moper123, personel/moper123 and selin/moper123');
    print('Demo QR token: ${config.defaultQrToken}');
  }
}
