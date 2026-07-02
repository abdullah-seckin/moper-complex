import '../config/app_config.dart';
import '../core/security.dart';
import '../repositories/repositories.dart';
import '../services/admin_service.dart';
import '../services/attendance_service.dart';
import '../services/auth_service.dart';
import '../services/migration_service.dart';

class AppServices {
  AppServices({
    required this.config,
    required this.repositories,
    required this.auth,
    required this.attendance,
    required this.admin,
    required this.migration,
  });

  final AppConfig config;
  final MoperRepositories repositories;
  final AuthService auth;
  final AttendanceService attendance;
  final AdminService admin;
  final LegacyMigrationService migration;

  static AppServices create({
    required AppConfig config,
    required MoperRepositories repositories,
    PasswordHasher? passwordHasher,
    TokenHasher? tokenHasher,
    JwtService? jwtService,
  }) {
    final effectivePasswordHasher = passwordHasher ?? PasswordHasher();
    final effectiveTokenHasher = tokenHasher ?? TokenHasher();
    final effectiveJwtService = jwtService ?? JwtService(config.jwtSecret);
    return AppServices(
      config: config,
      repositories: repositories,
      auth: AuthService(
        users: repositories.users,
        deviceSessions: repositories.deviceSessions,
        passwordHasher: effectivePasswordHasher,
        jwtService: effectiveJwtService,
      ),
      attendance: AttendanceService(
        users: repositories.users,
        workplaces: repositories.workplaces,
        attendance: repositories.attendance,
        tokenHasher: effectiveTokenHasher,
      ),
      admin: AdminService(
        users: repositories.users,
        attendance: repositories.attendance,
      ),
      migration: LegacyMigrationService(
        repositories: repositories,
        passwordHasher: effectivePasswordHasher,
        defaultWorkplaceId: 'default-workplace',
      ),
    );
  }
}
