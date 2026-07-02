import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:moper_complex/core/api_client.dart';
import 'package:moper_complex/core/session_store.dart';
import 'package:moper_complex/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows login screen when there is no saved session', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MoperComplexApp(
        api: ApiClient(baseUrl: 'http://localhost:8080'),
        sessionStore: SessionStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Moper Complex'), findsOneWidget);
    expect(find.text('Giriş yap'), findsOneWidget);
  });

  test('falls back to embedded demo data when API is not running', () async {
    final api = ApiClient(
      baseUrl: 'http://localhost:8080',
      client: _FailingClient(),
    );

    final session = await api.login(
      username: 'admin',
      password: 'moper123',
      platform: 'test',
      deviceInfo: const {},
    );
    final users = await api.adminUsers(session.token);

    expect(session.user.isAdmin, isTrue);
    expect(
      users.map((user) => user.username),
      containsAll(['admin', 'personel', 'selin']),
    );
    expect(users, hasLength(3));
  });
}

class _FailingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw http.ClientException('Connection refused', request.url);
  }
}
