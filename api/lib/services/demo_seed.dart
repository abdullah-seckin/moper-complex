import '../config/app_config.dart';
import '../core/security.dart';
import '../domain/models.dart';
import '../repositories/repositories.dart';
import 'id_generator.dart';

const demoAdminUsername = 'admin';
const demoEmployeeUsername = 'personel';
const demoSecondEmployeeUsername = 'selin';
const demoPassword = 'moper123';
const defaultWorkplaceId = 'default-workplace';

Future<void> seedDemoData({
  required AppConfig config,
  required MoperRepositories repositories,
  required PasswordHasher passwordHasher,
  required TokenHasher tokenHasher,
}) async {
  await repositories.workplaces.upsertWorkplace(
    Workplace(
      id: defaultWorkplaceId,
      name: config.defaultWorkplaceName,
      latitude: config.defaultLatitude,
      longitude: config.defaultLongitude,
      radiusMeters: config.defaultRadiusMeters,
      qrTokenHash: tokenHasher.hash(config.defaultQrToken),
      active: true,
    ),
  );

  if (await repositories.users.findByUsername(demoAdminUsername) == null) {
    await repositories.users.upsertUser(
      AppUser(
        id: newId(),
        username: demoAdminUsername,
        firstName: 'IK',
        lastName: 'Yoneticisi',
        passwordHash: passwordHasher.hash(demoPassword),
        role: UserRole.admin,
        active: true,
        currentStatus: WorkStatus.off,
      ),
    );
  }

  if (await repositories.users.findByUsername(demoEmployeeUsername) == null) {
    await repositories.users.upsertUser(
      AppUser(
        id: newId(),
        username: demoEmployeeUsername,
        firstName: 'Demo',
        lastName: 'Personel',
        passwordHash: passwordHasher.hash(demoPassword),
        role: UserRole.employee,
        active: true,
        currentStatus: WorkStatus.off,
      ),
    );
  }

  if (await repositories.users.findByUsername(demoSecondEmployeeUsername) ==
      null) {
    await repositories.users.upsertUser(
      AppUser(
        id: newId(),
        username: demoSecondEmployeeUsername,
        firstName: 'Selin',
        lastName: 'Kara',
        passwordHash: passwordHasher.hash(demoPassword),
        role: UserRole.employee,
        active: true,
        currentStatus: WorkStatus.working,
      ),
    );
  }
}
