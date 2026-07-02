import 'package:flutter/material.dart';

import 'core/api_client.dart';
import 'core/app_config.dart';
import 'core/app_theme.dart';
import 'core/models.dart';
import 'core/session_store.dart';
import 'features/admin/admin_home_page.dart';
import 'features/attendance/employee_home_page.dart';
import 'features/auth/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MoperComplexApp(
      api: ApiClient(baseUrl: AppConfig.apiBaseUrl),
      sessionStore: SessionStore(),
    ),
  );
}

class MoperComplexApp extends StatefulWidget {
  const MoperComplexApp({
    super.key,
    required this.api,
    required this.sessionStore,
  });

  final ApiClient api;
  final SessionStore sessionStore;

  @override
  State<MoperComplexApp> createState() => _MoperComplexAppState();
}

class _MoperComplexAppState extends State<MoperComplexApp> {
  UserSession? _session;
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = await widget.sessionStore.loadToken();
    if (token != null) {
      try {
        final user = await widget.api.me(token);
        _session = UserSession(token: token, user: user);
      } catch (_) {
        await widget.sessionStore.clear();
      }
    }
    if (mounted) setState(() => _restoring = false);
  }

  Future<void> _setSession(UserSession session) async {
    await widget.sessionStore.saveToken(session.token);
    setState(() => _session = session);
  }

  Future<void> _logout() async {
    await widget.sessionStore.clear();
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Moper Complex',
      theme: AppTheme.light,
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    if (_restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final session = _session;
    if (session == null) {
      return LoginPage(api: widget.api, onAuthenticated: _setSession);
    }

    if (session.user.isAdmin) {
      return AdminHomePage(
        api: widget.api,
        session: session,
        onLogout: _logout,
      );
    }

    return EmployeeHomePage(
      api: widget.api,
      session: session,
      onSessionChanged: (updated) => setState(() => _session = updated),
      onLogout: _logout,
    );
  }
}
