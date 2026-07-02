import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import 'user_events_page.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({
    super.key,
    required this.api,
    required this.session,
    required this.onLogout,
  });

  final ApiClient api;
  final UserSession session;
  final VoidCallback onLogout;

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  final _dateFormat = DateFormat('dd.MM.yyyy');
  List<AppUser> _users = [];
  DateTimeRange? _range;
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final users = await widget.api.adminUsers(widget.session.token);
      setState(() => _users = users);
    } on ApiFailure catch (error) {
      _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _exportReport() async {
    setState(() => _exporting = true);
    try {
      final rows = await widget.api.attendanceReport(
        token: widget.session.token,
        startDate: _range?.start,
        endDate: _range?.end,
      );
      if (rows.isEmpty) {
        _showMessage('Seçilen aralıkta rapor verisi yok.');
        return;
      }
      final fileName = _fileName();
      final bytes = _buildExcel(rows);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(bytes),
              name: fileName,
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            ),
          ],
          fileNameOverrides: [fileName],
          text: 'Moper giriş çıkış raporu',
        ),
      );
    } on ApiFailure catch (error) {
      _showMessage(error.message);
    } catch (error) {
      _showMessage('Rapor oluşturulamadı: $error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  List<int> _buildExcel(List<ReportRow> rows) {
    final excel = Excel.createExcel();
    const sheetName = 'Giris_Cikis_Raporu';
    final sheet = excel[sheetName];
    final headers = [
      'Personel',
      'Kullanıcı',
      'Tarih',
      'Saat',
      'Durum',
      'Enlem',
      'Boylam',
      'Accuracy',
    ];
    for (final (index, header) in headers.indexed) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: index, rowIndex: 0),
        TextCellValue(header),
      );
    }
    for (final (rowIndex, row) in rows.indexed) {
      final values = [
        row.fullName,
        row.username,
        _dateFormat.format(row.serverTime),
        DateFormat('HH:mm:ss').format(row.serverTime),
        row.type == 'check_in' ? 'Giriş' : 'Çıkış',
        row.latitude.toStringAsFixed(6),
        row.longitude.toStringAsFixed(6),
        row.accuracy.toStringAsFixed(1),
      ];
      for (final (columnIndex, value) in values.indexed) {
        sheet.updateCell(
          CellIndex.indexByColumnRow(
            columnIndex: columnIndex,
            rowIndex: rowIndex + 1,
          ),
          TextCellValue(value),
        );
      }
    }
    return excel.encode() ?? <int>[];
  }

  String _fileName() {
    final start = _range == null
        ? 'tum'
        : DateFormat('yyyyMMdd').format(_range!.start);
    final end = _range == null
        ? 'zamanlar'
        : DateFormat('yyyyMMdd').format(_range!.end);
    return 'moper_giris_cikis_${start}_$end.xlsx';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final rangeLabel = _range == null
        ? 'Tüm tarihler'
        : '${_dateFormat.format(_range!.start)} - ${_dateFormat.format(_range!.end)}';
    return Scaffold(
      appBar: AppBar(
        title: const Text('IK Admin Paneli'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading ? null : _loadUsers,
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
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(rangeLabel),
                ),
                OutlinedButton.icon(
                  onPressed: _range == null
                      ? null
                      : () => setState(() => _range = null),
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Filtreyi temizle'),
                ),
                FilledButton.icon(
                  onPressed: _exporting ? null : _exportReport,
                  icon: _exporting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.ios_share),
                  label: const Text('Excel raporu'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_users.isEmpty)
              const _EmptyState()
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 760;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _users.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: wide ? 2 : 1,
                      mainAxisExtent: 116,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemBuilder: (context, index) => _UserCard(
                      user: _users[index],
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => UserEventsPage(
                              api: widget.api,
                              token: widget.session.token,
                              user: _users[index],
                              initialRange: _range,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onTap});

  final AppUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final working = user.currentStatus == 'working';
    final color = working
        ? Theme.of(context).colorScheme.tertiary
        : Theme.of(context).colorScheme.primary;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                foregroundColor: color,
                child: Text(
                  user.fullName.isEmpty
                      ? '?'
                      : user.fullName.characters.first.toUpperCase(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      working ? 'Çalışıyor' : 'Çalışmıyor',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(
              Icons.group_off_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Kullanıcı bulunamadı.')),
          ],
        ),
      ),
    );
  }
}
