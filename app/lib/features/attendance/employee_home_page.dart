import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import 'qr_scan_page.dart';

class EmployeeHomePage extends StatefulWidget {
  const EmployeeHomePage({
    super.key,
    required this.api,
    required this.session,
    required this.onSessionChanged,
    required this.onLogout,
  });

  final ApiClient api;
  final UserSession session;
  final ValueChanged<UserSession> onSessionChanged;
  final VoidCallback onLogout;

  @override
  State<EmployeeHomePage> createState() => _EmployeeHomePageState();
}

class _EmployeeHomePageState extends State<EmployeeHomePage> {
  late String _status = widget.session.user.currentStatus;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  Future<void> _refreshStatus() async {
    setState(() => _loading = true);
    try {
      final status = await widget.api.attendanceStatus(widget.session.token);
      setState(() => _status = status);
      widget.onSessionChanged(
        widget.session.copyWith(
          user: AppUser.fromJson({
            ...widget.session.user.toJson(),
            'currentStatus': status,
          }),
        ),
      );
    } on ApiFailure catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openScanner() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            QrScanPage(api: widget.api, token: widget.session.token),
      ),
    );
    if (changed == true) await _refreshStatus();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isWorking = _status == 'working';
    final statusColor = isWorking
        ? Theme.of(context).colorScheme.tertiary
        : Theme.of(context).colorScheme.primary;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personel Paneli'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading ? null : _refreshStatus,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Çıkış',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  widget.session.user.fullName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '@${widget.session.user.username}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isWorking
                                  ? Icons.check_circle_outline
                                  : Icons.access_time,
                              color: statusColor,
                              size: 44,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isWorking
                                        ? 'Mesai devam ediyor'
                                        : 'Mesai bitirildi',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isWorking
                                        ? 'Bir sonraki QR işlemi çıkış olarak kaydedilir.'
                                        : 'Bir sonraki QR işlemi giriş olarak kaydedilir.',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 26),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _openScanner,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: Text(
                              isWorking ? 'Çıkış QR okut' : 'Giriş QR okut',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
