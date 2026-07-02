import '../core/http.dart';
import '../core/security.dart';
import '../domain/models.dart';
import '../repositories/repositories.dart';
import 'id_generator.dart';

class LoginResult {
  LoginResult({required this.token, required this.user});

  final String token;
  final AppUser user;

  Map<String, dynamic> toJson() => {
    'token': token,
    'user': user.toPublicJson(),
  };
}

class AuthService {
  AuthService({
    required UserRepository users,
    required DeviceSessionRepository deviceSessions,
    required PasswordHasher passwordHasher,
    required JwtService jwtService,
  }) : _users = users,
       _deviceSessions = deviceSessions,
       _passwordHasher = passwordHasher,
       _jwtService = jwtService;

  final UserRepository _users;
  final DeviceSessionRepository _deviceSessions;
  final PasswordHasher _passwordHasher;
  final JwtService _jwtService;

  Future<LoginResult> login({
    required String username,
    required String password,
    Map<String, dynamic>? deviceInfo,
    String platform = 'unknown',
  }) async {
    final user = await _users.findByUsername(username);
    if (user == null ||
        !user.active ||
        !_passwordHasher.verify(password, user.passwordHash)) {
      throw ApiException(401, 'Invalid username or password.');
    }

    if (deviceInfo != null && deviceInfo.isNotEmpty) {
      await _deviceSessions.createSession(
        DeviceSession(
          id: newId(),
          userId: user.id,
          platform: platform,
          deviceInfo: deviceInfo,
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }

    return LoginResult(
      token: _jwtService.issue(userId: user.id, role: user.role.value),
      user: user,
    );
  }

  Future<AppUser> userFromToken(String token) async {
    final payload = _jwtService.verify(token);
    if (payload == null) {
      throw ApiException(401, 'Invalid or expired token.');
    }
    final userId = payload['sub'];
    if (userId is! String) {
      throw ApiException(401, 'Invalid token subject.');
    }
    final user = await _users.findById(userId);
    if (user == null || !user.active) {
      throw ApiException(401, 'User is not active.');
    }
    return user;
  }
}
