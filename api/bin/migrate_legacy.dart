import 'dart:io';

import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:moper_complex_api/config/app_config.dart';
import 'package:moper_complex_api/core/security.dart';
import 'package:moper_complex_api/repositories/mongo_repositories.dart';
import 'package:moper_complex_api/services/demo_seed.dart';
import 'package:moper_complex_api/services/migration_service.dart';

Future<void> main() async {
  final config = AppConfig.load();
  if (config.mongoUri.isEmpty) {
    stderr.writeln('MONGO_URI is required for legacy migration.');
    exitCode = 64;
    return;
  }

  final db = mongo.Db(config.mongoUri);
  await db.open();
  try {
    final repositories = createMongoRepositories(db);
    await seedDemoData(
      config: config,
      repositories: repositories,
      passwordHasher: PasswordHasher(),
      tokenHasher: TokenHasher(),
    );
    final service = LegacyMigrationService(
      repositories: repositories,
      passwordHasher: PasswordHasher(),
      defaultWorkplaceId: defaultWorkplaceId,
    );
    final users = await db.collection('Users').find().toList();
    final devices = await db.collection('Devices').find().toList();
    final summary = await service.migrateSnapshot(
      legacyUsers: users,
      legacyDevices: devices,
    );
    stdout.writeln('Migration completed: ${summary.toJson()}');
  } finally {
    await db.close();
  }
}
