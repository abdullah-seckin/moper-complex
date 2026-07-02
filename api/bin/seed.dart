import 'dart:io';

import 'package:mongo_dart/mongo_dart.dart' as mongo;
import 'package:moper_complex_api/config/app_config.dart';
import 'package:moper_complex_api/core/security.dart';
import 'package:moper_complex_api/repositories/mongo_repositories.dart';
import 'package:moper_complex_api/services/demo_seed.dart';

Future<void> main() async {
  final config = AppConfig.load();
  if (config.mongoUri.isEmpty) {
    stderr.writeln('MONGO_URI is required for Mongo seed.');
    exitCode = 64;
    return;
  }

  final db = mongo.Db(config.mongoUri);
  await db.open();
  try {
    await seedDemoData(
      config: config,
      repositories: createMongoRepositories(db),
      passwordHasher: PasswordHasher(),
      tokenHasher: TokenHasher(),
    );
    stdout.writeln('Seed completed.');
  } finally {
    await db.close();
  }
}
