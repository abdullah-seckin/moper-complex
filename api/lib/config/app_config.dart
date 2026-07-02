import 'dart:io';

class AppConfig {
  AppConfig({
    required this.port,
    required this.mongoUri,
    required this.jwtSecret,
    required this.migrationKey,
    required this.defaultQrToken,
    required this.defaultWorkplaceName,
    required this.defaultLatitude,
    required this.defaultLongitude,
    required this.defaultRadiusMeters,
    required this.useMemoryStore,
  });

  final int port;
  final String mongoUri;
  final String jwtSecret;
  final String migrationKey;
  final String defaultQrToken;
  final String defaultWorkplaceName;
  final double defaultLatitude;
  final double defaultLongitude;
  final double defaultRadiusMeters;
  final bool useMemoryStore;

  static AppConfig load() {
    final env = {
      ..._readDotEnv(File(Platform.environment['MOPER_ENV_FILE'] ?? '.env')),
      ...Platform.environment,
    };

    return AppConfig(
      port: int.tryParse(env['PORT'] ?? '') ?? 8080,
      mongoUri: env['MONGO_URI'] ?? '',
      jwtSecret: env['JWT_SECRET'] ?? 'dev-only-change-me',
      migrationKey: env['MIGRATION_KEY'] ?? 'local-migration-key',
      defaultQrToken: env['DEFAULT_QR_TOKEN'] ?? 'MOPER_DEMO_QR',
      defaultWorkplaceName: env['DEFAULT_WORKPLACE_NAME'] ?? 'Moper HQ',
      defaultLatitude:
          double.tryParse(env['DEFAULT_WORKPLACE_LAT'] ?? '') ?? 40.9862,
      defaultLongitude:
          double.tryParse(env['DEFAULT_WORKPLACE_LNG'] ?? '') ?? 29.1244,
      defaultRadiusMeters:
          double.tryParse(env['DEFAULT_WORKPLACE_RADIUS_METERS'] ?? '') ?? 250,
      useMemoryStore: (env['MOPER_USE_MEMORY'] ?? '').toLowerCase() == 'true',
    );
  }
}

Map<String, String> _readDotEnv(File file) {
  if (!file.existsSync()) return {};
  final values = <String, String>{};
  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#') || !line.contains('=')) continue;
    final index = line.indexOf('=');
    final key = line.substring(0, index).trim();
    var value = line.substring(index + 1).trim();
    if ((value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))) {
      value = value.substring(1, value.length - 1);
    }
    values[key] = value;
  }
  return values;
}
