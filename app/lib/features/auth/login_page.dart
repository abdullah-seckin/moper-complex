import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/device_info.dart';
import '../../core/models.dart';
import '../legal/legal_text_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.api,
    required this.onAuthenticated,
  });

  final ApiClient api;
  final ValueChanged<UserSession> onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _kvkkAccepted = false;
  bool _consentAccepted = false;
  bool _passwordVisible = false;
  bool _loading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_kvkkAccepted || !_consentAccepted) {
      _showMessage('KVKK ve açık rıza onaylarını tamamlayın.');
      return;
    }
    if (_usernameController.text.trim().isEmpty ||
        _passwordController.text.isEmpty) {
      _showMessage('Kullanıcı adı ve şifre girin.');
      return;
    }

    setState(() => _loading = true);
    try {
      final device = await collectDeviceInfo();
      final session = await widget.api.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        platform: device.platform,
        deviceInfo: device.info,
      );
      widget.onAuthenticated(session);
    } on ApiFailure catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Giriş yapılamadı: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 720;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.verified_user_outlined,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Moper Complex',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              'Personel devam doğrulama',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 28 : 36),
                  TextField(
                    controller: _usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Kullanıcı adı',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _passwordController,
                    obscureText: !_passwordVisible,
                    onSubmitted: (_) => _loading ? null : _submit(),
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        tooltip: _passwordVisible ? 'Gizle' : 'Göster',
                        onPressed: () => setState(
                          () => _passwordVisible = !_passwordVisible,
                        ),
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _LegalCheck(
                    value: _kvkkAccepted,
                    label: 'KVKK aydınlatma metnini okudum',
                    onChanged: (value) =>
                        setState(() => _kvkkAccepted = value ?? false),
                    onOpen: () => _openLegal(
                      'KVKK Aydınlatma Metni',
                      LegalTextPage.kvkkBody,
                    ),
                  ),
                  _LegalCheck(
                    value: _consentAccepted,
                    label: 'Açık rıza beyanını onaylıyorum',
                    onChanged: (value) =>
                        setState(() => _consentAccepted = value ?? false),
                    onOpen: () => _openLegal(
                      'Açık Rıza Beyanı',
                      LegalTextPage.consentBody,
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: const Text('Giriş yap'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openLegal(String title, String body) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalTextPage(title: title, body: body),
      ),
    );
  }
}

class _LegalCheck extends StatelessWidget {
  const _LegalCheck({
    required this.value,
    required this.label,
    required this.onChanged,
    required this.onOpen,
  });

  final bool value;
  final String label;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Checkbox(value: value, onChanged: onChanged),
        Expanded(
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                label,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
