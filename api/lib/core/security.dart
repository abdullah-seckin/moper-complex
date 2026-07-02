import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class PasswordHasher {
  PasswordHasher({this.iterations = 12000});

  final int iterations;

  String hash(String password, {String? salt}) {
    final effectiveSalt = salt ?? _randomSalt();
    List<int> bytes = utf8.encode('$effectiveSalt:$password');
    for (var i = 0; i < iterations; i++) {
      bytes = sha256.convert(bytes).bytes;
    }
    return 'sha256:$iterations:$effectiveSalt:${base64UrlEncode(bytes)}';
  }

  bool verify(String password, String storedHash) {
    final parts = storedHash.split(':');
    if (parts.length != 4 || parts.first != 'sha256') return false;
    final parsedIterations = int.tryParse(parts[1]);
    if (parsedIterations == null) return false;
    final salt = parts[2];
    final hasher = PasswordHasher(iterations: parsedIterations);
    return hasher.hash(password, salt: salt) == storedHash;
  }

  String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}

class TokenHasher {
  String hash(String token) => sha256.convert(utf8.encode(token)).toString();
}

class JwtService {
  JwtService(this.secret);

  final String secret;

  String issue({
    required String userId,
    required String role,
    Duration ttl = const Duration(hours: 12),
  }) {
    final header = {'alg': 'HS256', 'typ': 'JWT'};
    final payload = {
      'sub': userId,
      'role': role,
      'exp': DateTime.now().toUtc().add(ttl).millisecondsSinceEpoch ~/ 1000,
    };
    final encodedHeader = _base64Json(header);
    final encodedPayload = _base64Json(payload);
    final signature = _sign('$encodedHeader.$encodedPayload');
    return '$encodedHeader.$encodedPayload.$signature';
  }

  Map<String, dynamic>? verify(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    final expected = _sign('${parts[0]}.${parts[1]}');
    if (expected != parts[2]) return null;
    final payload = jsonDecode(utf8.decode(base64Url.decode(_pad(parts[1]))));
    if (payload is! Map<String, dynamic>) return null;
    final exp = payload['exp'];
    if (exp is! int) return null;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
    if (exp < now) return null;
    return payload;
  }

  String _base64Json(Map<String, Object> value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  String _sign(String message) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    return base64Url
        .encode(hmac.convert(utf8.encode(message)).bytes)
        .replaceAll('=', '');
  }

  String _pad(String value) {
    final padding = value.length % 4;
    if (padding == 0) return value;
    return value.padRight(value.length + (4 - padding), '=');
  }
}
