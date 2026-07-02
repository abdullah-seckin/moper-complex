import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';

class UserEventsPage extends StatefulWidget {
  const UserEventsPage({
    super.key,
    required this.api,
    required this.token,
    required this.user,
    this.initialRange,
  });

  final ApiClient api;
  final String token;
  final AppUser user;
  final DateTimeRange? initialRange;

  @override
  State<UserEventsPage> createState() => _UserEventsPageState();
}

class _UserEventsPageState extends State<UserEventsPage> {
  final _dateFormat = DateFormat('dd.MM.yyyy');
  final _timeFormat = DateFormat('HH:mm:ss');
  DateTimeRange? _range;
  List<AttendanceEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange;
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _loading = true);
    try {
      final events = await widget.api.userEvents(
        token: widget.token,
        userId: widget.user.id,
        startDate: _range?.start,
        endDate: _range?.end,
      );
      setState(() => _events = events);
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
    if (picked != null) {
      setState(() => _range = picked);
      await _loadEvents();
    }
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
        title: Text(widget.user.fullName),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: _loading ? null : _loadEvents,
            icon: const Icon(Icons.refresh),
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
              children: [
                FilledButton.tonalIcon(
                  onPressed: _pickRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(rangeLabel),
                ),
                OutlinedButton.icon(
                  onPressed: _range == null
                      ? null
                      : () async {
                          setState(() => _range = null);
                          await _loadEvents();
                        },
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Filtreyi temizle'),
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
            else if (_events.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Bu aralıkta giriş/çıkış kaydı yok.'),
                ),
              )
            else
              ..._events.map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _EventCard(
                    event: event,
                    dateFormat: _dateFormat,
                    timeFormat: _timeFormat,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.dateFormat,
    required this.timeFormat,
  });

  final AttendanceEvent event;
  final DateFormat dateFormat;
  final DateFormat timeFormat;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(event.latitude, event.longitude);
    final isCheckIn = event.type == 'check_in';
    final color = isCheckIn
        ? Theme.of(context).colorScheme.tertiary
        : Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isCheckIn ? Icons.login : Icons.logout, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${event.typeLabel} - ${dateFormat.format(event.serverTime)} ${timeFormat.format(event.serverTime)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text('${event.accuracy.toStringAsFixed(0)} m'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 170,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: 16,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.abdullahseckin.mopercomplex',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.location_pin,
                            color: color,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _openMap(event.latitude, event.longitude),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Haritada aç'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMap(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
